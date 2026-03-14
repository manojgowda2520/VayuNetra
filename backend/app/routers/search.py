from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Report
from app.schemas import ReportOut
from app.services.embedding_service import find_similar_reports


router = APIRouter(prefix="/api", tags=["search"])


@router.get("/search", response_model=List[ReportOut])
def search(area: str = Query(...), db: Session = Depends(get_db)):
    reports = db.query(Report).filter(Report.address_text.ilike(f"%{area}%")).order_by(Report.report_date.desc()).limit(20).all()
    return [ReportOut.from_report(report) for report in reports]


@router.get("/similar/{report_id}", response_model=List[ReportOut])
def similar(report_id: int, db: Session = Depends(get_db)):
    target = db.query(Report).filter(Report.report_id == report_id).first()
    if not target:
        return []
    if not target.analysis or not target.analysis.image_embedding:
        fallback = db.query(Report).filter(Report.address_text == target.address_text, Report.report_id != report_id).limit(5).all()
        return [ReportOut.from_report(report) for report in fallback]
    candidates = [
        (report, report.analysis.image_embedding if report.analysis else None)
        for report in db.query(Report).filter(Report.report_id != report_id).all()
    ]
    similar_reports = find_similar_reports(target.analysis.image_embedding, candidates)
    return [ReportOut.from_report(report) for report in similar_reports]
