"""
TRI_fetch_baw_pdf — wxO flow tool.

Calls the BAW CRM REST endpoint directly using credentials injected from the
TRI_cp4ba_keyvalue_team connection (Key-Value / Team). Decodes the base64-encoded PDF
from the CRM response and returns it as raw bytes. The wxO platform automatically
uploads the bytes to S3 and exposes the result as a file data type within the
flow — consumed by the classify_document and extract_document_fields TIP nodes
via flow['fetch_baw_pdf'].output.

Connection env vars (injected by wxO platform from TRI_cp4ba_keyvalue_team):
    WXO_CONNECTION_TRI_cp4ba_keyvalue_team_ENDPOINT
    WXO_CONNECTION_TRI_cp4ba_keyvalue_team_USERID
    WXO_CONNECTION_TRI_cp4ba_keyvalue_team_PASSWORD
"""

import base64 as _base64
import os
from typing import Annotated

import requests

from ibm_watsonx_orchestrate.agent_builder.tools import tool, ToolPermission
from ibm_watsonx_orchestrate_core.types.connections.credentials import (
    ExpectedCredentials, ConnectionType,
)


@tool(
    permission=ToolPermission.READ_ONLY,
    expected_credentials=[
        ExpectedCredentials(app_id="TRI_cp4ba_keyvalue_team", type=ConnectionType.KEY_VALUE)
    ],
)
def TRI_fetch_baw_pdf(
    customer_id: Annotated[str, "Customer ID (e.g. C-3DBZFE)"],
) -> Annotated[bytes, "PDF document bytes — platform auto-uploads to S3 as a file data type for TIP nodes"]:
    """
    Fetch the customer's proof-of-warranty PDF from the BAW CRM REST endpoint.
    Returns raw PDF bytes; the wxO platform automatically uploads them to S3
    and makes the result available as a file data type in the flow.

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

    url = (
        f"{server_url}/automationservices/rest/TSOR/CRM"
        f"/get_customer_provided_proof_of_warranty_by_customer_id"
    )

    response = requests.post(
        url,
        auth=(username, password),
        json={"customer_id": customer_id},
        timeout=60,
        verify=False,
    )

    if not response.ok:
        raise RuntimeError(
            f"BAW CRM call failed {response.status_code}: {response.text[:300]}"
        )

    data = response.json()
    b64 = (
        data.get("attachment_content")
        or data.get("attachmentContent")
        or data.get("content")
        or ""
    )
    if not b64:
        raise RuntimeError(
            f"No attachment_content in BAW response for {customer_id}. "
            f"Keys returned: {list(data.keys())}"
        )

    b64 = b64.strip()
    if b64.startswith("data:"):
        b64 = b64[b64.find(",") + 1:]

    try:
        pdf_bytes = _base64.b64decode(b64)
    except Exception as exc:
        raise ValueError(f"Failed to base64-decode attachment for {customer_id}: {exc}")

    if not pdf_bytes.startswith(b"%PDF"):
        raise ValueError(
            f"Decoded bytes for {customer_id} are not a PDF (header={pdf_bytes[:8]!r})"
        )

    return pdf_bytes
