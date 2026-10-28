# Lab 3 — Agentic Workflow: Document Processing (Warranty Claim)

**Lab owner:** Sundeep
**Related use case spec:** [`specs/use-cases/UC-04_warranty-claim-external-reseller.md`](../../../specs/use-cases/UC-04_warranty-claim-external-reseller.md)
**Lab design reference:** [`specs/lab-design.md`](../../../specs/lab-design.md) § Lab 3

> This document collects all Lab 3 authoring guidance, extension scope, and implementation notes that are specific to building the `TRI_warranty_claim_workflow` as a hands-on exercise. It is the companion to UC-04, which defines the end-to-end scenario target behaviour. When the two documents conflict, UC-04 is the authoritative source for what the workflow must do; this document defines what Lab 3 participants will build and explore.

---

## Lab scope vs. end-to-end baseline

The end-to-end scenario baseline standardises on the **Out-of-Warranty (OOW) path** only, using a single customer (`C-3DBZFE`, Marie Smith, Platinum tier) with a receipt document. Lab 3 goes beyond this baseline in five areas:

| Area | End-to-end baseline | Lab 3 scope |
|------|--------------------|-|
| Document type | Receipt only | Receipt **and** Warranty Card (type-dependent extraction branches) |
| Document validity | Always valid | Valid path **and** Invalid document fallback path |
| Warranty outcome | OOW path only | OOW path **and** In-Warranty (IW) path with four resolution options |
| Catalog product match | First result always has confidence 100 — auto-selected | Auto-select **and** multi-match HITL selection form (code block + `ua_select_catalog_item`) |
| Document processing node coverage | `classify_document` + `extract_document_fields` only | All three node types: `classify_document`, `extract_document_fields`, **and** Doc Processing Node (`docproc`) — see Extension D |
| Payment data handling | Not present | Payment info fetched concurrently, sensitive fields masked via workflow settings, rendered conditionally on resolution form using dynamic expression templating — see Extension E |

---

> **Implementation notes** have been moved to [`specs/use-cases/UC-04_warranty-claim-external-reseller.md`](../../../specs/use-cases/UC-04_warranty-claim-external-reseller.md) § "Implementation & Design Notes for Sundeep", which is the authoritative location. Key points covered there:
>
> - End-to-end baseline customer is `C-3DBZFE` (Marie Smith, Platinum) — IW branch is Lab 3 Extension C (below).
> - End-to-end baseline uses the OOW path only, with rationale (aging fixed-date PDF; multi-branch execution risk).
> - Document type branching and the invalid document path are Lab 3 Extension A (below) — not part of the end-to-end demo.
> - Receipt field schema, HITL trigger mechanism, and the `purchase_date` confidence investigation item are in UC-04 § Step 6.
> - `tool_get_orders` has been removed from this use case.

---

> **⚠️ Workflow file decoupling — pending reconciliation:** `solution/workflows/TRI_warranty_claim_workflow.json` is the **end-to-end baseline only**. It does not implement, and is not expected to implement, any Lab 3-only extension (Extensions A–F below) — including Extension E's PayPal masking and dynamic expression templating, which are Lab 3 scope per UC-04's own implementation notes, not E2E scope. Reviewing the AC-L3 table against that baseline JSON will therefore always show most Extension rows as "not yet built," which is expected and not a defect in the baseline.
>
> A separate lab-specific workflow has been seeded at [`labs/lab-3/solution/workflows/TRI_warranty_claim_workflow_lab.json`](../solution/workflows/TRI_warranty_claim_workflow_lab.json), based on an earlier pre-optimization snapshot that already contains `branch_warranty`, `ua_inwarranty_options`, and `paypal`-related nodes — a closer starting point for Lab 3's extension scope than the current stripped-down E2E baseline. The source snapshot (`TRI_warranty_claim_workflow_original.json`) has been removed from `solution/workflows/` now that the lab copy is in place.
>
> **Pending work:** this seeded lab workflow has not yet been reconciled against the Extension A–F specs in this document (it may be missing nodes some extensions require, or contain nodes/logic that no longer match the current spec wording — e.g. the Extension E narrative's node-name and positioning claims have not been re-verified against it). Once reconciled, the AC-L3-* / TC-L3-* rows below should be derived and tested against `TRI_warranty_claim_workflow_lab.json`, not against the E2E baseline.

---

## SOR test data — lab fixtures

| Customer ID | Name | Tier | Warranty outcome | Document | Notes |
|-------------|------|------|-----------------|----------|-------|
| `C-3DBZFE` | Marie Smith | Platinum | **Out of warranty** | Receipt (`receipt_realistic_clean.pdf`) | **Primary end-to-end scenario customer** — also used as Lab 3 baseline, and as the guide's direct-catalog-match walkthrough customer (Exercises 3-6). |
| `C-11100` | Sam Taylor | Standard | **Out of warranty** | *(not assigned)* | Standalone dev/unit fixture (Standard tier OOW discount); also the guide's ambiguous-catalog-match / HITL-selection walkthrough customer (Exercises 3-6). |
| `C-33300` | Casey Morgan | Standard | **In warranty** (`OI-KBD001`) | Warranty card (`warranty_card_realistic.pdf`) | **The guide's actual Exercise 4 warranty-card document-type fixture** (`Lab Guide - Lab 3 - workflow-warranty.md:888`). Supersedes `C-48239` below for the guide walkthrough — this row reflects what the lab actually teaches. |
| `C-48239` | *(SOR record)* | *(SOR record)* | **In warranty** | Warranty card (`warranty_card_realistic.pdf`) | Test-suite-only fixture (TC-L3-001 through TC-L3-005), covering the Extension A/B/C paths — including the full 4-option in-warranty resolution combobox, which is parked/out of scope for the guide (see `LAB-03_audit-findings-2026-10-11.md`, Positive/compliance section). Not used anywhere in the guide itself; kept only to support the test suite. |
| *(TBD)* | *(new SOR record needed)* | *(TBD)* | *(not applicable)* | Invalid document (neither receipt nor warranty card) | **⚠️ Not yet assigned. Joint lab author + Olaf action** — a new customer record with an invalid document attached is required for Extension A's negative path (TC-L3-004). Lab author to agree fixture details with Olaf before the SOR record is created. |

---

## Unique agentic workflow features

This section identifies the wxO Agentic Workflow capabilities that are unique to Lab 3 — features that a lab guide author should describe and a participant should be able to name by the end of the lab. They are derived from UC-04's workflow spec and represent what this workflow does that Lab 2 does not.

**Core teaching point:** The Agentic Workflow here is a *probabilistic-input quality chain*. Document AI is inherently uncertain — confidence varies by document quality, handwriting, and formatting. The workflow manages that uncertainty explicitly: the HITL step is a quality gate that fires when extraction confidence falls below threshold, letting a human correct or confirm the extracted values before deterministic rules run. The Python code block makes the contrast vivid: date arithmetic must produce the same answer every time, even when everything around it is probabilistic.

> **[Allen Chan #2 — The Agent-as-Business-Process Fallacy](https://achan2013.medium.com/ai-agent-anti-patterns-part-1-architectural-pitfalls-that-break-enterprise-agents-before-they-32d211dded43) and [#9 — Agent-Washing](https://achan2013.medium.com/ai-agent-anti-patterns-part-2-tooling-observability-and-scale-traps-in-enterprise-agents-42a451ea84ec).** Lab 3's warranty claim workflow is the second workflow lab, so participants have already seen the three-question test applied in Lab 2. Here the lab guide should briefly re-apply it to the document processing scenario to reinforce the decision framework — and note that the answer is different in one dimension:
>
> | Question | Warranty claim (document processing) answer |
> |----------|--------------------------------------------|
> | Is tool selection dynamic? | No. The processing sequence is fixed: classify → extract → code → decide → resolve. |
> | Is the path conditional on unpredictable output? | **Yes** — but that unpredictability is managed *within* the workflow (via HITL when confidence is low), not by an agent reasoning loop. The workflow handles the uncertainty; it is not driven by it. |
> | Is there a feedback loop? | No. The HITL step corrects values once; it does not re-run the extraction. |
>
> Two No and one partially-Yes → still a workflow. The partially-Yes answer is the teaching point: the uncertainty from document AI is bounded and managed by a *quality gate*, not by having an LLM agent retry the extraction in an uncontrolled loop. This distinction matters — a naive approach would be "let an agent extract and re-extract until confident," which violates #2 and #37. The correct approach is to let the workflow engine manage the uncertainty at a defined point and involve a human when the machine cannot self-resolve.
>
> Also connect to **[Allen Chan #37 — Natural Language Workflow Engine](https://achan2013.medium.com/agent-anti-patterns-part-5-05da1c3c1828)**: extracting document fields, computing days elapsed, and looking up catalog items are deterministic, sequential steps. Encoding that sequence in an agent instruction (e.g. "extract the receipt, then check the warranty, then offer the appropriate discount") is the exact anti-pattern — the agent approximates the sequence, can skip steps, and produces inconsistent results across runs. The workflow canvas is the right place for this logic.

> **Cross-lab design thread — two approaches to workflow reuse:**
> Lab 2 and Lab 3 each face a situation where the same core logic needs to serve two slightly different contexts. They solve it differently, by design. Lab 3 (this lab, Extension F) extracts the shared review logic into a standalone sub-workflow (`TRI_warranty_review_workflow`) and lets each caller pass a `mode` input to control the terminal step — the shared unit is large and independently testable, so the logic comes *out*. Lab 2 keeps its shared review logic inside a single user activity and uses a variable-driven conditional branch to skip one step depending on the assigned role — the deviation is small, so the logic stays *in*. Lab guide authors should name this contrast explicitly: participants who complete both labs should be able to articulate when each approach is appropriate. See [`labs/lab-2/specs/LAB-02_billing-dispute-workflow.md`](../../lab-2/specs/LAB-02_billing-dispute-workflow.md) § "Conditional branch inside a user activity".

| Feature | Description | Why it matters |
|---------|-------------|----------------|
| **Front-loaded graceful-exit branches (Steps 1 and 2)** | Two independent deferred paths exit the workflow cleanly before document processing begins: `ua_close_later_upload` (customer not ready to upload during the call) and `ua_close_upload_deferred` (customer couldn't complete upload mid-call). Both terminate with a present-to-user closing guidance step and advance to `__end__` automatically. | Demonstrates that a workflow can handle real-world conversation variability — not every call progresses to the same endpoint. Lab 2 has no front-loaded exits; it always reaches the decision table. Both deferred paths also reinforce the "always conclude cleanly" design principle. **Note — no explicit input guard clause in Lab 3:** Lab 2 teaches a workflow-side gateway guard as an independent exercise because the billing dispute workflow can be invoked by any caller. Lab 3 does not repeat this exercise — the entry HITL (`ua_wait_callback`) acts as a natural gate that cannot be bypassed from the outside, and the teaching value of a standalone gateway guard was already delivered in Lab 2. Lab guide authors should name this explicitly so participants understand the omission is intentional, not an oversight. |
| **Doc Processing Node — raw text extraction (`docproc`) *(Extension D)*** | The `docproc()` node (`task="text_extraction"`) runs the wxO Doc Processing engine against the uploaded document and returns a URL pointing to a file of extracted plain text — before any classification or structured field extraction. Placed between `fetch_baw_pdf_url` (Step 4) and `classify_document` (Step 5), so all three document AI nodes run in sequence on the same input document. | Completes the document processing node triad: Docclassifier (what type is it?), Doc Processing (what text does it contain?), Docext (what named fields can be pulled?). Each answers a different question and together they represent the full wxO document AI surface available inside a workflow. Without this node, Lab 3 covers only two of the three. |
| **Document classification TIP node (`classify_document`)** | The workflow uses the wxO Docclassifier TIP node to identify the document type (`receipt`, `warranty_card`, or other) before any extraction happens. Classification drives which extraction schema is applied downstream. | Demonstrates a wxO-native AI node that has no equivalent in Lab 2. The document type determines the entire downstream path — Lab 3 Extension A adds the full three-way branch; the E2E baseline shows the receipt path only. |
| **Document extraction TIP node (`extract_document_fields`)** | The wxO Docext TIP node extracts structured fields from the classified document. The schema differs by document type: receipts yield `product_name`, `purchase_date` (mandatory), plus optional fields; warranty cards require `serial_no` as an additional mandatory field. `enable_review: true` allows automatic HITL escalation when confidence is below threshold. | Shows structured field extraction from unstructured documents as a first-class workflow node — not an external API call. The mandatory/optional and review-field distinctions directly drive the conditional HITL in the next step. **[Allen Chan #22 — Mixing Extraction with Processing](https://achan2013.medium.com/ai-agent-anti-patterns-part-3-knowledge-document-processing-0caf472856ff):** this node does one thing: extract named fields. It does not calculate, summarise, or make decisions. The date arithmetic happens in the Python code block (Step 7); the warranty eligibility decision happens in the decision table (Step 10). Each step has exactly one job — this decomposition is what makes the pipeline debuggable. If a test case fails, the lab guide author can point to the exact node that produced the wrong output. **[Allen Chan #23 — Lazy Field Definitions](https://achan2013.medium.com/ai-agent-anti-patterns-part-3-knowledge-document-processing-0caf472856ff):** field names and descriptions must be unambiguous and context-rich. The schema must distinguish `purchase_date` (the date the customer bought the item — format YYYY-MM-DD) from adjacent fields that might appear on the same document. Vague schema entries like `date` or `amount` cause the extraction model to guess wrong — especially on receipts with multiple date or currency values. The lab exercise for defining the extraction schema should explicitly ask participants to add a description attribute to each field explaining where the value is typically found and what format it is expected in. |
| **Conditional HITL as a quality gate (`ua_extracted_review`)** | The HITL review form fires *only if* extraction confidence for any mandatory `review_fields` falls below threshold. It is generated automatically by the Docext node — not a custom-designed form. The specialist sees all extracted fields, corrects what is wrong, and proceeds. | Structurally different from Lab 2's HITL, which is a role-based approval gate. Here the pause is triggered by machine uncertainty, not by a business rule about who must approve. The corrected value — not the low-confidence original — flows into the warranty calculation. |
| **Python code block for date arithmetic** | The warranty status is computed by calling `TSOR_Catalog_check_warranty_for_catalog_item_by_purchase_date`, which returns `days_expired` and `days_remaining`. A Python code block handles any necessary pre/post-processing for typed variable mapping — deterministic computation that must produce the same result on every run. | Explicit contrast with probabilistic steps: date arithmetic delegated to an LLM could produce different values or formats on different runs. A code block executes identically every time. This is the same principle as Lab 2's decision table, applied to a calculation rather than a rule lookup. **[Allen Chan #3 — Invisible State](https://achan2013.medium.com/ai-agent-anti-patterns-part-1-architectural-pitfalls-that-break-enterprise-agents-before-they-32d211dded43):** the extracted fields (`product_name`, `purchase_date`, `catalog_item_id`) travel as explicit typed workflow variables from the Docext node through the code block and into the decision table — never as LLM memory. If the HITL step corrects a value, the corrected value overwrites the original in the workflow state; the decision table receives the corrected value because state is explicit. **[Allen Chan #5 — Passing As-Is Information Through the Model](https://achan2013.medium.com/ai-agent-anti-patterns-part-1-architectural-pitfalls-that-break-enterprise-agents-before-they-32d211dded43):** `purchase_date` is passed directly from the extraction node into the Python code block and then into the SOR tool call — it is never re-interpreted by an LLM. The model does not reformat, round, or paraphrase a date it has been handed. Routing exact extracted values around the LLM is the correct pattern for downstream tool calls that require precise inputs. |
| **Chained dependent tool calls (`lookup_catalog_item` → `check_warranty`)** | Step 8 calls `TSOR_Catalog_search_catalog_items_by_name` and stores `catalog_item_id` from the result. Step 9 takes that `catalog_item_id` as a required input — it cannot run without Step 8's output. The data dependency is explicit on the workflow canvas: the output variable of one Call Tool node is wired directly into the input of the next. | In Lab 2 each tool call takes a workflow input variable, not a prior tool's output. Here the two-step chain — resolve product identity, then evaluate warranty against it — models how real multi-service business logic composes. The canvas makes the dependency visible and traceable in a way that agent tool calls inside an LLM loop cannot. **Auto mapping teaching opportunity:** Step 9's Call Tool node explicitly wires `catalog_item_id` via `input_map` (a variable mapping from Step 8's output), but leaves `purchase_date` out of the `input_map` (`fallback_strategy: "ask_the_user"`). The agentic engine infers `purchase_date` from context at runtime, including converting it from a plain string in the flow to the `date` type the tool expects. This is a good moment for the lab guide to contrast the explicit `input_map` wiring (both Step 8's tool call and Step 9's `catalog_item_id`) with this auto-mapping behaviour on `purchase_date`, and to name the benefit: fewer arguments to hand-wire, and type coercion handled for the author rather than requiring an explicit cast step. |
| **Conditional skip from code block *(Extension B)*** | A code block after `lookup_catalog_item` evaluates whether the first catalog result has `confidence = 100`. If yes, `catalog_item_id` is auto-selected and `ua_select_catalog_item` is skipped. If no, the workflow routes to a specialist selection form. | Shows conditional routing driven by a computed value — not a decision table or a gateway on a fixed field. Contrasts with Lab 2's Form 2c selectable table (always shown); here the selectable table is only shown when the machine cannot self-resolve. |
| **Decision table on a continuous dimension (`days_expired` × tier)** | The `decisions_warranty_offer` table evaluates `days_expired` across four bands (0, 1–90, 91–180, 181–365, >365) combined with `customer_tier`, outputting both `discount_pct` and `discount_note`. | Demonstrates a richer decision table than Lab 2's binary threshold check. Multiple output fields (`discount_pct`, `discount_note`, `offer_type`) from one table drive both the discount calculation and — in Extension C — the in-warranty/OOW branch. |
| **Combobox resolution selection *(Extension C)*** | `ua_inwarranty_options` uses a combobox (not buttons) for the four in-warranty resolution options: Replace, Gift certificate, Refund, Replace with another model. | Introduces a HITL input type not present in the E2E baseline or Lab 2. Combobox is appropriate when options are semantically equivalent and none should be visually emphasised as default. Also demonstrates four-path branch convergence at a single `ua_deliver_resolution` step. |
| **Generated artefact as workflow output (`generate_discount_code`)** | The workflow calls `TSOR_Orders_generate_discount_code` with `customer_id` and `discount_pct` and surfaces the returned code in the closing output. The workflow *produces* a new value as its resolution artefact. | Contrast with Lab 2, which updates an existing SOR record. Here the terminal action creates something new — the discount code is the deliverable handed to the specialist. |
| **Parallel Node — concurrent pre-checks *(Extension E)*** | A Parallel Node branches the workflow into two independent execution paths — `TSOR_CRM_get_customer_payment_info_by_customer_id` (payment details) and `TSOR_CRM_evaluate_fraud_risk` (risk score) — that run concurrently. The workflow engine automatically synchronises both branches before advancing; the combined output (masked payment instrument + fraud risk verdict) is surfaced on the downstream HITL resolution form. | The only concurrent orchestration construct in Lab 3, and the first time participants see workflow execution split into parallel paths. Contrast with every other node in both labs, which executes sequentially. Demonstrates that latency reduction is a first-class design concern on the workflow canvas — calling two independent services serially is a correctness error, not just a performance choice. |
| **Sub-workflow composition — Call Flow node *(Extension F)*** | Steps 5–12 of `TRI_warranty_claim_workflow` are extracted into a standalone `TRI_warranty_review_workflow`. The online caller and the batch caller each invoke it via a **Call Flow node** — a node type distinct from Call Tool (external API) and Call Agent (LLM agent). The sub-workflow receives a ready `document_url` and `mode` input; each caller owns the base64 → URL transport concern before invoking it. | Introduces the third callable node type on the wxO canvas. Call Tool = external service; Call Agent = LLM reasoning; Call Flow = deterministic sub-workflow. The sub-workflow boundary demonstrates the single-responsibility principle: the review logic lives once, is tested once, and is reused by both callers without duplication. Compare with Lab 2's approach to the same design problem: Lab 2 keeps shared logic *inside* a single user activity and uses a variable-driven conditional branch to handle the deviation — appropriate when the deviation is a small skip. Here the shared unit is large enough to warrant its own independently deployable workflow. Neither approach is universally correct; the right choice depends on the size and testability of the shared logic. |
| **Foreach Node — iterate over a list *(Extension F)*** | `TRI_warranty_batch_workflow` places a **Foreach Node** over the list returned by `TRI_get_pending_warranty_requests`. The node iterates `ForeachPolicy.SEQUENTIAL` — one item at a time — calling `TRI_warranty_review_workflow` per claim via a Call Flow node in the foreach body. The current item is accessed inside the body via the `parent._current_item` expression. | The only list-iteration construct in wxO Agentic Workflow. `SEQUENTIAL` policy is a deliberate choice, not a default: it means the reviewer sees one claim at a time rather than all claims simultaneously. The policy choice is itself a teaching point about workflow design for human review queues. Contrast with a Parallel Node, which would fire all iterations concurrently — appropriate for independent service calls, wrong for human review. |
| **Scheduled workflow (`schedulable=True`) *(Extension F)*** | `TRI_warranty_batch_workflow` is configured with `schedulable=True`, giving it a scheduler trigger alongside the standard agent-invocation trigger. The scheduler initiates the batch automatically (e.g. every morning at 08:00) without a specialist requesting it. HITL steps inside the foreach body still pause for human review — the schedule removes the manual initiation step, not the human review step. | The only trigger mechanism in Labs 2 and 3 that is not initiated by an agent in chat. Demonstrates that the same workflow engine that handles real-time specialist interactions can drive background batch processing — the HITL persistence model works identically regardless of trigger. Lab guide authors must state explicitly: *"The schedule removes the need for someone to manually start the batch; it does not remove the need for a specialist to review each claim."* |
| **Mode-aware end node (`null` vs. `BatchReviewResult`) *(Extension F)*** | `TRI_warranty_review_workflow` has a terminal branch driven by its `mode` input. For `mode = "online"`: all output has already been delivered to the specialist in chat; the end node returns `null` and the calling workflow receives no structured data. For `mode = "batch"`: the sub-workflow has no chat channel; the end node returns a `BatchReviewResult` object (`warranty_status`, `discount_code`, `resolution_type`, `review_required`, `customer_email`) that the batch orchestrator consumes to decide what to send to the customer. | The cleanest demonstration in Lab 3 of a typed workflow output contract. The dual-output design makes the architectural principle concrete: a workflow that runs in a synchronous chat context and a workflow that runs in a background batch context can share the same review logic — only the terminal communication step differs. This pattern generalises to any reusable sub-workflow that must behave consistently across multiple callers. |
| **Structured workflow output contract *(Extension F — named teaching point)*** | A workflow's end node can return a typed object rather than a plain text string. The current E2E baseline returns a single text string (`"Handling warranty claim completed."`) as a workaround for platform defects wo-tracker/84342 and wo-tracker/87940, which prevent output suppression. Once those defects are resolved — and already in Extension F's `TRI_warranty_review_workflow` — the end node returns a `BatchReviewResult` object with fields `warranty_status`, `discount_code`, `resolution_type`, `review_required`, and `customer_email` that the calling workflow consumes to decide what to do next. | The contrast between the text-string workaround and the structured output contract is itself a teaching point: a workflow that returns an opaque string forces the caller to parse free text; one that returns a typed object gives the caller a machine-readable contract it can branch on. Lab 2 also returns a text string (same workaround) — neither lab currently teaches the clean version. Extension F in this lab is where participants first see what the output contract *should* look like, even if the exercise stays in the Future section. Lab guide authors should name this distinction explicitly when explaining why the current workaround exists. |

---

## Architectural Note — PDF Ingress, Authentication, and Base64 Payload Management

> **Lab Guide Author & Solution Architecture Note:**
>
> In the current implementation of `TRI_warranty_claim_workflow`, document ingestion is handled in two steps:
> 1. An MCP tool (`TSOR_CRM_get_customer_provided_proof_of_warranty_by_customer_id`) retrieves customer attachment metadata and returns the document payload as a **Base64-encoded string** (`attachment_content`).
> 2. A custom Python tool (`TRI_fetch_baw_pdf_url`) accepts that Base64 string, decodes it to raw PDF bytes, uploads it to wxO internal S3 storage (`/upload-to-s3`), and returns a signed `url` (file grant) that the downstream Doc Processing, Classification, and Extraction nodes consume.
>
> ### Why we should consider combining retrieval into the Python tool (OpenAPI/REST inside Python):
> - **The Base64 Context Trap:** Base64-encoded documents are enormous (often tens or hundreds of thousands of characters). When the MCP tool returns Base64 directly to the workflow canvas, that raw string enters the workflow state machine and LLM execution context. This consumes significant context window tokens and risks triggering automatic platform summarization/truncation, which can corrupt binary strings and degrade reasoning.
> - **Ingress Boundary Principle:** To keep workflow state clean, large binary payloads should never traverse the workflow graph. A superior architectural alternative is to **bypass the workflow-level MCP Base64 return** entirely: implement a single unified Python tool that executes the authenticated OpenAPI/REST call directly against the BAW SOR, streams/decodes the bytes in memory, uploads directly to wxO S3, and returns **only the lightweight File object / S3 URL** to the workflow.
>
> ### Why external direct URLs aren't used:
> - **No Direct Protected URL Support on Document Nodes:** Ideally, the BAW SOR would simply return a URL to the document, and wxO document processing nodes would fetch it directly. However, wxO document processing and File objects do not support passing user credentials or authorization headers (Basic Auth / Bearer tokens) to fetch documents from arbitrary external URLs.
> - **Unrealistic Unprotected Endpoints:** Exposing customer enterprise documents over unauthenticated public URLs is a severe security violation, and token-in-URL schemes are non-standard and brittle.
> - **Conclusion:** Uploading the file to wxO internal S3 storage via an ingress tool (or combining the BAW OpenAPI fetch + S3 staging into one Python helper) is the necessary and robust integration pattern for enterprise document processing in wxO.

---

## Lab 3 workflow extensions

### Extension D — Doc Processing Node (`Extract Warranty Doc Text`)

Add between `fetch_baw_pdf_url` (Step 4) and `classify_document` (Step 5) so that the same uploaded document passes through the Doc Processing Node before classification begins. The node runs first because its output is raw text — independent of document type — and does not affect the classification or extraction steps that follow.

> **Scenario fit:** At the end of processing every warranty claim, a customer interaction log record is created in the SOR CRM. That record is intended to capture a summary of the entire warranty document — not just the handful of fields the workflow extracts for its own business logic (purchase date, serial number, etc.). Pulling the document's full plain text here, before classification branches the flow, gives a later Prompt step the raw material it needs to generate that summary and store it in the log. The Doc Processing Node is therefore not a display step — it runs silently and its output is consumed downstream. This gives the node a genuine business purpose: the text extractor feeds the audit trail, not the specialist's screen.
>
> This is also the only placement that guarantees every participant builds a `docproc` node regardless of which document-type branch (receipt or warranty card) they follow, completing the document AI node triad in a single exercise.

**Node:** `Extract Warranty Doc Text` (`docproc`, `task="text_extraction"`)

**Input:** Same document URL produced by `fetch_baw_pdf_url` (Step 4).

**Output:** A URL pointing to a file containing the extracted plain text of the document. Stored as a workflow variable for consumption by a downstream Prompt step that generates the interaction log summary.

**What participants build:**
- Add a `docproc` node named `Extract Warranty Doc Text` after Step 4 with `task="text_extraction"`, `Keep document layout` enabled, and `Output as object` enabled.
- No present-to-user step is attached — the node runs silently and advances automatically to `classify_document` (Step 5). The extracted text is referenced later by a Prompt step that writes the summary to the customer interaction log.
- Clear the auto-mapped `kvp_model_name` input — key-value-pair extraction is not needed here.

**Why this placement:**
- Runs on the same document URL before classification branches the flow — avoids duplicating the node inside both the receipt and warranty card branches.
- Silent execution is the correct design choice here: surfacing a raw OCR dump to the specialist mid-call adds no actionable value. The output's consumer is the interaction log, not the specialist's screen.
- Keeps the node in the main flow so every participant builds it regardless of which document-type branch they follow.

**Distinction from Docclassifier and Docext:**

| Node | ADK method | What it produces | When to use it |
|---|---|---|---|
| Doc Processing | `docproc(task="text_extraction")` | Plain text extracted from the document | When downstream steps need the raw text — e.g. logging, audit trail, or passing to a Prompt Node for summarisation |
| Docclassifier | `docclassifier(classes=…)` | A document type label + confidence score | When the document type determines which processing branch to follow |
| Docext | `docext(fields=…)` | Named structured fields with confidence scores per field | When specific field values are needed for downstream business logic |

**Learning points this extension demonstrates:**
- **Doc Processing Node as the entry point for raw document content** — distinct from classification (which type?) and extraction (which fields?)
- **Sequential composition of all three document AI nodes on the same input** — each answering a different question about the same document
- **Silent node with a downstream consumer** — not every workflow step needs to present output to the user; here the raw text feeds an audit log summary, not the specialist's screen
- **`Output as object` enabled** — makes the extracted text addressable as a structured variable that a later Prompt step can reference by name

---

### Extension A — Document type branch (`Doc Type?`)

Add after `Classify document` to handle all three document outcomes:

- `receipt` → `Extract Receipt Fields` (Unstructured extractor — receipt schema)
- `warranty_card` → `Extract Warranty Card Fields` (Structured extractor — warranty card schema)
- Anything else → **Invalid document path** (`Other` branch)

**Branch implementation (`Doc Type?`):**

- **Path 1 (if):** named `Receipt` — condition: `class_name == "receipt"`
- **Path 2 (else if):** named `Warranty Card` — condition: `class_name == "warranty_card"`
- **Path 3 (else):** named `Other` — catch-all for any unrecognised document type

**Key implementation distinction — Unstructured vs Structured extractor:**

The two document types use different extraction modes because they have fundamentally different layouts:

| | Receipt (`Extract Receipt Fields`) | Warranty Card (`Extract Warranty Card Fields`) |
|---|---|---|
| **Extractor mode** | Unstructured | Structured |
| **Model type** | Text-based AI — suited to free-form, variable-length documents | Vision-based AI — suited to short, fixed-layout documents |
| **HITL trigger** | Confidence threshold: fires when confidence on `Purchase Date` or `Product Name` falls below `10` | Any empty value: fires when any configured field returns empty |
| **Confidence setting** | Configurable threshold (set to `10`) scoped to review fields only | Not available — Structured extractor has no per-field confidence score |

**Receipt extraction schema (`Extract Receipt Fields` — Unstructured):**

| Field | Type | Review field | Notes |
|-------|------|:------------:|-------|
| `Purchase Date` | Date | ✅ Yes | Mandatory for warranty check. Configure two examples: `Purchase Date: 2024/05/15` → `2024/05/15` and `Purchase Date 2024/05/15` → `2024/05/15` to handle format variation |
| `Product Name` | String | ✅ Yes | Mandatory for catalog lookup |
| `Product Category` | String | ❌ No | |
| `Receipt No` | String | ❌ No | |
| `Reseller` | String | ❌ No | |
| `Serial No` | String | ❌ No | |
| `Price` | String | ❌ No | |

Review fields (`Purchase Date` and `Product Name`) are configured with a confidence threshold of `10` — the HITL review form fires automatically when either field's confidence falls below this value. The review form is generated by the platform; no custom form design is required.

**Warranty card extraction schema (`Extract Warranty Card Fields` — Structured):**

| Field | Type | Requirement | Notes |
|-------|------|:-----------:|-------|
| `Product Name` | String | **Mandatory** | Product identifier |
| `Purchase Date` | Date | **Mandatory** | Anchor for 1-year warranty expiration |
| `Serial No` | String | **Mandatory** | Essential on a warranty registration card |
| `Model No` | String | Optional | Model number if printed |
| `Reseller` | String | Optional | Store or vendor name |

The Structured extractor has no confidence threshold setting. User Review is enabled — if any configured field returns an empty value, the platform automatically sends the review form to the flow initiator. All three mandatory fields (`Product Name`, `Purchase Date`, `Serial No`) must be populated for the workflow to continue without HITL intervention.

For both extractors: `document_ref` is explicitly mapped to the output of the `Fetch PDF from SOR` tool call. No sample documents are provided — sample documents improve accuracy against varying real-world formats, which this demo solution does not need.

### Invalid document path

`Other` branch → `__end__` (deliberately not implemented)

The `Other` path is wired in the `Doc Type?` branch and routes directly to `__end__` without any intermediate steps. This is an intentional scope decision — the lab does not ask participants to build or test the invalid document path. AC-L3-2 and TC-L3-006 are out of scope for this lab.

---

### Extension B — Multi-match catalog product selection

**Context:** `TSOR_Catalog_search_catalog_items_by_name` (`Lookup Catalog Item`) returns a list of potential matches sorted by confidence. In the end-to-end baseline the first result has `confidence = 100` (a complete name match) and the workflow auto-selects it. When that condition is not met, a specialist selection step is required.

**Implementation — three nodes after `Lookup Catalog Item`:**

**1. `Prepare Warranty Check Inputs` (Logic block)**

Evaluates the search result and either auto-selects the item or builds a display list for the specialist. Sets `flow.private.catalog_item_id` directly on a confidence-100 match; otherwise populates `self.output.options` with display strings for items with `confidence > 50`.

```python
items = flow["Handle Warranty Claim"]["Lookup Catalog Item"].output.matchingItems or []

flow.private.catalog_item_id = None
self.output.options = []

if items and items[0].get("confidence") == 100:
    flow.private.catalog_item_id = items[0].get("catalog_item_id")
else:
    self.output.options = [
        f"{item.get('name')} (Confidence: {item.get('confidence')}, Catalog Item Id: {item.get('catalog_item_id')})"
        for item in items
        if item.get("confidence", 0) > 50
    ]
```

Output: `options` (List of String). Flow variable: `catalog_item_id` (String, defined as a private flow variable before this node).

> **Platform constraint — Single choice field:** The wxO Single choice field only supports a list of Strings where the display text and the submitted value are identical. A selectable table bound to a structured object array is not available in the Canvas UI. To preserve the `catalog_item_id` through the form submission, each option string embeds it inline: `"Focus Headset Pro 500 (Confidence: 87, Catalog Item Id: CI-A4WER4)"`. A logic block after the form parses it back out.

**2. `Catalog item found?` (Branch)**

- **Path `Yes` (if):** expression `flow.private.catalog_item_id != None` — auto-selected, skip form, proceed directly to `Check Warranty Status`
- **Path `No` (else):** route to `Select customer product` form

**3. `Select customer product` (Form — HITL)**

- **`View receipt document`** (File download, Present to user) — maps to the `Fetch PDF from SOR` output so the specialist can review the document before selecting
- **`Customer product`** (Single choice, Collect from user) — source variable: `options` from `Prepare Warranty Check Inputs`; Required toggle on — submission blocked until a selection is made
- Cancel button disabled

After form submission, a `Extract catalog_item_id` logic block parses the selected display string to recover `catalog_item_id`:

```python
ws = flow["Handle Warranty Claim"]["Select customer product"].output
selected_option = (ws.get("Customer product", "") if isinstance(ws, dict) else getattr(ws, "Customer product", "")) or ""

marker = "Catalog Item Id: "
if marker in selected_option:
    flow.private.catalog_item_id = selected_option.split(marker)[-1].rstrip(")").strip()
else:
    flow.private.catalog_item_id = None
```

Both the `Yes` path and the post-form `Extract catalog_item_id` path converge on `Check Warranty Status`.

**Learning points this extension demonstrates:**
- **Two-node auto-select pattern** — a logic block that either sets a flow variable directly or builds a display list, followed by a branch on whether the variable was set; cleaner than a single block with a boolean flag
- **Platform constraint: Single choice field** — wxO's Canvas UI Single choice field requires a flat list of strings; `catalog_item_id` must be embedded in the display string and parsed back out after submission
- **File download field on a HITL form** — giving the specialist access to the original document alongside the selection so they can make an informed choice
- **Post-form parsing logic block** — recovering a structured value from a user-submitted string when the platform cannot bind directly to object properties

---

### Extension C — In-warranty path

Add an `In Warranty?` branch after the `Warranty Discount Decision Table` to handle the `In Warranty` outcome. The branch evaluates `offer_type` — the decision table output — and routes to either the in-warranty path or the OOW path.

> **`offer_type`** is the decision table output that drives this branch. The decision table always sets `offer_type` alongside `discount_pct` and `discount_note`. `In Warranty?` evaluates `offer_type == "In Warranty"` to route between the two paths.

**Branch implementation (`In Warranty?`):**

- **Path `Yes` (if):** condition `offer_type == "In Warranty"` → `In Warranty Msg` (present-to-user message)
- **Path `No` (else):** → `Out of Warranty Message` (present-to-user message)

**Deliberate scope decision:** The full combobox resolution form (`ua_inwarranty_options`) with four resolution options and four converging `process_*` branches is **not implemented** in this lab. Both paths use a simple present-to-user message node that displays the warranty decision and relevant fields to the specialist. This is an intentional choice — the teaching goal of this lab is the document processing pipeline and the decision table, not the downstream resolution actions. AC-L3-3, AC-L3-4 and TC-L3-001 through TC-L3-004 are out of scope for this lab.

**`In Warranty Msg` message content:**

```
# WARRANTY CLAIM DECISION

## {flow.private.offer_type}

| Warranty Information |   |
| ---- | ---- |
| **Product:** | {extracted product_name} |
| **Purchase Date:** | {extracted purchase_date} |
| **Warranty Period:** | {warranty_period} |
| **Warranty End:** | {warranty_end_date} |
```

**`Out of Warranty Message` message content:**

Same fields as above, plus `Days Expired`.

**Learning points this extension demonstrates:**
- **Branch on a decision table output** — `offer_type` produced by the decision table drives the routing; the same variable that controls the discount percentage also controls which message the specialist sees
- **Simple present-to-user message as a terminal step** — not every outcome needs a full HITL form; when the workflow has no further action to take, a message node that auto-advances is the right choice

---

### Extension E — Concurrent Pre-Checks via Parallel Node, Payment Data Masking, and Conditional Visibility

**Context:** Demonstrates concurrent orchestration on the workflow canvas alongside enterprise data protection. Payment details and fraud risk are independent service calls — running them sequentially introduces unnecessary delay. At the same time, payment instrument data is sensitive and must never reach the LLM or appear unmasked in logs.

**Position in the workflow:** The Parallel Node runs at the very start of the `Handle Warranty Claim` user activity — before document upload, before document processing. This is the first thing the specialist sees when the workflow is invoked.

**How it works in the workflow:**

The workflow branches via a **`Parallel Pre-Check - Payment + Fraud`** Parallel Node into two concurrent paths:

- **Path 1 — `Fetch Payment Info`:** Calls `TSOR_CRM_get_customer_payment_info_by_customer_id` to retrieve `payment_type`, and either `card_number` or `paypal_username`. The raw values are masked in Flow Settings before they can appear anywhere.
- **Path 2 — `Assess Fraud Risk`:** Calls `TSOR_CRM_evaluate_fraud_risk` with `customer_id` and `amount = float(-1)` (no specific item amount is known at this point — `-1` signals a general risk check). Returns `risk_level`, `risk_score`, `prior_disputes_count`, and `risk_summary`.

The workflow engine synchronises both paths automatically before advancing to the `CUSTOMER DETAILS & UPLOAD READINESS` form.

**Payment data masking:**

Sensitive fields are masked in **Flow Settings → Sensitive data**, scoped to the `Fetch Payment Info` node within `Handle Warranty Claim` → `Parallel Pre-Check - Payment + Fraud`. Both variables are masked using regex:

| Variable | Masking behavior | Find | Replace |
|----------|-----------------|------|---------|
| `payment_info.card_number` | Mask using regex | `(\d{4})-(\d{4})-(\d{4})-(\d{4})` | `XXXX-XXXX-XXXX-$4` |
| `payment_info.paypal_username` | Mask using regex | `^(.*)(.{4})(@.*)$` | `$1xxxx$3` |

Masking is enforced at the display layer only — Call a tool, Decision, and Logic block nodes still have access to the raw value. The masked value is what appears in HITL forms, the Flow Inspector, execution traces, and agent responses.

**Conditional visibility for polymorphic payment display:**

Because `card_number` and `paypal_username` are mutually exclusive, the `CUSTOMER DETAILS & UPLOAD READINESS` form uses a 7-control sequence to show only the relevant field:

1. **Message 1 (hidden trigger):** Embeds `payment_type` in an HTML comment — `<!--{...payment_type}-->` — so it is available to visibility rules without being displayed.
2. **Message 2 (unconditional):** Customer name, tier, email, phone as a Markdown table.
3. **`Show Credit Card` (Visibility control):** Event trigger = Message 1; conditional field = Message 5; rule: value `== <!--Credit Card-->`.
4. **`Show Paypal` (Visibility control):** Event trigger = Message 1; conditional field = Message 6; rule: value `== <!--Paypal-->`.
5. **Message 5 (Credit Card):** Masked `card_number` + fraud risk fields. Shown only when `Show Credit Card` rule fires.
6. **Message 6 (PayPal):** Masked `paypal_username` + fraud risk fields. Shown only when `Show Paypal` rule fires.
7. **Message 7 (unconditional):** Specialist action instructions.

> **Why Visibility controls instead of a ternary expression:** The wxO Canvas UI does not support ternary expressions in Message controls. The hidden-trigger + Visibility-control pattern achieves the same polymorphic display without branching nodes — only the relevant payment block is shown, with no extra nodes on the canvas.

**Lab 3 fixture coverage:**

| Customer | Payment type | Used to verify |
|----------|-------------|----------------|
| `C-3DBZFE` (Marie Smith, Platinum) | Credit Card | Masked card number (`XXXX-XXXX-XXXX-9012`) shown; PayPal block hidden |
| `C-11100` (Sam Taylor, Standard) | PayPal | Masked PayPal account (`john.mu****@example.com`) shown; Credit Card block hidden |

**Learning points this extension demonstrates:**
- **Concurrent multi-service execution** — two independent SOR calls run in parallel; sequential execution would add unnecessary latency at the start of every claim.
- **Parallel branch synchronisation** — the workflow engine waits for both paths before advancing; no explicit join step is needed.
- **Engine-level data masking via Flow Settings** — masking is enforced before any display control renders the value; code-level masking cannot achieve the same guarantee.
- **Conditional visibility with a hidden trigger** — the hidden HTML comment pattern routes display logic through Visibility controls without branching nodes or a ternary expression.
- **`amount = float(-1)` convention** — a sentinel value that signals "general risk check, no specific item amount" to the fraud risk tool; worth explaining to participants as a tool contract decision.

> **Cross-extension contrast — Parallel Node vs. Foreach Node:** Both involve multiple execution paths, but they serve opposite purposes. A Parallel Node fires *independent service calls concurrently* — appropriate here because payment info and fraud risk are unrelated and latency reduction matters. A Foreach Node iterates *sequentially* over a list with human review per item (Extension F) — `SEQUENTIAL` policy is a deliberate design choice, not a default; firing all claims in parallel would overwhelm the reviewer. Participants who build both extensions should be able to articulate this distinction. See [§ Extension F — Sub-workflow, Foreach, and Scheduled Batch](#extension-f--sub-workflow-foreach-and-scheduled-batch).

---

### Extension F — Sub-workflow, Foreach, and Scheduled Batch

> **Status: IMPLEMENTED** — Exercises 6, 7, and 8 in `lab-guides/Lab Guide - Lab 3 - workflow-warranty.md`. This section has been updated to reflect the implemented design. Divergences from the original spec are noted inline.

#### Framing and teaching goals

This extension introduces three features that are closely interdependent in practice: **sub-workflow composition**, **Foreach iteration**, and **scheduled batch execution**. It does so by evolving the existing Lab 3 workflow in two directions — refactoring for reuse, then scaling to batch — rather than building anything from scratch.

The extension also introduces one important architectural concept: a **mode-aware sub-workflow** — a reusable workflow that behaves consistently for review and decision steps regardless of how it was triggered, but routes at the terminal step depending on whether a specialist is present (online) or not (batch).

---

#### How participants build this (implementation approach)

Step extraction from an existing workflow is **not supported** in the current wxO builder — the spec's Path A is not available. The implemented approach uses **UI duplication** instead of ADK CLI import: participants duplicate `(NAMESPACE)_TRI_warranty_claim_workflow` twice in the flow builder, rename each copy, then trim and rewire the canvas to produce the sub-workflow and the online caller. No CLI commands are required. This is simpler than importing a pre-built artifact and gives participants hands-on experience with the canvas at the same time.

---

#### Sub-workflow boundary and output contract

> **Divergence from original spec:** The `mode` input is a **Boolean** (`is_online_mode: True | False`) rather than the string `"online" | "batch"` planned in the spec. The output contract is simplified to a single Boolean property rather than the full `BatchReviewResult` object — sufficient to demonstrate the pattern without wiring up unused fields.

```
TRI_warranty_review_workflow
  inputs:  customer_id    String  [Required]
           customer_name  String  [Required]
           customer_tier  String  [Required]
           customer_email String  [Required]
           customer_phone String  [Required]
           document_ref   File    [Required]   ← signed file URL; caller's responsibility to produce this
           is_online_mode Boolean [Required]   ← True = online specialist call; False = batch run
           user_email_id  String  [Required]   ← email of the person to assign HITL tasks to

  outputs (end node):
    is_online_mode = True  → no structured output
                              (all output delivered directly to specialist in chat
                               via the existing HITL/present-to-user steps)
    is_online_mode = False → batch_review_result: Object
                              { is_in_warranty: Boolean }
```

The `user_email_id` input was added (not in the original spec) to support HITL task assignment. A `Build User Object` Logic block at the start of the sub-workflow resolves this email to a typed `User` object using `system.user.search_by_email(flow.input.user_email_id)`, which is then used to assign all HITL nodes within the `Handle Warranty Claim` User Activity. This makes the sub-workflow work correctly in both online mode (where a live specialist is present) and batch mode (where the schedule has no initiator and a named reviewer must be targeted explicitly).

The online caller determines `user_email_id` by calling `system.context.get_variable('wxo_email_id')` in a `Determine Current User Name` Logic block immediately before the sub-workflow call. The batch caller retrieves it the same way for preview test runs; in production scheduled runs it would be passed as a workflow input parameter.

The transport concern — fetching the uploaded document from the SOR — **stays in each caller**. The sub-workflow receives a ready `document_ref` file reference and starts immediately at document classification. No base64 conversion step exists: `TRI_fetch_baw_pdf` (a pre-deployed Python tool) fetches the PDF from the SOR CRM REST API and returns a signed file URL directly, which is the format document AI nodes require. The base64 → URL conversion path described in the original spec was eliminated by this tool.

---

#### Internal flow

```
TRI_warranty_review_workflow
  ├─ Build User Object             ← Logic block: resolves user_email_id → User object
  ├─ [Handle Warranty Claim User Activity — assigned to "User from a variable"]
  │    ├─ Extract Warranty Doc Text
  │    ├─ Classify document
  │    ├─ Doc Type? branch
  │    │    ├─ Receipt path  → Extract Receipt Fields  [HITL if confidence < threshold]
  │    │    ├─ Warranty Card → Extract Warranty Card Fields  [HITL if any empty field]
  │    │    └─ Other         → (exit path — not fully implemented)
  │    ├─ Lookup Catalog Item
  │    ├─ Prepare Warranty Check Inputs  (Logic block)
  │    ├─ Catalog item found? branch
  │    │    ├─ Yes (confidence 100)  → skip specialist selection
  │    │    └─ No                    → Select customer product [HITL form with File download]
  │    ├─ Extract catalog_item_id  (Logic block — parses selected option string)
  │    ├─ Check Warranty Status
  │    ├─ Extract Warranty Fields (flatten for decision table)  (Logic block)
  │    ├─ Warranty Discount Decision Table
  │    └─ In Warranty? branch
  │         ├─ Yes (Online)  → In Warranty Msg           (is_online_mode == True)
  │         ├─ No (Online)   → Out of Warranty Message   (is_online_mode == True)
  │         └─ Batch         → Set Offline Output        (else / default)
  │                             Logic block: flow.private.is_in_warranty =
  │                                          (flow.private.offer_type == 'In Warranty')
  └─ end node
       is_online_mode = True  → batch_review_result is empty (auto-mapped but not populated)
       is_online_mode = False → batch_review_result.is_in_warranty set by Set Offline Output
```

**Key teaching point:** The HITL steps are identical regardless of trigger mechanism. The wxO platform persists workflow state at every HITL boundary whether the workflow was initiated by an agent in chat or by a scheduler. The only thing `is_online_mode` controls is the terminal branch — online, the specialist sees the outcome in chat and the output is empty; batch, the `Set Offline Output` Logic block writes the verdict to `batch_review_result.is_in_warranty`.

---

#### Exercise 6 — Build: `TRI_warranty_review_workflow` and `TRI_warranty_claim_workflow_online`

**Create the sub-workflow by duplicating:**
Participants duplicate `(NAMESPACE)_TRI_warranty_claim_workflow` in the flow builder, rename the copy to `(NAMESPACE)_TRI_warranty_review_workflow`, then:
- Add inputs: `document_ref` (File), `is_online_mode` (Boolean), `user_email_id` (String)
- Add output: `batch_review_result` (Object) with `is_in_warranty` (Boolean) property; Auto-map enabled
- Add flow variable: `is_in_warranty` (Boolean)
- Add `Build User Object` Logic block before the User Activity; change User Activity assignment from **Flow initiator** to **User from a variable** pointing at `Build User Object`
- Update all document AI nodes to read `document_ref` from flow input rather than from the now-deleted `Fetch PDF from SOR` step; update HITL node user assignments to use the `user` variable from `Build User Object`
- Delete the upload-handling steps that belong to the online caller: `Progress - Payment info & fraud risk`, `Parallel Pre-Check - Payment + Fraud`, `CUSTOMER DETAILS & UPLOAD READINESS`, `Wait for customer upload confirmation`, `Fetch PDF from SOR`, `INSTRUCTIONS FOR FUTURE UPLOAD SENT`, `REMINDER FOR FUTURE UPLOAD`
- Add a third `Batch` path to the `In Warranty?` branch with a `Set Offline Output` Logic block; rename the two existing paths to `Yes (Online)` and `No (Online)` with `is_online_mode == True` conditions

**Create the online caller by duplicating:**
Participants duplicate `(NAMESPACE)_TRI_warranty_claim_workflow` a second time, rename it `(NAMESPACE)_TRI_warranty_claim_workflow_online`, then:
- Add `Determine Current User Name` Logic block after `Fetch PDF from SOR`; it calls `system.context.get_variable('wxo_email_id')` to retrieve the specialist's email
- Add a `Call a tool` node invoking `(NAMESPACE)_TRI_warranty_review_workflow` with all customer inputs, `document_ref` from `Fetch PDF from SOR`, `is_online_mode = True`, and `user_email_id` from `Determine Current User Name`
- Delete all downstream steps that the sub-workflow now owns (text extraction through warranty decision)
- Update `(NAMESPACE)_TRI_warranty_agent` to replace the original workflow tool with `(NAMESPACE)_TRI_warranty_claim_workflow_online`

> **Known platform defect:** The HITL review path inside the Document Extractor node does not complete correctly when invoked via a sub-workflow call (`Call a tool` node). Customer C-3DBZFE — whose receipt triggers the extraction confidence HITL — must be avoided in Exercise 6 tests. Customer C-11100 (receipt extracts cleanly, no HITL fired) is used for Exercise 6 verification instead.

---

#### Exercise 7 — Build: `TRI_warranty_claim_workflow_batch` and `TRI_warranty_batch_agent`

```
TRI_warranty_claim_workflow_batch   (Scheduling: ON — enabled in Flow settings)
  ├─ Set HITL user email id         ← Logic block: system.context.get_variable('wxo_email_id')
  │                                    (for preview; in production, pass as workflow input)
  ├─ Get Pending Warranty Documents ← Call a tool: (NAMESPACE)_TRI_get_pending_warranty_requests
  │                                    (per-participant namespaced Python tool; imported via prepare_lab_3.py)
  │                                    returns: outstanding_warranty_requests[]
  │                                    each item: { customer_id, customer_name, customer_tier,
  │                                                 customer_email, customer_phone } — metadata only,
  │                                                 no document; fetched per item below
  └─ Iterate over all documents     ← Foreach (Sequential), list = outstanding_warranty_requests
         └─ [foreach body]
              Fetch PDF from SOR    ← Call a tool: (NAMESPACE)_TRI_fetch_baw_pdf
                                       input: current_item.customer_id
                                       output: signed file URL
              TRI_warranty_review_workflow  ← Call a tool (sub-workflow)
                                       customer_id/name/email/phone from current_item.*
                                       customer_tier from current_item.customer_status
                                         (note: SOR field name differs from workflow input name)
                                       document_ref from Fetch PDF from SOR output
                                       is_online_mode = False (Expression)
                                       user_email_id from Set HITL user email id output
              Outcome specific handling  ← Logic block stub
                                       (placeholder for post-review email / SOR update logic;
                                        not implemented — introduces no new wxO concepts)
```

> **Divergence from original spec:** The spec described a base64 → S3 URL conversion step inside the foreach body. This was eliminated by `(NAMESPACE)_TRI_fetch_baw_pdf` — the per-participant Python tool calls the SOR CRM REST API and returns a signed file URL directly. No base64 handling is required.

> **SOR tool note:** `(NAMESPACE)_TRI_get_pending_warranty_requests` is the Python tool wrapping the BAW SOR Warranty REST API (`get_pending_warranty_requests`). Like all Lab 3 SOR/Python tools, it is not tenant-wide pre-deployed — each participant imports their own namespaced copy via `prepare_lab_3.py` (see `context/decisions.md`, 2026-10-11, "Lab 3 tool naming").

A dedicated agent `(NAMESPACE)_TRI_warranty_batch_agent` is used to trigger batch execution on demand during lab testing (instead of a scheduled Live deployment). Scheduling is enabled on `TRI_warranty_claim_workflow_batch` but the lab tests in the Agent Preview using this agent — Exercise 8 (reading-only) covers the scheduling architecture and how to promote to Live.

---

#### Features taught

| Feature | Where |
|---------|-------|
| Sub-workflow (workflow calling workflow via Call a tool node) | Ex 6: online caller; Ex 7: foreach body |
| Mode-aware terminal branch (`is_online_mode` Boolean) | Ex 6: `In Warranty?` branch — `Yes (Online)` / `No (Online)` / `Batch` paths |
| Simplified structured output (`batch_review_result.is_in_warranty`) | Ex 6: sub-workflow output contract |
| Transport concern kept in caller (`Fetch PDF from SOR` in each caller) | Ex 6 and Ex 7 |
| Dynamic HITL user assignment via `Build User Object` Logic block | Ex 6: sub-workflow setup |
| Foreach Node (Sequential) over SOR pending-claims list | Ex 7: `Iterate over all documents` |
| `current_item.*` expression inside foreach body | Ex 7: data mapping |
| Conditional HITL — same logic in both modes | Ex 6 / Ex 7: visible across both seed records |
| Scheduled workflow (`Scheduling: ON` in Flow settings) | Ex 7: batch workflow config |
| On-demand batch trigger via dedicated agent | Ex 7: `TRI_warranty_batch_agent` |
| Scheduling architecture and Live deployment path | Ex 8 (reading-only) |

---

#### SOR dependency

**Namespaced tool: `(NAMESPACE)_TRI_get_pending_warranty_requests`** (Python tool, per-participant — imported via `prepare_lab_3.py`)
- Returns `outstanding_warranty_requests[]`
- Each item contains customer metadata only: `customer_id`, `customer_name`, `customer_tier` (as `customer_status`), `customer_email`, `customer_phone` — no document field. The warranty document itself is fetched separately per item, below.
- Note: field is named `customer_status` in the SOR output; the foreach body maps it to the `customer_tier` workflow input explicitly

**Namespaced tool: `(NAMESPACE)_TRI_fetch_baw_pdf`** (Python tool, per-participant — imported via `prepare_lab_3.py`)
- Input: `customer_id`
- Output: signed file URL (the format document AI nodes require)
- Used in both the online caller (`Fetch PDF from SOR` after `Wait for customer upload confirmation`) and the batch foreach body (`Fetch PDF from SOR` per iteration)

No additional SOR changes are required beyond what was already available. The `is_online_mode` flag and `batch_review_result` output are purely workflow-side concerns.

---

## Lab 3 acceptance criteria (extensions)

All acceptance criteria are consolidated here — this is the single canonical list. Criteria are no longer duplicated inline in extension sections.

| # | Criterion | Extension |
|---|-----------|-----------|
| AC-L3-1 | When `classify_document` returns `warranty_card`, the workflow routes to `extract_document_fields` using the warranty card schema (mandatory: `product_name`, `purchase_date`, `serial_no`). | A |
| AC-L3-2 | When `classify_document` returns an unrecognised document type, the workflow routes to the invalid document path, notifies the specialist via `ua_close_invalid`, and terminates cleanly. | A |
| AC-L3-3 | `C-48239` (in-warranty): specialist sees "PRODUCT IS IN WARRANTY" with `warranty_end_date` and `days_remaining` from the `warranty_status` object, plus four resolution options (replace, gift certificate, refund, replace with another model) on `ua_inwarranty_options`. | C |
| AC-L3-4 | Each of the four resolution options routes to its corresponding `process_*` node and converges at `ua_deliver_resolution` before `__end__`. | C |
| *(no AC)* | Extension C — email templating is optional; no acceptance criterion. | C (optional) |
| AC-L3-5 | When `TSOR_Catalog_search_catalog_items_by_name` returns a non-empty result list whose first item has `confidence = 100`, the workflow selects it automatically and proceeds to Step 9 without showing `ua_select_catalog_item`. | B |
| AC-L3-6 | When the result is empty or the first item does not have `confidence = 100`, the workflow routes to `ua_select_catalog_item`; the specialist sees a selectable table with **Name**, **Description**, and **Confidence** columns only; submission is blocked until a row is selected. | B |
| AC-L3-7 | The `catalog_item_id` from the selected row is correctly passed to `TSOR_Catalog_check_warranty_for_catalog_item_by_purchase_date` in Step 9. | B |
| AC-L3-8 | The `docproc` node (`extract_raw_text`) is placed after Step 4 and before `classify_document`; it receives the same document URL produced by `fetch_baw_pdf_url`. | D |
| AC-L3-9 | The node runs with `task="text_extraction"` and produces a non-empty text URL as output. | D |
| AC-L3-10 | The specialist sees the extracted plain text in `ua_show_raw_text` before the workflow advances to `classify_document`; no button click is required. | D |
| AC-L3-11 | When the Parallel Node executes, `TSOR_CRM_get_customer_payment_info_by_customer_id` and `TSOR_CRM_evaluate_fraud_risk` run concurrently. | E |
| AC-L3-12 | The workflow engine synchronizes both branches and populates the combined payment details and fraud risk score on the downstream HITL form before user interaction. | E |
| AC-L3-13 | Sensitive payment fields (`card_number` / `paypal_username`) are masked in Flow Settings; raw values do not appear on any HITL form, in the execution trace, or in the agent response. | E |
| AC-L3-14 | The resolution form (`ua_inwarranty_options` / `ua_close_oow`) renders the masked payment instrument using a dynamic expression; `C-3DBZFE` shows a masked credit card number and `C-11100` (Sam Taylor) shows a masked PayPal account (`john.mu****@example.com`) without any branching node. | E |
| AC-L3-15 | *(Extension F — pending)* `TRI_warranty_review_workflow` accepts `customer_id`, `customer_name`, `customer_tier`, `customer_email`, `document_url`, and `mode` as inputs; for `mode = "online"` the end node returns `null`; for `mode = "batch"` it returns a `BatchReviewResult` object with all five fields populated. | F |
| AC-L3-16 | *(Extension F — pending)* The online caller (`TRI_warranty_claim_workflow`) retains Steps 1–4 unchanged and the specialist experience is identical to the pre-refactoring baseline (verified against TC-UC-04-001). | F |
| AC-L3-17 | *(Extension F — pending)* `TRI_warranty_batch_workflow` configured with `schedulable=True`; the Foreach Node iterates over the `WarrantyRequest[]` list using `SEQUENTIAL` policy; each item invokes `TRI_warranty_review_workflow` with `mode = "batch"`. | F |
| AC-L3-18 | *(Extension F — pending)* For the clean-receipt seed record, `ua_extracted_review` is skipped and `BatchReviewResult.review_required` is `false`. For the low-confidence warranty-card record, `ua_extracted_review` fires, the reviewer corrects the value, and `BatchReviewResult.review_required` is `true`. | F |

---

## Lab 3 test cases

These test cases exercise Lab 3 extensions beyond the end-to-end baseline. TC-L3-001 through TC-L3-004 (Extension C, all four in-warranty resolution paths) are active YAML cases in `tests/dev/cases/`. TC-L3-005 onwards are stubs — description and expected outcome are specified here; YAML files will be created once the corresponding extension is implemented and ready for verification.

| TC ID | Description | Customer / Document | Expected outcome | Covers AC |
|-------|-------------|---------------------|-----------------|-----------|
| TC-L3-001 | Extension C — in-warranty path, select Replace | `C-48239` | Specialist sees `ua_inwarranty_options`; selects Replace; workflow routes to `process_replacement` and converges at `ua_deliver_resolution` | AC-L3-3, AC-L3-4 |
| TC-L3-002 | Extension C — in-warranty path, select Gift Certificate | `C-48239` | Specialist sees `ua_inwarranty_options`; selects Gift Certificate; workflow routes to `process_gift_certificate` and converges at `ua_deliver_resolution` | AC-L3-4 |
| TC-L3-003 | Extension C — in-warranty path, select Refund | `C-48239` | Specialist sees `ua_inwarranty_options`; selects Refund; workflow routes to `process_refund` and converges at `ua_deliver_resolution` | AC-L3-4 |
| TC-L3-004 | Extension C — in-warranty path, select Replace with another model | `C-48239` | Specialist sees `ua_inwarranty_options`; selects Replace with another model; workflow routes to `process_replace_other_model` and converges at `ua_deliver_resolution` | AC-L3-4 |
| TC-L3-005 | Extension A — warranty card document type | `C-48239` / `warranty_card_realistic.pdf` | `classify_document` returns `warranty_card`; workflow routes to `extract_document_fields` using warranty card schema; `serial_no` is extracted as a mandatory field | AC-L3-1 |
| TC-L3-006 | Extension A — invalid document type | *(TBD customer)* / invalid document | `classify_document` returns unrecognised type; workflow routes to `prompt_invalid_doc` → `ua_close_invalid`; terminates at `__end__` without calling any SOR tool | AC-L3-2 |
| TC-L3-007 | Extension B — catalog auto-select (confidence = 100) | `C-3DBZFE` / `receipt_realistic_clean.pdf` | `lookup_catalog_item` first result has `confidence = 100`; `ua_select_catalog_item` is not shown; `catalog_item_id` is passed directly to `check_warranty` | AC-L3-5 |
| TC-L3-008 | Extension B — catalog manual selection (confidence < 100) | `C-3DBZFE` / receipt with ambiguous product name | `lookup_catalog_item` first result does not have `confidence = 100`; specialist sees `ua_select_catalog_item` with selectable table; submission blocked until row selected; selected `catalog_item_id` passed to `check_warranty` | AC-L3-6, AC-L3-7 |
| TC-L3-009 | Extension D — raw text extraction shown | `C-3DBZFE` / `receipt_realistic_clean.pdf` | `extract_raw_text` (`docproc`) runs after Step 4; specialist sees `ua_show_raw_text` with non-empty extracted text; workflow advances automatically to `classify_document` without button click | AC-L3-8, AC-L3-9, AC-L3-10 |
| TC-L3-010a | Extension E — parallel branches execute concurrently | `C-3DBZFE` | Parallel Node fires both `TSOR_CRM_get_customer_payment_info_by_customer_id` and `TSOR_CRM_evaluate_fraud_risk`; both complete before downstream HITL form is shown; combined payment details and fraud risk score appear on the form | AC-L3-11, AC-L3-12 |
| TC-L3-010b | Extension E — payment masked, credit card | `C-3DBZFE` | Resolution form shows masked credit card number (e.g. `XXXX-XXXX-XXXX-9012`); raw `card_number` value is absent from HITL form, execution trace, and agent response | AC-L3-13, AC-L3-14 |
| TC-L3-010c | Extension E — payment masked, PayPal | `C-11100` (Sam Taylor) | Resolution form shows masked PayPal account (`john.mu****@example.com`); raw `paypal_username` value is absent from HITL form, execution trace, and agent response | AC-L3-13, AC-L3-14 |
| TC-L3-011 | Extension F — online path unchanged after sub-workflow refactoring | `C-3DBZFE` / `receipt_realistic_clean.pdf` | After Steps 5–12 are replaced with a Call Flow node, specialist experience is identical to pre-refactoring baseline; `TRI_warranty_review_workflow` is invoked with `mode = "online"`; end node returns `null` | AC-L3-15, AC-L3-16 |
| TC-L3-012 | Extension F — batch processes clean receipt *(pending CR-18)* | Seed record 1 (receipt, clean) | `TRI_warranty_batch_workflow` foreach body invokes `TRI_warranty_review_workflow` with `mode = "batch"`; `ua_extracted_review` is skipped; `BatchReviewResult.review_required` is `false`; `warranty_status` and `discount_code` are populated | AC-L3-17, AC-L3-18 |
| TC-L3-013 | Extension F — batch HITL fires on low-confidence warranty card *(pending CR-18)* | Seed record 2 (warranty card, low-confidence `purchase_date`) | Foreach body invokes `TRI_warranty_review_workflow` with `mode = "batch"`; `ua_extracted_review` fires; reviewer corrects `purchase_date`; `BatchReviewResult.review_required` is `true`; sub-workflow returns correct `warranty_status` after correction | AC-L3-17, AC-L3-18 |
| TC-L3-014 | Extension F — scheduled trigger initiates batch *(pending CR-18)* | — | `TRI_warranty_batch_workflow` can be triggered by the scheduler (in addition to agent invocation); HITL steps inside the foreach body pause for human review identically to agent-triggered runs | AC-L3-17 |

