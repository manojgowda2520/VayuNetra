from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import AliasChoices, BaseModel, ConfigDict, EmailStr, Field

from app.services.s3_service import get_photo_url


class UserRegister(BaseModel):
    name: str = Field(validation_alias=AliasChoices("name", "username"))
    email: Optional[EmailStr] = None
    password: str


class UserLogin(BaseModel):
    email: str
    password: str


class UserOut(BaseModel):
    id: int
    name: str
    email: Optional[str]
    points: int
    badge_level: str
    report_count: int
    created_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

    @classmethod
    def from_user(cls, user):
        return cls(
            id=user.user_id,
            name=user.username,
            email=user.email,
            points=user.points,
            badge_level=user.badge_level,
            report_count=user.report_count,
            created_at=user.registration_date,
        )


class TokenResponse(BaseModel):
    token: str
    user: UserOut


def _severity_to_aqi(severity: str) -> tuple[str, str]:
    """Map severity to (estimated_aqi_impact, estimated_aqi_range)."""
    s = (severity or "MODERATE").upper()
    return {
        "CRITICAL": ("Severe", "201+"),
        "HIGH": ("High", "101–200"),
        "MODERATE": ("Moderate", "51–100"),
        "LOW": ("Low", "0–50"),
    }.get(s, ("Moderate", "51–100"))


class AnalysisOut(BaseModel):
    severity: str
    pollution_type: str
    health_risk: str
    description: str
    confidence: float
    recommendations: List[str]
    complaint_letter: str
    estimated_aqi_impact: str = "Moderate"
    estimated_aqi_range: str = "51–100"


class ReportOut(BaseModel):
    id: int
    user_id: Optional[int]
    area: str
    latitude: float
    longitude: float
    description: Optional[str]
    photo_url: Optional[str]
    status: str
    created_at: datetime
    analysis: Optional[AnalysisOut] = None

    @classmethod
    def from_report(cls, report):
        analysis = None
        photo_url = get_photo_url(report.image_url, getattr(report, "image_key", None))
        if report.analysis:
            analysis_obj = report.analysis
            severity = analysis_obj.severity.value if getattr(analysis_obj, "severity", None) else "MODERATE"
            aqi_impact, aqi_range = _severity_to_aqi(severity)
            resolved_pollution_type = analysis_obj.pollution_type
            pollution_type = resolved_pollution_type or analysis_obj.analysis_notes or "Unknown"
            analysis = AnalysisOut(
                severity=severity,
                pollution_type=pollution_type,
                health_risk=analysis_obj.health_risk or "",
                description=analysis_obj.full_description or analysis_obj.analysis_notes or "",
                confidence=analysis_obj.confidence_score or 0.8,
                recommendations=analysis_obj.recommendations or [],
                complaint_letter=analysis_obj.complaint_letter or "",
                estimated_aqi_impact=aqi_impact,
                estimated_aqi_range=aqi_range,
            )
        status = report.status.value if getattr(report.status, "value", None) else str(report.status or "analyzed")
        return cls(
            id=report.report_id,
            user_id=report.user_id,
            area=report.address_text or "",
            latitude=report.latitude,
            longitude=report.longitude,
            description=report.description,
            photo_url=photo_url,
            status=status,
            created_at=report.report_date,
            analysis=analysis,
        )


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    conversation_history: Optional[List[ChatMessage]] = []


class ChatResponse(BaseModel):
    response: str
    tools_used: List[str] = []


class StatsOut(BaseModel):
    total: int
    today: int
    areas: int
    critical: int
    high: int
    moderate: int
    low: int


class LeaderboardEntry(BaseModel):
    id: int
    name: str
    email: Optional[str]
    report_count: int
    points: int
    badge_level: str


class CleanZoneOut(BaseModel):
    id: int
    name: str
    aqi: int
    status: str
    latitude: float
    longitude: float
    activities: Optional[List[str]] = []

    model_config = ConfigDict(from_attributes=True)


class LiveCleanZoneOut(BaseModel):
    """Clean zone with live AQI from Google Air Quality API (no id)."""
    name: str
    aqi: int
    status: str
    latitude: float
    longitude: float
    activities: List[str] = []


class VoiceResponse(BaseModel):
    transcription: str
    language: str
    confidence: float


class NovaActResponse(BaseModel):
    status: str
    reference_number: Optional[str]
    message: str
    nova_act_used: bool
    complaint_letter: Optional[str] = None
    kspcb_portal: Optional[str] = None
