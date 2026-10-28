"""Lab 1.1 Python tool: retrieve a CRM customer through the BAW SOAP API."""

import os
import re
import xml.etree.ElementTree as ET
from typing import Annotated, TypedDict

import requests

from ibm_watsonx_orchestrate.agent_builder.tools import ToolPermission, tool
from ibm_watsonx_orchestrate_core.types.connections.credentials import (
    ConnectionType,
    ExpectedCredentials,
)


CONNECTION_ID = "TRI_cp4ba_keyvalue_team"
SOAP_NAMESPACE = "http://TSOR/CRM.tws"
SOAP_ACTION = f"{SOAP_NAMESPACE}/getCustomerInformation"


class CustomerResult(TypedDict, total=False):
    status: str
    customer: dict[str, str]
    error_code: str
    message: str
    correction_hint: str


def _connection_value(key: str) -> str:
    """Read one value injected from the wxO key-value connection."""
    variable = f"WXO_CONNECTION_{CONNECTION_ID}_{key}"
    value = os.environ.get(variable, "").strip()
    if not value:
        raise RuntimeError(
            f"Connection {CONNECTION_ID} is missing required key {key}."
        )
    return value


def _soap_endpoint(base_url: str) -> str:
    """Accept either a host URL or the BAW /bas base URL."""
    base = base_url.rstrip("/")
    if not base.endswith("/bas"):
        base = f"{base}/bas"
    return f"{base}/teamworks/webservices/TSOR/CRM.tws"


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _first_text(root: ET.Element, field: str) -> str:
    for element in root.iter():
        if _local_name(element.tag) == field and element.text:
            return element.text.strip()
    return ""


@tool(
    permission=ToolPermission.READ_ONLY,
    expected_credentials=[
        ExpectedCredentials(app_id=CONNECTION_ID, type=ConnectionType.KEY_VALUE)
    ],
)
def TRI_get_customer_by_id(
    customer_id: Annotated[
        str,
        "[Required] Customer ID in format C-*, e.g. C-3DBZFE.",
    ],
) -> Annotated[
    CustomerResult,
    "Structured success result with customer fields, or an actionable error result.",
]:
    """Look up a customer's full CRM profile by customer ID.

    Use when a customer ID in C-* format is available and the agent needs the
    customer's name, contact details, or status. Do NOT call if only an order ID
    is available; retrieve the order first and use its customer_id. Returns:
    status and customer (customer_id, firstname, lastname, sex, email, phone,
    status), or error_code, message, and correction_hint on failure.
    """
    if not re.fullmatch(r"C-[A-Z0-9]+", customer_id):
        return {
            "status": "error",
            "error_code": "INVALID_CUSTOMER_ID",
            "message": f"Customer ID {customer_id!r} is not valid.",
            "correction_hint": "Provide a customer ID in C-* format, e.g. C-3DBZFE.",
        }

    try:
        endpoint = _soap_endpoint(_connection_value("ENDPOINT"))
        user_id = _connection_value("USERID")
        password = _connection_value("PASSWORD")
        verify_ssl = os.environ.get(
            f"WXO_CONNECTION_{CONNECTION_ID}_VERIFY_SSL", "true"
        ).strip().lower() not in {"false", "0", "no"}

        envelope = ET.Element(
            "{http://www.w3.org/2003/05/soap-envelope}Envelope"
        )
        body = ET.SubElement(
            envelope, "{http://www.w3.org/2003/05/soap-envelope}Body"
        )
        operation = ET.SubElement(body, f"{{{SOAP_NAMESPACE}}}getCustomerInformation")
        ET.SubElement(operation, f"{{{SOAP_NAMESPACE}}}customer_id").text = customer_id

        response = requests.post(
            endpoint,
            data=ET.tostring(envelope, encoding="utf-8", xml_declaration=True),
            headers={
                "Content-Type": (
                    'application/soap+xml; charset=utf-8; '
                    f'action="{SOAP_ACTION}"'
                )
            },
            auth=(user_id, password),
            timeout=60,
            verify=verify_ssl,
        )
        response.raise_for_status()
        root = ET.fromstring(response.content)

        fault = next(
            (element for element in root.iter() if _local_name(element.tag) == "Fault"),
            None,
        )
        if fault is not None:
            reason = _first_text(fault, "Text") or _first_text(fault, "faultstring")
            return {
                "status": "error",
                "error_code": "SOAP_FAULT",
                "message": reason or "The CRM SOAP service returned a fault.",
                "correction_hint": "Check the customer ID and retry once.",
            }

        customer = {
            field: _first_text(root, field)
            for field in (
                "customer_id",
                "firstname",
                "lastname",
                "sex",
                "email",
                "phone",
                "status",
            )
        }
        if not any(customer.values()):
            return {
                "status": "error",
                "error_code": "CUSTOMER_NOT_FOUND",
                "message": f"Customer {customer_id} was not returned by the CRM service.",
                "correction_hint": "Verify the customer ID and try again.",
            }

        if not customer["customer_id"]:
            customer["customer_id"] = customer_id
        return {"status": "success", "customer": customer}

    except requests.Timeout:
        return {
            "status": "error",
            "error_code": "CRM_TIMEOUT",
            "message": "The CRM service did not respond within 60 seconds.",
            "correction_hint": "Retry once; if it fails again, contact the facilitator.",
        }
    except (requests.RequestException, ET.ParseError, RuntimeError) as exc:
        return {
            "status": "error",
            "error_code": "CRM_LOOKUP_FAILED",
            "message": str(exc),
            "correction_hint": (
                "Verify the connection values and customer ID, then retry once."
            ),
        }
