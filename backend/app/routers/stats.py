from datetime import datetime, timedelta
from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AnalysisResult, Report, SeverityEnum, User
from app.schemas import LeaderboardEntry, StatsOut


router = APIRouter(prefix="/api", tags=["stats"])


@router.get("/stats", response_model=StatsOut)
def stats(db: Session = Depends(get_db)):
    total = db.query(func.count(Report.report_id)).scalar() or 0
    today = db.query(func.count(Report.report_id)).filter(Report.report_date >= datetime.utcnow() - timedelta(days=1)).scalar() or 0
    areas = db.query(func.count(func.distinct(Report.address_text))).scalar() or 0
    critical = db.query(func.count(AnalysisResult.analysis_id)).filter(AnalysisResult.severity == SeverityEnum.critical).scalar() or 0
    high = db.query(func.count(AnalysisResult.analysis_id)).filter(AnalysisResult.severity == SeverityEnum.high).scalar() or 0
    moderate = db.query(func.count(AnalysisResult.analysis_id)).filter(AnalysisResult.severity == SeverityEnum.moderate).scalar() or 0
    low = db.query(func.count(AnalysisResult.analysis_id)).filter(AnalysisResult.severity == SeverityEnum.low).scalar() or 0
    return {
        "total": total,
        "today": today,
        "areas": areas,
        "critical": critical,
        "high": high,
        "moderate": moderate,
        "low": low,
    }


@router.get("/leaderboard", response_model=List[LeaderboardEntry])
def leaderboard(db: Session = Depends(get_db)):
    users = db.query(User).order_by(User.report_count.desc()).limit(20).all()
    return [
        LeaderboardEntry(
            id=user.user_id,
            name=user.username,
            email=user.email,
            report_count=user.report_count,
            points=user.points,
            badge_level=user.badge_level,
        )
        for user in users
    ]
