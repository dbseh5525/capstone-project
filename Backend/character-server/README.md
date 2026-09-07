# character-server

`emotion/photo.ipynb`를 옮긴 강아지 마스코트 캐릭터 생성 서버 (Stable Diffusion 1.5 + rembg).
GPU가 필요해서 `ai-server`(FastAPI, CPU로 충분)와 분리했다.

## 이 서버가 하는 일 / 안 하는 일

- `POST /generate` — 견종/색상/성격(한국어 텍스트) + seed를 받아 배경을 지운 챗봇 스타일 강아지 캐릭터 PNG 한 장을 반환한다. `emotion/photo.ipynb`의 로직 그대로.
- `emotion/FINAL.ipynb`처럼 **업로드한 실제 사진으로 LoRA를 파인튜닝해서 그 강아지를 닮은 캐릭터를 만드는 것은 포함하지 않는다.** LoRA 학습은 GPU로 몇 분~수십 분이 걸리는 별도의 오프라인 작업이라 앱의 실시간 흐름에 넣기 어렵다 (원본 `dog_lora_colab.ipynb` 참고).
  - 대신 앱의 "사진으로 만들기" 흐름은: 사진 업로드 → `Backend/ai-server`의 `/analyze-pet-photo`(Gemini Vision)로 품종/색상 텍스트 추출 → 그 텍스트를 이 서버의 `/generate`에 그대로 넘겨서 캐릭터를 만든다. 사용자의 특정 반려견과 완전히 똑같지는 않지만, 실시간으로 동작하는 현실적인 절충안이다.
  - 나중에 실제 반려견을 닮은 캐릭터가 필요해지면 `dog_lora_colab.ipynb`로 오프라인 학습 후 이 서버의 `pipe.load_lora_weights(...)`를 FINAL.ipynb처럼 추가하면 된다.

## 실행 (Colab 권장 — GPU 필요)

로컬에 CUDA GPU가 없다면 Colab에서 실행하고 ngrok로 터널링한다.

```python
# Colab 셀
!git clone https://github.com/kikimiya0606/capstone-project.git
%cd capstone-project/Backend/character-server
!pip install -q -r requirements.txt

from google.colab import userdata
from pyngrok import ngrok

# ngrok 토큰은 노트북에 평문으로 적지 말고 Colab Secrets(왼쪽 사이드바 열쇠 아이콘)에
# NGROK_AUTHTOKEN이라는 이름으로 등록해서 불러온다.
# (Backend/API/claude API 연동.ipynb에서 평문 토큰이 노출됐던 사고 이후로 이 방식으로 통일함 — BACKEND_STATUS.md 참고)
ngrok.set_auth_token(userdata.get('NGROK_AUTHTOKEN'))
public_url = ngrok.connect(5000)
print("API URL:", public_url)

!python app.py
```

`public_url`로 나온 주소(`https://xxxx.ngrok-free.dev`)를 mira 앱의
`Frontend/mira/lib/services/character_server_service.dart`에 있는
`_characterServerBaseUrl`에 넣어주면 된다.

로컬에 CUDA GPU가 있다면 그냥:

```bash
pip install -r requirements.txt
python app.py
```

## API

### `POST /generate`

`multipart/form-data`:

| 필드 | 설명 | 기본값 |
|---|---|---|
| breed | 견종 (한국어, 부분 일치 허용) | 포메라니안 |
| color | 색상 (한국어) | 흰색 |
| personality | 성격 (한국어, mira 앱의 PetSetup 선택지와 동일) | 활발함 |
| seed | 정수. 같은 값이면 같은 이미지 재생성 | 42 |

응답: `image/png` 바이너리.

### `GET /health`

상태 확인용.

## 참고

- 지원하는 한국어 표현은 `app.py`의 `BREED_MAP` / `COLOR_MAP` / `PERSONALITY_MAP`에 정의돼 있다. 목록에 없는 표현이 오면 부분 일치를 시도하고, 그래도 없으면 기본값으로 대체한다 — Stable Diffusion 1.5의 CLIP 텍스트 인코더가 한국어를 이해하지 못하기 때문에 알 수 없는 한국어를 프롬프트에 그대로 넣으면 결과가 무의미해진다.
- 원본 `emotion/photo.ipynb`는 노트북 파일 자체의 인코딩이 손상돼 있어 한글 딕셔너리 키를 그대로 복구할 수 없었다. 여기 있는 한국어 표기는 영어 프롬프트 값(`pomeranian`, `white` 등)에 맞춰 새로 정리한 것이다.
