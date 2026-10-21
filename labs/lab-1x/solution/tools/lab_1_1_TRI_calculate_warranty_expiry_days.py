"""Lab 1.1 Python tool: warranty expiry date arithmetic."""

from datetime import date, datetime
from typing import Annotated, TypedDict

from ibm_watsonx_orchestrate.agent_builder.tools import ToolPermission, tool


class WarrantyExpiredResult(TypedDict, total=False):
    status: str
    expiry_date: str
    as_of_date: str
    days_expired: int
    error_code: str
    message: str
    correction_hint: str


@tool(permission=ToolPermission.READ_ONLY)
def TRI_calculate_warranty_expiry_days(
    expiry_date: Annotated[
        str,
        "[Required] An expiry date.",
    ],
) -> Annotated[
    WarrantyExpiredResult,
    "Structured result containing the expiry date, today's date, and days expired.",
]:
    """Calculate the exact number of calendar days since a warranty expiry date.

    Use when a warranty expiry date is known and the agent needs deterministic elapsed-day
    arithmetic for warranty status, support eligibility, or expired warranty checks. Do NOT estimate the
    result in the language model. Returns: status, expiry_date, as_of_date,
    days_expired.
    """
    try:
        parsed_date = datetime.strptime(expiry_date, "%d-%m-%Y").date()
    except ValueError:
        return {
            "status": "error",
            "error_code": "INVALID_DATE_FORMAT",
            "message": f"Expiry date {expiry_date!r} is not in a valid format.",
            "correction_hint": "Provide an expiry date in DD-MM-YYYY format, e.g. 21-08-2026.",
        }

    today = date.today()
    if parsed_date > today:
        return {
            "status": "error",
            "error_code": "FUTURE_DATE",
            "message": "Expiry date cannot be in the future.",
            "correction_hint": "Provide an expiry date that is today or in the past.",
        }

    return {
        "status": "success",
        "expiry_date": parsed_date.isoformat(),
        "as_of_date": today.isoformat(),
        "days_expired": (today - parsed_date).days,
    }
