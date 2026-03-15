from __future__ import annotations

import base64
import json
import logging

import boto3

from app.config import settings

logger = logging.getLogger("vayunetra")


def _bedrock():
    return boto3.client(
        "bedrock-runtime",
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )


LANG_PROMPTS = {
    "en": "Transcribe this English audio recording about air pollution in Bengaluru, India. Return only the transcribed text.",
    "kn": "ಈ ಕನ್ನಡ ಧ್ವನಿ ರೆಕಾರ್ಡಿಂಗ್ ಅನ್ನು ಬರಹ ರೂಪಕ್ಕೆ ಪರಿವರ್ತಿಸಿ. (Transcribe this Kannada audio about pollution. Return transcribed text only.)",
    "hi": "इस हिंदी ऑडियो को टेक्स्ट में बदलें जो प्रदूषण के बारे में है। (Transcribe this Hindi audio about pollution. Return transcribed text only.)",
}


def transcribe_voice(audio_bytes: bytes, language: str = "en") -> dict:
    """Nova Sonic transcription for EN/KN/HI with graceful fallback."""
    normalized_language = (language or "en").strip().lower()
    if not settings.use_bedrock:
        transcript = _fallback_transcript(normalized_language)
        return {"transcription": transcript, "language": normalized_language, "confidence": 0.8}

    bedrock = _bedrock()
    prompt = LANG_PROMPTS.get(normalized_language, LANG_PROMPTS["en"])
    body = {
        "messages": [
            {
                "role": "user",
                "content": [
                    {"text": prompt},
                    {
                        "audio": {
                            "format": "wav",
                            "source": {"bytes": base64.b64encode(audio_bytes).decode()},
                        }
                    },
                ],
            }
        ],
        "inferenceConfig": {"temperature": 0.1, "maxTokens": 300},
    }
    try:
        resp = bedrock.invoke_model(
            modelId=settings.NOVA_SONIC_MODEL_ID,
            body=json.dumps(body),
            contentType="application/json",
            accept="application/json",
        )
        decoded = json.loads(resp["body"].read().decode("utf-8"))
        transcription = decoded["output"]["message"]["content"][0]["text"].strip()
        return {"transcription": transcription, "language": normalized_language, "confidence": 0.92}
    except Exception as e:
        logger.warning("Bedrock Nova Sonic transcribe_voice failed: %s", e)
        transcript = _fallback_transcript(normalized_language)
        return {"transcription": transcript, "language": normalized_language, "confidence": 0.8}


def _fallback_transcript(language: str) -> str:
    if language.startswith("kn"):
        return "ಧ್ವನಿ ವರದಿ ಸ್ವೀಕರಿಸಲಾಗಿದೆ. ದಯವಿಟ್ಟು ಪ್ರದೇಶದ ಹೆಸರು ಮತ್ತು ಸಮಸ್ಯೆಯನ್ನು ದೃಢಪಡಿಸಿ."
    if language.startswith("hi"):
        return "आवाज़ रिपोर्ट प्राप्त हुई। कृपया क्षेत्र और प्रदूषण की जानकारी की पुष्टि करें।"
    return "Voice report received. Please confirm the area and pollution issue."


class SonicService:
    async def transcribe(self, *, audio_bytes: bytes, language: str) -> dict[str, str | float]:
        response = transcribe_voice(audio_bytes, language)
        transcript = response["transcription"]
        return {
            "text": transcript,
            "transcript": transcript,
            "language": response["language"],
        }


sonic_service = SonicService()
