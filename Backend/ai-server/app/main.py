from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from google.genai import errors as genai_errors

from . import gemini_service
from .config import get_settings
from .emotion_model import get_classifier
from .schemas import MoodAnalysisRequest, MoodAnalysisResponse, PetPhotoAnalysisResponse

app = FastAPI(title="AI Family Emotion Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/analyze-mood", response_model=MoodAnalysisResponse)
def analyze_mood(req: MoodAnalysisRequest) -> MoodAnalysisResponse:
    ai_emotion = get_classifier().predict(req.mood_text)

    try:
        self_message = gemini_service.generate_self_message(
            req.mood_text, req.user_role, req.mood_tag, ai_emotion
        )
        family_message = gemini_service.generate_family_message(
            req.mood_text, req.user_role, req.mood_tag, ai_emotion
        )
    except genai_errors.APIError as exc:
        if exc.code == 429:
            raise HTTPException(status_code=429, detail="Gemini API rate limited") from exc
        raise HTTPException(status_code=502, detail=f"Gemini API error: {exc.message}") from exc

    return MoodAnalysisResponse(
        ai_emotion=ai_emotion,
        self_message=self_message,
        family_message=family_message,
        family_roles=req.family_roles,
    )


@app.post("/analyze-pet-photo", response_model=PetPhotoAnalysisResponse)
async def analyze_pet_photo(images: list[UploadFile] = File(...)) -> PetPhotoAnalysisResponse:
    if not images:
        raise HTTPException(status_code=422, detail="사진을 1장 이상 첨부해주세요.")
    if len(images) > 5:
        raise HTTPException(status_code=422, detail="사진은 최대 5장까지 가능해요.")

    image_bytes = [await image.read() for image in images]

    try:
        result = gemini_service.analyze_pet_photos(image_bytes)
    except genai_errors.APIError as exc:
        if exc.code == 429:
            raise HTTPException(status_code=429, detail="Gemini API rate limited") from exc
        raise HTTPException(status_code=502, detail=f"Gemini API error: {exc.message}") from exc

    return PetPhotoAnalysisResponse(
        breed=result["breed"],
        color_description=result["color_description"],
    )
