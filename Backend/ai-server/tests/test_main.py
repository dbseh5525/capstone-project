from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health() -> None:
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


@patch("app.main.gemini_service.generate_family_message", return_value="가족에게 보여줄 메시지")
@patch("app.main.gemini_service.generate_self_message", return_value="본인에게 보여줄 메시지")
@patch("app.main.get_classifier")
def test_analyze_mood_success(mock_get_classifier, mock_self, mock_family) -> None:
    mock_get_classifier.return_value.predict.return_value = "슬픔"

    resp = client.post(
        "/analyze-mood",
        json={
            "mood_text": "저녁을 같이 먹기로 했는데 다들 바빠서 결국 혼자 먹었다.",
            "mood_tag": "슬픔",
            "user_role": "딸",
            "family_roles": ["아빠", "엄마"],
        },
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body == {
        "ai_emotion": "슬픔",
        "self_message": "본인에게 보여줄 메시지",
        "family_message": "가족에게 보여줄 메시지",
        "family_roles": ["아빠", "엄마"],
    }
    # 가족 구성원 수와 무관하게 emotion 분류와 메시지 생성은 각각 1번씩만 호출되어야 한다
    mock_self.assert_called_once()
    mock_family.assert_called_once()


def test_analyze_mood_rejects_empty_text() -> None:
    resp = client.post(
        "/analyze-mood",
        json={"mood_text": "", "mood_tag": "슬픔", "user_role": "딸"},
    )
    assert resp.status_code == 422


@patch("app.main.gemini_service.generate_self_message")
@patch("app.main.get_classifier")
def test_analyze_mood_rate_limited(mock_get_classifier, mock_self) -> None:
    from google.genai import errors as genai_errors

    mock_get_classifier.return_value.predict.return_value = "슬픔"
    mock_self.side_effect = genai_errors.APIError(
        429, {"error": {"message": "rate limited", "status": "RESOURCE_EXHAUSTED"}}
    )

    resp = client.post(
        "/analyze-mood",
        json={"mood_text": "오늘 힘들었다", "mood_tag": "슬픔", "user_role": "딸"},
    )

    assert resp.status_code == 429
