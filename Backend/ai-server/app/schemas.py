from pydantic import BaseModel, Field


class MoodAnalysisRequest(BaseModel):
    mood_text: str = Field(..., min_length=1, description="사용자가 작성한 한 줄 감정 기록")
    mood_tag: str = Field(..., min_length=1, description="사용자가 직접 선택한 기분 태그")
    user_role: str = Field(..., min_length=1, description="작성자의 가족 내 역할 (예: 딸, 아빠)")
    family_roles: list[str] = Field(
        default_factory=list,
        description="작성자를 제외한 나머지 가족 구성원 역할 목록",
    )


class MoodAnalysisResponse(BaseModel):
    ai_emotion: str
    self_message: str
    family_message: str
    family_roles: list[str]


class PetPhotoAnalysisResponse(BaseModel):
    breed: str
    color_description: str
