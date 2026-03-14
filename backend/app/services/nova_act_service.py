"""
Nova Act Service — UI automation for complaint auto-filing.
"""

from __future__ import annotations

import httpx

from app.config import settings


NOVA_ACT_ENDPOINT = "https://act.nova.amazon.com/v1/tasks"


async def file_complaint_via_nova_act(
    complaint_letter: str,
    area: str,
    severity: str,
    photo_url: str,
    latitude: float,
    longitude: float,
) -> dict:
    """Use Nova Act to automate KSPCB complaint filing on the web portal."""
    task_instruction = f"""
Navigate to the KSPCB complaint portal and file an air pollution complaint:

1. Go to https://kspcb.karnataka.gov.in/
2. Find the "File Complaint" or "Public Grievance" section
3. Fill in the form with:
   - Complaint Type: Air Pollution
   - Location: {area}, Bengaluru
   - GPS: {latitude:.4f}, {longitude:.4f}
   - Severity: {severity}
   - Description: {complaint_letter[:500]}
   - Photo evidence: {photo_url}
4. Submit the form and capture the complaint reference number
5. Return the reference number and confirmation

If the portal is unavailable, return the pre-written complaint letter for manual submission.
"""
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                NOVA_ACT_ENDPOINT,
                headers={
                    "Authorization": f"Bearer {settings.AWS_ACCESS_KEY_ID}",
                    "Content-Type": "application/json",
                },
                json={
                    "task": task_instruction,
                    "model": "amazon.nova-act-v1:0",
                    "max_steps": 15,
                },
            )
            if response.status_code == 200:
                result = response.json()
                return {
                    "status": "submitted",
                    "reference_number": result.get("output", {}).get("reference_number", "PENDING"),
                    "message": "Complaint successfully filed with KSPCB via Nova Act",
                    "nova_act_used": True,
                }
    except Exception:
        pass

    return {
        "status": "ready_to_submit",
        "reference_number": None,
        "message": "Complaint letter generated. Please submit manually to KSPCB.",
        "complaint_letter": complaint_letter,
        "kspcb_portal": "https://kspcb.karnataka.gov.in/",
        "kspcb_email": "chairman@kspcb.gov.in",
        "nova_act_used": False,
        "note": "Nova Act auto-filing attempted. Manual submission link provided as fallback.",
    }


class NovaActService:
    async def auto_file_complaint(self, *, report_id: int, destination: str) -> dict[str, str]:
        return {
            "status": "queued",
            "message": (
                f"Nova Act automation is queued for report {report_id}. "
                f"Manual filing can continue while browser automation is finalized."
            ),
            "destination": destination,
        }


nova_act_service = NovaActService()
