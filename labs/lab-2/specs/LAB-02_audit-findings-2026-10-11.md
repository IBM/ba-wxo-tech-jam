# Lab 2 Audit Findings — 2026-10-11

Cross-lab consistency audit (Lab 1.x / Lab 2 / Lab 3), Lab 2 portion. Findings are ranked most significant first. Nothing in this document has been fixed yet — treat as a backlog pending review.

## 1. `customer_tier` input description didn't match the workflow's actual decision logic — FIXED 2026-10-11

- `lab-guides/Lab Guide - Lab 2 - workflow-billing.md:352` and both `labs/lab-2/solution/workflows/TRI_billing_dispute_workflow_ex7_complete.json:37` / `..._ex8_complete.json:37` agreed with each other but were all wrong: the `customer_tier` input was documented as `"Customer loyalty tier (Platinum, Gold, Premium, Standard)"` — a 4-value enum including "Premium."
- The decision-table gateway in the same workflow (`TRI_billing_dispute_workflow_ex7_complete.json:659-786`) actually branches on five literal values: `"Standard"`, `"Bronze"`, `"Silver"`, `"Gold"`, `"Platinum"`. `"Premium"` never appeared as a condition anywhere in the workflow.
- Not a guide-vs-solution mismatch as first reported — a description-vs-implementation mismatch present identically in all three files. A participant following the old description and passing `customer_tier = "Premium"` would have matched none of the five gateway conditions and silently fallen through to the default/else branch.
- Fix applied: corrected the description text in all three files to `"Platinum, Gold, Silver, Bronze, Standard"`, matching the actual gateway conditions.

## 2. Seed-data extract is stale relative to `loadData.sql` — not a guide defect

- The guide's main running scenario — customer `C-33310` / order `O-A33310` / billing record `B-TD3310` — is introduced at `Lab Guide - Lab 2 - workflow-billing.md:100-105` and reused through Exercises 1-6.
- All three IDs are legitimately seeded: `C-33310` (`references/source/sor/sql/loadData.sql:4`), `O-A33310` (`loadData.sql:65`), and `B-TD3310` (`loadData.sql:143`, description "Shipping before laptop return" — matching the guide's dispute scenario).
- Originally flagged as "unverifiable" because they're absent from `references/extracts/guiding/olaf-sor-seed-data-2026-10-08.md` and `context/decisions.md` — but `loadData.sql` is the authoritative source and confirms them. The gap is that the markdown seed-data extract is incomplete/stale relative to the actual SQL load script, not that the guide's fixtures are wrong.
- No guide or solution fix needed. Follow-up: update the seed-data extract doc (see below) so future audits don't have to fall back to `loadData.sql` directly.

## 3. Lab Complete section — bullet count fixed; pointer line not a defect — RESOLVED 2026-10-11

- "What You Built and Learned" bullet list had 8 bullets (one per exercise) vs. the convention's mandated 3-5 bullet range. Fixed: consolidated to 5 bullets covering the same ground (`Lab Guide - Lab 2 - workflow-billing.md`, "### What You Built and Learned").
- Originally also flagged for "missing the mandated Continue to Lab 3 follow-on pointer." That framing was wrong. Lab 2 and Lab 3 are not sequenced relative to each other — both are "Agentic Workflow" labs (Billing Dispute vs. Document Processing) that a participant can complete in either order, unlike the strictly sequential Intro → 1.0 → 1.1 → 1.2 → 1.3 → 2 chain, where each guide's Lab Complete section does say "Continue to **[next lab]**...".
- The guide's existing closing line ("Also consider exploring **Lab 3 — Agentic Workflow: Document Processing**...") was deliberately authored in an earlier session, at the owner's request, to present Lab 3 by its differing focus (document processing) rather than as Lab 2's successor. Left unchanged — not a defect.
- `context/decisions.md` updated (2026-10-11) to record Lab 2/Lab 3's non-sequential relationship, so the convention's "Continue to [next lab]" clause isn't mis-applied to this pair in a future audit pass.

## 4. "If You Are Starting Here" heading never used — NOT A DEFECT 2026-10-11

- Originally flagged because Lab 2 uses a paraphrased lead-in ("If you need to set up your billing tools," line 142) instead of Lab 1.0/1.1's literal `#### If You Are Starting Here` heading, repeated per exercise.
- That heading pattern exists for labs where exercises are independently resumable. Lab 2 is explicitly not that shape: `Lab Guide - Lab 2 - workflow-billing.md:136` — "Complete this lab start to finish... start at Exercise 1 and work through the exercises in order."
- Lab 1.3 hit this exact question first and the owner made a deliberate, recorded departure (`context/decisions.md`, 2026-09-30): single-sequence labs fold the preflight gate into §1.2.2 as a bold lead-in + branch ("if you completed the prior lab, skip" / "if starting here, run the script") instead of the per-exercise heading.
- Lab 2's §1.2.1/§1.2.2 (`Lab Guide - Lab 2 - workflow-billing.md:142,156-192`) already follows that exact pattern almost verbatim — bold lead-in → "If you completed Lab 1.1: ... the script detects and skips" (line 160) → unconditional, idempotent setup steps. It satisfies the actual convention requirement (`specs/lab-design.md:20`, self-contained chapter / preflight gate) in substance.
- No guide fix needed. `context/decisions.md` updated (2026-10-11) to explicitly extend the Lab 1.3 departure to Lab 2, so this isn't re-flagged as a missing heading in a future audit pass.

## 5. All 8 exercises still marked `(TBD)` / `(TBD — Optional)` — DEFERRED 2026-10-11

- Present in both the TOC and exercise headers despite fully written, screenshot-referenced content throughout.
- Document header still says "Status: Draft — authoring in progress" with a ⏱️ TODO callout for testers to fill in timing.
- Decision: intentional, not a defect. Stays open until testers report actual time-to-complete; filling it with an estimated/invented value would be worse than leaving it marked TBD. See `context/decisions.md` (2026-10-11).

## 6. Zero committed automated test cases — WON'T FIX (this cycle) 2026-10-11

- `labs/lab-2/tests/cases/` contains only `.gitkeep` — no test cases, vs. Lab 3's 10.
- `specs/lab-design.md` states every lab should maintain automated test cases for its own solution artifacts.
- Decision: out of time for this pass. Lab 2 ships without automated test coverage for now; the `lab-design.md` rule is knowingly unmet. See `context/decisions.md` (2026-10-11).

## 7. Allen Chan #43 never cited — FIXED 2026-10-11

- Flagged as relevant to Lab 2 in `LAB-GUIDE-CONVENTIONS.md`, but not cited anywhere in the guide.
- Other relevant numbers (#2, #9, #11, #32, #33, #36, #40) are all correctly cited with line numbers.
- Fix applied: added to `Lab Guide - Lab 2 - workflow-billing.md:96`, in the same "Why a Workflow for Billing Disputes?" paragraph as #9 and #2 — the natural third leg of the "why a workflow, not an agent" argument (skills are not a substitute for workflow execution guarantees). Cited as [Allen Chan #43 — The Copilot-as-Autopilot Fallacy](https://achan2013.medium.com/agent-anti-patterns-part-6-257c6b7ff437).

## Positive / compliance findings (no action needed)

- Parking-lot items (fee-waiver, workflow-input-validation gateway) correctly absent from the guide. (The Lab 2 *spec* itself still uses "fee waivers" as a rhetorical example at `LAB-02_billing-dispute-workflow.md:257`, which the guide correctly scrubbed — spec-vs-spec staleness, not a guide defect.)
- Error-handling exercises 7/8 well-grounded against spec and `decisions.md`.
- Generative prompt node verbatim-identical between guide and both solution JSONs.
- All other tool names/thresholds/status values/node names verified matching.
- "Supervisor" terminology correctly disambiguated from Lab 1.3's agent-supervisor pattern (explicit cross-reference at guide line 204).
- ✅ completion blocks present and correctly formatted at the end of every exercise.
- The suspected "dead-end node" in the ex8 workflow JSON (`user_0ba139` "Domain Write Error," no outgoing edge) was investigated and found to be intentional, matching the guide's documented "stop and let the flow implicitly end" pattern — not a defect.
- ~20+ unresolved `[SCREENSHOT NEEDED]` placeholders remain in Exercise 7 (figures 61-93 range) — carried over as a known open item, not newly discovered.
