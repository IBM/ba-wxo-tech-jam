#!/usr/bin/env python3
"""Automate the Lab 1.3 "If you are starting directly here" import sequence.

Runs prepare_lab_1_1.py (if the prepared output directory does not already
exist) and then imports both Lab 1.3 collaborator agents and everything they
depend on: shared connections, the MCP toolkit, OpenAPI and Python tools,
and the two agents themselves. The lab guide's own manual UI sanity checks
are not scripted — follow the lab guide for those.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

# Force UTF-8 stdout/stderr so progress lines print cleanly on Windows
# console (cp1252) as well as piped streams.
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

RED = "\033[0;31m"
GREEN = "\033[0;32m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
RESET = "\033[0m"


def info(msg: str) -> None:
    print(f"{CYAN}[INFO]{RESET}  {msg}")


def success(msg: str) -> None:
    print(f"{GREEN}[OK]{RESET}    {msg}")


def error(msg: str) -> None:
    print(f"{RED}[ERROR]{RESET} {msg}")
    sys.exit(1)


def header(msg: str) -> None:
    print(f"\n{BOLD}{msg}{RESET}")
    print("-" * 60)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True, shell=False)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Prepare Lab 1.1 artifacts (if needed) and import both Lab 1.3 "
            "collaborator agents, their connections, and their tools. "
            "Manual UI sanity checks from the lab guide are not scripted."
        )
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
        "--sor-base-url",
        required=True,
        help=(
            "System of Record base URL, pasted as shown on the labs page (it already ends in /bas; "
            "/bas is added if missing). See "
            "the labs page of the event GitHub repository, section '2. Grab your system of record credentials'."
        ),
    )
    parser.add_argument(
        "--sor-user-id",
        required=True,
        help=(
            "Your SOR user ID. See the labs page of the event GitHub repository, section '2. Grab your system of record credentials'."
        ),
    )
    parser.add_argument(
        "--sor-password",
        required=True,
        help=(
            "Your SOR password. See the labs page of the event GitHub repository, section '2. Grab your system of record credentials'."
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        help=(
            "Optional prepared-artifacts directory. Defaults to "
            "labs/lab-1x/solution/lab-1-prepared in the repo. Reused as-is "
            "if it already exists."
        ),
    )
    parser.add_argument(
        "--verify-ssl",
        default="false",
        help="VERIFY_SSL value for the Key-Value Team connection (default: false).",
    )
    parser.add_argument(
        "--http-timeout",
        default="300",
        help="HTTP_TIMEOUT value for the Key-Value Team connection (default: 300).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    namespace = (args.namespace or args.sor_user_id).strip().rstrip("_")
    if not re.fullmatch(r"[A-Za-z0-9]+", namespace):
        error("Namespace may contain only letters and digits, e.g. usr001.")

    sor_base_url = args.sor_base_url.strip().rstrip("/")
    parsed_url = urlparse(sor_base_url)
    if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
        error("--sor-base-url must be an absolute HTTP(S) URL, e.g. https://example.test/bas.")
    if not sor_base_url.endswith("/bas"):
        sor_base_url = f"{sor_base_url}/bas"

    if not shutil.which("orchestrate"):
        error("'orchestrate' CLI not found. Install the watsonx Orchestrate ADK and ensure it is on your PATH.")

    auth_check = subprocess.run(
        ["orchestrate", "agents", "list"], shell=False, capture_output=True, text=True
    )
    if auth_check.returncode != 0:
        error(
            "Not authenticated against the active wxO environment:\n"
            f"{(auth_check.stdout + auth_check.stderr).strip()}\n"
            "  Run `orchestrate env activate trinity-lab` to refresh your token, then retry."
        )

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parents[3]
    output = args.output or (repo_root / "labs/lab-1x/solution/lab-1-prepared")

    header("Step 1 — Prepare Lab 1.1 artifacts")
    if output.exists():
        info(f"{output} already exists — reusing it as-is.")
    else:
        info(f"{output} does not exist yet — running prepare_lab_1_1.py.")
        run([
            sys.executable,
            str(script_dir / "prepare_lab_1_1.py"),
            "--namespace", namespace,
            "--sor-base-url", sor_base_url,
            "--output", str(output),
        ])
        success(f"Lab 1.1 artifacts prepared in: {output}")

    connections_dir = output / "connections"
    toolkits_dir = output / "toolkits"
    tools_dir = output / "tools"
    agents_dir = output / "agents"

    keyvalue_team = f"{namespace}_TRI_cp4ba_keyvalue_team"
    basic_member = f"{namespace}_TRI_cp4ba_basic_member"

    header("Step 2 — Import Key-Value Team connection")
    run(["orchestrate", "connections", "import",
         "--file", str(connections_dir / "TRI_cp4ba_keyvalue_team.yaml")])
    success(f"Connection imported: {keyvalue_team}")

    header("Step 3 — Set Key-Value Team draft credentials")
    run(["orchestrate", "connections", "set-credentials",
         "--app-id", keyvalue_team, "--env", "draft",
         "-e", f"ENDPOINT={sor_base_url}",
         "-e", f"USERID={args.sor_user_id}",
         "-e", f"PASSWORD={args.sor_password}",
         "-e", f"VERIFY_SSL={args.verify_ssl}",
         "-e", f"HTTP_TIMEOUT={args.http_timeout}"])
    success(f"Credentials set for {keyvalue_team} (draft)")

    header("Step 4 — Import Basic Auth Member connection")
    run(["orchestrate", "connections", "import",
         "--file", str(connections_dir / "TRI_cp4ba_basic_member.yaml")])
    success(f"Connection imported: {basic_member}")

    header("Step 5 — Set Basic Auth Member draft credentials")
    run(["orchestrate", "connections", "set-credentials",
         "--app-id", basic_member, "--env", "draft",
         "-u", args.sor_user_id, "-p", args.sor_password])
    success(f"Credentials set for {basic_member} (draft)")

    header("Step 6 — Import MCP toolkit (Order agent)")
    run(["orchestrate", "toolkits", "import",
         "--file", str(toolkits_dir / "TRI_SOR_MCP.yaml")])
    success(f"Toolkit imported: {namespace}_TRI_SOR_MCP")

    header("Step 7 — Import Order agent's OpenAPI tools")
    run(["orchestrate", "tools", "import", "-k", "openapi",
         "--file", str(tools_dir / "lab_1_1_TRI_SOR_Orders_openapi.json"),
         "--app-id", basic_member])
    success("OpenAPI tools imported for the Order agent")

    header("Step 8 — Import Order agent")
    run(["orchestrate", "agents", "import",
         "--file", str(agents_dir / "lab_1_1_TRI_order_agent_complete.yaml")])
    success(f"Agent imported: {namespace}_TRI_order_agent")

    header("Step 9 — Import date-arithmetic Python tool (CRM agent)")
    run(["orchestrate", "tools", "import", "-k", "python",
         "-f", str(tools_dir / "lab_1_1_TRI_calculate_days_since_purchase.py")])
    success(f"Tool imported: {namespace}_TRI_calculate_days_since_purchase")

    header("Step 10 — Import customer-lookup Python tool (CRM agent)")
    run(["orchestrate", "tools", "import", "-k", "python",
         "-f", str(tools_dir / "lab_1_1_TRI_get_customer_by_id.py"),
         "--requirements-file", str(tools_dir / "lab_1_1_requirements.txt"),
         "--app-id", keyvalue_team])
    success(f"Tool imported: {namespace}_TRI_get_customer_by_id")

    header("Step 11 — Import CRM agent")
    run(["orchestrate", "agents", "import",
         "--file", str(agents_dir / "lab_1_1_TRI_crm_agent_lab_complete.yaml")])
    success(f"Agent imported: {namespace}_TRI_crm_agent_lab")

    header("Done")
    success("All 11 steps complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
