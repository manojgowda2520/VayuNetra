from fastapi import APIRouter, File, Form, UploadFile

from app.schemas import VoiceResponse
from app.services.sonic_service import transcribe_voice


router = APIRouter(prefix="/api", tags=["voice"])


@router.post("/voice", response_model=VoiceResponse)
async def voice(audio: UploadFile = File(...), language: str = Form(default="en")):
    """Nova 2 Sonic — multilingual voice transcription (EN/KN/HI)."""
    return transcribe_voice(await audio.read(), language)
