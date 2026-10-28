# Lab 3 Audit Findings — 2026-10-11

Cross-lab consistency audit (Lab 1.x / Lab 2 / Lab 3), Lab 3 portion. Findings are ranked most significant first. Nothing in this document has been fixed yet — treat as a backlog pending review.

## 1. Solution workflow JSON duplicates in-warranty resolution logic (BUG)

`labs/lab-3/solution/workflows/TRI_warranty_claim_workflow_lab.json` implements the full replace/gift_certificate/refund/replace_other_model resolution logic **twice**:

- Once inside the `ua_inwarranty_options` user_flow subflow, ending at `iw_deliver_form` (~line 2555).
- Again via edge `e-iw-to-branch3` (line 585) → `branch_3` (line 4120) → duplicate `process_*` nodes (lines 4223-4536) → `ua_deliver_resolution` (line 4537) → `__end__`.

`Lab Guide - Lab 3 - workflow-warranty.md:1172` explicitly tells participants: *"we will not implement the full resolution logic for each branch. Instead, we add a simple Message node..."* — the shipped solution does not match what the guide teaches. In practice, every in-warranty claim would trigger the "Close Case" form **twice**.

`context/decisions.md:225` traces this: the top-level cluster was grafted in from the production workflow via PR #49 and never reconciled against what the lab actually teaches.

All four active tests (TC-L3-001..004) have `hitl_steps` that stop at `iw_deliver_form` and never assert the second `ua_deliver_resolution` form — so the tests currently pass without catching this.

## 2. Test suite's canonical customer never appears in the guide — SPEC UPDATED 2026-10-11

- TC-L3-001 through TC-L3-004 and their shared precondition (`TC-UC-00-001-lab3_customer-lookup-for-lab3.yaml`) are all built on customer `C-48239` (Alex Rivera, Standard).
- `Lab Guide - Lab 3 - workflow-warranty.md` contains zero references to `C-48239` — it instead walks participants through `C-3DBZFE`, `C-11100`, and `C-33300`.
- Decision: the guide is reality — fix the spec, not the guide. `LAB-03_warranty-claim-workflow.md`'s "SOR test data — lab fixtures" table updated: added a `C-33300` row documenting it as the guide's actual Exercise 4 warranty-card fixture; `C-48239`'s row reframed as test-suite-only (TC-L3-001..005, Extension A/B/C), explicitly not used by the guide.
- Residual gap, not fixed here: passing TC-L3-001..004 still doesn't validate the participant-facing walkthrough, since those tests exercise the parked Extension C combobox (see Positive/compliance section) rather than anything the guide builds. That's expected given Extension C's parked status, not a new defect.
- Also cleared up while checking seed data: the old spec row's "⚠️ Joint lab author + Olaf action — confirm `C-48239` has a warranty card PDF attached... and the `under_warranty` flag ... is set to `true`" was moot, not open. `olaf-sor-seed-data-2026-10-08.md:49` already documents that Lab 3's in-warranty path keys off the CRM warranty-card PDF attachment (`CM-48239X`) via `TSOR_CRM_get_customer_provided_proof_of_warranty_by_customer_id`, not an SOR order/`under_warranty` flag — an orphaned order fixture built for that now-abandoned assumption was already removed. The new spec row text (above) drops the stale action item accordingly.

## 3. Fixture error in Exercise 4 — FIXED 2026-10-11

- Guide lines 925-946 use customer `C-33300` for the Warranty Card path — not present in LAB-03's "SOR test data — lab fixtures" table (which lists `C-3DBZFE`, `C-11100`, `C-48239`, and a TBD invalid-doc customer).
- The spec's documented warranty-card fixture, `C-48239`, is never used in the guide.
- Guide line 918 mislabels `C-11100`'s result as "warranty card had all fields successfully extracted" — `C-11100` is actually a receipt-path customer (confirmed by the `class_name` value and the next step reading `Extract Receipt Fields`).
- Checked against the seed-data extract updated during the Lab 2 review: `C-33300`'s warranty-card scenario (Casey Morgan, Standard, `O-33300X`/`OI-KBD001`) was already correctly seeded beforehand — the Lab 2 review only added the unrelated `C-33310`/`C-33311`/`C-33312` family, so no seed-data fix was needed here.
- `C-33300`'s spec-table gap already closed as part of finding #2's fix (new row added). The remaining guide-text bug (line 918's copy-paste leftover from the `C-33300` paragraph) fixed: now reads "This customer's receipt had all fields successfully extracted," matching the flow-inspector `class_name: receipt` result shown two steps earlier.

## 4. No invalid-document fixture exists anywhere — VERIFIED STILL OPEN 2026-10-11

- No `B-INVALID`-equivalent, `branch_invalid_doc`, or `ua_close_invalid` reference exists in the guide.
- Consistent with TC-L3-006's own `known_issues` note ("SOR fixture ... not yet created, Customer ID TBD").
- AC-L3-2 has no runnable coverage and no guide-side path to create one — unlike Lab 2's well-covered `B-INVALID` precedent.
- Re-checked against the Lab 2 seed-data review: not addressed. The `C-33310`/`C-33311`/`C-33312` family added there is a Lab 2 billing-dispute fixture set, unrelated to Lab 3's document-processing scenario — no invalid-document customer, attachment, or SOR record exists anywhere in `olaf-sor-seed-data-2026-10-08.md` or `loadData.sql`. Still a genuine gap pending a fixture decision (joint lab-author + Olaf action, same as originally flagged).

## 5. AC numbering inconsistent and unresolvable via the guide

- Three incompatible AC schemes exist across test files: `AC-L3-1..4` (per the original task brief), `AC-L3-5..10` (TC-L3-007/008/009), and `AC-3`/`AC-4`/`AC-L3-OOW` (TC-L3-010).
- The guide carries no acceptance-criteria IDs at all (zero matches for `AC-` anywhere), so this cannot be reconciled against the guide — must be resolved against the spec.

## 6. Stale/superseded tool name — FIXED 2026-10-11 (restructured further 2026-10-12)

- Guide §1.2.2 (setup) and line 1620 (Exercise 7 build step) reference `(NAMESPACE)_TRI_get_pending_warranty_requests`.
- LAB-03 spec's Extension F section stated this tool was **replaced** by `TRI_SOR_get_pending_warranty_documents` — confirmed wrong: that tool name does not exist anywhere in the repo (checked `solution/toolkits/TRI_SOR_MCP.yaml` and the seed-data extract's CR-18 record). The guide was correct; the spec's "replaced" claim was the stale half.
- Also surfaced mid-investigation: the guide's own "pre-registered, no namespace prefix" framing (old line 125) was *itself* stale — Lab 3 moved to a per-participant namespaced-deploy model (same as Lab 2), via `prepare_lab_3.py`. That script and the two Lab 3 Python tools existed on an unmerged branch (`lab-3-guide`) along with the already-updated guide text and a `context/decisions.md` entry recording the model (2026-10-11, "Lab 3 tool naming — per-participant namespaced tools"); `lab-3-guide` has since been merged with this working branch so both sets of fixes now live together.
- Fix applied to `LAB-03_warranty-claim-workflow.md`: Exercise 7 pseudocode and the "SOR dependency" section now reference `(NAMESPACE)_TRI_get_pending_warranty_requests` and `(NAMESPACE)_TRI_fetch_baw_pdf` (the latter also namespaced, since the per-participant model covers all Lab 3 SOR/Python tools, not just Warranty); the false "replaced by" claim rewritten to state the tool is correct and was never replaced; the dangling `document_type`/`WarrantyRequest` schema reference (no such schema exists in the current spec) dropped.
- 2026-10-12 follow-up: the guide's old §1.2.1 still carried a single "Pre-deployed tools" paragraph left over from before the namespace move — self-contradictory (called the tools "pre-deployed" while also saying to run a per-participant import script) and gave no runnable command for `prepare_lab_3.py` at all (no `orchestrate env activate` step, no command block, no verification step), unlike Lab 2's §1.2.2. Restructured to match Lab 2 exactly: removed the stale paragraph; split into §1.2.1 Prerequisites (now lists the ADK/Python/repo prerequisites needed to run the script) and a new §1.2.2 Required Setup, with the explicit `orchestrate env activate` + `prepare_lab_3.py` command block, a "**If you completed Lab 1.1:**" skip-branch note (confirmed accurate against the script's source — Steps 1-2 pull the same Key-Value connection and MCP toolkit as Lab 2's script and skip re-importing them if already present), a verification step, and an artifact-reference table. TOC updated to list 1.2.1/1.2.2 (previously only listed 1.2).
- Residual gap, unaffected by this fix: `labs/lab-3/solution/workflows/` has no pre-built end-state for Exercises 6/7, so a participant starting mid-lab at Exercise 6 has nothing to import.

## 7. Test bug in TC-L3-010 — FIXED 2026-10-11

- `TC-L3-010_oow-headset-reseller.yaml` used title-case `form_data`/`form_data_contains` keys (`"Customer Details"`, `"Upload Timing"`, `"Customer Upload Status"`, `"Extracted Fields"`, `"Warranty Claim Result"`) that don't match the actual snake_case field names in the workflow's form definitions.
- TC-L3-001-004 get this right; TC-L3-010 (`type: dev`) did not.
- Correct field names confirmed directly against `TRI_warranty_claim_workflow_lab.json`'s form specs (not just by analogy to TC-L3-001, since TC-L3-010 is the only active test that exercises `ua_close_oow` and the only one that asserts `form_data_contains` on `ua_extracted_review`): `ua_show_customer` → `customer_summary` / `upload_timing` (confirmed via TC-L3-001 precedent and the JSON, lines ~1347, ~1398); `ua_wait_callback` → `upload_callback` (line ~1604); `ua_extracted_review` → `extracted_summary` (line ~1954, the `confirm_extraction_form` field under `ui:title: "Extracted Fields"`); `ua_close_oow` → `msg` (line ~687, the `ua_close_oow_form` field — note its `ui:title` is "Out of Warranty," not "Warranty Claim Result"; the old key was a made-up label, not derived from either the field name or its UI title).
- Fix applied: all five keys in `TC-L3-010_oow-headset-reseller.yaml` renamed to their snake_case field names.

## 8. Lab Complete bullet-count violation — FIXED 2026-10-12

- "What You Learned" section (`Lab Guide - Lab 3 - workflow-warranty.md:1899-1909`) had 9 bullets — convention (`LAB-GUIDE-CONVENTIONS.md:384`) caps the closing bullet list at 3-5. Plus three more enumerated sections (Key Concepts Covered, What You Built, Next Steps) not accounted for in the convention's 4-element spec.
- Precedent checked: Lab 2's closing section (`Lab Guide - Lab 2 - workflow-billing.md:2103-2109`) already satisfies the convention exactly — a single merged "What You Built and Learned" list of 5 bullets, each bolding the artifact and explaining what it taught, plus one supplementary section ("Key References & Further Reading").
- Fix applied: Lab 3's "What You Learned" (9 bullets) and "What You Built" (4 items) merged into one "What You Built and Learned" list of 5 bullets, mirroring Lab 2's exact style. "Key Concepts Covered" (9 bullets) removed as redundant with the merged list. "Next Steps" kept unchanged as the single supplementary section, playing the same role as Lab 2's "Key References & Further Reading."
- Net result: 22 bullets/items across 4 sections → 5 bullets across 1 section (plus Next Steps) — matches Lab 2's structure and the convention's 3-5 cap.

## 9. No "If You Are Starting Here" section — NOT A DEFECT 2026-10-12

- Not present anywhere in the guide; the guide instead states "no import shortcut or mid-lab entry point — start at Exercise 1" (lines 117-119).
- Same precedent as Lab 2 finding #4 (`LAB-02_audit-findings-2026-10-11.md`): the per-exercise heading pattern exists for labs with independently resumable exercises. Lab 3 is explicitly single-sequence (line 119: "Complete this lab start to finish... start at Exercise 1 and work through the exercises in order"), matching the Lab 1.3 departure recorded in `context/decisions.md` (2026-09-30) and already extended to Lab 2 (2026-10-11): single-sequence labs fold the preflight gate into §1.2.1/1.2.2 instead of the per-exercise heading.
- Originally this looked like a weaker analogy than Lab 2's, since Lab 3 has no prior-lab dependency (line 117: "This lab has no dependency on any previous lab") while Lab 2's gate branches on "if you completed Lab 1.1." Checking `prepare_lab_3.py`'s source disproved that distinction: Steps 1-2 (Key-Value connection, MCP toolkit) pull from the exact same `labs/lab-1x/solution/connections` and `solution/toolkits` sources as Lab 2's script and skip re-importing them if a prior lab already created them — the identical "if you completed Lab 1.1, these steps skip" behavior, not an analogous one.
- Fix applied as part of finding #6's 2026-10-12 follow-up: guide §1.2.1/§1.2.2 now mirrors Lab 2's structure exactly, including an explicit "**If you completed Lab 1.1:**" skip-branch note. The convention's self-containment requirement is satisfied in substance, same as Lab 2.
- No further guide fix needed for this finding.

## 10. Duration mismatch — FIXED 2026-10-12

- Header stated "Duration: 1.5 Hours" (line 6); `specs/lab-design.md:353` stated "75 min." Core-only (Exercises 1-5) sums to ~55-60 min; all 8 exercises sum to ~95-100 min — neither stated figure cleanly matched the actual exercise-time sums.
- Provenance checked: both figures trace to the same unvalidated source. `specs/lab-design.md`'s "75 min" (line 353) and its companion open-question row ("Lab durations — all TBD except Lab 3 (75 min)," line 433) date to the very first commit (`64b1b81`, 2026-08-21) and were logged as an open question from day one, not a measured figure. The guide's "1.5 Hours" header was added over a month later (`164f536`, 2026-10-07) by simply rounding that original estimate — no independent measurement. Neither figure ever went through the tester-feedback discipline `context/decisions.md:100` records for Lab 2 (placeholders stay `(TBD)` until testers report real elapsed times); Lab 3's figures predate that discipline.
- Fix applied: `Lab Guide - Lab 3 - workflow-warranty.md`'s header changed to `**Duration**: (TBD)`, with a `⏱️ **TODO (Testers)**` callout added directly below it, matching Lab 2's convention (`Lab Guide - Lab 2 - workflow-billing.md:13`) word-for-word. `specs/lab-design.md:353` changed to `**Duration** | TBD`; its open-question row (line 433) reworded from "all TBD except Lab 3 (75 min)" to "all TBD, pending tester-reported timings" since Lab 3 is no longer an exception.
- Per-exercise minute estimates in the guide's TOC/exercise headings were not part of this finding and were left as-is.

## 11. Architecture diagram not a captioned figure — FIXED 2026-10-11

- Plain ASCII text (lines 99-109), not an image, and not captioned "Figure 1," despite the convention requiring a captioned diagram as Figure 1 in §1.1.
- Not a "needs to be an image" defect — `Lab Guide - Lab 2 - workflow-billing.md`'s own Figure 1 is a plain-text (`mermaid`) diagram with a caption, so a text diagram satisfies the convention as long as it's captioned. Lab 3's was simply missing the caption line.
- Fix applied: added `*Figure 1. Lab 3 solution architecture — ...*` directly below the ASCII block (`Lab Guide - Lab 3 - workflow-warranty.md`, § 1.1). Left as a bare "Figure 1" (not "Figure 1.1") to match the convention's letter and Lab 2's precedent — Lab 3's own screenshots use a separate `Figure {section}.{n}` scheme (`1.1`, `2.1`, ...) that is a pre-existing, unflagged deviation from the convention's sequential `Figure 1..N` numbering; not addressed here, out of scope for this finding.

## 12. `fetch_baw_pdf` output-shape mismatch — FIXED 2026-10-12

- Tool returned `FetchBawPdfResult.file_url: str` (a one-field Pydantic object), built via a manual temp-file write + `ibm_watsonx_orchestrate.run.files.upload()` signed-URL step. The workflow node's own `output_schema` (`TRI_warranty_claim_workflow_lab.json` ~line 805-836) declares the output as bare `"PDF bytes"` (`format: binary`), and both downstream consumers — `classify_document` and `extract_document_fields` — wire `document_ref` from the *entire* `flow['fetch_baw_pdf'].output` value (lines ~1787, ~3259), not a sub-field. So the node's own schema and its two consumers all expected raw bytes, while the tool hands back an object.
- A second, correct copy of this tool exists at the repo-root `solution/tools/TRI_fetch_baw_pdf/TRI_fetch_baw_pdf.py` (pre-dating the Lab 3 copy) that returns raw `bytes` and relies on the platform's auto-upload-to-S3-on-bytes-return behavior — confirmed to match the node's `output_schema` and both consumers exactly.
- Not a simple copy-paste, though: that root-level tool differs from Lab 3's actual deployment in one respect that does *not* carry over —
  1. **Credential convention differs, but deliberately.** The root tool uses `@tool(expected_credentials=[ExpectedCredentials(...)])` and reads `WXO_CONNECTION_<app_id>_<KEY>`-prefixed env vars — the Lab 1.1-era pattern. `context/decisions.md:309` (2026-10-11) documents that Lab 3's tools were deliberately written *without* `expected_credentials` (not available in the ADK PyPI version Lab 3 targets, 2.18.1) and instead read plain unprefixed env vars (`ENDPOINT`, `USERID`, `PASSWORD`, `VERIFY_SSL`, `HTTP_TIMEOUT`) injected via `--app-id` on import. This is a version constraint, not a correctness issue, so Lab 3's credential-reading code is kept as-is.
  2. **Correction (2026-10-12):** Lab 3's own copy actually had the REST path *wrong*, not the root tool. The root tool's snake_case path (`.../CRM/get_customer_provided_proof_of_warranty_by_customer_id`) is the one confirmed live in production — it's what `scripts/deploy.py` Step 4 imports verbatim, it matches `specs/use-cases/UC-04_warranty-claim-external-reseller.md:331` and its AC-5/AC-5b, and it matches `context/decisions.md:229` (2026-09-18, status Active). The camelCase path Lab 3's copy used (`getCustomerProvidedProofOfWarrantyByCustomerId`) was mis-derived from `olaf-sor-seed-data-2026-10-08.md:657`, which documents the SOAP WSDL operation name, not the REST HTTP path — a category error in the original audit entry below. Lab 3's URL has now been corrected to snake_case to match production.
- Fix applied: merged rather than copied. `labs/lab-3/solution/tools/TRI_fetch_baw_pdf/TRI_fetch_baw_pdf.py` keeps its existing credential-reading code unchanged; the return contract changed — dropped `FetchBawPdfResult`/pydantic wrapper and the temp-file/`wxo_files.upload()` logic, now returns `base64.b64decode(attachment_b64)` typed `-> bytes` directly, matching the node's `output_schema` and both downstream `.output` consumers — and the REST URL was corrected from camelCase to the production-confirmed snake_case path.

## 13. Appendix placement

- "Full Warranty Discount Decision Table" appendix sits after Lab Complete (line 1920) — a placement the convention sanctions specifically for reading-only labs, but it supports core/mandatory Exercise 5, not the optional reading-only Exercise 8.

## 14. Minor typo — FIXED 2026-10-11

- Figure 4.4 caption: "Reciept" (line 795) → corrected to "Receipt."

## 15. `TRI_get_pending_warranty_requests` wrong REST path casing and naming — FIXED 2026-10-12

- Same bug pattern as finding #12's REST URL: the tool called `.../rest/TSOR/Warranty/getPendingWarrantyRequests` (camelCase). `olaf-sor-seed-data-2026-10-08.md` documents this CR-18 operation in snake_case in two places — line 65 (`get_pending_warranty_requests`) and line 1101/1115, the latter explicitly noting its `attachment_content` field uses "the same encoding as `get_customer_provided_proof_of_warranty_by_customer_id`," the CRM operation now confirmed live in production with a snake_case REST path (finding #12). Could not confirm directly against the live Swagger docs (the URL the user provided returns 401 — OIDC auth required) — this fix rests on the internal naming-convention evidence, not a direct live confirmation.
- Fix applied: `labs/lab-3/solution/tools/TRI_get_pending_warranty_requests/TRI_get_pending_warranty_requests.py:73` URL changed to `.../rest/TSOR/Warranty/get_pending_warranty_requests`. Tool renamed from `TSOR_Warranty_get_pending_warranty_requests` to `TRI_get_pending_warranty_requests` to adhere to the `TRI_` prefix convention.

## Positive / compliance findings (no action needed)

- Parking-lot item: AC-L3-3/AC-L3-4's assumption of a full 4-option resolution combobox (`ua_inwarranty_options`) is out of scope for the lab guide per the spec's own Extension C ("not implemented... out of scope"). The combobox is built — it exists in the solution workflow (see finding #1's duplicate-logic cluster) — but is intentionally not surfaced in the Lab 3 teaching path, which uses the simplified In Warranty/Out of Warranty message split instead (`Lab Guide - Lab 3 - workflow-warranty.md:1131-1178`). The guide is internally consistent; the stale half is the spec's "Unique agentic workflow features" table (line 87), which should be reconciled against Extension C, not the guide.
- Allen Chan **#22 Mixing Extraction with Processing** (line 735) and **#23 Lazy Field Definitions** (line 803) both correctly cited with ADK Docs links, as flagged relevant for document-processing workflows.
- The "⚠️ Important:" callout is used once (line 402), correctly matching the convention's definition.
- No bare `[SCREENSHOT NEEDED]` placeholders remain, though the top-of-guide TODO (line 8) about replacing screenshots is still unresolved.
