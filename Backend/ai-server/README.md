# ai-server

감정 분석(klue/bert-base) + Gemini 공감 메시지 생성 FastAPI 서버.

## 실행

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # 값 채우기
uvicorn app.main:app --reload --port 8000
```

## 감정 분석 모델

`EMOTION_MODEL_PATH` 환경변수는 로컬 디렉터리 경로 또는 Hugging Face Hub repo id를 받습니다 (`transformers`의 `from_pretrained`에 그대로 전달됩니다).

Colab에서 학습한 파인튜닝 모델(`klue/bert-base` 기반, 6-class: 불안/분노/상처/슬픔/당황/기쁨)을 Hugging Face Hub의 private repo에 업로드하고 그 repo id를 넣어주세요. 지정하지 않으면 파인튜닝되지 않은 기본 `klue/bert-base`가 로드되어 감정 분류가 제대로 동작하지 않습니다.

## 엔드포인트

### `POST /analyze-mood`

```json
{
  "mood_text": "저녁을 같이 먹기로 했는데 다들 바빠서 결국 혼자 먹었다.",
  "mood_tag": "슬픔",
  "user_role": "딸",
  "family_roles": ["아빠", "엄마"]
}
```

```json
{
  "ai_emotion": "슬픔",
  "self_message": "...",
  "family_message": "...",
  "family_roles": ["아빠", "엄마"]
}
```

`family_message`는 발신자 역할만 반영하고 수신자별로 내용이 달라지지 않으므로, 가족 구성원 수와 무관하게 감정 분석 1회 + 메시지 생성 2회(본인용/가족용)만 호출하고 모든 `family_roles`가 결과를 공유한다.

### `GET /health`

상태 확인용.

## 테스트

```bash
pytest
```

`get_classifier`와 `gemini_service`를 모킹하므로 실제 모델 가중치나 `GEMINI_API_KEY` 없이도 실행됩니다.
