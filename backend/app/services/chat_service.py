from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import List

import boto3
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.config import settings


TOOLS = [
    {
        "toolSpec": {
            "name": "query_pollution_data",
            "description": "Query VayuNetra database for real-time Bengaluru pollution reports, statistics, and trends.",
            "inputSchema": {
                "json": {
                    "type": "object",
                    "properties": {
                        "query_type": {
                            "type": "string",
                            "enum": ["stats", "by_area", "recent", "by_severity", "hotspots", "leaderboard"],
                        },
                        "area": {"type": "string"},
                        "severity": {"type": "string"},
                        "limit": {"type": "integer", "default": 10},
                    },
                    "required": ["query_type"],
                }
            },
        }
    },
    {
        "toolSpec": {
            "name": "get_clean_air_zones",
            "description": "Get clean air zones and safe breathing spots in Bengaluru with AQI data and recommended activities.",
            "inputSchema": {"json": {"type": "object", "properties": {"max_aqi": {"type": "integer", "default": 100}}}},
        }
    },
    {
        "toolSpec": {
            "name": "get_health_advice",
            "description": "Get personalized health advice for a specific Bengaluru area and vulnerable group.",
            "inputSchema": {
                "json": {
                    "type": "object",
                    "properties": {
                        "area": {"type": "string"},
                        "group": {
                            "type": "string",
                            "enum": ["general", "children", "elderly", "respiratory", "pregnant"],
                        },
                    },
                    "required": ["area"],
                }
            },
        }
    },
    {
        "toolSpec": {
            "name": "get_kspcb_info",
            "description": "Get information about filing official complaints with KSPCB and BBMP for Bengaluru air pollution.",
            "inputSchema": {"json": {"type": "object", "properties": {"complaint_type": {"type": "string"}}}},
        }
    },
]


def _execute_tool(name: str, inp: dict, db: Session) -> str:
    from app.models import CleanZone, Report, ReportAnalysis, SeverityEnum, User

    if name == "query_pollution_data":
        query_type = inp.get("query_type", "stats")
        limit = inp.get("limit", 10)
        if query_type == "stats":
            total = db.query(func.count(Report.report_id)).scalar() or 0
            today = (
                db.query(func.count(Report.report_id))
                .filter(Report.report_date >= datetime.utcnow() - timedelta(days=1))
                .scalar()
                or 0
            )
            critical = (
                db.query(func.count(Report.report_id))
                .join(ReportAnalysis)
                .filter(ReportAnalysis.severity == SeverityEnum.critical)
                .scalar()
                or 0
            )
            areas = db.query(func.count(func.distinct(Report.address_text))).scalar() or 0
            return json.dumps({"total_reports": total, "today": today, "critical": critical, "unique_areas": areas})
        if query_type == "by_area":
            area = inp.get("area", "")
            reports = (
                db.query(Report)
                .filter(Report.address_text.ilike(f"%{area}%"))
                .order_by(Report.report_date.desc())
                .limit(limit)
                .all()
            )
            return json.dumps([{"id": report.report_id, "area": report.address_text, "date": str(report.report_date)} for report in reports])
        if query_type == "recent":
            reports = db.query(Report).order_by(Report.report_date.desc()).limit(limit).all()
            return json.dumps([{"id": report.report_id, "area": report.address_text, "date": str(report.report_date)} for report in reports])
        if query_type == "by_severity":
            severity = (inp.get("severity", "CRITICAL") or "CRITICAL").upper()
            severity_enum = {
                "LOW": SeverityEnum.low,
                "MODERATE": SeverityEnum.moderate,
                "HIGH": SeverityEnum.high,
                "CRITICAL": SeverityEnum.critical,
            }.get(severity, SeverityEnum.critical)
            count = (
                db.query(func.count(Report.report_id))
                .join(ReportAnalysis)
                .filter(ReportAnalysis.severity == severity_enum)
                .scalar()
                or 0
            )
            return json.dumps({"severity": severity, "count": count})
        if query_type == "hotspots":
            results = (
                db.query(Report.address_text, func.count(Report.report_id).label("cnt"))
                .group_by(Report.address_text)
                .order_by(func.count(Report.report_id).desc())
                .limit(limit)
                .all()
            )
            return json.dumps([{"area": row[0], "reports": row[1]} for row in results])
        if query_type == "leaderboard":
            users = db.query(User).order_by(User.report_count.desc()).limit(5).all()
            return json.dumps([{"name": user.username, "reports": user.report_count, "badge": user.badge_level} for user in users])
        return "{}"

    if name == "get_clean_air_zones":
        max_aqi = inp.get("max_aqi", 100)
        zones = db.query(CleanZone).filter(CleanZone.aqi <= max_aqi).order_by(CleanZone.aqi).all()
        return json.dumps([{"name": zone.name, "aqi": zone.aqi, "status": zone.status, "activities": zone.activities} for zone in zones])

    if name == "get_health_advice":
        area = inp.get("area", "Bengaluru")
        group = inp.get("group", "general")
        advice = {
            "general": f"Avoid outdoor exercise in {area} during peak hours (8-10 AM, 6-8 PM). Check KSPCB AQI updates.",
            "children": f"Keep children indoors in {area} during high pollution. N95 masks are recommended for outdoor school activities.",
            "elderly": f"Elderly residents in {area} should stay indoors when pollution spikes and monitor breathlessness or chest tightness.",
            "respiratory": f"Asthma or COPD patients in {area} should carry inhalers and avoid outdoor activity during critical pollution events.",
            "pregnant": f"Pregnant women in {area} should limit outdoor exposure because high PM2.5 can raise health risks.",
        }.get(group, "Minimize outdoor exposure and monitor local AQI levels.")
        return json.dumps({"area": area, "group": group, "advice": advice})

    if name == "get_kspcb_info":
        return json.dumps(
            {
                "kspcb_hotline": "1800-425-0099",
                "kspcb_email": "chairman@kspcb.gov.in",
                "bbmp_complaint": "080-22660000",
                "online_portal": "https://kspcb.karnataka.gov.in/",
                "how_to_file": "Use VayuNetra's Report screen to generate a complaint letter for KSPCB and BBMP.",
            }
        )
    return "{}"


def agentic_chat(user_message: str, history: List[dict], db: Session) -> dict:
    """Nova Lite agentic chat with multi-round tool calling."""
    if not settings.use_bedrock:
        return _fallback_chat(user_message)

    bedrock = boto3.client(
        "bedrock-runtime",
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )

    system_prompt = """You are VayuNetra AI — Bengaluru's intelligent air quality assistant.
ವಾಯು ನೇತ್ರ (vaayu nethra) means "The Eye on Air" in Sanskrit/Kannada.

You help Bengaluru citizens:
- Understand current pollution levels in their area
- Find clean air zones for outdoor activities
- File complaints with KSPCB and BBMP
- Get health advice based on their vulnerability
- Access real-time pollution statistics

ALWAYS use tools to get real data before answering. Be specific about Bengaluru areas.
If user writes in Kannada or Hindi, respond in that language."""

    messages = [{"role": item["role"], "content": [{"text": item["content"]}]} for item in history[-8:]]
    messages.append({"role": "user", "content": [{"text": user_message}]})

    tools_used: list[str] = []
    try:
        for _ in range(6):
            resp = bedrock.converse(
                modelId=settings.NOVA_LITE_MODEL_ID,
                system=[{"text": system_prompt}],
                messages=messages,
                toolConfig={"tools": TOOLS},
                inferenceConfig={"temperature": 0.3, "maxTokens": 1024},
            )
            stop_reason = resp["stopReason"]
            message = resp["output"]["message"]
            messages.append(message)

            if stop_reason == "end_turn":
                text = "".join(block.get("text", "") for block in message["content"])
                return {"response": text, "tools_used": tools_used}

            if stop_reason == "tool_use":
                results = []
                for block in message["content"]:
                    if "toolUse" in block:
                        tool_name = block["toolUse"]["name"]
                        tool_input = block["toolUse"]["input"]
                        tool_id = block["toolUse"]["toolUseId"]
                        tools_used.append(tool_name)
                        result = _execute_tool(tool_name, tool_input, db)
                        results.append({"toolResult": {"toolUseId": tool_id, "content": [{"text": result}]}})
                messages.append({"role": "user", "content": results})
    except Exception:
        return _fallback_chat(user_message)

    return {
        "response": "I've gathered Bengaluru pollution data. What specific area or question can I help you with?",
        "tools_used": tools_used,
    }


def _fallback_chat(user_message: str) -> dict:
    lower = user_message.lower()
    if "mask" in lower:
        answer = "Use a well-fitted N95 mask if you notice smoke, dust, or burning smells outdoors."
    elif "report" in lower:
        answer = "Capture a clear photo, confirm the area, and submit the report so authorities can review it."
    elif "clean air" in lower or "park" in lower:
        answer = "Try greener zones like Cubbon Park or Lalbagh early in the morning when traffic emissions are lower."
    else:
        answer = "I can help with pollution reporting, health precautions, complaint escalation, and clean-air guidance."
    return {"response": answer, "tools_used": ["fallback_guidance"]}


class ChatService:
    async def reply(
        self,
        *,
        message: str,
        conversation_history: list[dict[str, str]],
        db: Session | None = None,
    ) -> dict[str, object]:
        if db is not None:
            return agentic_chat(message, conversation_history, db)
        return _fallback_chat(message)


chat_service = ChatService()
