#!/usr/bin/env python3
"""Prepare and import Lab 3 artifacts for one participant namespace.

For each artifact this script checks whether it already exists in the active
wxO environment before importing — if it does, the import step is skipped
(safe to re-run; assumes the artifact was set up correctly in Lab 1.1 or
a prior run of this script).

Credentials are always (re-)set, even when an artifact already exists, so
that running this script acts as a credential-refresh for the connection.

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
    python3 labs/lab-3/solution/scripts/prepare_lab_3.py \\
        --sor-base-url <YOUR-SOR-BASE-URL> \\
        --sor-user-id  <YOUR-SOR-USER-ID> \\
        --sor-password <YOUR-SOR-PASSWORD>

  From the repository root (Windows):
    python labs\\lab-3\\solution\\scripts\\prepare_lab_3.py ^
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
                   labs/lab-3/solution/lab-3-prepared/ inside the repo.

  Examples
  ────────
  Typical first run (namespace = SOR user ID):
    python3 labs/lab-3/solution/scripts/prepare_lab_3.py \\
        --sor-base-url https://cp4ba.example.test/bas \\
        --sor-user-id  usr001 \\
        --sor-password s3cr3t

  Override namespace separately from SOR user ID:
    python3 labs/lab-3/solution/scripts/prepare_lab_3.py \\
        --sor-base-url https://cp4ba.example.test/bas \\
        --sor-user-id  usr001 \\
        --sor-password s3cr3t \\
        --namespace    usr099

  Re-run to refresh credentials after a token expiry (safe — skips imports):
    python3 labs/lab-3/solution/scripts/prepare_lab_3.py \\
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
  Step 3  (NAMESPACE)_TRI_fetch_baw_pdf         Python tool — fetches warranty
             import: always (tools import is idempotent — re-import updates)
             PDF from BAW and returns a signed file URL for Document AI nodes.
             Credentials injected via --app-id on import (Key-Value connection).
 Step 4  (NAMESPACE)_TRI_get_pending_warranty_requests
            Python tool — returns pending warranty claim records for batch
            import: always (tools import is idempotent — re-import updates)
            Credentials injected via --app-id on import (Key-Value connection).
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

import yaml

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


def _patch_python_tool(src: Path, old_func_name: str, new_func_name: str, output_dir: Path) -> Path:
    """Rename the tool function definition in a Python tool file."""
    content = src.read_text(encoding="utf-8")
    content = content.replace(old_func_name, new_func_name)
    # Also update expect_credentials app_id to use the namespaced connection
    dest = output_dir / src.name
    dest.write_text(content, encoding="utf-8")
    return dest


def _patch_python_tool_credentials(content: str, kv_team_app_id: str) -> str:
    """Namespace-patch the hardcoded TRI_cp4ba_keyvalue_team app-id references.

    Covers the @tool(expected_credentials=[ExpectedCredentials(app_id=...)])
    declaration, the WXO_CONNECTION_<app_id>_<KEY> env var names it implies,
    and the docstring mentions. Tools that don't use this connection (no
    occurrences of the literal string) are left unchanged.
    """
    return content.replace("TRI_cp4ba_keyvalue_team", kv_team_app_id)


def _patch_agent_yaml(src: Path, replacement: str, output_dir: Path) -> Path:
    """Namespace-patch an agent YAML file (display_name + tool references)."""
    with open(src, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    data["display_name"] = data.get("display_name", "").replace("TRI_", replacement)
    data["tools"] = [t.replace("TRI_", replacement) for t in data.get("tools", [])]
    dest = output_dir / src.name
    with open(dest, "w", encoding="utf-8") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    return dest


def _patch_workflow_json(src: Path, replacement: str, output_dir: Path) -> Path:
    """Namespace-patch a workflow JSON file (name, display_name, tool references)."""
    import json
    with open(src, encoding="utf-8") as f:
        data = json.load(f)
    # Patch top-level spec fields
    if "spec" in data:
        data["spec"]["name"] = data["spec"].get("name", "").replace("TRI_", replacement)
        data["spec"]["display_name"] = data["spec"].get("display_name", "").replace("TRI_", replacement)
    # Patch tool references in all nodes
    if "nodes" in data:
        for node in data["nodes"].values():
            if isinstance(node, dict) and "spec" in node and "tool" in node["spec"]:
                node["spec"]["tool"] = node["spec"]["tool"].replace("TRI_", replacement)
    dest = output_dir / src.name
    with open(dest, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    return dest


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Prepare Lab 3 artifacts for one participant namespace. "
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
            "Optional directory for prepared artifacts. Defaults to "
            "labs/lab-3/solution/lab-3-prepared in the repo."
        ),
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    args = parse_args()

    namespace = (args.namespace or args.sor_user_id).strip().rstrip("_")
    if not re.fullmatch(r"[A-Za-z0-9]+", namespace):
        error("Namespace may contain only letters and digits, e.g. usr001.")

    sor_base_url = args.sor_base_url.strip().rstrip("/")
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
    output = args.output or (repo_root / "labs/lab-3/solution/lab-3-prepared")
    output.mkdir(parents=True, exist_ok=True)

    # Source paths
    lab1x_connections = repo_root / "labs/lab-1x/solution/connections"
    solution_toolkits = repo_root / "labs/lab-1x/solution/toolkits"
    fetch_pdf_src = (
        repo_root / "labs/lab-3/solution/tools/TRI_fetch_baw_pdf/TRI_fetch_baw_pdf.py"
    )
    warranty_requests_src = (
        repo_root
        / "labs/lab-3/solution/tools"
        / "TRI_get_pending_warranty_requests"
        / "TRI_get_pending_warranty_requests.py"
    )
    requirements_src = repo_root / "labs/lab-3/solution/tools/lab_3_requirements.txt"

    # Output sub-directories
    connections_dir = output / "connections"
    toolkits_dir = output / "toolkits"
    tools_dir = output / "tools"
    agents_dir = output / "agents"
    workflows_dir = output / "workflows"
    for d in (connections_dir, toolkits_dir, tools_dir, agents_dir, workflows_dir):
        d.mkdir(parents=True, exist_ok=True)

    replacement = f"{namespace}_TRI_"
    kv_team_app_id = f"{namespace}_TRI_cp4ba_keyvalue_team"
    toolkit_name = f"{namespace}_TRI_SOR_MCP"
    fetch_pdf_tool_name = f"{namespace}_TRI_fetch_baw_pdf"
    warranty_requests_tool_name = f"{namespace}_TRI_get_pending_warranty_requests"

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
        "-e", f"USERID={args.sor_user_id}",
        "-e", f"PASSWORD={args.sor_password}",
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
    # Step 3 — TRI_fetch_baw_pdf Python tool
    # ======================================================================
    header(f"Step 3 — Python tool ({fetch_pdf_tool_name})")

    fetch_pdf_content = fetch_pdf_src.read_text(encoding="utf-8")
    # Patch function name (TRI_fetch_baw_pdf → {namespace}_TRI_fetch_baw_pdf)
    fetch_pdf_content = fetch_pdf_content.replace("TRI_fetch_baw_pdf", fetch_pdf_tool_name)
    # Patch @expect_credentials app_id to use the namespaced connection
    fetch_pdf_content = _patch_python_tool_credentials(fetch_pdf_content, kv_team_app_id)
    fetch_pdf_dest = tools_dir / "TRI_fetch_baw_pdf.py"
    fetch_pdf_dest.write_text(fetch_pdf_content, encoding="utf-8")
    success(f"Python tool file written: {fetch_pdf_dest}")

    run([
        "orchestrate", "tools", "import",
        "-k", "python",
        "--file", str(fetch_pdf_dest),
        "--requirements-file", str(requirements_src),
        "--app-id", kv_team_app_id,
    ])
    success(f"Python tool imported: {fetch_pdf_tool_name}")

    # ======================================================================
    # Step 4 — TRI_get_pending_warranty_requests Python tool
    # ======================================================================
    header(f"Step 4 — Python tool ({warranty_requests_tool_name})")

    warranty_requests_content = warranty_requests_src.read_text(encoding="utf-8")
    # Patch function name
    warranty_requests_content = warranty_requests_content.replace(
        "TRI_get_pending_warranty_requests",
        warranty_requests_tool_name,
    )
    # Patch @expect_credentials app_id
    warranty_requests_content = _patch_python_tool_credentials(
        warranty_requests_content, kv_team_app_id
    )
    warranty_requests_dest = tools_dir / "TRI_get_pending_warranty_requests.py"
    warranty_requests_dest.write_text(warranty_requests_content, encoding="utf-8")
    success(f"Python tool file written: {warranty_requests_dest}")

    run([
        "orchestrate", "tools", "import",
        "-k", "python",
        "--file", str(warranty_requests_dest),
        "--requirements-file", str(requirements_src),
        "--app-id", kv_team_app_id,
    ])
    success(f"Python tool imported: {warranty_requests_tool_name}")

    # ======================================================================
    # Step 5 — Agents (prepared but not imported)
    # ======================================================================
    header("Step 5 — Agents (prepared for deployment)")

    agents_src = repo_root / "labs/lab-3/solution/agents"
    if agents_src.exists():
        for agent_yaml in agents_src.glob("*.yaml"):
            namespaced_agent = _patch_agent_yaml(agent_yaml, replacement, agents_dir)
            success(f"Agent file written: {namespaced_agent} (not imported)")
    else:
        skip("No agents found in source directory")

    # ======================================================================
    # Step 6 — Workflows (prepared but not imported)
    # ======================================================================
    header("Step 6 — Workflows (prepared for deployment)")

    workflows_src = repo_root / "labs/lab-3/solution/workflows"
    if workflows_src.exists():
        for workflow_json in workflows_src.glob("*.json"):
            namespaced_workflow = _patch_workflow_json(workflow_json, replacement, workflows_dir)
            success(f"Workflow file written: {namespaced_workflow} (not imported)")
    else:
        skip("No workflows found in source directory")

    # ======================================================================
    # Done
    # ======================================================================
    header("Done")
    success(
        "All steps complete. The following artifacts are ready in your namespace:\n"
        f"  Connection : {kv_team_app_id}  (credentials refreshed)\n"
        f"  Toolkit    : {toolkit_name}\n"
        f"  Tool       : {fetch_pdf_tool_name}\n"
        f"  Tool       : {warranty_requests_tool_name}\n"
        f"  Agents     : prepared (not imported)\n"
        f"  Workflows  : prepared (not imported)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
