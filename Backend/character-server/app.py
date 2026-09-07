# -*- coding: utf-8 -*-
"""강아지 마스코트 캐릭터 생성 서버.

emotion/photo.ipynb를 정리해서 옮긴 것. Stable Diffusion 1.5 + rembg로 견종/색상/성격
설명을 받아 배경이 지워진 강아지 캐릭터 PNG를 생성한다.

GPU가 필요해서 (Colab 등에서) 별도로 띄우고, mira 앱에서는
CharacterServerService가 이 서버의 베이스 URL을 가리키게 설정한다.
자세한 실행 방법은 README.md 참고.

## 사진 기반 생성은 포기했다
초기엔 사용자가 올린 실제 반려견 사진을 img2img 기준 이미지로 써서 "그 강아지를
닮은" 캐릭터를 만들려고 했지만, SD1.5는 이 용도로 학습된 모델이 아니라서 결과가
사진마다 들쭉날쭉했다 — strength를 조금만 올리면 형태가 깨지고, 낮추면 스타일 변환
없이 사진을 그대로 잘라붙인 것처럼 나왔다. 실제로 그 강아지를 닮게 하려면
dog_lora_colab.ipynb처럼 LoRA를 따로 학습시켜야 하는데, 이건 GPU로 몇십 분 걸리는
오프라인 작업이라 지금 구조엔 안 맞는다 (Backend/character-server/README.md 참고).

그래서 지금은 사진 업로드 여부와 무관하게 항상 `assets/dog/baby_idle.png`(기존
강아지방 캐릭터)를 img2img 기준 이미지로 쓰고, 품종/색상/성격은 텍스트로만 반영한다.
사진 업로드는 여전히 ai-server의 /analyze-pet-photo(품종·색상 텍스트 추출)에만
쓰인다 — 이 서버는 그 텍스트만 받는다.

원본 노트북의 한글 딕셔너리 키가 인코딩 손상으로 복구 불가능했어서
(BREED_MAP 등의 키) 같은 영어 프롬프트에 대응하는 한국어 표기를 새로 정리했다.
"""

import io
import os
import threading

from flask import Flask, request, send_file
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Frontend/mira/assets/dog/baby_idle.png — 기존 강아지방 캐릭터, img2img 기준 이미지.
_APP_DIR = os.path.dirname(os.path.abspath(__file__))
REFERENCE_IMAGE_PATH = os.path.normpath(
    os.path.join(_APP_DIR, "..", "..", "Frontend", "mira", "assets", "dog", "baby_idle.png")
)

# 실제 모델(파이프라인)은 첫 요청 전에 무겁게 로드되므로 지연 초기화한다.
# 이 모듈만 import해서 BREED_MAP 등을 테스트하거나 재사용할 수 있게 하기 위함.
_img2img_pipe = None
_bg_session = None
_ref_image = None
_lock = threading.Lock()


def _get_pipeline():
    """(img2img 파이프라인, rembg 세션, 기준 이미지) 반환. 첫 호출 때만 무겁게 로드."""
    global _img2img_pipe, _bg_session, _ref_image
    if _img2img_pipe is not None:
        return _img2img_pipe, _bg_session, _ref_image
    with _lock:
        if _img2img_pipe is None:
            import torch
            from diffusers import (
                StableDiffusionPipeline,
                StableDiffusionImg2ImgPipeline,
                DPMSolverMultistepScheduler,
            )
            from rembg import new_session
            from PIL import Image

            base_pipe = StableDiffusionPipeline.from_pretrained(
                "runwayml/stable-diffusion-v1-5",
                torch_dtype=torch.float16,
                safety_checker=None,
            ).to("cuda")
            base_pipe.scheduler = DPMSolverMultistepScheduler.from_config(
                base_pipe.scheduler.config
            )
            _img2img_pipe = StableDiffusionImg2ImgPipeline(**base_pipe.components)
            _bg_session = new_session("u2net")

            ref_raw = Image.open(REFERENCE_IMAGE_PATH).convert("RGBA")
            white_bg = Image.new("RGBA", ref_raw.size, (255, 255, 255, 255))
            _ref_image = Image.alpha_composite(white_bg, ref_raw).convert("RGB").resize((512, 512))
    return _img2img_pipe, _bg_session, _ref_image


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

# baby_idle.png를 기준으로 시작해서 텍스트로 품종/색상/성격만 바꾸는 img2img 강도.
# 0.68+ : 형태가 쉽게 깨짐 (색 이상해지거나 기형으로 나옴)
# 0.5 이하: 원본(흰 포메라니안)에서 거의 안 벗어남
# 0.6이 여러 견종으로 테스트했을 때 가장 안정적이었다.
IMG2IMG_STRENGTH = 0.6


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

    # Frontend/mira/assets/dog/*.png(기존 강아지방 캐릭터)와 스타일을 맞춘다 — 부드러운
    # 카툰풍 일러스트(굵은 테두리의 플랫 벡터도, 실사 3D 렌더도 아님). img2img 기준
    # 이미지(baby_idle.png)와 함께 써야 이 스타일이 안정적으로 나온다 (build_prompt만
    # txt2img로 단독으로 쓰면 결과가 매번 크게 달라진다).
    prompt = (
        f"full body chibi {color} {breed} puppy standing on four legs, "
        "cute cartoon illustration, simple flat shading, "
        "big round eyes, blush pink cheeks, smiling open mouth, fluffy fur, "
        f"{personality}, "
        "isolated on plain white background, no border, no frame, no shadow"
    )
    negative_prompt = (
        "badge, circular frame, decorative border, polka dot, vignette, "
        "colorful background, pattern background, sticker border, frame, "
        "cropped, close up, head only, face only, portrait, no body, "
        "3d render, photorealistic, realistic photo, photograph, detailed realistic fur, "
        "bear, teddy bear, cat, feline, whiskers, "
        "collar, tag, accessories, "
        "humanoid, ground, multiple animals, "
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

    img2img_pipe, bg_session, ref_image = _get_pipeline()
    generator = torch.Generator(device="cuda").manual_seed(seed)
    img = img2img_pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        image=ref_image,
        strength=IMG2IMG_STRENGTH,
        guidance_scale=7.5,
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
