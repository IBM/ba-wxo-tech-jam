"""Lab 1.1 Python tool: deterministic date arithmetic."""

from datetime import date
from typing import Annotated, TypedDict

from ibm_watsonx_orchestrate.agent_builder.tools import ToolPermission, tool


class DaysSincePurchaseResult(TypedDict):
    status: str
    purchase_date: str
    as_of_date: str
    days_since_purchase: int


@tool(permission=ToolPermission.READ_ONLY)
def TRI_calculate_days_since_purchase(
    purchase_date: Annotated[
        str,
        "[Required] Purchase date in ISO format YYYY-MM-DD, e.g. 2026-08-21.",
    ],
) -> Annotated[
    DaysSincePurchaseResult,
    "Structured result containing the purchase date, today's date, and elapsed days.",
]:
    """Calculate the exact number of calendar days since a purchase date.

    Use when a purchase date is known and the agent needs deterministic elapsed-day
    arithmetic for a warranty, return, or eligibility check. Do NOT estimate the
    result in the language model. Returns: status, purchase_date, as_of_date,
    days_since_purchase.
    """
    try:
        parsed_date = date.fromisoformat(purchase_date)
    except ValueError as exc:
        raise ValueError(
            "purchase_date must use ISO format YYYY-MM-DD, for example 2026-08-21."
        ) from exc

    today = date.today()
    if parsed_date > today:
        raise ValueError("purchase_date cannot be in the future.")

    return {
        "status": "success",
        "purchase_date": parsed_date.isoformat(),
        "as_of_date": today.isoformat(),
        "days_since_purchase": (today - parsed_date).days,
    }
