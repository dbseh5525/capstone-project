from .config import get_settings

# Backend/백엔드_분석_모델.ipynb 학습 시 사용한 라벨 순서와 반드시 동일해야 함.
LABELS = ["불안", "분노", "상처", "슬픔", "당황", "기쁨"]


class EmotionClassifier:
    def __init__(self, model_path: str) -> None:
        # torch/transformers는 여기서만 import해서 API 레이어와 테스트에 무거운 의존성이 안 붙게 함
        import torch
        from transformers import AutoModelForSequenceClassification, AutoTokenizer

        self._torch = torch
        self.tokenizer = AutoTokenizer.from_pretrained(model_path)
        self.model = AutoModelForSequenceClassification.from_pretrained(model_path)
        self.model.eval()

    def predict(self, text: str) -> str:
        inputs = self.tokenizer(
            text, return_tensors="pt", padding=True, truncation=True, max_length=64
        )
        with self._torch.no_grad():
            logits = self.model(**inputs).logits
        label_id = int(self._torch.argmax(logits, dim=1).item())
        return LABELS[label_id]


_classifier: EmotionClassifier | None = None


def get_classifier() -> EmotionClassifier:
    global _classifier
    if _classifier is None:
        _classifier = EmotionClassifier(get_settings().emotion_model_path)
    return _classifier
