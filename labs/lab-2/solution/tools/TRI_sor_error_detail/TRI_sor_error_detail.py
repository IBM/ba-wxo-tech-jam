"""TRI_sor_error_detail — SOR Error Detail Extractor

Purpose
-------
When a SOR tool node fails (HTTP error returned by the System of Record),
the wxO agentic workflow platform makes two implicit outputs available on
the failure branch of that node:

    error_message  (str)    generic platform-level description of the failure
    error_detail   (str)    full raw failure string, including the original
                            SOR response body

Auto-map can bind both to this tool's inputs. The tool:
1. Relays both inputs directly under their original names (error_message, error_detail).
2. Parses the SOR error code to determine if it is a domain error (is_domain_error, sor_error_code).
3. Extracts a specific, clean error detail (sor_error_detail) from the general raw error_detail,
   specifically extracting the first element of "message_parameters" from the SOR response.

The key output for Gateway branching is is_domain_error: it is True when the
SOR returned a recognisable error code (domain-level rejection such as
ORDER_NOT_FOUND), and False for transient or infrastructure failures where no
error code is present. This lets a single Gateway condition distinguish between
"tell the specialist the order doesn't exist" and "tell the specialist to try
again later".

Contract
--------
Inputs:
    error_message     (str)            platform-level generic failure message
    error_detail      (str)            raw failure string from platform / SOR

Outputs:
    error_message     (str)            relayed directly from input
    error_detail      (str)            relayed directly from input
    is_domain_error   (bool)           true if sor_error_code is present
    sor_error_code    (str | None)     parsed SOR error code (e.g. ORDER_NOT_FOUND)
    sor_error_detail  (str)            specific extract from the general error_detail

Sample output
-------------
Given a SOR tool call that failed because the requested record does not exist:

    {
        "error_message":     "Something went wrong while running 'TRI_TSOR_Billing_...'",
        "error_detail":      "<raw SOR response string from platform>",
        "is_domain_error":   true,
        "sor_error_code":    "ORDER_NOT_FOUND_STRING_MAPPING",
        "sor_error_detail":  "An exception occurred in activity \"Error End Event (with error mapping)\" of \"Service Flow\" with name \"getBillingRecordsByOrderId 2\". Task instance id \"null\". Details: \"errorCode: ORDER_NOT_FOUND_STRING_MAPPING\"."
    }

Given a transient infrastructure failure (network timeout, service unavailable):

    {
        "error_message":     "Something went wrong while running 'TRI_TSOR_Billing_...'",
        "error_detail":      "<raw SOR response string from platform>",
        "is_domain_error":   false,
        "sor_error_code":    null,
        "sor_error_detail":  "Undeclared local variable..."
    }

Flow variable references (after auto-map wires this tool on the failure branch)
-------------------------------------------------------------------------------
    flow["TRI_sor_error_detail"].output.error_message
    flow["TRI_sor_error_detail"].output.error_detail
    flow["TRI_sor_error_detail"].output.is_domain_error
    flow["TRI_sor_error_detail"].output.sor_error_code
    flow["TRI_sor_error_detail"].output.sor_error_detail
"""

import json
import re
from typing import Optional

from pydantic import BaseModel
from ibm_watsonx_orchestrate.agent_builder.tools import tool


class SorErrorDetail(BaseModel):
    error_message: str
    error_detail: str
    is_domain_error: bool
    sor_error_code: Optional[str] = None
    sor_error_detail: str


@tool
def TRI_sor_error_detail(
    error_message: str = "",
    error_detail: str = "",
) -> SorErrorDetail:
    """Extract structured error information from a failed SOR tool call.

    Receives the implicit error outputs that the platform places on the failure
    branch of a tool node, relays both inputs directly, parses any SOR-level error
    code out of the raw detail string, and extracts a specific, human-readable
    sor_error_detail by extracting the first element of message_parameters
    from the SOR JSON response body when present.

    Args:
        error_message: Generic platform message describing the failure
            (optional; defaults to empty string if auto-map cannot bind it).
        error_detail: Raw failure detail string including the SOR response body
            (optional; defaults to empty string if auto-map cannot bind it).

    Returns:
        SorErrorDetail with relayed inputs (error_message, error_detail),
        domain error flag (is_domain_error), parsed code (sor_error_code), and
        specific extracted error description (sor_error_detail).
    """
    combined_text = f"{error_detail}\n{error_message}"

    # 1. Parse the SOR error code from the raw text.
    # The SOR embeds it as: errorCode: ORDER_NOT_FOUND or "errorCode": "ORDER_NOT_FOUND"
    sor_error_code: Optional[str] = None
    code_match = re.search(
        r'(?:errorCode|error_code)["\']?\s*[:=]\s*["\']?([A-Z0-9_]+)',
        combined_text,
        re.IGNORECASE,
    )
    if code_match:
        sor_error_code = code_match.group(1).upper()

    # 2. Extract specific sor_error_detail from message_parameters or SOR response body.
    sor_error_detail = ""

    # Strategy A: Extract the first element of message_parameters array.
    # Deliberate SOR errors (BAW Error End Events) place the detailed explanation
    # in message_parameters: ["An exception occurred in activity \"...\" ..."].
    # Because wxO escapes quotes in nested error responses (e.g. \" or \\\"),
    # we locate the [ ... ] slice and cleanly unescape it.
    param_pos = combined_text.find("message_parameters")
    if param_pos != -1:
        bracket_start = combined_text.find("[", param_pos)
        if bracket_start != -1:
            bracket_end = combined_text.find("]", bracket_start)
            if bracket_end != -1:
                param_content = combined_text[bracket_start + 1 : bracket_end].strip()

                # If standard JSON parsing works on the array slice, use it
                try:
                    parsed = json.loads(f"[{param_content}]")
                    if isinstance(parsed, list) and parsed and isinstance(parsed[0], str) and parsed[0].strip():
                        sor_error_detail = parsed[0].strip()
                except Exception:
                    pass

                # If JSON parsing failed due to nested unescaped quotes, strip outer quotes and unescape
                if not sor_error_detail:
                    # Strip leading and trailing quotes (e.g. \" or " or ')
                    param_content = re.sub(r'^(?:\\*["\'])', '', param_content)
                    param_content = re.sub(r'(?:\\*["\'])$', '', param_content)

                    # Unescape internal backslash-escaped quotes (\\\" or \" -> ")
                    cleaned = re.sub(r'\\+["\']', '"', param_content)
                    cleaned = cleaned.replace(r'\n', '\n').replace(r'\t', '\t').replace(r'\\', '\\')
                    if cleaned.strip():
                        sor_error_detail = cleaned.strip()

    # Strategy B: Parse JSON following "body:" if present
    if not sor_error_detail:
        body_match = re.search(r'body:\s*(.*)', combined_text, re.DOTALL | re.IGNORECASE)
        if body_match:
            body_text = body_match.group(1).strip()
            for trim in range(0, 15):
                candidate = body_text if trim == 0 else body_text[:-trim]
                try:
                    p = json.loads(candidate)
                    if isinstance(p, dict):
                        params = p.get("message_parameters")
                        if isinstance(params, list) and params and isinstance(params[0], str) and params[0].strip():
                            sor_error_detail = params[0].strip()
                            break
                        cause = p.get("cause")
                        deepest = None
                        while isinstance(cause, dict):
                            msg = cause.get("message", "")
                            if msg:
                                deepest = msg
                            cause = cause.get("cause")
                        if deepest:
                            sor_error_detail = deepest.strip()
                            break
                        if p.get("message"):
                            sor_error_detail = str(p.get("message")).strip()
                            break
                except Exception:
                    pass

    # Strategy C: Exception information regex
    if not sor_error_detail:
        exc_match = re.search(r"Exception information:\s*['\"](.*?)['\"]", combined_text, re.DOTALL)
        if exc_match:
            sor_error_detail = exc_match.group(1).strip()

    # Strategy D: Deepest cause message regex
    if not sor_error_detail:
        cause_matches = re.findall(r'["\']?message["\']?\s*:\s*["\']([^"\']+)["\']', combined_text)
        if cause_matches:
            for msg in reversed(cause_matches):
                if msg.strip() and not msg.startswith("CWTBG") and not msg.startswith("Failed to execute"):
                    sor_error_detail = msg.strip()
                    break

    # Fallback to general text or error_message
    if not sor_error_detail:
        if error_detail.strip() and not error_detail.startswith("OH_") and not error_detail.startswith("TRI_"):
            sor_error_detail = error_detail.strip()
        else:
            sor_error_detail = error_message or "(unknown error)"

    return SorErrorDetail(
        error_message=error_message,
        error_detail=error_detail,
        is_domain_error=sor_error_code is not None,
        sor_error_code=sor_error_code,
        sor_error_detail=sor_error_detail,
    )
