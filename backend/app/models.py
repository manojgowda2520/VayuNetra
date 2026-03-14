from __future__ import annotations

import enum

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship, synonym
from sqlalchemy.sql import func

from app.config import settings
from app.database import Base


VectorColumn = Vector(1024) if settings.is_postgres else JSON


class AccountStatusEnum(str, enum.Enum):
    active = "active"
    inactive = "inactive"
    suspended = "suspended"


class ReportStatusEnum(str, enum.Enum):
    submitted = "submitted"
    analyzing = "analyzing"
    analyzed = "analyzed"
    resolved = "resolved"
    rejected = "rejected"


class SeverityEnum(str, enum.Enum):
    low = "LOW"
    moderate = "MODERATE"
    high = "HIGH"
    critical = "CRITICAL"


class PriorityEnum(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"


class HotspotStatusEnum(str, enum.Enum):
    active = "active"
    monitoring = "monitoring"
    resolved = "resolved"


class TrendEnum(str, enum.Enum):
    increasing = "increasing"
    stable = "stable"
    decreasing = "decreasing"


class QueueStatusEnum(str, enum.Enum):
    pending = "pending"
    processing = "processing"
    completed = "completed"
    failed = "failed"


class HazardLevelEnum(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class AdminRoleEnum(str, enum.Enum):
    super_admin = "super_admin"
    admin = "admin"
    moderator = "moderator"


class LogLevelEnum(str, enum.Enum):
    info = "info"
    warning = "warning"
    error = "error"
    critical = "critical"


class User(Base):
    """User accounts — mobile app auth."""

    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=True, index=True)
    phone_number = Column(String(20), nullable=True)
    password_hash = Column(String(255), nullable=False)
    registration_date = Column(DateTime(timezone=True), server_default=func.now())
    last_login = Column(DateTime(timezone=True), nullable=True)
    account_status = Column(Enum(AccountStatusEnum), default=AccountStatusEnum.active)
    profile_image_url = Column(String(255), nullable=True)
    verification_status = Column(Boolean, default=False)
    points = Column(Integer, default=0)
    badge_level = Column(String(50), default="Bronze Guardian")
    report_count = Column(Integer, default=0)
    is_admin = Column(Boolean, default=False)

    reports = relationship("Report", back_populates="user")
    api_keys = relationship("ApiKey", back_populates="creator")
    verifications = relationship("UserVerification", back_populates="user")

    id = synonym("user_id")
    name = synonym("username")
    created_at = synonym("registration_date")


class Location(Base):
    """Predefined Bengaluru areas/zones."""

    __tablename__ = "locations"

    location_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    district = Column(String(100), nullable=True)
    sub_district = Column(String(100), nullable=True)
    latitude = Column(Float(precision=10), nullable=False)
    longitude = Column(Float(precision=11), nullable=False)
    population_estimate = Column(Integer, nullable=True)
    area_sqkm = Column(Float, nullable=True)

    reports = relationship("Report", back_populates="location")
    hotspots = relationship("Hotspot", back_populates="location")


class PollutionType(Base):
    """Pollution type classification."""

    __tablename__ = "pollution_types"

    pollution_type_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)
    description = Column(Text, nullable=True)
    hazard_level = Column(Enum(HazardLevelEnum), default=HazardLevelEnum.medium)
    icon_url = Column(String(255), nullable=True)


class Report(Base):
    """Pollution reports submitted via Flutter mobile app."""

    __tablename__ = "reports"

    report_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=True)
    location_id = Column(Integer, ForeignKey("locations.location_id"), nullable=True)
    latitude = Column(Float(precision=10), nullable=False)
    longitude = Column(Float(precision=11), nullable=False)
    report_date = Column(DateTime(timezone=True), server_default=func.now())
    description = Column(Text, nullable=True)
    status = Column(Enum(ReportStatusEnum), default=ReportStatusEnum.submitted)
    image_url = Column(String(255), nullable=True)
    image_key = Column(String(300), nullable=True)
    device_info = Column(JSON, nullable=True)
    address_text = Column(String(255), nullable=True)

    user = relationship("User", back_populates="reports")
    location = relationship("Location", back_populates="reports")
    analysis = relationship("AnalysisResult", back_populates="report", uselist=False)
    queue = relationship("ImageProcessingQueue", back_populates="report", uselist=False)
    hotspot_reports = relationship("HotspotReport", back_populates="report")

    __table_args__ = (
        Index("idx_reports_location", "latitude", "longitude"),
        Index("idx_reports_status_date", "status", "report_date"),
        Index("idx_reports_user", "user_id"),
    )

    id = synonym("report_id")
    created_at = synonym("report_date")
    photo_url = synonym("image_url")
    area = synonym("address_text")
    owner = synonym("user")
    image_embedding = None


class AnalysisResult(Base):
    """
    AI analysis results from Nova Lite + Nova Embed Image.
    VECTOR(1024) columns are enabled on Postgres and fall back to JSON elsewhere.
    """

    __tablename__ = "analysis_results"

    analysis_id = Column(Integer, primary_key=True, autoincrement=True)
    report_id = Column(Integer, ForeignKey("reports.report_id"), unique=True)
    pollution_type_id = Column(Integer, ForeignKey("pollution_types.pollution_type_id"), nullable=True)
    analyzed_date = Column(DateTime(timezone=True), server_default=func.now())
    confidence_score = Column(Float, nullable=True)
    severity_score = Column(Integer, nullable=True)
    severity = Column(Enum(SeverityEnum), nullable=True)
    priority_level = Column(Enum(PriorityEnum), nullable=True)
    analysis_notes = Column(Text, nullable=True)
    full_description = Column(Text, nullable=True)
    health_risk = Column(Text, nullable=True)
    recommendations = Column(JSON, nullable=True)
    complaint_letter = Column(Text, nullable=True)
    processed_by = Column(String(80), default="us.amazon.nova-2-lite-v1:0")
    image_embedding = Column(VectorColumn, nullable=True)
    location_embedding = Column(VectorColumn, nullable=True)

    report = relationship("Report", back_populates="analysis")
    primary_pollution_type = relationship("PollutionType", foreign_keys=[pollution_type_id])
    pollution_types = relationship("ReportPollutionType", back_populates="analysis")

    __table_args__ = (Index("idx_analysis_date", "analyzed_date"),)

    id = synonym("analysis_id")
    confidence = synonym("confidence_score")
    description = synonym("full_description")

    @property
    def pollution_type(self) -> str:
        if self.primary_pollution_type is not None:
            return self.primary_pollution_type.name
        if self.pollution_types:
            first = self.pollution_types[0]
            if first.pollution_type is not None:
                return first.pollution_type.name
        return "Unknown"


class ReportPollutionType(Base):
    """Many-to-many: one report can have multiple pollution types."""

    __tablename__ = "report_pollution_types"

    id = Column(Integer, primary_key=True, autoincrement=True)
    analysis_id = Column(Integer, ForeignKey("analysis_results.analysis_id"))
    pollution_type_id = Column(Integer, ForeignKey("pollution_types.pollution_type_id"))
    confidence_score = Column(Float, nullable=True)
    percentage = Column(Float, nullable=True)

    analysis = relationship("AnalysisResult", back_populates="pollution_types")
    pollution_type = relationship("PollutionType")


class Hotspot(Base):
    """Geographic clusters of pollution accumulation in Bengaluru."""

    __tablename__ = "hotspots"

    hotspot_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    center_latitude = Column(Float(precision=10), nullable=False)
    center_longitude = Column(Float(precision=11), nullable=False)
    radius_meters = Column(Integer, default=500)
    location_id = Column(Integer, ForeignKey("locations.location_id"), nullable=True)
    first_reported = Column(Date, nullable=True)
    last_reported = Column(Date, nullable=True)
    total_reports = Column(Integer, default=0)
    average_severity = Column(Float, nullable=True)
    status = Column(Enum(HotspotStatusEnum), default=HotspotStatusEnum.active)
    notes = Column(Text, nullable=True)

    location = relationship("Location", back_populates="hotspots")
    hotspot_reports = relationship("HotspotReport", back_populates="hotspot")

    __table_args__ = (Index("idx_hotspots_location", "center_latitude", "center_longitude"),)


class HotspotReport(Base):
    """Links reports to hotspots."""

    __tablename__ = "hotspot_reports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    hotspot_id = Column(Integer, ForeignKey("hotspots.hotspot_id"))
    report_id = Column(Integer, ForeignKey("reports.report_id"))

    hotspot = relationship("Hotspot", back_populates="hotspot_reports")
    report = relationship("Report", back_populates="hotspot_reports")


class DashboardStatistic(Base):
    """Pre-calculated analytics for dashboard performance."""

    __tablename__ = "dashboard_statistics"

    stat_id = Column(Integer, primary_key=True, autoincrement=True)
    stat_date = Column(Date, nullable=False, index=True)
    location_id = Column(Integer, ForeignKey("locations.location_id"), nullable=True)
    pollution_type_id = Column(Integer, ForeignKey("pollution_types.pollution_type_id"), nullable=True)
    total_reports = Column(Integer, default=0)
    resolved_reports = Column(Integer, default=0)
    average_severity = Column(Float, nullable=True)
    trend_direction = Column(Enum(TrendEnum), default=TrendEnum.stable)
    last_updated = Column(DateTime(timezone=True), server_default=func.now())


class ImageProcessingQueue(Base):
    """Async queue for Nova embedding generation."""

    __tablename__ = "image_processing_queue"

    queue_id = Column(Integer, primary_key=True, autoincrement=True)
    report_id = Column(Integer, ForeignKey("reports.report_id"), unique=True)
    image_url = Column(String(255), nullable=False)
    status = Column(Enum(QueueStatusEnum), default=QueueStatusEnum.pending)
    queued_at = Column(DateTime(timezone=True), server_default=func.now())
    processed_at = Column(DateTime(timezone=True), nullable=True)
    retry_count = Column(Integer, default=0)
    error_message = Column(Text, nullable=True)

    report = relationship("Report", back_populates="queue")


class UserVerification(Base):
    """OTP email verification."""

    __tablename__ = "user_verifications"

    verification_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id"))
    email = Column(String(100), nullable=False)
    otp = Column(String(10), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_verified = Column(Boolean, default=False)
    attempts = Column(Integer, default=0)

    user = relationship("User", back_populates="verifications")


class ApiKey(Base):
    """API keys for external integrations."""

    __tablename__ = "api_keys"

    key_id = Column(Integer, primary_key=True, autoincrement=True)
    api_key = Column(String(255), unique=True, nullable=False)
    name = Column(String(100), nullable=False)
    created_date = Column(DateTime(timezone=True), server_default=func.now())
    expiration_date = Column(DateTime(timezone=True), nullable=True)
    active = Column(Boolean, default=True)
    permissions = Column(JSON, nullable=True)
    last_used = Column(DateTime(timezone=True), nullable=True)
    created_by = Column(Integer, ForeignKey("users.user_id"), nullable=True)

    creator = relationship("User", back_populates="api_keys")


class AdminUser(Base):
    """Admin panel accounts."""

    __tablename__ = "admin_users"

    admin_id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(Enum(AdminRoleEnum), default=AdminRoleEnum.admin)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_login = Column(DateTime(timezone=True), nullable=True)
    active = Column(Boolean, default=True)


class SystemLog(Base):
    """Audit logs for all system actions."""

    __tablename__ = "system_logs"

    log_id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    agent = Column(String(50), nullable=True)
    action = Column(String(100), nullable=False)
    details = Column(Text, nullable=True)
    log_level = Column(Enum(LogLevelEnum), default=LogLevelEnum.info)
    related_id = Column(Integer, nullable=True)
    related_table = Column(String(50), nullable=True)


class CleanZone(Base):
    """Clean air zones in Bengaluru."""

    __tablename__ = "clean_zones"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(200), nullable=False)
    aqi = Column(Integer, default=50)
    status = Column(String(50), default="Good")
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    activities = Column(JSON, nullable=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now())


ReportAnalysis = AnalysisResult
