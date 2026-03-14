from __future__ import annotations

import base64
import json
import re
from dataclasses import asdict, dataclass

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from app.config import settings


def _bedrock():
    return boto3.client(
        "bedrock-runtime",
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )


ANALYSIS_PROMPT = """You are an AI expert in air pollution analysis for Bengaluru, India.
Analyze this pollution photo and return ONLY valid JSON:

{
  "severity": "CRITICAL | HIGH | MODERATE | LOW",
  "severity_score": 1-10,
  "pollution_type": "Vehicle Exhaust | Construction Dust | Industrial Smoke | Garbage Burning | Open Burning | Chemical Emissions | Dust Pollution | Mixed Pollution",
  "health_risk": "1-2 sentences about health risks for Bengaluru residents",
  "description": "2-3 sentences describing the pollution in the photo",
  "confidence": 0.0-1.0,
  "recommendations": ["action 1", "action 2", "action 3"],
  "estimated_aqi_impact": "Low | Moderate | High | Severe",
  "affected_groups": ["general public", "children", "elderly", "respiratory patients"]
}

Severity for Bengaluru:
CRITICAL: Dense industrial smoke, large garbage fires, severe haze blocking visibility
HIGH: Heavy vehicle exhaust, multiple sources, visible thick smoke
MODERATE: Moderate traffic fumes, small fires, construction dust cloud
LOW: Minor pollution, single source, light dust

Return ONLY JSON. No markdown."""


@dataclass
class AnalysisPayload:
    severity: str
    pollution_type: str
    health_risk: str
    description: str
    confidence: float
    recommendations: list[str]
    complaint_letter: str
    severity_score: int = 5

    def as_response(self) -> dict[str, object]:
        return asdict(self)


def analyze_pollution_photo(image_bytes: bytes, area: str = "Bengaluru") -> dict:
    """Nova Lite multimodal analysis of pollution photo."""
    if not settings.use_bedrock:
        return _fallback_analysis_dict(area)

    bedrock = _bedrock()
    body = {
        "messages": [
            {
                "role": "user",
                "content": [
                    {"text": ANALYSIS_PROMPT.replace("Bengaluru", area)},
                    {
                        "image": {
                            "format": "jpeg",
                            "source": {"bytes": base64.b64encode(image_bytes).decode()},
                        }
                    },
                ],
            }
        ],
        "inferenceConfig": {"temperature": 0.2, "maxTokens": 1024},
    }
    try:
        resp = bedrock.invoke_model(
            modelId=settings.NOVA_LITE_MODEL_ID,
            body=json.dumps(body),
            contentType="application/json",
            accept="application/json",
        )
        text = _extract_message_text(resp["body"].read())
        text = re.sub(r"```json\s*|\s*```", "", text).strip()
        return json.loads(extract_json_block(text))
    except Exception:
        return _fallback_analysis_dict(area)


def generate_complaint_letter(
    area: str,
    severity: str,
    pollution_type: str,
    description: str,
    latitude: float,
    longitude: float,
) -> str:
    """Nova Lite generates formal KSPCB + BBMP complaint letter."""
    if not settings.use_bedrock:
        return _fallback_letter(area, severity, pollution_type, description, latitude, longitude)

    bedrock = _bedrock()
    prompt = f"""Write a formal complaint letter to KSPCB (Karnataka State Pollution Control Board) and BBMP about air pollution in Bengaluru.

Details:
- Location: {area}, Bengaluru (GPS: {latitude:.4f}, {longitude:.4f})
- Severity: {severity}
- Pollution Type: {pollution_type}
- Observation: {description}

Requirements:
1. Salutation: "The Chairman, KSPCB & The Commissioner, BBMP"
2. Date: March 2026
3. Subject line referencing location and pollution type
4. 2-3 paragraphs describing the issue
5. Cite: Air (Prevention and Control of Pollution) Act 1981, Environment Protection Act 1986
6. Demand: Immediate inspection, fines, and corrective action within 7 days
7. Close: "Yours faithfully, A Concerned Citizen of Bengaluru"

Return ONLY the letter text."""

    body = {
        "messages": [{"role": "user", "content": [{"text": prompt}]}],
        "inferenceConfig": {"temperature": 0.3, "maxTokens": 600},
    }
    try:
        resp = bedrock.invoke_model(
            modelId=settings.NOVA_LITE_MODEL_ID,
            body=json.dumps(body),
            contentType="application/json",
            accept="application/json",
        )
        return _extract_message_text(resp["body"].read()).strip()
    except Exception:
        return _fallback_letter(area, severity, pollution_type, description, latitude, longitude)


class BedrockAnalysisService:
    async def analyze_report(
        self,
        *,
        image_bytes: bytes,
        area: str,
        description: str | None,
    ) -> AnalysisPayload:
        analysis = analyze_pollution_photo(image_bytes, area)
        complaint_letter = generate_complaint_letter(
            area=area,
            severity=str(analysis.get("severity", "MODERATE")),
            pollution_type=str(analysis.get("pollution_type", "Mixed Pollution")),
            description=str(analysis.get("description", description or "")),
            latitude=12.9716,
            longitude=77.5946,
        )
        return AnalysisPayload(
            severity=str(analysis.get("severity", "MODERATE")).upper(),
            severity_score=int(analysis.get("severity_score", 5)),
            pollution_type=str(analysis.get("pollution_type", "Mixed Pollution")),
            health_risk=str(analysis.get("health_risk", "Potential respiratory irritation.")),
            description=str(analysis.get("description", description or "Pollution detected.")),
            confidence=float(analysis.get("confidence", 0.6)),
            recommendations=list(analysis.get("recommendations", [])) or [
                "Report to KSPCB",
                "Wear N95 mask",
                "Avoid the area",
            ],
            complaint_letter=complaint_letter,
        )


def _extract_message_text(raw_body: bytes) -> str:
    try:
        decoded = json.loads(raw_body.decode("utf-8"))
    except Exception:
        return raw_body.decode("utf-8", errors="ignore")
    output = decoded.get("output", {})
    message = output.get("message", {})
    content = message.get("content", [])
    if content and isinstance(content, list):
        first = content[0]
        if isinstance(first, dict) and "text" in first:
            return str(first["text"])
    return raw_body.decode("utf-8", errors="ignore")


def _fallback_analysis_dict(area: str) -> dict:
    return {
        "severity": "MODERATE",
        "severity_score": 5,
        "pollution_type": "Mixed Pollution",
        "health_risk": f"Potential respiratory irritation for sensitive groups in {area}.",
        "description": f"Visible pollution indicators detected near {area}. Manual review is recommended.",
        "confidence": 0.6,
        "recommendations": ["Report to KSPCB", "Wear N95 mask", "Avoid the area"],
        "estimated_aqi_impact": "Moderate",
        "affected_groups": ["general public"],
    }


def _fallback_letter(
    area: str,
    severity: str,
    pollution_type: str,
    description: str,
    latitude: float,
    longitude: float,
) -> str:
    return (
        "The Chairman, KSPCB & The Commissioner, BBMP\n"
        "March 2026\n\n"
        f"Subject: Complaint regarding {pollution_type} in {area}, Bengaluru\n\n"
        f"I am writing to report a {severity.lower()} air pollution issue in {area}, Bengaluru "
        f"at coordinates {latitude:.4f}, {longitude:.4f}. {description}\n\n"
        "This issue requires urgent inspection under the Air (Prevention and Control of Pollution) Act 1981 "
        "and the Environment Protection Act 1986. I request immediate inspection, fines where applicable, "
        "and corrective action within 7 days.\n\n"
        "Yours faithfully,\n"
        "A Concerned Citizen of Bengaluru"
    )


def extract_json_block(text: str) -> str:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    return match.group(0) if match else text


analysis_service = BedrockAnalysisService()
