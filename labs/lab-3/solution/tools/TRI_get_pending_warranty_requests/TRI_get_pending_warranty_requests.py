"""TRI_get_pending_warranty_requests — Batch Warranty Claims Fetcher

Purpose
-------
Retrieves all pending warranty claim requests from the BAW SOR Warranty service
for batch processing. Each record contains the customer profile for one
outstanding claim; the warranty document itself is fetched separately, per
record, via TRI_fetch_baw_pdf(customer_id) in the foreach body.

This tool is the entry point for the batch warranty claim workflow
(`TRI_warranty_claim_workflow_batch`). It returns the list of unprocessed
requests that a Foreach node then iterates over, invoking the review sub-workflow
(`TRI_warranty_review_workflow`) once per record.

Connection env vars (injected by wxO platform from TRI_cp4ba_keyvalue_team):
    WXO_CONNECTION_TRI_cp4ba_keyvalue_team_ENDPOINT
    WXO_CONNECTION_TRI_cp4ba_keyvalue_team_USERID
    WXO_CONNECTION_TRI_cp4ba_keyvalue_team_PASSWORD

Contract
--------
Inputs:
    None

Outputs:
    outstanding_warranty_requests   (list[dict])   List of pending warranty requests.
    Each item contains:
        customer_id       (str)   Format C-*
        customer_name     (str)   Full name
        customer_status   (str)   Customer tier, e.g. silver, bronze
        customer_email    (str)   Email address on file
        customer_phone    (str)   Phone number on file
"""

import os
from typing import Any

import requests
from pydantic import BaseModel

from ibm_watsonx_orchestrate.agent_builder.tools import tool, ToolPermission
from ibm_watsonx_orchestrate_core.types.connections.credentials import (
    ExpectedCredentials, ConnectionType,
)


class WarrantyRequestItem(BaseModel):
    customer_id: str
    customer_name: str
    customer_status: str
    customer_email: str
    customer_phone: str


class PendingWarrantyRequestsResult(BaseModel):
    outstanding_warranty_requests: list[WarrantyRequestItem]


@tool(
    permission=ToolPermission.READ_ONLY,
    expected_credentials=[
        ExpectedCredentials(app_id="TRI_cp4ba_keyvalue_team", type=ConnectionType.KEY_VALUE)
    ],
)
def TRI_get_pending_warranty_requests() -> PendingWarrantyRequestsResult:
    """Retrieve all pending warranty claim requests queued for batch processing.

    Use as the entry point for a batch warranty claim workflow when a list of
    unprocessed requests is needed. Do NOT call during a single-customer warranty
    lookup — use customer-scoped CRM tools instead. Does not return the warranty
    document itself — fetch it separately per record via TRI_fetch_baw_pdf(customer_id).
    Returns: outstanding_warranty_requests[] — each with customer_id, customer_name,
    customer_status, customer_email, customer_phone.

    Uses TRI_cp4ba_keyvalue_team connection credentials (Key-Value / Team).
    """
    server_url = os.environ.get(
        "WXO_CONNECTION_TRI_cp4ba_keyvalue_team_ENDPOINT", ""
    ).strip().rstrip("/")
    username = os.environ.get(
        "WXO_CONNECTION_TRI_cp4ba_keyvalue_team_USERID", ""
    ).strip()
    password = os.environ.get(
        "WXO_CONNECTION_TRI_cp4ba_keyvalue_team_PASSWORD", ""
    ).strip()

    if not server_url:
        raise RuntimeError(
            "TRI_cp4ba_keyvalue_team connection is missing ENDPOINT."
        )
    if not username or not password:
        raise RuntimeError(
            "TRI_cp4ba_keyvalue_team connection is missing USERID or PASSWORD."
        )

    url = f"{server_url}/automationservices/rest/TSOR/Warranty/get_pending_warranty_requests"

    response = requests.post(
        url,
        json={},
        auth=(username, password),
        timeout=60,
        verify=False,
    )
    response.raise_for_status()

    payload = response.json()
    raw_requests: list[dict[str, Any]] = payload.get("outstanding_warranty_requests", [])

    items = [
        WarrantyRequestItem(
            customer_id=r.get("customer_id", ""),
            customer_name=r.get("customer_name", ""),
            customer_status=r.get("customer_status", ""),
            customer_email=r.get("customer_email", ""),
            customer_phone=r.get("customer_phone", ""),
        )
        for r in raw_requests
    ]

    return PendingWarrantyRequestsResult(outstanding_warranty_requests=items)
