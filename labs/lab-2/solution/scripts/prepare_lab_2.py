#!/usr/bin/env python3
"""Prepare and import Lab 2 artifacts for one participant namespace.

For each artifact this script checks whether it already exists in the active
wxO environment before importing — if it does, the import step is skipped
(safe to re-run; assumes the artifact was set up correctly in Lab 1.1).

Credentials are always (re-)set, even when an artifact already exists, so
that running this script acts as a credential-refresh for both connections.

Usage
──────────────────────────────────────────────────────────────────────────────
  Prerequisites
  ─────────────
  1. Python 3.11 or later.
  2. The watsonx Orchestrate ADK CLI installed and on your PATH.
  3. An active ADK environment pointing at the event wxO tenant:
       orchestrate env activate trinity-lab -a <YOUR-API-KEY>
  4. The Trinity-Event repository cloned or downloaded to your local machine.
     Run this script from the repository root, or from any directory — the
     script resolves all paths relative to its own location automatically.

  Invocation
  ──────────
  From the repository root (Mac/Linux):
    python3 labs/lab-2/solution/scripts/prepare_lab_2.py \\
        --sor-base-url <YOUR-SOR-BASE-URL> \\
        --sor-user-id  <YOUR-SOR-USER-ID> \\
        --sor-password <YOUR-SOR-PASSWORD>

  From the repository root (Windows):
    python labs\\lab-2\\solution\\scripts\\prepare_lab_2.py ^
        --sor-base-url <YOUR-SOR-BASE-URL> ^
        --sor-user-id  <YOUR-SOR-USER-ID> ^
        --sor-password <YOUR-SOR-PASSWORD>

  Arguments
  ─────────
  --sor-base-url   Required. The SOR REST base URL, e.g.
                   https://cp4ba.example.test/bas
                   The script appends /bas automatically if omitted.
  --sor-user-id    Required. Your SOR user ID (event GitHub labs page, section 2),
                   e.g. usr001. Also used as the wxO namespace prefix when
                   --namespace is not supplied.
  --sor-password   Required. Your SOR password (event GitHub labs page, section 2).
  --namespace      Optional. Override the wxO namespace prefix independently
                   of --sor-user-id, e.g. --namespace usr042. Defaults to the
                   value of --sor-user-id.
  --output         Optional. Directory where prepared artifact files are
                   written before import. Defaults to
                   labs/lab-2/solution/lab-2-prepared/ inside the repo.

  Examples
  ────────
  Typical first run (namespace = SOR user ID):
    python3 labs/lab-2/solution/scripts/prepare_lab_2.py \\
        --sor-base-url https://cp4ba.example.test/bas \\
        --sor-user-id  usr001 \\
        --sor-password s3cr3t

  Override namespace separately from SOR user ID:
    python3 labs/lab-2/solution/scripts/prepare_lab_2.py \\
        --sor-base-url https://cp4ba.example.test/bas \\
        --sor-user-id  usr001 \\
        --sor-password s3cr3t \\
        --namespace    usr099

  Re-run to refresh credentials after a token expiry (safe — skips imports):
    python3 labs/lab-2/solution/scripts/prepare_lab_2.py \\
        --sor-base-url https://cp4ba.example.test/bas \\
        --sor-user-id  usr001 \\
        --sor-password s3cr3t

  Output
  ──────
  The script prints a numbered [INFO] / [OK] / [SKIP] / [ERROR] line for
  each step. A final [OK] "All steps complete" summary lists every artifact
  that is ready in your namespace. If any step fails, fix the reported issue
  and re-run — every step is safe to repeat.

Artifacts managed by this script
──────────────────────────────────────────────────────────────────────────────
  Step 1  (NAMESPACE)_TRI_cp4ba_keyvalue_team   Key-Value/team connection
             import: skip if exists
             credentials: always set (draft)
  Step 2  (NAMESPACE)_TRI_SOR_MCP               MCP toolkit
             import: skip if exists
             (no credentials — inherits from Key-Value connection)
  Step 3  (NAMESPACE)_TRI_cp4ba_basic_member    Basic-auth/member connection
             import: skip if exists
             credentials: always set (draft)
  Step 4  Prepare Billing OpenAPI tool file      (file generation only)
  Step 5  (NAMESPACE)_TRI_TSOR_Billing_*        Three Billing OpenAPI tools
             import: always (tools import is idempotent — re-import updates)
  Step 6  (NAMESPACE)_TRI_billing_evidence_agent Evidence agent for Exercise 5
             import: skip if exists
  Step 7  (NAMESPACE)_TRI_sor_error_detail      Python tool for Exercise 7
             import: always (tools import is idempotent — re-import updates)
             Extracts structured error details from a failed SOR tool node's
             implicit error outputs (error_message, error_detail, sor_error_code).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

import yaml


def _load_event_env(script_path: Path) -> dict:
    """Read labs/event.env (repo root / labs / event.env) and return key→value dict.

    Ignores blank lines and comment lines. Returns {} when the file does not exist
    or is fully blank. Callers should always prefer explicit CLI arguments over the
    values returned here — this is a fallback only.
    """
    env_path = script_path.resolve().parents[4] / "labs" / "event.env"
    result: dict = {}
    if not env_path.exists():
        return result
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        k, v = k.strip(), v.strip()
        if k and v:
            result[k] = v
    return result

# Force UTF-8 stdout/stderr so progress lines print cleanly on Windows
# console (cp1252) as well as piped streams.
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

RED = "\033[0;31m"
GREEN = "\033[0;32m"
CYAN = "\033[0;36m"
YELLOW = "\033[0;33m"
BOLD = "\033[1m"
RESET = "\033[0m"

# Fixed SOR connection constants — match deploy.py
_VERIFY_SSL = "false"
_HTTP_TIMEOUT = "300"


def info(msg: str) -> None:
    print(f"{CYAN}[INFO]{RESET}  {msg}")


def skip(msg: str) -> None:
    print(f"{YELLOW}[SKIP]{RESET}  {msg}")


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


# ---------------------------------------------------------------------------
# Existence checks
# ---------------------------------------------------------------------------

def connection_exists(app_id: str) -> bool:
    """Return True if a connection with the given app_id already exists."""
    result = subprocess.run(
        ["orchestrate", "connections", "list"],
        shell=False, capture_output=True, text=True,
    )
    return app_id in result.stdout


def toolkit_exists(name: str) -> bool:
    """Return True if a toolkit with the given name already exists."""
    result = subprocess.run(
        ["orchestrate", "toolkits", "list"],
        shell=False, capture_output=True, text=True,
    )
    return name in result.stdout


def agent_exists(name: str) -> bool:
    """Return True if an agent with the given name already exists."""
    result = subprocess.run(
        ["orchestrate", "agents", "list"],
        shell=False, capture_output=True, text=True,
    )
    return name in result.stdout


# ---------------------------------------------------------------------------
# YAML patching helpers
# ---------------------------------------------------------------------------

def _patch_keyvalue_connection(src: Path, replacement: str, output_dir: Path) -> Path:
    """Namespace-patch the Key-Value/team connection YAML and write to output_dir."""
    with open(src, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    data["app_id"] = data["app_id"].replace("TRI_", replacement)
    data["description"] = data["description"].replace("TRI_", replacement)
    dest = output_dir / src.name
    with open(dest, "w", encoding="utf-8") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    return dest


def _patch_basic_member_connection(
    src: Path, replacement: str, sor_base_url: str, output_dir: Path
) -> Path:
    """Namespace-patch the Basic-auth/member connection YAML and inject server_url."""
    content = src.read_text(encoding="utf-8")
    content = content.replace("TRI_", replacement)
    content = re.sub(
        r"^(\s*server_url:)\s+.*$",
        rf"\1 {sor_base_url}",
        content,
        flags=re.MULTILINE,
    )
    dest = output_dir / src.name
    dest.write_text(content, encoding="utf-8")
    return dest


def _patch_toolkit(src: Path, replacement: str, output_dir: Path) -> Path:
    """Namespace-patch the MCP toolkit YAML (name + connection reference)."""
    with open(src, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    data["name"] = data["name"].replace("TRI_", replacement)
    data["connections"] = [c.replace("TRI_", replacement) for c in data.get("connections", [])]
    dest = output_dir / src.name
    with open(dest, "w", encoding="utf-8") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    return dest


def _patch_agent(src: Path, replacement: str, output_dir: Path) -> Path:
    """Namespace-patch the evidence agent YAML (name, display_name, tools)."""
    with open(src, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    data["name"] = data["name"].replace("TRI_", replacement)
    # Prefix display_name with [NAMESPACE] tag so the UI shows distinct names
    ns_tag = replacement.rstrip("_").removeprefix("").rstrip("_")  # e.g. "usr001_TRI_" → "usr001"
    if "display_name" in data:
        data["display_name"] = f"[{ns_tag}] {data['display_name']}"
    # Patch tool references: "TRI_SOR_MCP:TSOR_*" → "(NS)_TRI_SOR_MCP:TSOR_*"
    if "tools" in data:
        data["tools"] = [t.replace("TRI_", replacement) for t in data["tools"]]
    dest = output_dir / src.name
    with open(dest, "w", encoding="utf-8") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    return dest


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Prepare Lab 2 artifacts for one participant namespace. "
            "Each artifact is imported only if not already present; "
            "credentials are always refreshed."
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
        default=None,
        help=(
            "System of Record base URL, pasted as shown on the labs page (you may include or omit "
            "the /bas suffix — it is added automatically if missing). Defaults to the sorURL value "
            "in labs/event.env when not supplied."
        ),
    )
    parser.add_argument(
        "--sor-user-id",
        default=None,
        help=(
            "Your SOR user ID. Defaults to the sorUsername value in labs/event.env when not supplied."
        ),
    )
    parser.add_argument(
        "--sor-password",
        default=None,
        help=(
            "Your SOR password. Defaults to the sorPassword value in labs/event.env when not supplied."
        ),
    )
    parser.add_argument(
        "--output",
        type=Path,
        help=(
            "Optional directory for prepared artifacts. Defaults to "
            "labs/lab-2/solution/lab-2-prepared in the repo."
        ),
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    args = parse_args()
    env = _load_event_env(Path(__file__))

    sor_user_id = (args.sor_user_id or env.get("sorUsername") or "").strip()
    sor_password = (args.sor_password or env.get("sorPassword") or "").strip()
    namespace = (args.namespace or sor_user_id).strip().rstrip("_")
    if not re.fullmatch(r"[A-Za-z0-9]+", namespace):
        error(
            "Namespace may contain only letters and digits, e.g. usr001. "
            "Provide --sor-user-id or set sorUsername in labs/event.env."
        )
    if not sor_password:
        error("Provide --sor-password or set sorPassword in labs/event.env.")

    raw_url = (args.sor_base_url or env.get("sorURL") or "").strip()
    if not raw_url:
        error("Provide --sor-base-url or set sorURL in labs/event.env.")
    sor_base_url = raw_url.rstrip("/")
    parsed_url = urlparse(sor_base_url)
    if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
        error(
            "--sor-base-url must be an absolute HTTP(S) URL, e.g. "
            "https://example.test/bas."
        )
    if not sor_base_url.endswith("/bas"):
        sor_base_url = f"{sor_base_url}/bas"

    if not subprocess.run(
        ["orchestrate", "--version"], shell=False, capture_output=True
    ).returncode == 0:
        error(
            "'orchestrate' CLI not found. Install the watsonx Orchestrate ADK "
            "and ensure it is on your PATH."
        )

    auth_check = subprocess.run(
        ["orchestrate", "agents", "list"], shell=False, capture_output=True, text=True
    )
    if auth_check.returncode != 0:
        error(
            "Not authenticated against the active wxO environment:\n"
            f"{(auth_check.stdout + auth_check.stderr).strip()}\n"
            "  Run `orchestrate env activate trinity-lab` to refresh your token, "
            "then retry."
        )

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parents[3]
    output = args.output or (repo_root / "labs/lab-2/solution/lab-2-prepared")
    output.mkdir(parents=True, exist_ok=True)

    # Source paths
    lab1x_connections = repo_root / "labs/lab-1x/solution/connections"
    solution_toolkits = repo_root / "labs/lab-1x/solution/toolkits"
    lab2_agents = repo_root / "labs/lab-2/solution/agents"
    billing_openapi_src = (
        repo_root / "labs/lab-2/solution/tools/lab_2_TRI_SOR_Billing_openapi.json"
    )
    sor_error_detail_src = (
        repo_root / "labs/lab-2/solution/tools/TRI_sor_error_detail/TRI_sor_error_detail.py"
    )

    # Output sub-directories
    connections_dir = output / "connections"
    toolkits_dir = output / "toolkits"
    agents_dir = output / "agents"
    tools_dir = output / "tools"
    for d in (connections_dir, toolkits_dir, agents_dir, tools_dir):
        d.mkdir(parents=True, exist_ok=True)

    replacement = f"{namespace}_TRI_"
    kv_team_app_id = f"{namespace}_TRI_cp4ba_keyvalue_team"
    basic_member_app_id = f"{namespace}_TRI_cp4ba_basic_member"
    toolkit_name = f"{namespace}_TRI_SOR_MCP"
    evidence_agent_name = f"{namespace}_TRI_billing_evidence_agent"
    sor_error_detail_tool_name = f"{namespace}_TRI_sor_error_detail"

    # ======================================================================
    # Step 1 — Key-Value / team connection (TRI_cp4ba_keyvalue_team)
    # ======================================================================
    header("Step 1 — Key-Value connection (TRI_cp4ba_keyvalue_team)")

    kv_src = lab1x_connections / "TRI_cp4ba_keyvalue_team.yaml"
    kv_dest = _patch_keyvalue_connection(kv_src, replacement, connections_dir)
    success(f"Connection file written: {kv_dest}")

    if connection_exists(kv_team_app_id):
        skip(f"Connection '{kv_team_app_id}' already exists — skipping import.")
    else:
        run(["orchestrate", "connections", "import", "--file", str(kv_dest)])
        success(f"Connection imported: {kv_team_app_id}")

    # Configure the connection slot before setting credentials — safe to retry
    try:
        run([
            "orchestrate", "connections", "configure",
            "--app-id", kv_team_app_id,
            "--environment", "draft",
            "--type", "team",
            "--kind", "key_value",
        ])
    except subprocess.CalledProcessError:
        pass  # already configured

    run([
        "orchestrate", "connections", "set-credentials",
        "-a", kv_team_app_id,
        "--env", "draft",
        "-e", f"ENDPOINT={sor_base_url}",
        "-e", f"USERID={sor_user_id}",
        "-e", f"PASSWORD={sor_password}",
        "-e", f"VERIFY_SSL={_VERIFY_SSL}",
        "-e", f"HTTP_TIMEOUT={_HTTP_TIMEOUT}",
    ])
    success(f"Credentials set for {kv_team_app_id} (draft)")

    # ======================================================================
    # Step 2 — MCP toolkit (TRI_SOR_MCP)
    # ======================================================================
    header("Step 2 — MCP toolkit (TRI_SOR_MCP)")

    toolkit_src = solution_toolkits / "TRI_SOR_MCP.yaml"
    toolkit_dest = _patch_toolkit(toolkit_src, replacement, toolkits_dir)
    success(f"Toolkit file written: {toolkit_dest}")

    if toolkit_exists(toolkit_name):
        skip(f"Toolkit '{toolkit_name}' already exists — skipping import.")
    else:
        run(["orchestrate", "toolkits", "import", "--file", str(toolkit_dest)])
        success(f"Toolkit imported: {toolkit_name}")

    # ======================================================================
    # Step 3 — Basic-auth / member connection (TRI_cp4ba_basic_member)
    # ======================================================================
    header("Step 3 — Basic-auth connection (TRI_cp4ba_basic_member)")

    basic_member_src = lab1x_connections / "TRI_cp4ba_basic_member.yaml"
    basic_member_dest = _patch_basic_member_connection(
        basic_member_src, replacement, sor_base_url, connections_dir
    )
    success(f"Connection file written: {basic_member_dest}")

    if connection_exists(basic_member_app_id):
        skip(f"Connection '{basic_member_app_id}' already exists — skipping import.")
    else:
        run(["orchestrate", "connections", "import", "--file", str(basic_member_dest)])
        success(f"Connection imported: {basic_member_app_id}")

    run([
        "orchestrate", "connections", "set-credentials",
        "--app-id", basic_member_app_id,
        "--env", "draft",
        "-u", sor_user_id,
        "-p", sor_password,
    ])
    success(f"Credentials set for {basic_member_app_id} (draft)")

    # ======================================================================
    # Step 4 — Prepare Billing OpenAPI tool file
    # ======================================================================
    header("Step 4 — Prepare Billing OpenAPI tool file")

    billing_spec = json.loads(billing_openapi_src.read_text(encoding="utf-8"))
    billing_spec["servers"] = [
        {"url": f"{sor_base_url}/automationservices/rest/TSOR/Billing"}
    ]
    for path_item in billing_spec.get("paths", {}).values():
        for operation in path_item.values():
            if "operationId" in operation:
                operation["operationId"] = operation["operationId"].replace(
                    "TRI_", replacement
                )
            if "summary" in operation:
                operation["summary"] = operation["summary"].replace(
                    "TRI_", replacement
                )
    billing_dest = tools_dir / "lab_2_TRI_SOR_Billing_openapi.json"
    billing_dest.write_text(
        json.dumps(billing_spec, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    success(f"Billing OpenAPI file written: {billing_dest}")

    # ======================================================================
    # Step 5 — Import Billing OpenAPI tools
    # ======================================================================
    header("Step 5 — Import Billing OpenAPI tools")

    run([
        "orchestrate", "tools", "import",
        "-k", "openapi",
        "--file", str(billing_dest),
        "--app-id", basic_member_app_id,
    ])
    success(
        f"Billing OpenAPI tools imported:\n"
        f"  {replacement}TSOR_Billing_get_billing_record_by_id\n"
        f"  {replacement}TSOR_Billing_get_billing_records_by_order_id_ext\n"
        f"  {replacement}TSOR_Billing_update_billing_record_status_description"
    )

    # ======================================================================
    # Step 6 — Evidence agent (TRI_billing_evidence_agent)
    # ======================================================================
    header("Step 6 — Evidence agent (TRI_billing_evidence_agent)")

    evidence_src = lab2_agents / "lab_2_TRI_billing_evidence_agent.yaml"
    evidence_dest = _patch_agent(evidence_src, replacement, agents_dir)
    success(f"Agent file written: {evidence_dest}")

    if agent_exists(evidence_agent_name):
        skip(f"Agent '{evidence_agent_name}' already exists — skipping import.")
    else:
        run(["orchestrate", "agents", "import", "--file", str(evidence_dest)])
        success(f"Agent imported: {evidence_agent_name}")

    # ======================================================================
    # Step 7 — SOR error detail Python tool (TRI_sor_error_detail)
    # ======================================================================
    header("Step 7 — SOR error detail Python tool (TRI_sor_error_detail)")

    # Patch the function name and class name to carry the participant namespace.
    sor_error_detail_content = sor_error_detail_src.read_text(encoding="utf-8")
    sor_error_detail_content = sor_error_detail_content.replace("TRI_sor_error_detail", sor_error_detail_tool_name)
    sor_error_detail_dest = tools_dir / "TRI_sor_error_detail.py"
    sor_error_detail_dest.write_text(sor_error_detail_content, encoding="utf-8")
    success(f"Python tool file written: {sor_error_detail_dest}")

    run([
        "orchestrate", "tools", "import",
        "-k", "python",
        "--file", str(sor_error_detail_dest),
    ])
    success(f"Python tool imported: {sor_error_detail_tool_name}")

    # ======================================================================
    # Done
    # ======================================================================
    header("Done")
    success(
        "All steps complete. The following artifacts are ready in your namespace:\n"
        f"  Connection : {kv_team_app_id}  (credentials refreshed)\n"
        f"  Toolkit    : {toolkit_name}\n"
        f"  Connection : {basic_member_app_id}  (credentials refreshed)\n"
        f"  Tools      : {replacement}TSOR_Billing_get_billing_record_by_id\n"
        f"             : {replacement}TSOR_Billing_get_billing_records_by_order_id_ext\n"
        f"             : {replacement}TSOR_Billing_update_billing_record_status_description\n"
        f"  Agent      : {evidence_agent_name}\n"
        f"  Tool       : {sor_error_detail_tool_name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
