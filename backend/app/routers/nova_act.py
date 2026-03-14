from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Report, User
from app.schemas import NovaActResponse
from app.services.nova_act_service import file_complaint_via_nova_act


router = APIRouter(prefix="/api", tags=["nova-act"])


@router.post("/file-complaint/{report_id}", response_model=NovaActResponse)
async def auto_file_complaint(
    report_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    report = db.query(Report).filter(Report.report_id == report_id).first()
    if not report:
        raise HTTPException(404, "Report not found")
    if not report.analysis:
        raise HTTPException(400, "Report not yet analyzed")

    return await file_complaint_via_nova_act(
        complaint_letter=report.analysis.complaint_letter or "",
        area=report.address_text or "Bengaluru",
        severity=report.analysis.severity.value if report.analysis.severity else "MODERATE",
        photo_url=report.image_url or "",
        latitude=report.latitude,
        longitude=report.longitude,
    )
