# Labs

This folder contains the builder lab artifacts for the Trinity enablement event. Each lab has its own subfolder with three layers mirroring the root-level structure of the end-to-end solution.

The end-to-end Trinity solution lives at repo root (`solution/`, `specs/`, `tests/`) — it is the primary deliverable and is intentionally kept separate from the labs.

## Structure

```
labs/
  lab-0/                ← Lab 0: Trinity scenario walkthrough (no author work yet)
  lab-1x/               ← Ramy: Technical Worker Agent (RAG/KB) + Order Worker Agent (tools) + supervisor/collaborator patterns
  lab-2/                ← Pooja: Agentic Workflow — Billing Dispute (decision table + HITL)
  lab-3/                ← Sundeep: Agentic Workflow — Document Processing (upload, extraction, HITL, warranty rule)
  lab-4/                ← Vinicius: AgentOps (planned)

Each lab folder contains:
  solution/             ← Solution artifacts organized by type
  specs/                ← Lab use case and exercise specs
  tests/cases/          ← YAML test cases for this lab (same format as root tests/)
```

Participant-facing lab guides live at the top-level [`lab-guides/`](../lab-guides/), not nested under `labs/lab-Nx/` — see `lab-guides/LAB-GUIDE-CONVENTIONS.md`.

## Solution Artifacts Organization

Solution artifacts are organized by type, permanently, at `labs/lab-Nx/solution/`:
```
labs/lab-Nx/solution/
  agents/
    lab-N-M_TRI_agent_name.yaml      ← Lab N, Exercise/Section M
  tools/
    lab-N-M_TRI_tool_name.py
    lab-N-M_TRI_tool_name.yaml
  knowledge_bases/
    lab-N-M_KB_name.txt
  workflows/
    lab-N-M_TRI_workflow_name.json
```

**Naming convention:**
- Prefix all artifacts with `lab-N-M_` where `N` is the lab number and `M` is the exercise/section number (e.g., `lab-1-0_`, `lab-1-1_`)
- This keeps artifacts clearly sorted and attributed to their lab and exercise
- Example: `lab-1-1_TRI_order_agent.yaml` belongs to Lab 1, Exercise 1

**When promoting to publication:**
- **Reversed 2026-09-29:** solution artifacts stay at `labs/lab-Nx/solution/` permanently — they no longer move to `lab-guides/` when a lab is promoted for formal review. Only the guide document itself moves to `lab-guides/`.
- Lab guides reference artifacts at their one, permanent `labs/lab-Nx/solution/` location — no path update needed at promotion time

## Working conventions

- **Solution artifacts** — export from wxO UI using Bob + ADK CLI (`orchestrate <type> export`), not manual download. Overwrite the file in `solution/` and commit.
- **Test cases** — same YAML format as root `tests/`. Bob assists authoring. Run via `scripts/test.py` (custom `--cases-dir` support planned — see `SETUP-PLAN.md`).
- **Lab test results** — gitignored locally (personal dev runs). Baseline snapshots committed to `tests/cases/baselines/` when stable milestones are reached (convention TBD with team).
- **Branch** — each lab owner works on their own branch and opens a PR to `main` when ready for review.

## Lab owners

| Lab | Topic | Owner |
|-----|-------|-------|
| lab-1x | Technical Worker Agent (RAG/KB) · Order Worker Agent (MCP/OpenAPI/Python) · Supervisor and Collaborator patterns | Ramy |
| lab-2 | Agentic Workflow: Billing Dispute (decision table + HITL) | Pooja |
| lab-3 | Agentic Workflow: Document Processing (upload, extraction, HITL, warranty rule) | Sundeep |
| lab-4 | AgentOps (planned) | Vinicius |
