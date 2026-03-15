from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user, get_optional_user
from app.models import AnalysisResult, ImageProcessingQueue, PriorityEnum, QueueStatusEnum, Report, ReportStatusEnum, SeverityEnum, User
from app.schemas import ReportOut
from app.services.bedrock_service import analyze_pollution_photo, generate_complaint_letter
from app.services.embedding_service import generate_image_embedding, generate_location_embedding
from app.services.s3_service import delete_photo, upload_photo


router = APIRouter(prefix="/api", tags=["reports"])

BADGE_MAP = [(100, "Legend of Bengaluru"), (50, "Diamond Sentinel"), (20, "Gold Protector"), (5, "Silver Watchdog"), (1, "Bronze Guardian")]
POINTS = {"CRITICAL": 25, "HIGH": 18, "MODERATE": 10, "LOW": 10}


def _severity_enum(value: str) -> SeverityEnum:
    return {
        "CRITICAL": SeverityEnum.critical,
        "HIGH": SeverityEnum.high,
        "MODERATE": SeverityEnum.moderate,
        "LOW": SeverityEnum.low,
    }.get((value or "MODERATE").upper(), SeverityEnum.moderate)


def _priority_enum(value: str) -> PriorityEnum:
    return {
        "CRITICAL": PriorityEnum.critical,
        "HIGH": PriorityEnum.high,
        "MODERATE": PriorityEnum.medium,
        "LOW": PriorityEnum.low,
    }.get((value or "MODERATE").upper(), PriorityEnum.medium)


def _update_user(user: User, severity: str, db: Session):
    user.report_count += 1
    user.points += POINTS.get(severity, 10)
    for threshold, badge in BADGE_MAP:
        if user.report_count >= threshold:
            user.badge_level = badge
            break
    db.commit()


@router.post("/reports", response_model=ReportOut, response_class=JSONResponse)
async def submit_report(
    request: Request,
    area: str = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    description: Optional[str] = Form(None),
    photo: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    photo_bytes = await photo.read()

    try:
        photo_url, photo_key = upload_photo(photo_bytes, photo.content_type or "image/jpeg")
    except Exception:
        from app.services.s3_service import storage_service

        photo_url = await storage_service.upload_image(
            filename=photo.filename or "report.jpg",
            file_bytes=photo_bytes,
            content_type=photo.content_type,
            request=request,
        )
        photo_key = None

    report = Report(
        user_id=current_user.user_id if current_user else None,
        latitude=latitude,
        longitude=longitude,
        description=description,
        image_url=photo_url,
        image_key=photo_key,
        address_text=area,
        status=ReportStatusEnum.analyzing,
        report_date=datetime.utcnow(),
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    # 1. Analyze pollution only (no complaint yet)
    analysis_data = analyze_pollution_photo(photo_bytes, area)
    severity = (analysis_data.get("severity") or "MODERATE").upper()

    try:
        img_embedding = generate_image_embedding(photo_bytes)
        loc_embedding = generate_location_embedding(latitude, longitude, area)
    except Exception:
        img_embedding = None
        loc_embedding = None

    # 2. Save report + analysis (pollution shown); complaint_letter left empty
    analysis = AnalysisResult(
        report_id=report.report_id,
        analyzed_date=datetime.utcnow(),
        confidence_score=analysis_data.get("confidence", 0.8),
        severity_score=analysis_data.get("severity_score", 5),
        severity=_severity_enum(severity),
        priority_level=_priority_enum(severity),
        analysis_notes=analysis_data.get("pollution_type"),
        full_description=analysis_data.get("description"),
        health_risk=analysis_data.get("health_risk"),
        recommendations=analysis_data.get("recommendations"),
        complaint_letter=None,
        processed_by="us.amazon.nova-2-lite-v1:0 + amazon.nova-2-multimodal-embeddings-v1:0",
        image_embedding=img_embedding,
        location_embedding=loc_embedding,
    )
    db.add(analysis)
    db.add(
        ImageProcessingQueue(
            report_id=report.report_id,
            image_url=photo_url,
            status=QueueStatusEnum.completed if img_embedding else QueueStatusEnum.failed,
            queued_at=datetime.utcnow(),
            processed_at=datetime.utcnow() if img_embedding else None,
            error_message=None if img_embedding else "Embedding generation unavailable",
        )
    )
    report.status = ReportStatusEnum.analyzed
    db.commit()
    db.refresh(analysis)

    # 3. Generate complaint only after report exists, and only for MODERATE / HIGH / CRITICAL
    if severity in ("MODERATE", "HIGH", "CRITICAL"):
        complaint = generate_complaint_letter(
            area=area,
            severity=severity,
            pollution_type=analysis_data.get("pollution_type", "Air Pollution"),
            description=analysis_data.get("description", ""),
            latitude=latitude,
            longitude=longitude,
        )
        analysis.complaint_letter = complaint
        db.commit()
        db.refresh(report)

    if current_user:
        _update_user(current_user, severity, db)

    return ReportOut.from_report(report)


@router.get("/reports", response_model=List[ReportOut])
def get_reports(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    reports = db.query(Report).order_by(Report.report_date.desc()).offset(skip).limit(limit).all()
    return [ReportOut.from_report(report) for report in reports]


@router.get("/reports/{report_id}", response_model=ReportOut)
def get_report(report_id: int, db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.report_id == report_id).first()
    if not report:
        raise HTTPException(404, "Report not found")
    return ReportOut.from_report(report)


@router.delete("/reports/{report_id}")
def delete_report(report_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    report = db.query(Report).filter(Report.report_id == report_id).first()
    if not report:
        raise HTTPException(404, "Not found")
    if report.user_id != user.user_id and not user.is_admin:
        raise HTTPException(403, "Not authorized")
    if report.image_key:
        delete_photo(report.image_key)
    db.delete(report); db.commit()
    return {"message": "Deleted"}


@router.get("/my-reports", response_model=List[ReportOut])
def my_reports(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    reports = db.query(Report).filter(Report.user_id == user.user_id).order_by(Report.report_date.desc()).all()
    return [ReportOut.from_report(report) for report in reports]
