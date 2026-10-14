#!/usr/bin/env python3
"""Create namespace-safe Lab 1.1 import files without editing source artifacts."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlparse


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare Lab 1.1 artifacts for one participant namespace."
    )
    parser.add_argument(
        "--namespace",
        default=None,
        help=(
            "Participant namespace without a trailing underscore, e.g. usr001. "
            "Defaults to the value of --sor-user-id when omitted."
        ),
    )
    parser.add_argument(
        "--sor-user-id",
        default=None,
        help=(
            "Your SOR user ID. See the labs page of the event GitHub repository, section '2. Grab your system of record credentials'. "
            "Used as the namespace when --namespace is omitted."
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        help=(
            "Optional output directory. Defaults to "
            "labs/lab-1x/solution/lab-1-prepared in the repo."
        ),
    )
    parser.add_argument(
        "--sor-base-url",
        required=True,
        help=(
            "System of Record base URL, pasted as shown on the labs page (it already ends in /bas; "
            "/bas is added if missing). See "
            "the labs page of the event GitHub repository, section '2. Grab your system of record credentials'."
        ),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    namespace = (args.namespace or args.sor_user_id or "").strip().rstrip("_")
    if not namespace:
        raise SystemExit("Provide --sor-user-id (or --namespace), e.g. usr001.")
    if not re.fullmatch(r"[A-Za-z0-9]+", namespace):
        raise SystemExit("Namespace may contain only letters and digits, e.g. usr001.")

    sor_base_url = args.sor_base_url.strip().rstrip("/")
    parsed_url = urlparse(sor_base_url)
    if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
        raise SystemExit(
            "--sor-base-url must be an absolute HTTP(S) URL, e.g. "
            "https://example.test/bas."
        )
    if not sor_base_url.endswith("/bas"):
        sor_base_url = f"{sor_base_url}/bas"

    repo_root = Path(__file__).resolve().parents[4]
    output = args.output or (repo_root / "labs/lab-1x/solution/lab-1-prepared")
    output.mkdir(parents=True, exist_ok=True)

    sources = {
        "TRI_cp4ba_keyvalue_team.yaml": (
            "connections",
            repo_root / "labs/lab-1x/solution/connections/TRI_cp4ba_keyvalue_team.yaml",
        ),
        "TRI_cp4ba_basic_member.yaml": (
            "connections",
            repo_root / "labs/lab-1x/solution/connections/TRI_cp4ba_basic_member.yaml",
        ),
        "TRI_SOR_MCP.yaml": (
            "toolkits",
            repo_root / "labs/lab-1x/solution/toolkits/TRI_SOR_MCP.yaml",
        ),
        "lab_1_1_TRI_order_agent_start.yaml": (
            "agents",
            repo_root
            / "labs/lab-1x/solution/agents/lab_1_1_TRI_order_agent_start.yaml",
        ),
        "lab_1_1_TRI_order_agent_mcp_complete.yaml": (
            "agents",
            repo_root
            / "labs/lab-1x/solution/agents/lab_1_1_TRI_order_agent_mcp_complete.yaml",
        ),
        "lab_1_1_TRI_order_agent_complete.yaml": (
            "agents",
            repo_root
            / "labs/lab-1x/solution/agents/lab_1_1_TRI_order_agent_complete.yaml",
        ),
        "lab_1_1_TRI_crm_agent_lab_complete.yaml": (
            "agents",
            repo_root
            / "labs/lab-1x/solution/agents/lab_1_1_TRI_crm_agent_lab_complete.yaml",
        ),
        "lab_1_1_TRI_SOR_Orders_openapi.json": (
            "tools",
            repo_root
            / "labs/lab-1x/solution/tools/lab_1_1_TRI_SOR_Orders_openapi.json",
        ),
        "lab_1_1_TRI_calculate_days_since_purchase.py": (
            "tools",
            repo_root
            / "labs/lab-1x/solution/tools/lab_1_1_TRI_calculate_days_since_purchase.py",
        ),
        "lab_1_1_TRI_calculate_warranty_expiry_days.py": (
            "tools",
            repo_root
            / "labs/lab-1x/solution/tools/lab_1_1_TRI_calculate_warranty_expiry_days.py",
        ),
        "lab_1_1_TRI_get_customer_by_id.py": (
            "tools",
            repo_root / "labs/lab-1x/solution/tools/lab_1_1_TRI_get_customer_by_id.py",
        ),
        "lab_1_1_requirements.txt": (
            "tools",
            repo_root / "labs/lab-1x/solution/tools/lab_1_1_requirements.txt",
        ),
    }

    replacement = f"{namespace}_TRI_"
    for destination_name, (subfolder, source) in sources.items():
        content = source.read_text(encoding="utf-8")
        if destination_name != "lab_1_1_requirements.txt" and destination_name != "requirements.txt":
            content = content.replace("TRI_", replacement)
        if destination_name == "TRI_cp4ba_basic_member.yaml":
            content = re.sub(
                r"^(\s*server_url:)\s+.*$",
                rf"\1 {sor_base_url}",
                content,
                flags=re.MULTILINE,
            )
        if destination_name == "lab_1_1_TRI_SOR_Orders_openapi.json":
            specification = json.loads(content)
            specification["servers"] = [
                {
                    "url": (
                        f"{sor_base_url}/automationservices/rest/TSOR/Orders"
                    )
                }
            ]
            content = json.dumps(specification, indent=2, ensure_ascii=False) + "\n"
        destination_dir = output / subfolder
        destination_dir.mkdir(parents=True, exist_ok=True)
        (destination_dir / destination_name).write_text(content, encoding="utf-8")

    print(f"Prepared Lab 1.1 artifacts in: {output}")
    for name, (subfolder, _source) in sources.items():
        print(f"  {subfolder}/{name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
