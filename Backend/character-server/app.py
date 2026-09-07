# -*- coding: utf-8 -*-
"""강아지 마스코트 캐릭터 생성 서버.

emotion/photo.ipynb를 정리해서 옮긴 것. Stable Diffusion 1.5 + rembg로 견종/색상/성격
설명을 받아 배경이 지워진 챗봇 스타일 강아지 캐릭터 PNG를 생성한다.

GPU가 필요해서 (Colab 등에서) 별도로 띄우고, mira 앱에서는
CharacterServerService가 이 서버의 베이스 URL을 가리키게 설정한다.
자세한 실행 방법은 README.md 참고.

원본 노트북의 한글 딕셔너리 키가 인코딩 손상으로 복구 불가능했어서
(BREED_MAP 등의 키) 같은 영어 프롬프트에 대응하는 한국어 표기를 새로 정리했다.
"""

import io
import threading

from flask import Flask, request, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# 실제 모델(파이프라인)은 첫 요청 전에 무겁게 로드되므로 지연 초기화한다.
# 이 모듈만 import해서 BREED_MAP 등을 테스트하거나 재사용할 수 있게 하기 위함.
_pipe = None
_bg_session = None
_lock = threading.Lock()


def _get_pipeline():
    global _pipe, _bg_session
    if _pipe is not None:
        return _pipe, _bg_session
    with _lock:
        if _pipe is None:
            import torch
            from diffusers import StableDiffusionPipeline, DPMSolverMultistepScheduler
            from rembg import new_session

            pipe = StableDiffusionPipeline.from_pretrained(
                "runwayml/stable-diffusion-v1-5",
                torch_dtype=torch.float16,
                safety_checker=None,
            ).to("cuda")
            pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config)
            _pipe = pipe
            _bg_session = new_session("u2net")
    return _pipe, _bg_session


# 견종/색상/성격 한국어 표현 -> 영어 프롬프트 조각.
# 앱(PetSetup) 화면에서 자유 입력 또는 AI 사진 분석 결과(자유 문장)로 들어오기 때문에
# 정확히 일치하지 않을 수 있어 _lookup()에서 부분 일치까지 시도한다.
BREED_MAP = {
    "포메라니안": "pomeranian",
    "골든리트리버": "golden retriever",
    "시바견": "shiba inu",
    "푸들": "poodle",
    "토이푸들": "toy poodle",
    "웰시코기": "corgi",
    "말티즈": "maltese",
    "비숑프리제": "bichon frise",
    "치와와": "chihuahua",
    "닥스훈트": "dachshund",
    "진돗개": "jindo dog",
}

COLOR_MAP = {
    "흰색": "white",
    "화이트": "white",
    "검정": "black",
    "블랙": "black",
    "갈색": "brown",
    "브라운": "brown",
    "크림": "cream beige",
    "베이지": "cream beige",
    "회색": "gray",
    "그레이": "gray",
    "황금색": "golden",
    "황갈색": "golden brown",
    "흑백": "black and white",
    "갈색+흰색": "brown and white",
}

# 앱의 PetSetup 화면에서 실제로 쓰는 성격 칩(활발함/애교쟁이/호기심/차분함)과
# photo.ipynb 원본에 있던 나머지 표현을 함께 지원한다.
PERSONALITY_MAP = {
    "활발함": "energetic pose, big happy smile, excited expression",
    "차분함": "calm sitting pose, gentle smile, peaceful expression",
    "장난꾸러기": "playful pose, mischievous grin, tilted head",
    "애교쟁이": "adorable pose, sparkling big eyes, sweet smile",
    "애교많음": "adorable pose, sparkling big eyes, sweet smile",
    "호기심": "curious pose, head tilted, sparkling curious eyes",
    "당당함": "confident standing pose, proud expression, head up",
    "수줍음": "shy pose, small smile, looking up cutely",
}

DEFAULT_BREED = "포메라니안"
DEFAULT_COLOR = "흰색"
DEFAULT_PERSONALITY = "활발함"


def _lookup(value: str, table: dict, default_key: str) -> str:
    """정확히 일치하면 그대로, 아니면 테이블 키가 value에 포함되는지 부분 일치로 찾는다.
    (AI 사진 분석 결과는 "말티즈로 추정돼요" 같은 완전한 문장일 수 있어서)
    둘 다 실패하면 기본값으로 대체한다 — SD1.5는 한국어 프롬프트를 이해하지 못한다.
    """
    value = (value or "").strip()
    if value in table:
        return table[value]
    for key, prompt_value in table.items():
        if key in value:
            return prompt_value
    return table[default_key]


def build_prompt(breed_kr: str, color_kr: str, personality_kr: str) -> tuple[str, str]:
    breed = _lookup(breed_kr, BREED_MAP, DEFAULT_BREED)
    color = _lookup(color_kr, COLOR_MAP, DEFAULT_COLOR)
    personality = _lookup(personality_kr, PERSONALITY_MAP, DEFAULT_PERSONALITY)

    prompt = (
        f"cute {color} {breed} dog mascot character, {personality}, "
        "flat vector illustration, chibi proportions, "
        "big round eyes, thick black outline, flat colors, "
        "full body, entire body inside frame, "
        "isolated on plain white background, no ground, no shadow, "
        "clean digital illustration"
    )
    negative_prompt = (
        "realistic, photo, photorealistic, 3d render, real fur texture, "
        "cropped, cut off, out of frame, close up, "
        "ground, floor, shadow, object, "
        "text, watermark, logo, deformed, extra limbs, blurry, low quality, ugly"
    )
    return prompt, negative_prompt


@app.get("/health")
def health():
    return {"status": "ok"}


@app.route("/generate", methods=["POST"])
def generate():
    import torch
    from rembg import remove

    breed_kr = request.form.get("breed", DEFAULT_BREED)
    color_kr = request.form.get("color", DEFAULT_COLOR)
    personality_kr = request.form.get("personality", DEFAULT_PERSONALITY)
    seed = int(request.form.get("seed", 42))

    prompt, negative_prompt = build_prompt(breed_kr, color_kr, personality_kr)

    pipe, bg_session = _get_pipeline()
    generator = torch.Generator(device="cuda").manual_seed(seed)
    img = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        guidance_scale=7.5,
        num_inference_steps=30,
        generator=generator,
    ).images[0]

    final = remove(img, session=bg_session)

    buf = io.BytesIO()
    final.save(buf, format="PNG")
    buf.seek(0)
    return send_file(buf, mimetype="image/png")


if __name__ == "__main__":
    # 로컬/Colab에서 직접 실행할 때. 배포 환경에서는 gunicorn 등을 쓰는 걸 권장.
    app.run(host="0.0.0.0", port=5000)
