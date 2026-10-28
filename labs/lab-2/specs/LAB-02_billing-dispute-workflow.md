# Lab 2 — Agentic Workflow: Billing Dispute

**Lab owner:** Pooja
**Related use case spec:** [`specs/use-cases/UC-03_billing-dispute-duplicate-charge.md`](../../../specs/use-cases/UC-03_billing-dispute-duplicate-charge.md)
**Lab design reference:** [`specs/lab-design.md`](../../../specs/lab-design.md) § Lab 2

> This document collects all Lab 2 authoring guidance, extension scope, and implementation notes specific to building the `TRI_billing_dispute_workflow` as a hands-on exercise. It is the companion to UC-03, which defines the end-to-end scenario target behaviour. When the two documents conflict, UC-03 is the authoritative source for what the workflow must do; this document defines what Lab 2 participants will build and explore.

---

## Lab scope vs. end-to-end baseline

The end-to-end scenario baseline standardises on **Path A** only (Platinum customer, $2,500 disputed amount → supervisor review). Lab 2 goes beyond this baseline in three areas:

| Area | End-to-end baseline | Lab 2 scope |
|------|--------------------|-|
| Approval path | Path A (supervisor review) only | Path A **and** Path B (specialist resolves directly) |
| Workflow input validation | None — inputs assumed present | Gateway + error-exit guard clause at workflow entry |
| Sub-agent architecture | `TRI_billing_evidence_agent` (narrow, single-tool) | *(Future topic)* Refactored routing via full orchestrator / Shipping Agent hierarchy |

---

## Unique agentic workflow features

This section identifies the wxO Agentic Workflow capabilities that are unique to Lab 2 — features that a lab guide author should describe and a participant should be able to name by the end of the lab. They are derived from UC-03's workflow spec and represent what this workflow does that Lab 3 does not.

**Core teaching point:** The Agentic Workflow here is an *approval and audit mechanism*. The input arrives as unstructured conversation, but the decision must be deterministic, role-bounded, and produce a verifiable SOR write. The HITL step is not about uncertainty in extracted data — it is an approval gate that enforces governance and accountability before money changes hands.

> **Allen Chan #2 — Agent-as-Business-Process Fallacy.** Before participants build anything, the lab guide should apply the **three-question test** (Allen Chan #9 — Agent-Washing) to the billing dispute use case, then show why an agent fails all three questions and a workflow is therefore correct:
>
> | Question | Billing dispute answer |
> |----------|----------------------|
> | Is tool selection dynamic — does the model need to choose between 5+ ways to solve the problem? | No. The eligibility check is always the same two-input rule. |
> | Is the path conditional on unpredictable output of a prior step? | No. The inputs are known; the decision table output is deterministic. |
> | Is there a feedback loop — does the model need to look at its own output and try again? | No. Once the supervisor decides, the workflow writes and exits. |
>
> All three are No → this is a workflow, not an agent (#9). The lab guide should show this explicitly — ideally as a brief "should this be an agent or a workflow?" decision box at the start of Exercise 1, before the first build step. Give participants the same test to apply to their own future projects.
>
> Also connect to **#36 — Probabilistic Rule Engine**: the threshold check (`customer_tier` × `billing_amount`) must produce the same answer every time. An agent instruction saying "auto-approve amounts below $200 for standard customers" is not enforced — it is approximated. The decision table is enforced.
>
> And connect to **#40 — Prompt-Secured Workflow**: if the approval gate were an agent instruction ("NEVER approve without supervisor sign-off for amounts over $500"), it could be bypassed by crafting a user prompt that overrides the instruction in the same context window. A HITL node in a workflow cannot be bypassed from user input — the platform enforces the pause independently of the LLM. This is the correct place to put a compliance gate.

> **Cross-lab design thread — two approaches to workflow reuse:**
> Lab 2 and Lab 3 each face a situation where the same core logic needs to serve two slightly different contexts. They solve it differently, by design. Lab 2 (this lab) keeps the shared review logic inside a single user activity and uses a variable-driven conditional branch to skip one step depending on the assigned role — the deviation is small, so the logic stays *in*. Lab 3 Extension F extracts the shared review logic into a standalone sub-workflow (`TRI_warranty_review_workflow`) and lets each caller pass a `mode` input to control the terminal step — the shared unit is large and independently testable, so the logic comes *out*. Lab guide authors should name this contrast explicitly: participants who complete both labs should be able to articulate when each approach is appropriate. See [`labs/lab-3/specs/LAB-03_warranty-claim-workflow.md`](../../lab-3/specs/LAB-03_warranty-claim-workflow.md) § "Sub-workflow composition — Call Flow node".

| Feature | Description | Why it matters |
|---------|-------------|----------------|
| **Workflow input validation — gateway guard clause *(Lab 2 extension)*** | A gateway node placed as the very first node in the workflow evaluates whether the required input fields (`order_id`, `billing_amount`, `billing_record_id`, `reason_for_dispute`) are non-null and non-empty. If any are missing, the workflow routes to `ua_close_invalid_input` — a present-to-user error step that names the missing field(s) — and exits cleanly to `__end__` without touching any SOR data. | Complements the agent-side guardrail in UC-03 (where `TRI_billing_agent` refuses to start the workflow if inputs are missing) with a workflow-side defence. The two layers are independent: the agent guard fires before invocation; the workflow guard fires at runtime and makes the workflow robust regardless of which caller invokes it. Lab 3 has no equivalent — its entry HITL (`ua_show_customer`) serves as a natural gate, but the inputs are validated by the form itself, not by an explicit gateway node. |
| **Decision table as the first node** | The workflow opens with a pure rule evaluation — no probabilistic step fires first. Two structured inputs (`customer_tier` × `billing_amount`) are evaluated deterministically and route to Path A (supervisor review) or Path B (specialist resolves directly). | Canonical example of determinism as the *entry point* of a Composite Tool. Contrast with Lab 3, where a probabilistic extraction step fires before any decision logic. |
| **Path B — specialist resolves directly *(Lab 2 extension)*** | When the disputed amount falls at or below the direct-approval threshold, the decision table routes to Path B. A script node sets `flow.private.role_label = "specialist"` and `flow.private.reviewer` to the flow initiator. Path A sets `flow.private.role_label = "supervisor"` and `flow.private.reviewer` to the named supervisor user. Both paths converge at a single shared `ua_review_activity` — `assign_to` resolves the correct recipient from `flow.private.reviewer` at runtime. Build and test Path B before adding Path A's complexity. | Demonstrates that decision table branching controls not just which downstream nodes execute but *who receives the user activity* and *what they see inside it*. The variable set on the branch becomes the single source of truth for both routing and conditional behaviour. |
| **Conditional branch inside a user activity** | `ua_review_activity` contains a branch node as its first internal step. It evaluates `flow.private.role_label`: if `"supervisor"`, the activity shows `ua_role_switch_header` (the `--- SUPERVISOR VIEW ---` output-only step, advances automatically) before Form 2b; if `"specialist"`, it skips the header and goes directly to Form 2b. The evidence-gathering loop, decision form, and all subsequent steps are shared by both paths inside the same activity. | A `UserFlow` in wxO is a sub-graph with its own internal edge wiring — it supports `conditions()` branch nodes just like the outer flow. This means a single user activity can serve two roles with a minimal conditional deviation rather than duplicating entire activity definitions. Contrast with Lab 3 Extension F, which achieves reuse by factoring logic *out* into a sub-workflow; here reuse is achieved by factoring conditional logic *in* to a single activity. |
| **Script node as a bridge to platform capabilities not exposed in the UI *(Lab 2 extension)*** | The two script nodes on Path A and Path B use `flow.initiator` to resolve `flow.private.reviewer`, and the commented-out production variant shows `system.user.search_by_email(...)` for resolving a named user. Neither dynamic user resolution into a private variable nor wiring that variable into `assign_to` is configurable through the wxO workflow builder UI directly — the script node bridges that gap in two lines of Python. The key discipline: keep script nodes minimal, single-purpose, and always accompanied by a comment explaining what the script achieves and why a declarative alternative was insufficient. | Script nodes should not be overused — decision tables, gateway nodes, and the built-in node types cover the majority of workflow logic more readably and without code. But when the platform UI does not expose a capability that the runtime engine supports, a script node is the correct escape hatch. This is different from Lab 3's Python code block for date arithmetic, which uses the same construct for a different reason: determinism rather than capability access. The contrast across both labs gives participants a concrete mental model for when to reach for a script node and when to leave it alone. |
| **Role-switch HITL (two distinct principals)** | Path A sets `flow.private.reviewer` to a named supervisor user (`UserAssignmentPolicy.USER`); Path B sets it to the flow initiator (`UserAssignmentPolicy.FLOW_INITIATOR`). At runtime the platform delivers `ua_review_activity` to the resolved user. In the lab both paths are performed by the same participant (the participant acts as both specialist and supervisor), but the workflow is built to support genuinely different users — in a real deployment, `flow.private.reviewer` resolves to a different person for each path. The `--- SUPERVISOR VIEW ---` header fires only for the supervisor path, gated by the internal branch. | Demonstrates that a single user activity node can represent a multi-role business process with data-driven assignment — `assign_to` reads a variable, not a hardcoded role. The lab simplification (one user plays both roles) is explicitly named so participants understand the design intent without confusing the teaching point. Structurally different from Lab 3's HITL, which is a quality gate on uncertain data — here the pause enforces governance accountability before money changes hands. |
| **Call Agent node — the deterministic↔probabilistic bridge** | Form 2b embeds a Call Agent node mid-workflow: the supervisor's free-text query is passed to `TRI_billing_evidence_agent` (an LLM agent), and its probabilistic response is wired back into the deterministic workflow as a present-to-user step. The workflow neither knows nor cares what the agent reasoned — it just receives the output and continues. | This is the mechanism that makes the Composite Tool pattern span the full spectrum from fully deterministic to fully probabilistic. The decision table at the start is pure rules; the Call Agent node in the middle is pure LLM; the HITL forms on either side are human. All three coexist in one callable unit. No other platform offers this mix as a built-in no-code construct. *(Future topic — deepening this concept: see the sub-agent refactoring section below, which replaces the narrow agent with the full Trinity orchestrator hierarchy to show the same pattern at enterprise scale.)* |
| **Selectable table with a hidden bound column (Form 2c)** | The decision form presents billing records as a selectable table. `billing_record_id` is bound as a hidden field — not shown to the supervisor but available to the downstream Call Tool step. Submission is blocked until a row is selected (Required field). | Shows how a HITL form can bind a technical identifier invisibly while keeping the display clean. Contrast with Lab 3 Extension B's selectable table, which is for *identification* (which product?); here it is for *decision* (which record to act on?). |
| **SOR write as the workflow's terminal action** | The workflow converges — whether Approve or Reject — on a single `TSOR_Billing_update_billing_record_status_description` Call Tool step that writes the outcome back to the SOR, followed by a formatted confirmation to the specialist. | Canonical embodiment of the *workflows-handle-writes* architectural principle. The audit trail (decision, reason, status) is baked into the workflow structure, not left to agent memory. **Allen Chan #3 — Invisible State:** the decision, the reason, the billing record ID, and the outcome status all travel as explicit typed workflow variables (`flow.form_2c.selected_billing_record_id`, `flow.decision.update_decision`, etc.) — never as LLM memory. The audit trail works because state is explicit. **Allen Chan #5 — Passing As-Is Information Through the Model:** the billing record ID and the final status update are routed directly from the HITL form to the Call Tool node, bypassing the LLM entirely. Routing exact compliance data around the model is the correct pattern. |
| **Error handling on the SOR write *(Lab 2 extension)*** | The `TSOR_Billing_update_billing_record_status_description` Call Tool step is configured with an error edge (**Retry on error OFF**, `on_error="branch"`). On failure, the error path executes a **retry-with-state-verification loop**: (1) read the current record status via `TSOR_Billing_get_billing_record_by_id`; (2) if the status already matches the target, the write succeeded before the connection dropped — proceed to confirmation; (3) if not, retry the write and loop back. A workflow counter variable caps the loop at N attempts (not the node-level retry setting, which cannot span the intervening read). Once the counter is exhausted without success, `ua_sor_error_fallback` surfaces the failure to the specialist. The human only appears when automated recovery has genuinely given up. | Teaches that non-idempotent writes require a fundamentally different retry strategy than idempotent reads. The node-level retry setting is unsafe here — a timeout does not tell you whether the write went through; in a real implementation, `cancelled` status could trigger customer reimbursement and a blind retry would reimburse twice. The loop uses the SOR as the source of truth on every iteration, so each retry is only attempted when the pre-check confirms the record is still in the original state. The counter variable must be a workflow variable (e.g. `flow.private.write_attempts`), not the node retry setting — because retry logic that spans multiple nodes cannot be expressed with a per-node setting. Pairs with AC-L2-6. **Allen Chan #11 — Happy Path Engineering:** without the error edge this workflow fails silently. **Allen Chan #33 — Stateful Tool Trap:** Retry on error OFF is deliberate — see § Error Handling for the full rationale and loop design. |
| **Inline Generative Prompt Node (`Prompt Node`) *(Lab 2 extension)*** | Placed immediately before workflow completion to dynamically synthesize the multi-path dispute history and supervisor justification into an audit narrative. | Teaches the architectural distinction between calling an Agent node (stateful, multi-turn, tool use) vs. an inline Prompt node (stateless, fast, single-shot synthesis) on the workflow canvas. Added last — requires all path variables to be populated, and wraps the exit of a fully working flow. **Why GenAI over a fixed template:** a multi-path workflow (Path A supervisor review with evidence queries vs. Path B direct resolution; Approved vs. Rejected; fee waivers) requires nested conditional expressions to reproduce every path variation in a static string — brittle and hard to maintain. A Prompt Node receives all populated variables and generates a coherent narrative regardless of which combination of paths executed. The correct teaching sequence: show participants what a static template would look like, discuss its limitations, then replace it with the Prompt Node and observe the same output quality with zero branching logic. |

---

## Workflow input validation — gateway guard clause *(Parked — not implemented)*

> ⏸️ **Not implemented in the current lab.** The agent-side guardrail in UC-03 (`TRI_billing_agent` refuses to invoke the workflow if inputs are missing) is sufficient for the lab's teaching goals. Adding a workflow-side input validation gateway would add exercise steps without a proportionate teaching return given time constraints. This section is preserved as a design reference for anyone extending the lab or adapting the pattern to a production deployment.

The end-to-end baseline and the E2E test scenarios always supply all required workflow inputs — the agent-side guardrail in UC-03 ensures this before calling the workflow. The guard clause exercise would teach participants to make the workflow itself robust, independently of any specific caller.

**How it works:**

Add a **gateway node** as the very first node in `TRI_billing_dispute_workflow`, before the decision table. The gateway evaluates the four required string inputs in a single condition:

```
order_id != null AND order_id != ""
AND billing_amount != null AND billing_amount > 0
AND billing_record_id != null AND billing_record_id != ""
AND reason_for_dispute != null AND reason_for_dispute != ""
```

- **Valid path (all present):** gateway routes directly to the decision table. No change to the existing flow.
- **Invalid path (any missing or empty):** gateway routes to `ua_close_invalid_input`.

**`ua_close_invalid_input` — present-to-user step:**

```
WORKFLOW INPUT ERROR
────────────────────────────────────────────
The billing dispute workflow could not be started
because one or more required inputs are missing:

  • order_id          : <present / MISSING>
  • billing_record_id : <present / MISSING>
  • billing_amount    : <present / MISSING>
  • reason_for_dispute: <present / MISSING>

Please ensure all required fields are provided
before initiating the billing dispute workflow.
────────────────────────────────────────────
```

The step advances automatically to `__end__` — no button required. No SOR tool is called.

**Why a gateway, not a code block:**
A gateway node expresses a boolean branch condition directly on the canvas — no Python needed. The condition is readable to any low-code author inspecting the flow. Using a code block here would work but would obscure the intent behind a script. This is the same principle that makes decision tables preferable to code blocks for rule evaluation.

**Two-layer defence — how this relates to the UC-03 agent-side guardrail:**

| Layer | Where | What it prevents |
|-------|-------|-----------------|
| Agent-side (UC-03) | `TRI_billing_agent` refuses to invoke the workflow if `customer_id`, `order_id`, or billing records are missing from context | Missing context before invocation — agent can recover by fetching SOR data |
| Workflow-side (this extension) | First gateway node in `TRI_billing_dispute_workflow` | Missing or empty workflow input variables at runtime — workflow exits cleanly regardless of which agent or caller invoked it |

The agent guard is the primary line of defence; the workflow guard is the safety net. Together they ensure no silent failure and no partial SOR write under any invocation path.

---

## Path B — below-threshold routing *(Lab 2 scope)*

Path B does not occur in the end-to-end scenario (Platinum + $2,500 always exceeds the direct approval threshold and routes to Path A). It is a Lab 2 exercise.

The decision table (UC-03 § Agentic workflow, Step 1) evaluates customer status and disputed amount. Path B fires when the combination falls at or below the direct-resolution threshold:

| Customer status | Disputed amount | Outcome |
|-----------------|-----------------|---------|
| Platinum / Gold | ≤ $500 | Specialist can resolve directly |
| All other | ≤ $200 | Specialist can resolve directly |

**Path B workflow behaviour:**

Path B and Path A share a single `ua_review_activity` user activity. The divergence is controlled by two variables set on each branch immediately after the decision table:

| Variable | Path A (supervisor) | Path B (specialist) |
|---|---|---|
| `flow.private.role_label` | `"supervisor"` | `"specialist"` |
| `flow.private.reviewer` | named supervisor user (via `system.user.search_by_email(...)`) | flow initiator (`UserAssignmentPolicy.FLOW_INITIATOR`) |

> **Lab note:** In the lab, the participant plays both the specialist and the supervisor — they initiate the workflow and then also complete the supervisor activity in the same session. The workflow is built to support genuinely different users: in a real deployment `flow.private.reviewer` on Path A resolves to a different person than the flow initiator. The lab guide must state this explicitly so participants understand what the `assign_to` configuration achieves in production, even though the lab collapses both roles into one session.

**Script node on Path A** (fires immediately after the decision table, before `ua_review_activity`):
```python
# Lab simplification: use the flow initiator so the same participant can act as supervisor.
# In a real deployment, resolve the supervisor by email instead:
#   flow.private.reviewer = system.user.search_by_email('supervisor@focuscorp.com')[0]
flow.private.reviewer = flow.initiator
flow.private.role_label = "supervisor"
```

**Script node on Path B** (fires immediately after the decision table, before `ua_review_activity`):
```python
flow.private.reviewer = flow.initiator
flow.private.role_label = "specialist"
```

**`ua_review_activity` — shared user activity** (`assign_to` policy: `UserAssignmentPolicy.USER`, `assignees`: `flow.private.reviewer`):

The activity is a sub-graph with its own internal branch at `START`:

- **Branch: `flow.private.role_label == "supervisor"`** → `ua_role_switch_header` (present-to-user, output-only, advances automatically) → Form 2b
- **Default branch (specialist)** → Form 2b directly

From Form 2b onwards, both roles follow identical steps:

1. **Form 2b** — billing records table (read-only) + "Request information" text field → "Get Information" (Call Agent loop) or "Make Decision" → Form 2c
2. **Form 2c** — billing records selectable table + hidden `billing_record_id` + Reason field (Required) + Approve / Reject buttons
3. Both Approve and Reject converge at `TSOR_Billing_update_billing_record_status_description`, then display the `--- BILLING DISPUTE RESOLVED ---` confirmation.

> The full UC-03 Path B note is intentionally brief in the UC spec — this document is the authoritative home for the Path B implementation spec and test cases.
>
> **End-to-end baseline note:** The E2E baseline only executes Path A (Platinum + $2,500 always exceeds the threshold). The shared `ua_review_activity` design does not change Path A's behaviour — `flow.private.reviewer` resolves to the supervisor user, the role-switch header fires, and the activity proceeds exactly as specified in UC-03.

---

## Architecture target — sub-agent refactoring *(Future topic)*

> ⏸️ **Not expected in the near term.** The core teaching point — that a workflow's Call Agent node spans the deterministic↔probabilistic spectrum — is already demonstrated by the existing E2E baseline using `TRI_billing_evidence_agent`. This section describes a future deepening exercise that replaces the narrow stub agent with the full Trinity orchestrator hierarchy. It is preserved here as a design target, not a Lab 2 deliverable.

The end-to-end workflow uses `TRI_billing_evidence_agent` — a narrow sub-agent intentionally scoped to three capabilities (shipping record retrieval, customer profile lookup, fraud risk lookup). See UC-03 § `TRI_billing_evidence_agent` for the full agent spec and design principles.

The target architecture replaces this narrow agent with routing through the full Trinity orchestrator, following the core architectural principle of using domain agents. This demonstrates the same deterministic↔probabilistic bridge pattern at enterprise scale — the workflow's Call Agent node invokes not a stub but a full multi-agent system:

- Form 2b "Get Information" routes to `TRI_orchestrator` (with context continuity ON) instead of `TRI_billing_evidence_agent`.
- A dedicated `TRI_shipping_agent` collaborator is introduced to handle shipping record lookups.
- `TRI_billing_evidence_agent` is retired once this routing is in place.

**When this becomes relevant:** once `TRI_shipping_agent` is introduced as a collaborator in the end-to-end solution. `TC-UC-03-L2-03` (see below) validates this change when implemented.

---

## Error Handling & Resilient Tool Invocations *(Lab 2 Extension / Best Practice)*

Enterprise workflows must gracefully manage tool failures (e.g. backend SOR downtime, schema mismatch, or non-existent record lookups) rather than halting unhandled in the chat interface.

### 1. Best Practices for Workflow Error Handling
- **Attach Error Handlers to State-Changing Tool Calls:** Critical write operations (such as `TSOR_Billing_update_billing_record_status_description`) should be configured with error handling (`on_error="branch"` / error edge in UI) rather than relying solely on platform unhandled exceptions.
- **Retries on read-only tools require error classification, not just idempotency:** `TSOR_Billing_get_billing_records_by_order_id` is a pure read — calling it twice changes nothing in the SOR. But idempotency alone does not make retries safe. There are two structurally different failure modes, and only one benefits from a retry:

  | Failure mode | Signal | Retry appropriate? |
  |---|---|---|
  | **Transient** — network timeout, BAW slow-start, 5xx infrastructure error | HTTP 5xx, connection reset | ✅ Yes — the order exists; the call just didn't complete |
  | **Permanent** — unknown order ID, bad input | HTTP 4xx, or a success-status response with an error payload (e.g. `{ "error": "order not found" }`) | ❌ No — the order genuinely doesn't exist; every retry will fail identically |

  Configuring `max_retries: 2` without discrimination means an unknown order ID causes three identical failing calls before the error surfaces — adding latency for a failure that was immediately diagnosable.

  **Tool design is the upstream factor (Allen Chan #32 — The Useless Error):** how the workflow can discriminate between these two failure modes depends entirely on how the tool surfaces errors. There are two patterns in practice:

  - **HTTP-status-based signalling:** the tool returns a genuine HTTP 4xx for "order not found" and a 5xx for infrastructure failures. The workflow engine can branch on status code — retry on 5xx, route to a permanent-error path on 4xx. This is the cleanest design.
  - **Success-status with error payload:** the tool always returns HTTP 200 but embeds an error indicator in the response body (e.g. `{ "billing_records": [], "error": "order_not_found" }`). The workflow engine sees a successful call; the error is only visible by inspecting the result. In this case, the retry configuration on the node is irrelevant for permanent failures — the workflow must read the response body and branch on the `error` field or an empty result before proceeding. BAW-backed tools often follow this pattern for domain-level errors.

  **The best practice (Allen Chan #32):** well-designed tools return structured, discriminating errors — not raw stack traces or generic "500 Internal Server Error". A tool should signal infrastructure failures via HTTP status codes (so the platform can retry automatically) and domain-level failures via a structured response field (so the calling workflow can branch explicitly). When using an existing tool that mixes both signals into a single error path, the workflow must compensate with explicit result inspection.

  **Lab guide authoring note:** investigate how `TSOR_Billing_get_billing_records_by_order_id` actually signals a not-found order in the current BAW implementation — HTTP 4xx, or a 200 with an empty/error body? The answer determines whether the platform's `max_retries` configuration is useful here, and how the error-path exercise should be structured. Name the two patterns explicitly so participants understand the principle regardless of what the specific tool does.

- **Do not use automatic retry on non-idempotent write tools (Allen Chan #33 — Stateful Tool Trap):** `TSOR_Billing_update_billing_record_status_description` is a mutating call. A network timeout does not tell you whether the write went through — the SOR may have applied the change a fraction of a second before the connection dropped. In a real implementation, setting status to `cancelled` could trigger customer reimbursement; a blind retry would reimburse twice. Set **Retry on error to OFF** on this node. Use the retry-with-state-verification loop instead.
- **Retry-with-state-verification loop for non-idempotent writes:** The correct retry pattern for a non-idempotent write is a multi-node loop driven by a workflow counter variable, not `max_retries` on the write node. The loop:

  ```
  initialise: flow.private.write_attempts = 0

  LOOP:
    [Script] flow.private.write_attempts += 1
    [Call Tool] TSOR_Billing_update_billing_record_status_description
        → success → confirmation (exit loop)
        → error   → [Call Tool] TSOR_Billing_get_billing_record_by_id
                        → billing_record.status == target_status?
                            → Yes (write went through before timeout) → confirmation (exit loop)
                            → No  (write didn't go through)
                                → flow.private.write_attempts < MAX_ATTEMPTS? → back to LOOP
                                → exhausted → ua_sor_error_fallback (human)
  ```

  Three properties make this correct: (1) the read is cheap, idempotent, and safe to call on every iteration; (2) the write is only retried when the pre-check confirms the record is still in the original state — a double-apply is structurally impossible; (3) the human only appears when automated recovery has genuinely exhausted its options, not on every first failure. The counter variable must be a workflow variable (e.g. `flow.private.write_attempts`), not `max_retries` on a single node — because retry logic that spans multiple nodes cannot be expressed with a per-node setting.

  **Lab guide authoring note:** this is a three-step exercise: (1) add the error edge and `ua_sor_error_fallback` — basic error handling; (2) insert the read-check gateway on the error path — safe state verification; (3) add the counter variable and loop-back edge — full retry-with-verification. Participants who stop at step 1 have functional error handling; steps 2 and 3 build toward production-grade resilience. Each step is independently testable using the error-forcing methods in § 2 below.
- **Specialist-Facing Remediation Form (`ua_sor_error_fallback`):** Reached only when the loop counter is exhausted. The lab guide implements this as a **display-only surface**: it shows the failure reason, the number of attempts made, and the current SOR status (from the last read-check) so the specialist has enough context to act manually. The workflow exits cleanly after acknowledgement — no SOR data is left in a partial state.

  **Production target (not built in the lab):** A full remediation form would offer three actionable choices rather than a display-only exit:
  - **Retry loop:** Reset the counter and re-enter the loop — appropriate if the specialist believes the SOR is now available.
  - **Manual Escalate:** Create an offline support ticket / notify operations — appropriate when the SOR appears genuinely unavailable.
  - **Cancel:** Abort the workflow cleanly and log the incident.

  The display-only version is sufficient for the lab's teaching goal (demonstrating that write failures surface a clear specialist message rather than aborting silently). The three-choice form is the production-grade extension for teams taking this pattern into a real deployment.

### 2. Forcing SOR Errors for Testing and Demonstration
To reliably demonstrate error handling working end-to-end during lab exercises without taking down the BAW SOR backend, participants can use three approaches:

| Approach | Error type | How to trigger | What it demonstrates |
|---|---|---|---|
| **Invalid Record ID injection** | Domain (v.0.37c: via wrapper) | Pass `B-INVALID` (order `O-ER8T0G`) to `TSOR_Billing_update_billing_record_status_description` | The call completes with HTTP 200; the response wrapper signals the domain error: `billing_record_update_status.is_error = true`, `error_code = "RECORD_NOT_FOUND"`, `error_message = "Billing record 'B-INVALID' not found"`. The workflow failure edge does **not** fire. The domain error must be detected by inspecting the wrapper on the success path (same pattern as `get_billing_records_by_order_id_ext` Build 4 in Exercise 7). Use this to test the wrapper-inspection path in Part 2. |
| **Alternating-failure toggle (CR-20)** | Transient (infrastructure) | Use predefined record ID `B-ERRTOG` (order `O-ER7T0G`) | 1st call: HTTP 500 → failure edge fires → read-check: status unchanged → retry; 2nd call: HTTP 200, `is_error = false` → confirmation. Demonstrates the retry-with-state-verification loop recovering automatically without human involvement. To test the exhaustion path, set `MAX_ATTEMPTS` to `1` and force the failure again — loop exhausts immediately and routes to `ua_sor_error_fallback`. Also use `B-ERRTOG` for Part 1's basic error path test: its first call fires the infrastructure failure edge, which is the path Part 1 builds. |

---

## Inline Generative Prompt Node for Customer Audit Logging *(Lab 2 Extension)*

**Context:** Enterprise compliance and CRM auditability require recording an authoritative summary of customer dispute resolutions in the customer's CRM history. In the end-to-end scenario, the final user activity confirms: `Audit Log : Customer interaction log record created in CRM`. Lab 2 provides a dedicated exercise where participants add an inline Generative Prompt Node (`Prompt Node`) to synthesize this narrative audit log entry.

### Why GenAI over a Fixed Static Template (Key Teaching Concept):
- **Multi-Branch & Exception Nuance:** In a workflow that branches across multiple paths (Path A supervisor review with evidence queries vs. Path B direct resolution; Approved cancellation vs. Rejected dispute; fee waivers), a fixed string template requires complex, brittle nested expressions to capture the exact path taken.
- **Human Narrative Distillation:** When the supervisor inputs free-text justification and reasons during Form 2c (e.g. *"Customer returned device 17 days ago per shipping tracking S-H6A0OS, but billing record B-TDDU12 remained active; approved cancellation"*), GenAI seamlessly merges human reasoning with machine variables into an authoritative compliance record.

### Sample Prompt Configuration in SaaS UI:
- **Node Type:** `Prompt Node`
- **Node Name:** `generate_dispute_audit_log`
- **Model:** `groq/openai/gpt-oss-120b` (or IBM Granite)
- **System Prompt:**
  ```text
  You are an enterprise CRM audit compliance logger for Focus Corp.
  Generate a concise, factual, 2-to-3 sentence audit log record summarizing the billing dispute resolution.
  Include: customer ID, disputed order, billing record ID, decision (Approve/Reject), supervisor rationale, and final status.
  Tone: objective, standardized, auditable. Do not address the customer.
  ```
- **User Prompt Template (with variable interpolation):**
  ```text
  Customer ID: {flow.input.customer_id} (Tier: {flow.input.customer_tier})
  Order ID: {flow.input.order_id}
  Disputed Billing Record: {flow.form_2c.selected_billing_record_id} (Amount: ${flow.form_2c.selected_amount})
  Resolution Decision: {flow.decision.update_decision} (New Status: {flow.decision.update_status})
  Supervisor / Specialist Justification: {flow.form_2c.reason}
  Evidence Consulted: {flow.evidence_agent.response_summary ? flow.evidence_agent.response_summary : "None"}
  ```
- **Sample Generated Output:**
  ```text
  [BILLING-DISPUTE-RESOLVED] Processed duplicate charge dispute for customer C-3DBZFE on order O-DF340K. Supervisor reviewed shipping return evidence (S-H6A0OS) and approved cancellation of billing record B-TDDU12 ($2,500.00). Status updated to cancelled with justification: 'Item was returned but charge not cancelled'.
  ```

### Lab Verification (Zero SOR Extension Required):
- In a full production system, this string would be written via a CRM audit logging tool node.
- In **Lab 2**, participants have already wired up SOR tools. To avoid waiting on backend SOR schema changes, the exercise simply connects the output of the `Prompt Node` to a **present-to-user review screen** (`ua_show_dispute_audit_log`) so participants can visually inspect the GenAI-generated audit summary before the workflow concludes.

---

## Lab 2 acceptance criteria

| # | Criterion |
|---|-----------|
| AC-L2-1 | When customer status is Platinum/Gold and disputed amount ≤ $500, the decision table routes to Path B (specialist direct resolution). |
| AC-L2-2 | When customer status is Standard and disputed amount ≤ $200, the decision table routes to Path B (specialist direct resolution). |
| AC-L2-3 | Path B sets `flow.private.role_label = "specialist"` and `flow.private.reviewer` to the flow initiator; `ua_review_activity` is delivered to the flow initiator; the internal branch skips `ua_role_switch_header` and routes directly to Form 2b. |
| AC-L2-4 | Both Path B outcomes (Approve and Reject) call `TSOR_Billing_update_billing_record_status_description` and display the `--- BILLING DISPUTE RESOLVED ---` confirmation. |
| AC-L2-5 | Path A sets `flow.private.role_label = "supervisor"` and `flow.private.reviewer` to the supervisor user; `ua_review_activity` is delivered to that user; the internal branch fires `ua_role_switch_header` (advances automatically) before routing to Form 2b. |
| AC-L2-6 | When `TSOR_Billing_update_billing_record_status_description` fails (e.g., forced invalid record ID), the workflow follows the error edge to the remediation user activity (`ua_sor_error_fallback`) rather than failing unhandled. |
| AC-L2-7 | When the inline Generative Prompt Node (`generate_dispute_audit_log`) runs, it ingests workflow variables and supervisor reason to synthesize a coherent 2-3 sentence audit log narrative displayed on `ua_show_dispute_audit_log`. |
| AC-L2-8 | When any required workflow input (`order_id`, `billing_amount`, `billing_record_id`, `reason_for_dispute`) is null or empty, the gateway routes to `ua_close_invalid_input`; the error output names the missing field(s); the workflow exits to `__end__` without calling `TSOR_Billing_get_billing_records_by_order_id` or `TSOR_Billing_update_billing_record_status_description`. |
| AC-L2-9 | When all required inputs are present and valid, the gateway routes to the decision table without displaying `ua_close_invalid_input`; the existing Path A / Path B flow proceeds unchanged. |

### Future acceptance criteria

These criteria apply only after the sub-agent architecture refactoring described in [§ Architecture target — sub-agent refactoring *(Future topic)*](#architecture-target--sub-agent-refactoring-future-topic). They are not expected to be verified in the current lab delivery.

| # | Criterion |
|---|-----------|
| AC-L2-10 | After sub-agent refactoring, Form 2b "Get Information" routes through `TRI_orchestrator`; a shipping query returns shipping records via the Shipping Agent collaborator. `TRI_billing_evidence_agent` is no longer invoked. |

---

## Lab 2 test cases

These test cases exercise Lab 2 extensions beyond the end-to-end baseline. Refer to UC-03 § Test cases for the full E2E test suite (TC-UC-03-001 through TC-UC-03-017) and the consolidated workflow test design note, which explains the run-optimisation rationale and preflight/teardown requirements that also apply to the Lab 2 cases below.

| TC ID | Target AC(s) | Target topic | Description | Type | File |
|-------|-------------|--------------|-------------|------|------|
| TC-UC-03-L2-01 | AC-L2-1, AC-L2-3, AC-L2-9 | Path B routing (Platinum/Gold) + variable assertions | **Preflight:** none — uses Standard customer SOR fixture (customer status Platinum/Gold, dispute amount ≤ $500). Asserts: (1) decision table routes to Path B; (2) `flow.private.role_label` is `"specialist"`; (3) `flow.private.reviewer` resolves to flow initiator; (4) `ua_review_activity` is delivered to initiator; (5) internal branch does **not** display `ua_role_switch_header` before Form 2b; (6) `ua_close_invalid_input` is **not** shown (gateway happy path). **Teardown:** None. | dev / lab2 | *(Lab 2 test suite)* |
| TC-UC-03-L2-02 | AC-L2-2, AC-L2-3, AC-L2-9 | Path B routing (Standard) + variable assertions | **Preflight:** none — uses Standard customer SOR fixture (customer status Standard, dispute amount ≤ $200). Asserts: (1) decision table routes to Path B; (2) `flow.private.role_label` is `"specialist"`; (3) `flow.private.reviewer` resolves to flow initiator; (4) `ua_review_activity` is delivered to initiator; (5) internal branch does **not** display `ua_role_switch_header` before Form 2b; (6) `ua_close_invalid_input` is **not** shown (gateway happy path). **Teardown:** None. | dev / lab2 | *(Lab 2 test suite)* |
| TC-UC-03-L2-06 | AC-L2-3, AC-L2-4 | Path B — Approve outcome (SOR write + confirmation) | **Preflight:** Set billing record to `active` state. Uses Path B fixture (below-threshold customer + amount). Asserts: (1) `ua_role_switch_header` is **not** shown; (2) Form 2b presented directly; (3) specialist selects billing record and enters reason; (4) clicks "Approve Cancellation"; (5) `TSOR_Billing_update_billing_record_status_description` is called with `status="cancelled"` and `description=<reason>`; (6) `--- BILLING DISPUTE RESOLVED ---` confirmation displayed with `update_decision="Approve"`, `update_status="cancelled"`, and correct `billing_record_id`. **Teardown:** Restore billing record to `active` state. | dev / lab2 | *(Lab 2 test suite)* |
| TC-UC-03-L2-07 | AC-L2-4 | Path B — Reject outcome (SOR write + confirmation) | **Preflight:** Set billing record to `active` state. Uses Path B fixture (below-threshold customer + amount). Asserts: (1) specialist selects billing record and enters reason; (2) clicks "Reject Cancellation"; (3) `TSOR_Billing_update_billing_record_status_description` is called with updated `description=<reason>` and `status` left unchanged (`active`); (4) `--- BILLING DISPUTE RESOLVED ---` confirmation displayed with `update_decision="Reject"` and correct `billing_record_id`. **Teardown:** None — Reject leaves status `active`. | dev / lab2 | *(Lab 2 test suite)* |
| TC-UC-03-L2-08 | AC-L2-6 | Error handling — SOR write failure → `ua_sor_error_fallback` | **Preflight:** None. Invokes workflow with `billing_record_id = B-INVALID` (order `O-ER8T0G`) so `TSOR_Billing_update_billing_record_status_description` returns HTTP 200 with `is_error = true`. Asserts: (1) workflow detects the domain error via wrapper inspection (failure edge does **not** fire); (2) `ua_sor_error_fallback` is displayed to the specialist with failure reason and number of attempts; (3) `--- BILLING DISPUTE RESOLVED ---` confirmation is **not** shown. **Teardown:** None. | dev / lab2 | *(Lab 2 test suite)* |
| TC-UC-03-L2-09 | AC-L2-7 | Prompt Node — audit log narrative synthesis | **Preflight:** Set billing record to `active` state. Runs a complete Path A or Path B workflow to completion (Approve path). Asserts: (1) `generate_dispute_audit_log` Prompt Node executes; (2) `ua_show_dispute_audit_log` is displayed; (3) output contains customer ID (`C-*`), order ID (`O-*`), billing record ID (`B-*`), the decision ("Approve"), and a non-empty supervisor/specialist justification string; (4) narrative is 2–3 sentences (not a raw variable dump). **Teardown:** Restore billing record to `active` state. | dev / lab2 | *(Lab 2 test suite)* |
| TC-UC-03-L2-04 | AC-L2-8 | Input validation — missing `billing_record_id` | Invoke workflow with `billing_record_id` set to empty string; asserts workflow routes to `ua_close_invalid_input`, names `billing_record_id` as missing, and exits to `__end__` without calling `TSOR_Billing_get_billing_records_by_order_id` or `TSOR_Billing_update_billing_record_status_description`. | dev / lab2 | *(Lab 2 test suite)* |
| TC-UC-03-L2-05 | AC-L2-8 | Input validation — missing `reason_for_dispute` | Invoke workflow with `reason_for_dispute` set to null; asserts workflow routes to `ua_close_invalid_input`, names `reason_for_dispute` as missing, and exits to `__end__` without calling `TSOR_Billing_get_billing_records_by_order_id` or `TSOR_Billing_update_billing_record_status_description`. | dev / lab2 | *(Lab 2 test suite)* |
| TC-UC-03-L2-03 | AC-L2-10 *(Future)* | Architecture target — sub-agent refactoring to full orchestrator | Sub-agent refactoring: verifies Form 2b "Get Information" routes through `TRI_orchestrator`; a shipping query returns shipping records via the Shipping Agent collaborator; `TRI_billing_evidence_agent` is **not** invoked. Not active until `TRI_shipping_agent` exists. | future / lab2 | *(Lab 2 test suite — future)* |
