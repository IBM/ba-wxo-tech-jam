# Lab 3 — Agentic Workflow: External Warranty Claim

Version 1.0.0 / Authors: Sundeep Anne, Madhav Bezawada, Olaf Hahnl / Duration: ~4-5 hours

---

## Notices

This information was developed for products and services offered in the USA. IBM may not offer the products, services, or features discussed in this document in other countries. Consult your local IBM representative for information on the products and services currently available in your area.

INTERNATIONAL BUSINESS MACHINES CORPORATION PROVIDES THIS PUBLICATION "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

This information could include technical inaccuracies or typographical errors. Changes are periodically made to the information herein; these changes will be incorporated in new editions of the publication.

This information contains examples of data and reports used in daily business operations. To illustrate them as completely as possible, the examples include the names of individuals, companies, brands, and products. All of these names are fictitious and any similarity to the names and addresses used by an actual business enterprise is entirely coincidental.

Trademarks: IBM, the IBM logo, and ibm.com are trademarks or registered trademarks of International Business Machines Corp., registered in many jurisdictions worldwide. Other product and service names might be trademarks of IBM or other companies. A current list of IBM trademarks is available at [www.ibm.com/legal/copytrade.shtml](https://www.ibm.com/legal/copytrade.shtml).

© Copyright International Business Machines Corporation 2026. This document may not be reproduced in whole or in part without the prior written permission of IBM. US Government Users Restricted Rights — Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.

---

## Table of Contents

1. [Lab Introduction](#1-lab-introduction)
   - 1.1 [Lab Scenario](#11-lab-scenario)
   - 1.2 [Lab Setup Instructions](#12-lab-setup-instructions)
     - 1.2.1 [Prerequisites](#121-prerequisites)
     - 1.2.2 [Required Setup — Run the Preparation Script](#122-required-setup--run-the-preparation-script)
2. [Lab Instructions](#2-lab-instructions)
   - [Exercise 1: Build the Bare Agentic Workflow](#exercise-1-build-the-bare-agentic-workflow-15-mins) *(~15 mins)*
   - [Exercise 2: Build an AI Agent](#exercise-2-build-an-ai-agent-15-mins) *(~15 mins)*
   - [Exercise 3: Display Payment and Fraud Info from Parallel Tool Calls, with Sensitive Data Masked](#exercise-3-display-payment-and-fraud-info-from-parallel-tool-calls-with-sensitive-data-masked-25-mins) *(~25 mins)*
   - [Exercise 4: Retrieve, Classify, and Extract the Uploaded Document](#exercise-4-retrieve-classify-and-extract-the-uploaded-document-25-mins) *(~25 mins)*
   - [Exercise 5: Identify the Catalog Product and Determine Warranty Duration](#exercise-5-identify-the-catalog-product-and-determine-warranty-duration-25-mins) *(~25 mins)*
   - [Exercise 6: Extracting the Warranty Review Sub-Workflow and Simplifying the Online Caller](#exercise-6-extracting-the-warranty-review-sub-workflow-and-simplifying-the-online-caller-25-30-mins--optional) *(~25-30 mins — Optional)*
   - [Exercise 7: Implementing the Batch Warranty Claim Workflow](#exercise-7-implementing-the-batch-warranty-claim-workflow-25-mins--optional) *(~25 mins — Optional)*
   - [Exercise 8: Architecture Deep Dive — Scheduling Agentic Workflows](#exercise-8-architecture-deep-dive--scheduling-agentic-workflows-15-mins--optional-reading-only) *(~15 mins — Optional, Reading Only)*
3. [Lab Complete](#lab-complete)
4. [Appendix: Full Warranty Discount Decision Table](#appendix-full-warranty-discount-decision-table)

---

## 1. Lab Introduction

This lab demonstrates how to build an enterprise-grade agentic workflow using IBM watsonx Orchestrate that processes external warranty claims. You will combine low-code Canvas UI design with pro-code Python tools to create an intelligent workflow that validates customers, classifies documents using AI, extracts warranty information, applies business rules, and delivers personalized remedies.

The workflow integrates multiple capabilities including System of Record (SOR) lookups, document AI classification and extraction, decision tables, concurrent processing via a Parallel Node, and sensitive data masking.

By combining **Agentic Workflows** (structured, multi-step deterministic orchestration) with **Agents** (conversational AI, intent routing), organizations achieve zero-code business rule updates, human-in-the-loop AI, and seamless handoff between internal and external systems.

### 1.1 Lab Scenario

**Focus Corp** is an electronics manufacturer that sells products through both direct channels and third-party retailers. When customers purchase through external retailers, Focus Corp's internal order database has no record of the transaction.

This lab covers two scenarios built on the same workflow foundation:

---

**Scenario A — Online Warranty Claim (Exercises 1–5, core lab)**

A customer calls the Focus Corp contact center about a product bought from an external reseller. The specialist opens a warranty claim during the call:

1. **No internal order found** — the customer ID search returns no result for the product
2. **External proof required** — the customer must provide a receipt or warranty card
3. **Workflow handles verification in real time:**
   - Fetches payment information and fraud risk concurrently, presenting masked payment details to the specialist
   - Asks the specialist whether the customer is ready to upload now or prefers to receive upload instructions for later
   - If the customer uploads now: retrieves the document, extracts raw text, classifies the document type, and extracts warranty fields using Document AI — pausing for specialist review if confidence is low
   - Resolves the product against the SOR catalog, checks warranty status, and applies business rules via a decision table
   - Presents the outcome: in-warranty resolution options (replace, gift certificate, refund, replace with another model) or an out-of-warranty discount offer

---

**Scenario B — Deferred Upload and Batch Review (Exercises 6–8, optional)**

A customer cannot upload their document during the call. The specialist sends upload instructions and closes the interaction. When the customer uploads later, a scheduled batch workflow picks up all pending claims since the last run and processes them unattended:

1. **Deferred upload** — the online workflow exits cleanly, sending upload instructions to the customer
2. **Batch processing** — a scheduled workflow retrieves all pending warranty documents, iterates over them sequentially, and for each one runs the same document review and warranty determination logic
3. **HITL where needed** — the batch workflow pauses for human review on any document where extraction confidence is low, even though no specialist is present on a live call — the wxO platform persists workflow state at every HITL boundary regardless of how the workflow was triggered
4. **Scheduling architecture** — Exercise 8 explains how the batch workflow can be promoted to a recurring automated schedule in wxO's Live environment, covering platform prerequisites, agent-level configuration, and schedule lifecycle management

---

The solution uses a **Supervisor Agent** pattern where:
- **TRI_orchestrator** (Supervisor) routes customer inquiries
- **TRI_warranty_agent** (Specialist) handles external warranty claims
- **TRI_warranty_claim_workflow** (Agentic Workflow) executes the multi-step process for Scenario A
- **TRI_warranty_batch_workflow** (Agentic Workflow, optional) processes pending claims on a schedule for Scenario B

```text
Scenario A — Online
[Customer Chat] → [Supervisor Agent] → [Warranty Agent] → [Warranty Claim Workflow]
                                                                    ↓
                         [Payment + Fraud] → [Document AI] → [Business Rules] → [Resolution]

Scenario B — Batch (optional)
[Scheduler] → [Batch Workflow] → [foreach: pending claims]
                                          ↓
                         [Document AI] → [Business Rules] → [Resolution]
```

*Figure 1. Lab 3 solution architecture — the Supervisor Agent routes to the Warranty Agent, which invokes the Warranty Claim Workflow (Scenario A, online) or the optional Batch Workflow (Scenario B, scheduled); both converge on the same document-processing, business-rules, and resolution logic.*

### 1.2 Lab Setup Instructions

#### 1.2.1 Prerequisites

**No lab dependency.** This lab has no dependency on any previous lab. You can start it directly without completing any earlier exercises in this event.

**Complete this lab start to finish.** Each exercise builds directly on the workflow state left by the previous one. There is no import shortcut or mid-lab entry point — start at Exercise 1 and work through the exercises in order.

Before starting, ensure you have:

- An active watsonx Orchestrate tenant environment with **Builder** role (permissions to create and edit agents and workflows). If you are attending this event, your facilitator will have confirmed this access.
- Access credentials (IBMid or SSO) and your assigned user ID (e.g. `usr001`).
- A modern web browser (Chrome, Firefox, or Edge — latest version).
- The ADK CLI (version 2.15 or later) installed, connected to the event tenant, and authenticated.
- Your SOR user ID, SOR password, and SOR base URL (needed to run the preparation script in **1.2.2** below). To get these values, see the labs page of the event GitHub repository, section **2. Grab your system of record credentials**.
- The Trinity-Event repository (the event GitHub repository) cloned or downloaded to your machine (needed to run the preparation script in **1.2.2** below). To get it, see the labs page of the event GitHub repository, section **4. Clone this GitHub**.

> 💡 **Tip:** To install, update, or connect the ADK CLI, see **Setup & Event Credentials**, sections **1.1 Before the Event** and **1.2 On Event Day**.

**Namespace prefix convention:** All participants work on a shared wxO tenant. Every artifact you create must be prefixed with your assigned user ID followed by `_TRI_` to avoid naming conflicts (for example: `usr001_TRI_warranty_claim_workflow`). The placeholder `(NAMESPACE)` throughout this lab means your assigned user ID — replace it wherever it appears in instructions, input tables, and step text.

#### 1.2.2 Required Setup — Run the Preparation Script

The artifacts below must be in your namespace before you start Exercise 1. Run the prep script now — it takes about a minute.

**If you completed Lab 1.1:** your Key-Value connection and MCP toolkit already exist. The script detects each one and skips its import — it only refreshes credentials and imports the two Lab 3 Python tools.

1. Refresh your ADK CLI token before running the script. Pass your API key directly to avoid the interactive prompt:

   ```bash
   orchestrate env activate trinity-lab -a (YOUR-API-KEY)
   ```

   > 💡 **Tip:** Don't know where to get your API key? See **Setup & Event Credentials**, section **1.2 On Event Day**, Step 2.

2. Run `prepare_lab_3.py`:

   ```bash
   python3 labs/lab-3/solution/scripts/prepare_lab_3.py --sor-base-url "(YOUR-SOR-BASE-URL)" --sor-user-id (YOUR-SOR-USER-ID) --sor-password (YOUR-SOR-PASSWORD)
   ```

   > **Note:** On Windows, use `python` if `python3` is not available. The script prints a numbered `[INFO]`/`[OK]`/`[SKIP]` line for each step as it runs. If any step fails, re-run the same command once the underlying issue (credentials, connectivity) is resolved — every step is safe to repeat.

3. Confirm both tools appear in the wxO UI: expand the hamburger menu (☰), click **Active inventory** → **Tools**, and search for `(NAMESPACE)_TRI_fetch_baw_pdf` and `(NAMESPACE)_TRI_get_pending_warranty_requests`.

**What the script sets up — artifact reference:**

| Artifact | Type | Role | Source |
|---|---|---|---|
| `(NAMESPACE)_TRI_warranty_claim_workflow` | Workflow | **Built in this lab** | — |
| `(NAMESPACE)_TRI_cp4ba_keyvalue_team` | Connection | Key-Value/team credentials for the MCP toolkit and Python tools | Lab 1.1 or prep script |
| `(NAMESPACE)_TRI_SOR_MCP` | Toolkit (MCP) | Provides the SOR tools used across the lab (customer, catalog, payment, fraud, orders) | Lab 1.1 or prep script |
| `(NAMESPACE)_TRI_fetch_baw_pdf` | Tool (Python) | Fetches the warranty PDF from BAW CRM (Exercise 4) | Prep script |
| `(NAMESPACE)_TRI_get_pending_warranty_requests` | Tool (Python) | Returns pending warranty claim records (Exercise 7) | Prep script |

[↑ Back to Table of Contents](#table-of-contents)

---

## 2. Lab Instructions

### Exercise 1: Build the Bare Agentic Workflow (~15 mins)

In this exercise, you will create the agentic workflow shell — named, described, and with its input schema defined — so it exists as a tool you can attach to the agent in Exercise 2. Starting with Exercise 3, you will add the internal processing logic in stages across the remaining exercises.

#### Steps

1. Log in to the wxO UI, expand the hamburger menu (☰) in the top left, click **Active inventory** under the **BUILD & RUN** category, click **Tools**, then click **All tools**.

   ![All Tools Page](Lab%203%20screenshots/exercise-1/ex1-step1-all-tools.png)
   *Figure 1.1: watsonx Orchestrate All tools page*

2. Click the **Create Tool +** button, then select **Agentic workflow** as the tool type.

   ![Create Workflow Dialog](Lab%203%20screenshots/exercise-1/ex1-step2-create-workflow.png)
   *Figure 1.2: Create agentic workflow dialog*

3. In the **Name your agentic workflow** dialog, enter **Name**: `(NAMESPACE)_TRI_warranty_claim_workflow`, then click **Start building**.

   > **Note:** A pop-up introducing some of the editor's capabilities may appear — you can close it. The agentic workflow editor has no explicit save action; it autosaves your changes.

Like any other tool type, an agentic workflow is only as good as its description — this is the routing contract the agent reads to decide whether to call it at all. It needs the business action, a positive trigger (when to call it), a negative guard (when not to call it), an explicit `Returns:` list, and the inputs it expects.

4. Click the gear icon right of the name of the workflow in the middle of the screen to open the **Flow settings**.

5. On the **General** tab, copy-paste the text below into the **Description** field and check that all four criteria are being met by the description:

```
Initiate the warranty claim document processing workflow for a product not
purchased through the Focus Corp online shop (reseller or external purchase —
no internal order record exists). Call when the specialist's prompt indicates
the product was bought from a reseller, an external shop, or any source other
than Focus Corp, and the customer wants to file a warranty claim.
Required inputs: customer_id [Required], customer_name [Required],
customer_tier [Required], customer_email [Required], customer_phone [Required].
Do NOT call if under_warranty is already present in context for the product —
that means a Focus Corp order record exists; use the knowledge base options
lookup instead.
Returns: nothing — the workflow owns all document collection, extraction, HITL
review, and outcome steps, and presents the warranty outcome directly to the
specialist via its own closing step.
```

6. Configure some additional basic flow settings:
   - Toggle **OFF**: **Scheduling** (we don't need end users to schedule this workflow)
   - Toggle **OFF**: **Agent summarization** (the workflow provides its own completion messages, so the agent is not supposed to summarize the flow execution in addition)
   - Toggle **ON**: **Auto-map chat history to inputs** (enables chat history as a source the flow's per-field "Auto-map" mapping can pull node-input values from — not a separate mechanism)

   ![Edit details](Lab%203%20screenshots/exercise-1/ex1-step3-edit-details.png)
   *Figure 1.3: Flow settings with scheduling and agent summarization disabled, auto-map enabled*

The workflow requires a set of customer information to be passed in by the calling agent. Beyond `customer_id`, the remaining fields avoid making a redundant call back to fetch additional customer information the agent already has in context. These inputs can be defined either through the Start node (the green play icon in the middle of the flow) or through the Flow settings dialog — we'll use the Flow settings dialog, which is still open, first.

7. Click the **Parameters** tab on the left, then click **Add input +** at the top right of the Inputs table. Select the **Data type** of the input to add, then specify the **Name**, **Description**, and whether it is required, before clicking **Add** to add the input definition. Do this five times, once for each input shown below:

   | Property Name | Type | Required | Description |
   |--------------|------|----------|-------------|
   | `customer_id` | String | ✅ Yes | Customer ID in format C-*, e.g. C-3DBZFE |
   | `customer_name` | String | ✅ Yes | Full name of the customer, e.g. Marie Smith |
   | `customer_tier` | String | ✅ Yes | Customer loyalty tier (Platinum, Gold, Silver, Bronze, Standard) |
   | `customer_email` | String | ✅ Yes | Customer's email address on file |
   | `customer_phone` | String | ✅ Yes | Customer's phone number on file |

   ![Add Input Dialog](Lab%203%20screenshots/exercise-1/ex1-step4-add-input-dialog.png)
   *Figure 1.4: Add input dialog on the Parameters tab of the Flow settings*

   > **Note:** Outputs can be defined the same way, using the **Add output +** button in the Outputs table. For now, our workflow will not define any outputs.

8. Close the Flow settings dialog by clicking the **x** in the top right corner

9. Observe that the Start node now shows 5 inputs defined. Click on the Start node to open the dialog where you can see and edit the inputs — the second way to do it.

   ![Flow Input](Lab%203%20screenshots/exercise-1/ex1-step5-flow-input.png)
   *Figure 1.5: Flow input schema with customer profile fields, viewed from the Start node*

> **Going further — Keyboard shortcuts in the workflow builder:**
>
> The canvas supports the following keyboard shortcuts to help you work faster. On Mac, use the **⌘ (Command)** key; on Windows, use the **Ctrl** key.
>
> | Action | Mac | Windows |
> |---|---|---|
> | Copy node(s) | ⌘ + C | Ctrl + C |
> | Cut node(s) | ⌘ + X | Ctrl + X |
> | Paste node(s) | ⌘ + V | Ctrl + V |
> | Undo | ⌘ + Z | Ctrl + Z |
> | Redo | ⌘ + Shift + Z | Ctrl + Shift + Z |
> | Open/close palette | ⌘ + K | Ctrl + K |
>
> **Tip:** Long-press the ⌘ key (Mac) or Ctrl key (Windows) at any time while on the canvas to open the keyboard shortcuts reference window.


> **Going further — Why a workflow instead of an agent?** Before building out the workflow's internal logic in the exercises ahead, it is worth applying the three-question test from [Allen Chan #9 — Agent-Washing](https://achan2013.medium.com/ai-agent-anti-patterns-part-2-tooling-observability-and-scale-traps-in-enterprise-agents-42a451ea84ec): (1) Is tool selection dynamic? (2) Is the path conditional? (3) Is there a feedback loop? For this warranty claim process all three answers are No — the steps are fixed, the branching is deterministic, and there is no iterative reasoning loop. That is exactly the definition of a workflow, not an agent. Encoding this logic inside agent instructions instead (pattern [Allen Chan #2 — The Agent-as-Business-Process Fallacy](https://achan2013.medium.com/ai-agent-anti-patterns-part-1-architectural-pitfalls-that-break-enterprise-agents-before-they-32d211dded43)) would make the outcome probabilistic and non-auditable — an agent might approximate the right steps on a good run but cannot guarantee them. ADK Docs: [`agents/agent_design/agentic_workflow_decision_guide`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/agentic_workflow_decision_guide) · [`agents/agent_design/tooling_scalability`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/tooling_scalability) · [`agents/agent_design/foundational_architecture`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/foundational_architecture)

---

✅ Exercise 1 complete. You created the `(NAMESPACE)_TRI_warranty_claim_workflow` shell — named, described, with scheduling and agent summarization disabled, auto-map chat history enabled, 5 required input fields, and a bare Start → End flow ready to be attached as a tool. In Exercise 2, you will build the AI agent and attach this workflow to it; you'll come back to it in Exercise 3 to build out its internal logic.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 2: Build an AI Agent (~15 mins)

The only way to test an agentic workflow is to embed it into an agent and trigger it from there — the Flow builder itself has no standalone way to run a full conversational test. In this exercise, you will create that agent, starting from the workflow shell you built in Exercise 1.

#### Steps

#### Build the Agent

1. In the Flow builder, click the **Preview** button in the top right corner. Read the popup — it confirms what was just stated above, that the workflow needs to be embedded in an agent to be tested — then click **Go to build agents and tools**. This opens the **Build agent and tools** page in a new window/tab, keeping the Flow builder open.

   > **Note:** If you have already closed the workflow, you can either open it again from **Active inventory** → **Tools**, or navigate directly to agent building via the hamburger menu (☰) → **Active inventory** → **Agents**.

    ![Preview Build Agent Popup](Lab%203%20screenshots/exercise-2/ex2-step1-preview-agent-popup.png)
    *Figure 2.1: Preview popup with the "Go to build agents and tools" button*

2. Click **Create agent +**, then select **Create from scratch** under **Other ways to start**.

   ![Create Agent](Lab%203%20screenshots/exercise-2/ex2-step2-create-agent.png)
   *Figure 2.2: Create new agent*

To speed up testing in this lab, you will invoke this agent directly rather than through a supervisor agent, as the real Trinity solution does — see **Lab 1.3** for the supervisor/collaborator pattern.

In the full solution, this agent handles warranty claims for products bought both through Focus Corp's online shop and externally. Its description below, while not actually used here (you're calling the agent directly, so no supervisor ever reads it to decide whether to delegate), covers both use cases for completeness.

Its instructions, however, are tailored to testing the workflow using this agent on its own: the second paragraph below — calling `TSOR_CRM_get_customer_by_id` to resolve `customer_name` and `customer_tier` when only `customer_id` is provided — was added compared to the real solution agent, specifically so this agent can resolve that customer information itself. The real agent's instructions in the Trinity solution omit that paragraph: they assume this agent acts as a collaborator agent, so the calling supervisor is expected to have already supplied the full customer context.

3. In the **Profile** section on the **Behavior** tab, configure:
   - **Agent name**: `(NAMESPACE)_TRI_warranty_agent`
   - **Model**: Keep default (GPT-OSS 120B — OpenAI via Groq)
   - **Description**:
   ```
   Call when a specialist needs to initiate a warranty claim for a product not
   purchased through Focus Corp, or needs warranty resolution options for a product
   issue.

   Two capabilities:

   (1) Document processing workflow: for products not purchased through Focus Corp
      (reseller / external purchase) — provide customer_id, customer_name,
      customer_tier [all Required], customer_email, customer_phone when available.

   (2) KB options lookup: use only when under_warranty [Required] (true or false) is
      already known from an order item returned for the product; if under_warranty
      is false also provide status [Required] (Standard, Gold, or Platinum) from the
      customer profile — returns the applicable resolution options as a list. A
      product with no order item has no known warranty status: use capability (1),
      not this path — a missing order does not mean out of warranty.
   ```
   - **Instructions**:
   ```
   Warranty worker agent with two capabilities: document processing workflow and KB
   options lookup.

   Before invoking the document processing workflow: if customer_name or customer_tier
   are not already provided in the delegation, call (NAMESPACE)_TRI_SOR_MCP:TSOR_CRM_get_customer_by_id with
   the customer_id first to retrieve them. Pass customer_id, customer_name (first_name
   + last_name), customer_tier (status field), customer_email (email field), and
   customer_phone (phone field) to the workflow.

   When the delegation includes an under_warranty value (true = in warranty, false =
   out of warranty): query the knowledge base using "in-warranty resolution options"
   when true, or "out-of-warranty resolution options" when false. Present the
   retrieved options exactly as returned — same wording, same order, nothing added.
   Stop after the last option. If the knowledge base does not contain relevant
   information, respond: "I don't have information about that in my knowledge base."
   ```

   > **Note:** The **Instructions** text above was copy-pasted as-is and still contains the literal `(NAMESPACE)` placeholder in its `(NAMESPACE)_TRI_SOR_MCP:TSOR_CRM_get_customer_by_id` tool reference. Replace `(NAMESPACE)` with your assigned user ID in the **Instructions** field before continuing — the tool reference must match the actual namespaced toolkit, or the agent won't resolve it.

   ![Configure Agent](Lab%203%20screenshots/exercise-2/ex2-step3-configure-agent.png)
   *Figure 2.3: Configure agent behaviors*

4. Select the **Tools** tab, click **Add Tool +**, then under **Add from**, select **Local instance**.

   ![Add Tool Dialog](Lab%203%20screenshots/exercise-2/ex2-step5a-add-tool-dialog.png)
   *Figure 2.5a: Select Local instance to add tools*

5. Enter `(NAMESPACE)_TRI_warranty_claim_workflow` in the search field to filter the tool list down, then select the workflow you just created. Next, enter `(NAMESPACE)_TRI_SOR_MCP:TSOR_CRM_get_customer_by_id` in the search field and select this second tool. Once both tools are selected, click **Add to agent**.

   ![Select Local Tools](Lab%203%20screenshots/exercise-2/ex2-step5b-select-tools.png)
   *Figure 2.5b: Select workflow and customer lookup tool*

   > **Note:** `TSOR_CRM_get_customer_by_id` was just added as the other side of the instruction paragraph that resolves customer information directly, making this agent self-contained for testing on its own. In the real Trinity solution, this agent does not have that tool — the CRM collaborator agent fulfills that role instead.

#### Test the Agent

6. In the **Draft Preview** chat window, enter the prompt:
   ```
   Customer C-3DBZFE has a headset they bought from a reseller — it stopped working and they want warranty.
   ```

7. Click **Show reasoning** next to the agent's response, then expand step 1 — the call that resolves the customer information — and step 2 — the invocation of the workflow.

    ![Draft Preview Chat Step 2 Reasoning](Lab%203%20screenshots/exercise-2/ex2-step7-draft-preview-chat-reasoning.png)
   *Figure 2.6: Reasoning trace with step 2 (workflow invocation) expanded, showing its input and response*

8. Click the three stacked dots (⋮) on the Workflow tool tile, then select **Open flow inspector**.
    ![Open Flow Inspector](Lab%203%20screenshots/exercise-2/ex2-step8-open-flow-inspector.png)

    *Figure 2.7: Workflow tool tile menu with "Open flow inspector" selected*

   The Flow inspector dialog shows a list of flows in the center with filter options on the left. It should show the `(NAMESPACE)_TRI_warranty_claim_workflow` flow that was just started, with a Flow run state of **Completed**.

   > **Going further — Flow inspector capabilities:** When you select a node on the canvas during design, the Flow Inspector panel displays that node's properties, input/output schema, variable mappings, and configuration settings. You can edit these directly in the inspector without opening separate dialogs. During runtime debugging, the inspector shows execution traces, variable values at each step, error messages, and the complete execution timeline — making it essential for both building and troubleshooting workflows throughout this lab.

9. Click the **View details** link in the rightmost column to see the flow details, which open in a new tab/window.

   Since this workflow currently only has a Start and End node, the flow events listed on the left show only these two.
    ![View Flow Instance Details](Lab%203%20screenshots/exercise-2/ex2-step9-flow-instance-details.png)
    *Figure 2.8: Flow instance details with the Flow events tab open*

10. Click **Flow parameters** and observe the 5 inputs you specified as mandatory for the workflow, plus an implicit sixth input, `wxo_system_context`.

11. Close this new tab/window showing the flow instance details.

---

✅ Exercise 2 complete. You created `(NAMESPACE)_TRI_warranty_agent` in draft mode, equipped it with the workflow shell from Exercise 1 and `TSOR_CRM_get_customer_by_id`, and used the reasoning trace and Flow inspector to confirm a test prompt actually invoked the workflow end to end. In Exercise 3, you will add the first piece of that workflow's internal logic: a parallel node that calls the payment and fraud risk tools, and a user activity that displays the results with sensitive data masked.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 3: Display Payment and Fraud Info from Parallel Tool Calls, with Sensitive Data Masked (~25 mins)

This exercise introduces the two constructs you'll build with for the rest of this workflow.

A **user activity** is the central construct an agentic workflow uses to interact with a human, mid-flow, directly inside the chat interface — it can both display information to that person and collect information from them. This workflow is invoked from two different use cases: an online one, where the user activity talks to the specialist who initiated the claim, and a batch one, where it's routed to a different, named user instead — you'll build that second use case in a later exercise. In this exercise, you'll configure the user activity with the flow initiator assignment and use it only to display information, not collect it.

One of the fields you'll display is a payment card number. The agentic workflow runtime has native support for masking sensitive data like this so the full value is never exposed — you'll turn that on as part of this exercise.

The second construct is the **Call a tool node**, the way a workflow talks to the systems around it rather than to a human. You'll add two of them here: one to retrieve payment info, one to determine fraud risk.

> ⚠️ **Important: Node display names must match exactly as specified in this lab.** Logic blocks reference nodes by their display names in Python code, and Message controls do the same through `{flow[...]}` variable references in their Output message (e.g., `flow["Review customer & choose upload timing"]["Capture Payment info & Fraud Risk"]`). If you use different display names, the workflow will fail at runtime with errors like "KeyError" or "node not found," or a Message control will simply fail to resolve its variable. Use the exact display names provided in each step — preserve capitalization, spacing, and punctuation exactly, and copy-paste from this guide rather than retyping where possible. If you do make a naming mistake, you must either rename the node to match the lab instructions, or update all Python code and Message control references to use your custom name.

#### Steps

#### Build the Payment & Fraud Review Segment

There are usually two ways to add an activity to the flow: drag it from the palette — opened by clicking the blue plus sign on the left of the canvas — onto the correct place within the flow, or click one of the plus signs that appear when you hover over a line within the flow itself.

**Adding the User Activity**

1. Click the **blue plus sign** on the top-left of the canvas to open the **Flow nodes, Tools, Agent** palette
2. Locate the **User activity** tile in the **Flow activities** section of the palette
3. Drag-and-drop it onto the canvas between the **Start** node and the flow edge
4. Configure the user activity:
   - Click the green ellipsis with the stylized user icon on the node to open its properties pane on the right
   - Set both **Label** and **Node name** to: `Handle Warranty Claim`
   - Note the **Assign to** field, defaulted to **Flow initiator** — keep this default

   > **Note:** Hovering over the user activity also shows a pencil icon, but that only lets you edit the **Node name**, not the **Label** — use the properties pane instead so both fields are set.

   ![User Activity Container](Lab%203%20screenshots/exercise-3/ex3-step4-user-activity.png)
   *Figure 3.1: User activity container for warranty claim workflow*

> **Going further — One user activity, or several?** A User Activity node scopes all HITL (Human-in-the-Loop) steps to a single assignable unit, shown to one user under one assignment policy. In this workflow, the whole flow only ever interacts with a single user — the specialist — so we put all of its steps inside this one User Activity. Splitting it into multiple User Activities every time we need to interact with the user would only clutter the canvas, with no added benefit. Separate User Activities make sense — and become necessary — once different steps need different labels, or once a different person needs to get involved.

Invoking tools can take a considerable amount of time. We address this on two fronts: we optimize how long it takes to perform the tool calls until the next interaction with the user happens — that's what the parallel activity you'll add shortly is for — and we keep the user informed about what's going on by printing progress to the chat.

**Adding a Present to User Message**

5. Click the **Add +** button within the User activity. Select **Present to user** → **Message**.
6. Click the **pencil icon** above the node shape and specify `Progress - Payment info & fraud risk` as the node name.
7. Set the **Agent message** in the properties pane to: `Fetching payment info and fraud risk status in progress...`

   Besides static text like this, the message editor also lets you insert dynamic text by adding variables via the **{x}** icon — you'll make use of this shortly.

   ![Progress Indicator](Lab%203%20screenshots/exercise-3/ex3-step7-progress.png)
   *Figure 3.2: Progress indicator message*

> **Going further — Two ways to inform the user:** There are two options for showing information to the user. **Present to user** outputs the text directly to the chat, and the flow continues right away without waiting. **Add a form** also offers several Present-to-user types, but wraps the chosen one in a form that must be confirmed with a button click before the flow continues — pausing execution until the user responds. You'll experience the form-based option later in this exercise.

**Adding the Parallel Flow Control**

The two tool calls you're about to add — fetching payment info and assessing fraud risk — are independent of each other, so they can be invoked in parallel instead of one after the other, reducing the overall elapsed time to retrieve the information. In production workflows every second counts: sequential calls would take 4-6 seconds total (2-3 seconds each), while parallel execution completes in just 2-3 seconds — a 50% reduction that improves both customer satisfaction and specialist productivity.

8. Click the **+** button below the progress message node you just added
9. Select **Add a flow control** → **Parallel**
10. Configure the parallel node:
    - Set the name by clicking the pencil icon next to the default name and enter `Parallel Pre-Check - Payment + Fraud`
    - Keep the setting **Execution** at the default **Unconditional**, but observe that the execution of the parallel paths can also be restricted by specifying conditions after changing the value to **Conditional**
    - Delete the third unused default path by clicking the three stacked dots on **Path 3** and click **Delete**

    > **Note:** You could also set the path names or reorder the paths, but that's not required here.

    ![Parallel Node Configuration](Lab%203%20screenshots/exercise-3/ex3-step11-parallel-config.png)
    *Figure 3.3: Parallel node configuration with 2 default paths*

**Adding Tool Calls**

In agentic workflows, tool calls have inputs for which different mapping options exist — Auto-map, Explicit mapping, or an expression — with Auto-map applied by the flow engine by default. Outputs, however, are not explicitly mapped to variables: any activity that follows a tool call can access its outputs implicitly, without any additional mapping step.

**Path 1: Invoke Tool to Get Payment Info**

11. In the parallel node, click **Add +** in Path 1
12. Select **Call a tool**, which switches the palette to the **Tools** tab
13. Enter `(NAMESPACE)_TRI_SOR_MCP:TSOR_CRM_get_customer_payment_info_by_customer_id` in the **Search for tools** search field

    ![Tool Search](Lab%203%20screenshots/exercise-3/ex3-step14-branch1-tool-search.png)
    *Figure 3.4: Tools tab in the palette after selecting Call a tool*

14. Drag and drop the `(NAMESPACE)_TRI_SOR_MCP:TSOR_CRM_get_customer_payment_info_by_customer_id` tool onto Path 1
15. Click the tool call node, then click the pencil icon next to the default name and replace it with `Fetch Payment Info`
16. Click the `(NAMESPACE)_TRI_SOR_MCP:TSOR_CRM_get_customer_payment_info_by_customer_id` link in the middle of the dialog to see the tool's inputs and outputs, then click the **×** in the top-right corner to close the details page
17. Click **Edit data mapping**, hover over the **customer_id** input variable, click the **{x}** variable icon, click **Input** on the left side of the picker, and select the **customer_id** flow input. Finally, click the **×** in the top-right corner to close the picker.

    ![Data Mapping](Lab%203%20screenshots/exercise-3/ex3-branch1-data-mapping.png)
    *Figure 3.5: Mapping the customer_id input for the payment info tool call*

> **Going further — Auto-map vs. explicit mapping:** Since the tool's expected input is also called `customer_id`, and that's the exact same name as the flow input, keeping **Auto-map** on would have worked just as well here. Whether to auto-map or map explicitly in a case like this is a matter of choice. When the naming doesn't line up as cleanly, explicit mapping becomes the better option. A mismatch in data types when the names do match is actually a good use case for auto-map, since it performs the type conversion automatically — something explicit mapping cannot do.

**Path 2: Invoke Tool to Assess Fraud Risk**

18. Enter `(NAMESPACE)_TRI_SOR_MCP:TSOR_CRM_evaluate_fraud_risk` in the **Search for tools** search field on the **Tools** tab of the palette
19. Drag and drop the `(NAMESPACE)_TRI_SOR_MCP:TSOR_CRM_evaluate_fraud_risk` tool onto Path 2
20. Click the tool call node, then click the pencil icon next to the default name and replace it with `Assess Fraud Risk`

The evaluate fraud risk tool expects the `customer_id` and an amount for which to assess the fraud risk. At this point there is no specific amount yet, just a general fraud risk to be checked. As described by the tool's description, in this case the amount should be set to `-1`.

21. Click **Edit data mapping**. For **amount**, hover over the input row, click the **</>** icon (the second icon from the right), click into the field showing the **Enter expression** placeholder, and enter `float(-1)` to set the expected value of -1. For **customer_id**, hover over the input variable, click the **{x}** variable icon, click **Input** on the left side of the picker, and select the **customer_id** flow input. Finally, click the **×** in the top-right corner to close the picker.

    ![Data Mapping](Lab%203%20screenshots/exercise-3/ex3-branch2-data-mapping.png)
    *Figure 3.6: Expression mapping for customer_id in Branch 2*

Your parallel activity should look like this:

![Parallel Node](Lab%203%20screenshots/exercise-3/ex3-step22-parallel-node.png)

*Figure 3.7: Parallel node for concurrent payment and fraud validation*

**Masking Sensitive Data (card_number and paypal_username)**

Production solutions often contain sensitive data that should not be displayed to users or administrators unmasked. Agentic workflows in wxO have a built-in feature to declare String and Number inputs, flow control outputs, or flow variables as sensitive, defining masking patterns for them. Four different masking behaviors exist: Fully mask, Mask first 4 characters, Mask last 4 characters, and Mask using regex — regex being the most flexible one, with the other three self-explanatory. Regex uses two expressions: the first (Find) needs to create at least two capture groups `()` that split the input string into its components; the second (Replace) can then contain arbitrary output that references one or multiple of the capture groups defined in Find using the `$n` syntax, where `n` is the number of the capture group to include in the output. For example, the credit card number consists of four four-digit groups separated by `-`; in the masked output, the first twelve digits are presented statically as `XXXX`, while the last four digits are taken from the original input.

Masking is enforced only at the display layer: Call a tool, Decision, and Logic block nodes all have access to the actual, unmasked value of the variable, while the wxO runtime ensures that display-related controls — such as the Message control or the Flow Inspector — only show the masked data. You'll see this distinction in action in the **Test the Payment & Fraud Review Segment** section below.

> **Going further — Why mask via Flow Settings instead of in code?** Masking configured here is enforced at the workflow engine level — the raw value is never exposed in HITL forms, execution traces, agent responses, or the Flow Inspector, regardless of which node reads the field. Masking a value yourself inside a Logic block's Python code, by contrast, only hides it from whatever you explicitly format — the raw value still appears in execution logs and variable inspectors, and potentially in LLM context, before your code ever runs. Engine-level masking provides a defense-in-depth that code-level masking can't.

22. Click the gear icon right of the name of the workflow in the middle of the screen to open the **Flow settings**
23. Click **Sensitive data** on the left
24. Select **Fetch Payment Info** within **Handle Warranty Claim** → **Parallel Pre-Check - Payment + Fraud**
25. Flip the toggle for both variables, `payment_info.card_number` and `payment_info.paypal_username`, in front of the respective name
26. Click the pencil icon at the end of each row and specify:

    | Variable | Masking behavior | Find | Replace |
    |----------|-------------------|------|---------|
    | `payment_info.card_number` | Mask using regex | `(\d{4})-(\d{4})-(\d{4})-(\d{4})` | `XXXX-XXXX-XXXX-$4` |
    | `payment_info.paypal_username` | Mask using regex | `^(.*)(.{4})(@.*)$` | `$1xxxx$3` |

    Leave all other settings as is.

    ![Sensitive Data Masking Configuration](Lab%203%20screenshots/exercise-3/ex3-step27-sensitive-data-masking.png)
    *Figure 3.8: Regex masking configuration for card_number and paypal_username*

27. Close the **Flow settings** by clicking the **x** in the top right corner

**Adding a Form for the Specialist to Review Data and Decide Next Steps**

Now is the time to show the specialist some information about the customer and ask them to decide what the next step is — either uploading the warranty document now or later. This is where a form comes into play, which requires a user to review information and take some action. As part of that, we explore dynamic output, output formatting, and how to use the buttons to proceed.

28. Click the **+** sign that appears when hovering over the line outside of the Parallel node but within the User Activity
29. Select **Add a form**
30. Put `CUSTOMER DETAILS & UPLOAD READINESS` into both the **Form Title** and the **Node name**

Forms in agentic workflow can have a cancel button and one or more action buttons. Like in HTML forms, the cancel button will not submit the data entered in any form fields that may exist, while the action buttons do. Nevertheless, both the cancel and the action buttons have individual navigation paths. In the current UI implementation of the wxO chat, the cancel button is shown on the left when enabled (or the space on the left remains empty when the cancel button is disabled), while the first action button is shown as the right button. When more than one action button is defined, the additional action buttons are not directly displayed and are only accessible via a twisty on the first action button. To improve the usability and look-and-feel of the solution, we are using the renamed cancel button for navigating the Upload Later path — something we can do here since this form has no fields whose data needs to be submitted on either path — while the single action button will be used later to navigate the Upload Now path.

31. Rename the **Primary action** button to `Upload Now`
32. Rename the **Cancel** button to `Upload Later`

The goal is to present the retrieved customer data while ensuring only the relevant payment details (Credit Card or PayPal) appear. The form accomplishes this using a 7-control sequence:

- **Hidden trigger message (Control 1):** A Message control can render plain text, HTML, or Markdown. We make use of that here by hiding the actual output — the payment type — inside an HTML comment block, so it's available to conditional visibility rules strictly behind the scenes while staying hidden from display.
- **Unconditional messages (Controls 2 & 7):** Message controls with Markdown tables and instructions shown to all specialists regardless of payment method.
- **Dynamic rules & conditional messages (Controls 3–6):** Two **Visibility** controls that evaluate the trigger and display either the Credit Card message (Control 5) or the PayPal message (Control 6).
- **Dynamic templating:** Combines Markdown tables with dynamic `{flow[...]}` variable expressions.

> **Note:** The snippet blocks to be copied and pasted in the subsequent steps already contain the special syntax representing dynamic variables (`{flow[...]}`) to avoid tedious, repetitive manual variable assembly. However, you are encouraged to click the **Insert variable** icon ({x}) in the editor to see how to browse and select dynamic workflow values directly.

33. Add seven controls sequentially, each one below the previous: the first two as **Present to user** → **Message**, then two as **Dynamic Rules** → **Visibility** (named `Show Credit Card` and `Show Paypal`), then three more **Present to user** → **Message** controls

    > **Note:** Currently, a Visibility control's **Event trigger** and **Conditional fields** pickers only show you the name of each candidate control — and a Message control's name stops showing there as soon as that control has an Output message configured, leaving just its generic position label (`Message 1`, `Message 2`, and so on). That's why it matters to add all five Message controls sequentially, top to bottom, exactly as described above: it keeps them numbered `Message 1` through `Message 5` in order, so you can count down from the top to pick the right one.

    ![Form Controls Added](Lab%203%20screenshots/exercise-3/ex3-step34-form-seven-controls.png)
    *Figure 3.9: Seven controls added to the Customer Details & Upload Readiness form*

34. Click the first control and set the following as its **Output message**:

    ```
    <!--{flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Fetch Payment Info"].output.payment_info.payment_type}-->
    ```

35. Click the second control and set the following as its **Output message**:

    ```
    | Customer Information |   |
    | ---- | ---- |
    | **Name:** |{flow.input.customer_name}|
    | **Tier/Status:** | {flow.input.customer_tier}|
    | **Email:** |{flow.input.customer_email}|
    | **Phone:** |{flow.input.customer_phone}|
    ```

36. Click the third control, set `Show Credit Card` as its **Name**, select **Message 1** as the **Event trigger**, and select **Message 3** as the **Conditional fields**. Hover over Message 3 in the **Selected conditional fields** section and click **Add rule** at the right of the row. In the **If** row, select **== (is equal to)** in the dropdown and put `<!--Credit Card-->` into the field after it. Click **Save** to close.
37. Click the fourth control, set `Show Paypal` as its **Name**, and repeat the previous step, selecting **Message 4** as the **Conditional fields** and specifying `<!--Paypal-->` in the conditional rule.
38. Click the fifth control (Message 3) and set the following as its **Output message**:

    ```
    | Customer Financial Information |   |
    | ---- | ---- |
    | **Payment type:** |{flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Fetch Payment Info"].output.payment_info.payment_type} ({flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Fetch Payment Info"].output.payment_info.card_number})|
    | **Fraud risk info:** |{flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Assess Fraud Risk"].output.fraud_risk_assessment.risk_level} (Score: {flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Assess Fraud Risk"].output.fraud_risk_assessment.risk_score}/100, {flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Assess Fraud Risk"].output.fraud_risk_assessment.prior_disputes_count} prior claims)|
    | **Fraud risk summary:** |{flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Assess Fraud Risk"].output.fraud_risk_assessment.risk_summary}|
    ```

39. Click the sixth control (Message 4) and set the following as its **Output message**:

    ```
    | Customer Financial Information |   |
    | ---- | ---- |
    | **Payment type:** |{flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Fetch Payment Info"].output.payment_info.payment_type} ({flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Fetch Payment Info"].output.payment_info.paypal_username})|
    | **Fraud risk info:** |{flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Assess Fraud Risk"].output.fraud_risk_assessment.risk_level} (Score: {flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Assess Fraud Risk"].output.fraud_risk_assessment.risk_score}/100, {flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Assess Fraud Risk"].output.fraud_risk_assessment.prior_disputes_count} prior claims)|
    | **Fraud risk summary:** |{flow["Handle Warranty Claim"]["Parallel Pre-Check - Payment + Fraud"]["Assess Fraud Risk"].output.fraud_risk_assessment.risk_summary}|
    ```

    > **Note:** The only difference between step 38 and step 39 is that step 38 outputs `card_number` while step 39 outputs `paypal_username` — all other fields and formatting in the message are identical.

40. Click the seventh control (Message 5) and set the following as its **Output message**:

    ```
    **Actions:**
    1. Please **confirm** the customer's email address, phone number, and payment information on file.
    2. **Check** the fraud risk assessment.
    3. **Ask** the customer if they have their receipt or warranty card ready to upload now, or if they prefer to receive instructions to upload it later.
    ```

    ![Form Final Output](Lab%203%20screenshots/exercise-3/ex3-step41-form-final-output.png)
    *Figure 3.10: Final output of the Customer Details & Upload Readiness form*

41. Click the **x** in the top right corner to close the form editor

**Adding the Upload Later Path Message**

42. Hover over the **Upload Later** output pill on the form node, click the connection point, and drag a connection line to the **End** node within the user activity
43. Click the **+** icon that appears when hovering over this new connection line and select **Present to user** → **Message**

    > **Tip:** After adding nodes the canvas can look cluttered. Click the middle icon — **Tidy canvas** — in the top-left toolbar (next to the flow variables icon) to automatically re-arrange the remaining nodes into a clean layout.

44. Click the **pencil icon** above the node shape and specify `INSTRUCTIONS FOR FUTURE UPLOAD SENT` as the node name
45. In the message configuration pane on the right, enter the following in the **Agent message** field of the Message control:

    ```
    Instructions for uploading the document later have been sent to {flow.input.customer_email}.

    **Actions:**
    1. **Inform** the customer that once they upload their receipt or warranty card, Customer Support will review it and reach out with next steps.
    2. Thank the customer for calling Focus Corp and ask if there are any other topics they would like to discuss today.
    ```

**Adding a Gateway Form to Wait for the Customer's Upload**

This section doesn't introduce any new building blocks — it reuses the same form and messaging patterns from the steps above. Its purpose is simply to add a second graceful exit path: even after choosing to upload now, the customer may run into trouble actually doing so — for example, they have trouble capturing and uploading the document from their mobile phone, or they can't locate the receipt or warranty card at all. Both are realistic situations, and workflows need to anticipate them upfront and design for them accordingly, rather than leaving the specialist stuck waiting in the chat on a document that may never arrive. `Deferred Document Upload` lets the specialist fall back to the same future-upload outcome as the `Upload Later` path. This is a general design principle, not just a one-off accommodation: real conversations are unpredictable, and production agentic workflows need multiple graceful exits to stay robust without forcing the conversation into rigid patterns.

46. Click the **+** icon that appears when hovering over the connection line coming from the **Upload Now** output pill on the form node and select **Add a form**
47. Put `Wait for customer upload confirmation` into both the **Form Title** and the **Node name**
48. Rename the **Primary action** button to `Document Uploaded`
49. Rename the **Cancel** button to `Deferred Document Upload`
50. Add a single **Present to user** → **Message** control
51. Set the following as its **Output message**:

    ```
    Upload instructions have been sent to {flow.input.customer_email}.

    **Actions:**
    - **Ask** the customer to check their email and upload the receipt or warranty card now.
    - Once document **upload confirmed**, click **Document Uploaded** to start document processing.
    - In case document **cannot be uploaded**, click **Deferred Document Upload**.
    ```

52. Click the **x** in the top right corner to close the form editor
53. Hover over the **Deferred Document Upload** output pill on the form node, click the connection point, and drag a connection line to the **End** node within the user activity
54. Click the **+** icon that appears when hovering over this new connection line and select **Present to user** → **Message**
55. Click the **pencil icon** next to the default name and specify `REMINDER FOR FUTURE UPLOAD` as the node name
56. In the message configuration pane on the right, enter the following in the **Agent message** field of the Message control:

    ```
    **Actions:**
    1. **Remind** the customer that they can upload their receipt or warranty card at any time using the link that was sent to {flow.input.customer_email}.
    2. **Let them know** that once the document is received, Customer Support will review it and follow up with the warranty outcome.
    3. Thank the customer for calling Focus Corp and ask if there are any other topics they would like to discuss today.
    ```

    ![Exercise 3 Completed Flow](Lab%203%20screenshots/exercise-3/ex3-step58-exercise-3-completed-flow.png)
    *Figure 3.11: Completed workflow structure for Exercise 3 with Upload Later path*

#### Test the Payment & Fraud Review Segment

To exercise the masking and visibility rules you just configured, you'll run the workflow twice with two different customers who have different payment methods on file — one with a credit card, one with PayPal. Comparing the two runs demonstrates both the `Show Credit Card` / `Show Paypal` visibility rules branching correctly, and how the Flow inspector displays masked sensitive data in each case.

1. Switch to the tab/window with the `(NAMESPACE)_TRI_warranty_agent` open — keep the Flow builder tab/window open as well, since you'll switch back to it later.
2. Click the **Reset chat** icon in the top right of **Draft Preview** to start a fresh conversation, then enter the prompt:
    ```
    Customer C-3DBZFE has a headset they bought from a reseller — it stopped working and they want warranty.
    ```
3. Observe the `Fetching payment info and fraud risk status in progress...` message, confirming the payment info and fraud risk tools are being invoked.
4. Once both tool calls complete, the form shows the collected customer data — for this customer, a masked credit card number and no mention of a PayPal username. Both the `Show Credit Card` and `Show Paypal` visibility rules are in action here: the Credit Card Message output is visible, while the Paypal Message output stays hidden.
5. Notice the two buttons to choose from, as configured in the prior steps.

    ![First Test Run Form](Lab%203%20screenshots/exercise-3/ex3-test-run1-form.png)
    *Figure 3.12: Customer Details & Upload Readiness form for customer C-3DBZFE, showing a masked credit card and no PayPal information*

6. For this test, click the **Upload Later** (cancel) button.
7. Observe the graceful completion of this exit path via the closing message shown to the specialist.

    ![First Test Run Completion](Lab%203%20screenshots/exercise-3/ex3-test-run1-completion.png)
    *Figure 3.13: Closing message for the Upload Later exit path*

8. Click the three stacked dots (⋮) on the Workflow tool tile, then select **Open flow inspector**.
9. Click the **View details** link for the latest flow instance, which should show a Flow run status of **Completed**.
10. Click the **Fetch Payment Info** step on the left-hand side of the Flow Events tab.
11. Note the `payment_info.card_number` and `payment_info.paypal_username` output parameters: the variable name shows a shield icon to indicate it contains sensitive data, and the **Current value** only shows the masked value.

    > **Note:** At this point, notice that a variable containing no data (empty) is also shown as masked — here, `paypal_username`.

    ![Flow Details - Sensitive Data Step](Lab%203%20screenshots/exercise-3/ex3-test-run1-flow-details.png)
    *Figure 3.14: Flow Events detail for the Fetch Payment Info step, showing masked card_number and paypal_username outputs*

12. Close the details for this flow instance by closing the tab/window that opened.
13. Close the Flow inspector view by clicking the **x** in the top right corner.
14. In the **Draft Preview** chat window, enter the prompt:
    ```
    Customer C-11100 has a headset they bought from a reseller — it stopped working and they want warranty.
    ```
15. Observe that the output now shows the data for this other customer — notice the masked PayPal username is shown, and no credit card information appears, since this customer has a PayPal profile on file.
16. Click the **Upload Now** button and observe that the `Wait for customer upload confirmation` form appears directly afterward — this is the gateway form that holds the specialist here in the chat until the customer finishes the upload.

    ![Second Test Run Gateway Form](Lab%203%20screenshots/exercise-3/ex3-test-run2-gateway-form.png)
    *Figure 3.15: Wait for customer upload confirmation form shown after choosing Upload Now for customer C-11100*

17. For this test, click the **Deferred Document Upload** (cancel) button — the second early exit path — since the **Document Uploaded** path isn't implemented yet; that's what you'll build in the next exercise.
18. Observe the graceful completion of this exit path via the closing message shown to the specialist.

    ![Second Test Run Completion](Lab%203%20screenshots/exercise-3/ex3-test-run2-completion.png)
    *Figure 3.16: Closing message after choosing Deferred Document Upload for customer C-11100*

19. Optionally, open the Flow inspector and the flow instance details again, focusing on the **Fetch Payment Info** step. Notice the masking is reversed from the first run: `payment_info.paypal_username` now shows real, masked content, while `payment_info.card_number` shows as masked `***`, since that field is empty for this customer.

    ![Second Test Run Flow Details](Lab%203%20screenshots/exercise-3/ex3-test-run2-flow-details.png)
    *Figure 3.17: Flow Events detail for the Fetch Payment Info step on the second run, showing masked paypal_username and empty card_number*

---

✅ Exercise 3 complete. You built the parallel payment and fraud-risk segment, configured regex masking on `card_number` and `paypal_username`, and created a `CUSTOMER DETAILS & UPLOAD READINESS` form with conditional payment visibility and an `Upload Now` / `Upload Later` choice — including a second gateway form with its own `Deferred Document Upload` exit. In Exercise 4, you will implement the `Document Uploaded` path: retrieving the uploaded document, classifying it, and extracting its fields with a human-in-the-loop review gate.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 4: Retrieve, Classify, and Extract the Uploaded Document (~25 mins)

This exercise implements the `Document Uploaded` path left stubbed out in Exercise 3. Once the specialist confirms the customer has uploaded their receipt or warranty card, the workflow takes over: it retrieves the document, pulls its raw text, determines whether it's a receipt or a warranty card, pulls the fields relevant to that document type, and — if the extraction isn't confident enough — pauses for the specialist to review and correct the values before continuing. Along the way you'll build all three of wxO's document AI node types on the same document — Text Extractor, Document Classifier, and Document Extractor — each answering a different question about it.

#### Steps

#### Build the Document Classification and Extraction Segment

Unlike Exercise 3, you will not add a progress message before each tool call in this segment — the tool calls run silently, and you only see output when a form or message is explicitly presented.

> **Going further — One node, one job ([Allen Chan #22 — Mixing Extraction with Processing](https://achan2013.medium.com/ai-agent-anti-patterns-part-3-knowledge-document-processing-0caf472856ff)):** This segment uses three separate Document AI nodes — Text Extractor, Document Classifier, and Document Extractor — each answering a different question about the uploaded file. A common mistake is to collapse these into fewer nodes or to post-process extracted values inside the same node that extracts them. [Allen Chan #22 — Mixing Extraction with Processing](https://achan2013.medium.com/ai-agent-anti-patterns-part-3-knowledge-document-processing-0caf472856ff) names exactly this: when a node both extracts and interprets, failures become harder to diagnose and the node can no longer be reused independently. Keep each node focused on a single responsibility. ADK Docs: [`agents/agent_design/knowledge_processing`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/knowledge_processing)

**Retrieve the Uploaded Document**

This step pulls the uploaded document into the workflow as a usable file. Rather than calling the underlying MCP tool directly — which would return the document as a Base64-encoded string large enough to blow up the LLM's execution context — you'll use the Python wrapper tool `(NAMESPACE)_TRI_fetch_baw_pdf`. It fetches the document from the SOR CRM REST API and returns only a lightweight signed file URL, the format Document AI nodes require. For a deeper look at Python tools in general, see **Lab 1.1, Exercise 4**.

1. Click the **+** sign on the line from the **Document Uploaded** button to the **End** node
2. Select **Call a tool**, which switches the palette to the **Tools** tab
3. Enter `(NAMESPACE)_TRI_fetch_baw_pdf` in the **Search for tools** search field
4. Drag and drop the `(NAMESPACE)_TRI_fetch_baw_pdf` tool onto the edge
5. Click the tool call node, then click the pencil icon next to the default name and replace it with `Fetch PDF from SOR`
6. Click **Edit data mapping**, hover over the **customer_id** input variable, click the **{x}** variable icon, click **Input** on the left side of the picker, and select the **customer_id** flow input. Finally, click the **×** in the top-right corner to close the picker.

![Fetch PDF from SOR](Lab%203%20screenshots/exercise-4/ex4-fetch-pdf-sor.png)

*Figure 4.1: Fetch PDF from SOR tool node with customer_id mapped*

**Extract Raw Text from the Document (Text Extractor)**

At the end of processing the warranty claim, a log record is created for this customer interaction. That record is meant to capture a summary of the entire warranty document — not just the handful of fields the workflow extracts for its own processing, like purchase date or serial number. The first step toward that summary is pulling the document's full text now, so a later Prompt step can summarize it and store that summary in the customer interaction log. This step runs the document through the Text Extractor — wxO's Doc Processing node (`docproc`, `task="text_extraction"`), labeled "Text extractor" in the Canvas UI palette.

7. Click the **+** sign on the line after the `Fetch PDF from SOR` node, then select **Add a flow activity** → **Text extractor**
8. Click the pencil icon next to the default name and rename it to `Extract Warranty Doc Text`
9. In the extraction options, check **Keep document layout** and enable **Output as object** — the object output is what allows the extracted text to be referenced as a structured variable later. Disable all other options, but read each option's tooltip first to get a sense of what it's good for
10. Click **Edit data mapping** and explicitly map **document_ref** to the output of the `Fetch PDF from SOR` tool call. The **kvp_model_name** input is only used for key-value-pair extraction, which this step doesn't need — click the little **×** on its auto-mapped entry to clear it
11. Click the **x** icon in the top-right corner to close the **Edit data mapping** panel and return to the canvas.

![Extract Warranty Doc Text](Lab%203%20screenshots/exercise-4/ex4-extract-warranty-doc-text.png)

*Figure 4.2: Text extractor node configured with Keep document layout and Output as Object*

**Classify the Document Type**

Before any fields can be extracted, the workflow needs to determine what kind of document was uploaded. This solution only supports receipts and warranty cards — each has a different set of values to extract — and any other document is rejected.

12. Click the **+** sign on the line after the `Extract Warranty Doc Text` node, then select **Add a flow activity** → **Document classifier**
13. Click the pencil icon next to the default name and rename it to `Classify document`
14. On the node's main page, deselect **User Review**
15. Click the pencil icon on the classes section, which opens the Classes screen:
    - Keep the default AI model and language
    - Click **Add class** and enter `receipt`
    - Click **Add class** and enter `warranty_card`
    - Note: The "Other" class is automatically included as a catch-all option
    - Don't provide sample documents for either class — sample documents improve classification accuracy against varying real-world document formats, which this demo solution doesn't need
    - Click the **←** icon at the top left of the Classes screen to return to the node
16. Click **Edit data mapping** and explicitly map **document_ref** to the output of the `Fetch PDF from SOR` tool call

![Classify Document](Lab%203%20screenshots/exercise-4/ex4-classify-document.png)

*Figure 4.3: Classify document node configured with receipt and warranty_card classes*

**Branch on the Document Type**

17. Click the **+** button and select **Add a flow control** → **Branch**
18. Click the pencil icon next to the default name and set it to `Doc Type?`
19. Click **Add path +** to add a third path for the "other" case
20. Rename the paths: click **Path 1 (if)** and rename it to `Receipt`; click **Path 3 (else if)** and rename it to `Warranty Card`; click **Path 2 (else)** and rename it to `Other`
21. Click **Edit condition** for the `Receipt` path
22. Click **+** next to **if**, select **class_name** from the `Classify document` node, select **==**, and enter `receipt` in the field on the right, then click the **←** icon in the top-left corner to return
23. Click **Edit condition** for the `Warranty Card` path
24. Click **+** next to **if**, select **class_name** from the `Classify document` node, select **==**, and enter `warranty_card` in the field on the right, then click the **←** icon in the top-left corner to return

![Doc Type Branch](Lab%203%20screenshots/exercise-4/ex4-doc-type-branch.png)

*Figure 4.4: Doc Type branch configuration with Receipt, Warranty Card and Other branches*

25. Hover over the connection point at the end of the path that shows the **Add +** placeholder and drag a connection line down to the **End** node
26. Click **+** on the `Receipt` path, select **Add a flow activity** → **Document extractor**, and select **Unstructured** in the dialog

**Extract Fields by Document Type for Unstructured Receipts**

With the document confirmed as a receipt, this Document extractor pulls out the specific fields the workflow needs for warranty validation — product name, purchase date, and so on. Receipts have no fixed template or field layout, since they come from whichever retailer the customer bought from, so the extractor relies on AI rather than rigid positions to find each field. Providing a couple of examples — like `Purchase Date: 2024/05/15` versus `Purchase Date 2024/05/15` — teaches it to recognize that variation, which matters here since you can't control the format of whatever a customer uploads. Of all the fields extracted, only **Purchase Date** and **Product Name** are mandatory for the workflow to proceed — so you'll configure a confidence threshold below which a human reviews and confirms those two fields before the workflow continues.

> **Going further — Name fields precisely ([Allen Chan #23 — Lazy Field Definitions](https://achan2013.medium.com/ai-agent-anti-patterns-part-3-knowledge-document-processing-0caf472856ff)):** [Allen Chan #23 — Lazy Field Definitions](https://achan2013.medium.com/ai-agent-anti-patterns-part-3-knowledge-document-processing-0caf472856ff) warns against vague field names like `date` or `name` — the extraction model uses the field name as a hint when scanning the document. `Purchase Date` is unambiguous; `date` could match a dozen values on a receipt. The same principle applies to the examples you provide: specific input/output pairs teach the model to handle the exact formatting variation it will encounter, rather than guessing. ADK Docs: [`agents/agent_design/knowledge_processing`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/knowledge_processing)

27. Click the pencil icon next to the default name and rename it to `Extract Receipt Fields`, and keep the default AI model
28. Click **Add field +** and enter `Purchase Date`, then configure it:
    - Click the **three dots (⋮)** next to the field
    - Click **Edit**
    - Change the data type to **Date**
    - Toggle **Description** off
    - Toggle **Examples** to ON
    - Add two example input/output pairs:
      - **Example 1**:
        - Input: `Purchase Date: 2024/05/15`
        - Output: `2024/05/15`
      - **Example 2**:
        - Input: `Purchase Date 2024/05/15`
        - Output: `2024/05/15`
    - Click **Submit**
29. Click the **Add field +** button directly above the table of fields to be extracted, and specify the name for each of the remaining fields — **String** is the default data type, so no further customization is needed:
    - `Product Category`
    - `Receipt No`
    - `Reseller`
    - `Serial No`
    - `Price`
    - `Product Name`
30. Don't provide sample documents for training here either — like with the classifier, sample documents help with varying real-world document formats, which this demo solution doesn't need

![Extract Receipt Fields](Lab%203%20screenshots/exercise-4/ex4-extract-reciept-fields.png)

*Figure 4.5: Extract Receipt Fields Configuration*

31. Click the **x** in the top right corner to close the dialog, then click the step again to open its properties overview page
32. Ensure the **User Review** toggle is on — once switched on, a form displaying the document alongside its extracted values is generated automatically at runtime; there's no option to specify your own customized review form
33. Click the pencil icon next to **If the extraction confidence is below**, enter `10` in the number field, then click the pencil icon to the right of the **All fields** label, click **Fields (7)** to deselect all, select only **Purchase Date** and **Product Name**, click **Done**, and keep **Assign to** on the default **Flow initiator**
34. Click the **←** icon in the top-left corner to go back
35. Click **Edit data mapping** and explicitly map **document_ref** to the output of the `Fetch PDF from SOR` tool call

**Extract Fields by Document Type for Structured Warranty Cards**

The warranty card looks nothing like the receipt: it's a short, fixed-layout card where every field sits in the same place, label next to value. That's exactly the shape the Document extractor's **Structured** option is built for — a vision-based model suited to short, fixed-layout documents, as opposed to the text-based model **Unstructured** uses for longer, free-form content like the receipt. The fields themselves are configured the same way as before; only the extraction method changes.

> **Note:** One significant difference between Structured and Unstructured extraction: the Structured extractor has no confidence threshold setting. Instead of a per-field confidence score, it uses a simpler rule — if the extraction returns any empty values for the configured fields, the review form is automatically sent to the flow initiator. This means the HITL trigger for warranty cards is **any empty mandatory field**, rather than the numerical confidence threshold used for receipts.

36. Click **+** on the `Warranty Card` path, select **Add a flow activity** → **Document extractor**, and select **Structured** in the dialog
37. Click the pencil icon next to the default name and rename it to `Extract Warranty Card Fields`, and keep the default AI model
38. Click **Define schema**, keep **User-defined schema** selected, and click **Create**

    > **Note:** A set of predefined schemas is also provided to choose from, but this lab needs its own set of fields, so a user-defined schema is used instead.

39. Click the **Add field +** button directly above the table of fields to be extracted, and add the four fields — **String** is the default data type, so no further customization is needed:
    - `Product Name`
    - `Serial No`
    - `Model No`
    - `Reseller`
40. Click **Add field +** and enter `Purchase Date`, then configure it:
    - Click the **three dots (⋮)** next to the field
    - Click **Edit**
    - Change the data type to **Date**
    - Toggle **Description** off
    - Toggle **Examples** off
    - Toggle **Available options** off
    - Click **Submit**
41. Don't provide sample documents for training here either — same as for the receipt
42. Click the **x** in the top right corner to close the dialog, then click the step again to open its properties overview page
43. Ensure the **User Review** toggle is on — once switched on, a form displaying the document alongside its extracted values is generated automatically at runtime; there's no option to specify your own customized review form. If the extraction returns any empty values, the form is sent to the flow initiator automatically

![Doc Extractor User Review On](Lab%203%20screenshots/exercise-4/ex4-doc-extractor-user-review-on.png)

*Figure 4.6: Extract Warranty Card Fields Document Extractor user review toggled on*

44. Click **Edit data mapping** and explicitly map **document_ref** to the output of the `Fetch PDF from SOR` tool call
#### Test the Document Classification and Extraction Segment

1. Switch to the tab/window with the `(NAMESPACE)_TRI_warranty_agent` open — keep the Flow builder tab/window open as well, since you'll switch back to it later.
2. Click the **Reset chat** icon in the top right of **Draft Preview** to start a fresh conversation, then enter the prompt:
    ```
    Customer C-3DBZFE has a headset they bought from a reseller — it stopped working and they want warranty.
    ```
3. When the **CUSTOMER DETAILS & UPLOAD READINESS** form appears, click **Upload Now**.
4. When the **Wait for customer upload confirmation** form appears, click **Document Uploaded**.
5. Observe the **Review document extraction** output in the chat.

    ![Review document extraction output in chat with View link](Lab%203%20screenshots/exercise-4/ex4-test-review-doc-chat-card.png)

    *Figure 4.7: Review document extraction output in the chat with the View link*

6. Click the **View** link to open the Review document extraction form showing the document alongside the extracted fields.

    ![Review document extraction output in chat](Lab%203%20screenshots/exercise-4/ex4-test-review-doc-extraction-output.png)

    *Figure 4.8: Review document extraction form showing the document alongside the extracted fields*

7. Enlarge the document image shown on the left by clicking **Zoom in**. Observe that the last digit of the purchase date is partially obscured — this is what caused the extraction confidence to fall below the threshold and triggered the HITL review form. This is the same receipt document used in Lab 0.

    ![Review document extraction form with obscured date](Lab%203%20screenshots/exercise-4/ex4-test-review-doc-form-zoomed.png)
    *Figure 4.9: Review document extraction form with the zoomed document showing the obscured purchase date digit*

8. The purchase date is extracted correctly despite the obscured digit. Click **Submit**, then click **Confirm and submit** in the confirmation popup.

    > **Note:** This completes the flow for now — no further processing is implemented yet. The workflow reaches the **End** node after the extraction review step.

9. Click the three stacked dots (⋮) on the Workflow tool tile, then select **Open flow inspector**.
10. Click the **View details** link for the latest flow instance.
11. Click the **Fetch PDF from SOR** step on the left-hand side of the Flow Events tab. Observe that the response of the Python tool is not the PDF content itself but a special pointer — a signed file URL — to the retrieved document. This is the reference that later steps, including the document AI nodes, use to access the file without ever passing the raw document bytes through the workflow state.

    ![Fetch PDF from SOR step in Flow inspector](Lab%203%20screenshots/exercise-4/ex4-test-flow-inspector-fetch-pdf.png)
    *Figure 4.10: Fetch PDF from SOR step in the Flow inspector showing the signed file URL output*

12. Click the **Extract Warranty Doc Text** step and observe the `document_ref` input variable — this is the signed file URL pointer returned by the previous step, confirming that the document AI node receives the file reference rather than the raw bytes. Also observe the `text` output variable containing the full plain text extracted from the receipt document.

    ![Extract Warranty Doc Text step in Flow inspector](Lab%203%20screenshots/exercise-4/ex4-test-flow-inspector-extract-text.png)
    *Figure 4.11: Extract Warranty Doc Text step showing document_ref input and text output*

13. Click the **Classify document** step and observe the `class_name` output variable — it identifies the uploaded document as a `receipt`.

    ![Classify document step in Flow inspector](Lab%203%20screenshots/exercise-4/ex4-test-flow-inspector-classify.png)
    *Figure 4.12: Classify document step showing class_name output as receipt*

14. Click the **Doc Type?** step and observe that the **Receipt** path was taken.

    ![Doc Type branch step in Flow inspector](Lab%203%20screenshots/exercise-4/ex4-test-flow-inspector-branch.png)
    *Figure 4.13: Doc Type? branch step showing the Receipt path taken*

15. Click the **Extract Receipt Fields** step and observe the 7 output variables populated with the data extracted from the receipt document, matching the fields defined in the Document Extractor node.

    ![Extract Receipt Fields step in Flow inspector](Lab%203%20screenshots/exercise-4/ex4-test-flow-inspector-extract-receipt.png)
    *Figure 4.14: Extract Receipt Fields step showing all 7 output variables populated*

16. Close the flow instance details by closing the tab/window that opened.
17. Close the Flow inspector view by clicking the **x** in the top right corner.
18. In the **Draft Preview** chat window, enter the prompt:
    ```
    Customer C-11100 has a headset they bought from a reseller — it stopped working and they want warranty.
    ```
19. When the **CUSTOMER DETAILS & UPLOAD READINESS** form appears, click **Upload Now**.
20. When the **Wait for customer upload confirmation** form appears, click **Document Uploaded**.
21. Observe that after some time the flow ends without the **Review document extraction** output appearing. This customer's receipt had all fields successfully extracted — no empty values were returned, so no HITL review was required and the workflow continued directly to the **End** node.
22. Click the three stacked dots (⋮) on the Workflow tool tile, then select **Open flow inspector**.
23. Click the **View details** link for the latest flow instance.
24. Click the **Classify document** step and confirm that `class_name` again identifies the document as a `receipt`.
25. Click the **Extract Receipt Fields** step and confirm that all 7 output variables are populated — extracted automatically, without any specialist review step.
26. Close the flow instance details by closing the tab/window that opened.
27. Close the Flow inspector view by clicking the **x** in the top right corner.
28. In the **Draft Preview** chat window, enter the prompt:
    ```
    Customer C-33300 has a headset they bought from a reseller — it stopped working and they want warranty.
    ```
29. When the **CUSTOMER DETAILS & UPLOAD READINESS** form appears, click **Upload Now**.
30. When the **Wait for customer upload confirmation** form appears, click **Document Uploaded**.
31. Observe that after some time the flow ends without the **Review document extraction** output appearing. This customer's warranty card was extracted with sufficient confidence on all fields — no HITL review was required and the workflow continued directly to the **End** node.
32. Click the three stacked dots (⋮) on the Workflow tool tile, then select **Open flow inspector**.
33. Click the **View details** link for the latest flow instance.
34. Click the **Classify document** step and observe the `class_name` output variable — it identifies the uploaded document as a `warranty_card`.

    ![Classify document step in Flow inspector — warranty card](Lab%203%20screenshots/exercise-4/ex4-test-flow-inspector-classify-warranty-card.png)
    *Figure 4.15: Classify document step showing class_name output as warranty_card*

35. Click the **Doc Type?** step and observe that the **Warranty Card** path was taken.
36. Click the **Extract Warranty Card Fields** step and observe the output variables populated with the data extracted from the warranty card document, matching the fields defined in the Document Extractor node.

    ![Extract Warranty Card Fields step in Flow inspector](Lab%203%20screenshots/exercise-4/ex4-test-flow-inspector-extract-warranty-card.png)
    *Figure 4.16: Extract Warranty Card Fields step showing output variables populated*

37. Close the flow instance details by closing the tab/window that opened.
38. Close the Flow inspector view by clicking the **x** in the top right corner.

✅ Exercise 4 complete. You built the document-processing segment: a `Fetch PDF from SOR` tool call, a Text Extractor, a Document Classifier routing between `receipt` and `warranty_card`, and an Unstructured or Structured Document Extractor for each — each with its own HITL review gate — confirmed across three customers (C-3DBZFE, C-11100, C-33300). In Exercise 5, you will use the extracted product name to look up the matching catalog item and read its warranty duration.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 5: Identify the Catalog Product and Determine Warranty Duration (~25 mins)

With the product name extracted in Exercise 4, this exercise resolves it to the exact item in the SOR catalog. The catalog lookup can return more than one match — when it does, the specialist chooses the right one — and the resolved catalog item is what lets the workflow check the product's warranty status against its purchase date.

#### Steps

The steps below build out the receipt path only. The warranty card path follows the same pattern — a catalog lookup using the `product_name` extracted from `Extract Warranty Card Fields`, feeding into the same `Prepare Warranty Check Inputs` logic block — so it is not repeated here.

#### Build the Identify the Catalog Product and Determine Warranty Duration Segment

**Look Up the Catalog Item by Product Name**

To determine the warranty status in the next exercise, the workflow needs the catalog item's warranty period — and that lives on the catalog item record in Focus Corp's SOR, not on the extracted document fields. The tool `TSOR_Catalog_search_catalog_items_by_name` performs a fuzzy search against the SOR catalog using the product name extracted from the receipt. It returns a list of potential matches sorted by confidence value, where a confidence of 100 means a complete name match.

1. Click the **+** sign on the line after the `Extract Receipt Fields` node, then select **Call a tool**, which switches the palette to the **Tools** tab
2. Enter `(NAMESPACE)_TRI_SOR_MCP:TSOR_Catalog_search_catalog_items_by_name` in the **Search for tools** search field
3. Drag and drop the `(NAMESPACE)_TRI_SOR_MCP:TSOR_Catalog_search_catalog_items_by_name` tool onto the edge
4. Click the tool call node, then click the pencil icon next to the default name and replace it with `Lookup Catalog Item`
5. Click **Edit data mapping**, hover over the **product_name** input variable, click the **{x}** variable icon, click **Extract Receipt Fields** on the left side of the picker, and select **product_name**. Finally, click the **×** in the top-right corner to close the picker.

![Lookup Catalog Item](Lab%203%20screenshots/exercise-5/ex5-lookup-catalog-item.png)

*Figure 5.1: Lookup Catalog Item node with product_name mapped*

**Prepare Warranty Check Inputs**

The catalog search returns a list of matches — but the workflow needs to interpret that result and prepare it for the steps that follow. If the first result has a confidence of 100, it can be used directly without the specialist needing to get involved. If not, the items list needs to be prepared so it can be presented to the specialist in a selection form. wxO lets you write this logic inline using a Logic block — a Python code node that runs inside the workflow and can read any prior step's output.

6. Click the **{x}** icon in the top left corner of the canvas to show the flow variables, then click **Add +** to add a new flow variable. Select **String** as the data type, enter `catalog_item_id` as the name, and click **Add**

    This flow variable will be used to hold the actual `catalog_item_id` of the identified product the customer bought, independent of the product being found directly or the specialist selecting from a set of products.

7. Click the **+** sign on the line after the `Lookup Catalog Item` node, then select **Add a flow activity** → **Logic block**
8. Click the pencil icon next to the default name and replace it with `Prepare Warranty Check Inputs`
9. Click **Define outputs** for the Logic block, then click **Add output +** in the top right corner of the Outputs table. Select **String** as the data type, enter `options` as the name, check **List of String**, and click **Add**
10. Switch to the **Code editor** tab and copy-paste the following Python code, replacing the default code. Note that this code only selects those items whose confidence score is above 50:

    ```python
    # Retrieve the list of matching items from the previous step
    items = flow["Handle Warranty Claim"]["Lookup Catalog Item"].output.matchingItems or []

    # Initialize defaults
    flow.private.catalog_item_id = None
    self.output.options = []

    # Check if the first item has a confidence of 100
    if items and items[0].get("confidence") == 100:
        flow.private.catalog_item_id = items[0].get("catalog_item_id")
    else:
        # Filter items with confidence > 50 and format display strings
        self.output.options = [
            f"{item.get('name')} (Confidence: {item.get('confidence')}, Catalog Item Id: {item.get('catalog_item_id')})"
            for item in items
            if item.get("confidence", 0) > 50
        ]
    ```

    **Note:** Single choice fields in wxO only support a list of Strings, where the display text shown to the user is the same value that gets submitted. For this reason, each option string embeds the `catalog_item_id` alongside the product name and confidence score. A logic block added after the form submission will parse the selected string to extract the `catalog_item_id`.

    > **Why `flow.private`?** There is a current bug in wxO where a Decision node cannot directly access the properties of a complex object — such as a tool call's output object. Writing `catalog_item_id` into `flow.private` works around this: the Decision node downstream can read the plain scalar value directly.

11. Close the dialog by clicking the **×** in the top right corner

![ Prepare Warranty Check Inputs](Lab%203%20screenshots/exercise-5/ex5-prepare-warranty-inputs.png)

*Figure 5.2: Prepare Warranty Check Inputs logic block*

**Auto-Select on a Confident Match**

12. Click the **+** button on the line after the `Prepare Warranty Check Inputs` logic block, then select **Add a flow control** → **Branch**
13. Click the pencil icon next to the default name and set it to `Catalog item found?`
14. Rename the paths: click **Path 1 (if)** and rename it to `Yes`; click **Path 2 (else)** and rename it to `No`
15. Click **Edit condition** for the `Yes` path, switch to the **Expression editor** by clicking the **</>** icon, enter `flow.private.catalog_item_id != None`, and click the **←** icon in the top-left corner to return

    This time we are using the expression editor to express that the flow variable is set (i.e. is not `None`), which cannot be done using the standard Condition builder we used before.

![Catalog item found? branch with Yes/No paths](Lab%203%20screenshots/exercise-5/ex5-catalog-item-found-branch.png)

*Figure 5.3: Catalog item found? branch with Yes/No paths*

**Resolve Ambiguous Matches with the Specialist (HITL)**

When the catalog lookup doesn't return a single confident match, the workflow presents the list of candidates to the specialist so they can pick the right one. This is a human-in-the-loop (HITL) step implemented as a Form node.

16. Click **Add +** on the **No** branch and select **Add a form**
17. Set `Select customer product` as both the **Form title** and the **Node name**
18. Disable the **Cancel** button — we will not model the cancellation path at this stage
19. Click **Add field +** and select **File download** from the **Present to user** section. Set the label to `View receipt document` and map the output from the `Fetch PDF from SOR` step to it.
20. Click **Add field +** and select **Single choice** from the **Collect from user** section
21. Replace the default label with `Customer product`
22. As the **Source variable**, select `options` from the `Prepare Warranty Check Inputs` step
23. Toggle the **Required** switch to on
24. Close the form editor by clicking the **×** in the top right corner

![Select customer product form with file download and single choice](Lab%203%20screenshots/exercise-5/ex5-select-customer-product-form.png)

*Figure 5.4: Select customer product form with file download and single choice*

**Extract the Selected Catalog Item ID**

Since the Single choice field submits the full display string, we need to parse out the `catalog_item_id` embedded in the selected option and assign it to the `catalog_item_id` flow variable so subsequent steps can use it.

25. Click the **+** sign on the line after the `Select customer product` form node, then select **Add a flow activity** → **Logic block**
26. Click the pencil icon next to the default name and replace it with `Extract catalog_item_id`
27. Switch to the **Code editor** tab and copy-paste the following Python code, replacing the default code:

    ```python
    ws = flow["Handle Warranty Claim"]["Select customer product"].output
    selected_option = (ws.get("Customer product", "") if isinstance(ws, dict) else getattr(ws, "Customer product", "")) or ""

    marker = "Catalog Item Id: "
    if marker in selected_option:
        # Split on the marker and strip the trailing closing parenthesis
        flow.private.catalog_item_id = selected_option.split(marker)[-1].rstrip(")").strip()
    else:
        flow.private.catalog_item_id = None
    ```

28. Close the dialog by clicking the **×** in the top right corner

![Extract catalog_item_id logic block](Lab%203%20screenshots/exercise-5/ex5-extract-catalog-item-id.png)

*Figure 5.5: Extract catalog_item_id logic block*

**Check the Warranty Status**

With the `catalog_item_id` resolved and stored in the flow variable, the workflow can now call the SOR to check the warranty status for the identified product against its purchase date.

29. Click the **+** sign on the line after the `Extract catalog_item_id` node, then select **Call a tool**, which switches the palette to the **Tools** tab
30. Enter `(NAMESPACE)_TRI_SOR_MCP:TSOR_Catalog_check_warranty_for_catalog_item_by_purchase_date` in the **Search for tools** search field
31. Drag and drop the `(NAMESPACE)_TRI_SOR_MCP:TSOR_Catalog_check_warranty_for_catalog_item_by_purchase_date` tool onto the line
32. Click the tool call node, then click the pencil icon next to the default name and replace it with `Check Warranty Status`
33. Click **Edit data mapping**, hover over the **catalog_item_id** input variable, click the **{x}** variable icon, and select `catalog_item_id` from the flow variables. For the **purchase_date** input, leave it set to **Auto-map**.

    The flow engine will automatically resolve the `purchase_date` from the extracted fields and convert the string value to the date type expected by the tool.

![Check Warranty Status tool call with catalog_item_id mapped](Lab%203%20screenshots/exercise-5/ex5-check-warranty-status.png)

*Figure 5.6: Check Warranty Status tool call with catalog_item_id mapped*

34. Close the dialog by clicking the **×** in the top right corner

35. Click the **Yes** branch path to select it. Move the mouse to the end of the line until the cursor changes to a move cursor (four arrows). Drag the line end and drop it onto the connection point of the `Check Warranty Status` tool call node, so that both the direct-match path and the specialist-selection path converge on the same warranty check step.

![Yes branch rewired](Lab%203%20screenshots/exercise-5/ex5-yes-branch-rewired.png) \

*Figure 5.7: Yes branch rewired to converge on Check Warranty Status Tool*

**Extract Warranty Fields (flatten for decision table)**

Due to a current bug in wxO where a decision table cannot directly access the properties of a complex object returned by a tool call, we need to flatten the warranty status result into individual output fields using a Logic block.

36. Click the **+** sign on the line after the `Check Warranty Status` node, then select **Add a flow activity** → **Logic block**
37. Click the pencil icon next to the default name and replace it with `Extract Warranty Fields (flatten for decision table)`
38. Click **Define outputs**, then click **Add output +** and add the following outputs:
    - `days_expired` — **Integer**
    - `days_remaining` — **Integer**
    - `warranty_period` — **String**
    - `warranty_end_date` — **String**
39. Switch to the **Code editor** tab and copy-paste the following Python code, replacing the default code:

    ```python
    ws = flow["Handle Warranty Claim"]["Check Warranty Status"].output

    if isinstance(ws, dict):
        status = ws.get('warranty_status', ws)
    else:
        status = getattr(ws, 'warranty_status', ws)

    def _int(val, default=0):
        try: return int(val)
        except: return default

    def _str(val, default=''):
        try: return str(val).strip() if val is not None else default
        except: return default

    self.output.days_expired      = _int(status.get('days_expired', 0) if isinstance(status, dict) else getattr(status, 'days_expired', 0))
    self.output.days_remaining    = _int(status.get('days_remaining', 0) if isinstance(status, dict) else getattr(status, 'days_remaining', 0))
    self.output.warranty_period   = _str(status.get('warranty_period') if isinstance(status, dict) else getattr(status, 'warranty_period', ''))
    self.output.warranty_end_date = _str(status.get('warranty_end_date') if isinstance(status, dict) else getattr(status, 'warranty_end_date', ''))
    ```

![Extract Warranty Fields logic block with four outputs defined](Lab%203%20screenshots/exercise-5/ex5-extract-warranty-fields.png)

*Figure 5.8: Extract Warranty Fields logic block with four outputs defined*

40. Close the dialog by clicking the **×** in the top right corner

**Determine the Discount with a Decision Table**

With the warranty fields flattened into individual outputs, the workflow can now evaluate them against business rules in a Decision table to determine the applicable discount percentage, note, and offer type. This Decision table is a deterministic rule engine — unlike AI-based decisions, it produces predictable, auditable outcomes, embodying the "agents-read / workflows-write" principle where the LLM agent retrieves data but the workflow enforces business rules before writing to the System of Record. Decision tables also externalize business rules so analysts can modify discount policies without changing code. This decision point is also a critical business rule junction: in-warranty claims require different handling than out-of-warranty claims, and by implementing this as a workflow branch rather than hardcoding the logic, business analysts can modify decision criteria without developer involvement.

> **Going further — Rules belong in the table, not in instructions ([Allen Chan #37 — Natural Language Workflow Engine](https://achan2013.medium.com/agent-anti-patterns-part-5-05da1c3c1828)):** A tempting alternative is to describe the discount logic in the agent's instructions: "if the customer is Platinum and the warranty expired more than a year ago, offer 30%…". [Allen Chan #37 — Natural Language Workflow Engine](https://achan2013.medium.com/agent-anti-patterns-part-5-05da1c3c1828) names this mistake — encoding deterministic sequential logic inside a prompt. The same point applies here: discount eligibility rules are business policy, not conversational intent. They must produce the same output every time for the same input, be auditable, and be updatable by a business analyst without touching code. A Decision table delivers all three; a prompt cannot. ADK Docs: [`agents/agent_design/foundational_architecture`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/foundational_architecture)

> **Note:** For this exercise we use a simplified three-rule table (two explicit rules plus the default action). See the [Appendix: Full Warranty Discount Decision Table](#appendix-full-warranty-discount-decision-table) for the complete 17-rule implementation used in the full Trinity solution.

41. Click the **+** sign on the line after the `Extract Warranty Fields (flatten for decision table)` node, then select **Add a flow activity** → **Decision**
42. Click the pencil icon next to the default name and replace it with `Warranty Discount Decision Table`
43. Click the first condition column header on the left, select **Input** → `customer_tier`, and rename the column to `Customer Tier`. Leave the match type set to **Exact match**.
44. Click the **⋮** (three stacked dots) menu on the `Customer Tier` condition column and select **Insert column right**
45. Set the new condition column name to `Days Expired (Min Inclusive)`, select **Extract Warranty Fields (flatten for decision table)** → `days_expired` as the variable, and set the match type to **Minimum inclusive**
46. Click the first action column header and rename the column to `discount_pct`. When selecting the target variable, click **Add +** in the variable picker to create a new flow variable, set the data type to **Integer**, enter `discount_pct` as the name, and click **Add**. Then select the newly created `discount_pct` variable.
47. Click the **⋮** menu on the `discount_pct` action column and select **Insert column right**
48. Set the new action column name to `discount_note`. Click **Add +** in the variable picker to create a new **String** flow variable named `discount_note`, click **Add**, and select it.
49. Click the **⋮** menu on the `discount_note` action column and select **Insert column right**
50. Set the new action column name to `offer_type`. Click **Add +** in the variable picker to create a new **String** flow variable named `offer_type`, click **Add**, and select it.
51. Fill in the decision table rules as follows:

    | Customer Tier | Days Expired (Min Inclusive) | discount_pct | discount_note                          | offer_type      |
    |---------------|------------------------------|--------------|----------------------------------------|-----------------|
    | Platinum      | 366                          | 30           | Platinum loyalty - over 1 year expired | Out of Warranty |
    | Standard      | 0                            | 10           | Standard loyalty - 10%                 | In Warranty     |

    The default values are not entered in the main rules table. At the bottom of the dialog you will find a separate **Default action** section — enter `10` for `discount_pct`, `Fallback` for `discount_note`, and `Out of Warranty` for `offer_type`.

![Warranty Discount Decision Table with two rules and default action](Lab%203%20screenshots/exercise-5/ex5-decision-table.png)

*Figure 5.9: Warranty Discount Decision Table with two rules and default action*

52. Close the dialog by clicking the **×** in the top right corner

**Out of Warranty / In Warranty Handling**

For this exercise we will not implement the full resolution logic for each branch. Instead, we add a simple Message node to each path to surface the warranty decision to the specialist — this is sufficient to verify the flow end-to-end without building out the complete downstream steps.

53. Click the **+** sign on the line after the `Warranty Discount Decision Table` node, then select **Add a flow control** → **Branch**
54. Click the pencil icon next to the default name and replace it with `In Warranty?`
55. Rename the paths: click **Path 1 (if)** and rename it to `Yes`; click **Path 2 (else)** and rename it to `No`
56. Click **Edit condition** for the `Yes` path, select the `offer_type` flow variable, set the operator to `==`, and enter `In Warranty` as the value. Click the **←** icon in the top-left corner to return.
57. Click **+** on the **Yes** branch and select **Present to user** → **Message**
58. Click the **pencil icon** above the node shape and specify `In Warranty Msg` as the node name
59. Click **Edit message** and enter the following **Agent message**:

    ```
    # WARRANTY CLAIM DECISION

    ## {flow.private.offer_type}

    | Warranty Information |   |
    | ---- | ---- |
    | **Product:** |{flow["Handle Warranty Claim"]["Extract Receipt Fields"].output.product_name}|
    | **Purchase Date:** |{flow["Handle Warranty Claim"]["Extract Receipt Fields"].output.purchase_date}|
    | **Warranty Period:** |{flow["Handle Warranty Claim"]["Extract Warranty Fields (flatten for decision table)"].output.warranty_period}|
    | **Warranty End:** |{flow["Handle Warranty Claim"]["Extract Warranty Fields (flatten for decision table)"].output.warranty_end_date}|
    ```

60. Close the dialog by clicking the **×** in the top right corner
61. Click **Add +** on the **No** branch and select **Present to user** → **Message**
62. Click the **pencil icon** above the node shape and specify `Out of Warranty Message` as the node name
63. Click **Edit message** and enter the following **Agent message**:

    ```
    # WARRANTY CLAIM DECISION

    ## {flow.private.offer_type}

    | Warranty Information |   |
    | ---- | ---- |
    | **Product:** |{flow["Handle Warranty Claim"]["Extract Receipt Fields"].output.product_name}|
    | **Purchase Date:** |{flow["Handle Warranty Claim"]["Extract Receipt Fields"].output.purchase_date}|
    | **Warranty Period:** |{flow["Handle Warranty Claim"]["Extract Warranty Fields (flatten for decision table)"].output.warranty_period}|
    | **Warranty End:** |{flow["Handle Warranty Claim"]["Extract Warranty Fields (flatten for decision table)"].output.warranty_end_date}|
    | **Days Expired:** |{flow["Handle Warranty Claim"]["Extract Warranty Fields (flatten for decision table)"].output.days_expired} days|
    ```

64. Close the dialog by clicking the **×** in the top right corner

![In Warranty? branch with In Warranty Msg and Out of Warranty Message nodes](Lab%203%20screenshots/exercise-5/ex5-in-warranty-branch.png)

*Figure 5.10: In Warranty? branch with In Warranty Msg and Out of Warranty Message nodes*

#### Test the Identify the Catalog Product and Determine Warranty Duration Segment

We will use two customers — both with a headset problem — to demonstrate different aspects of what we have implemented. The first customer produces a direct catalog match, letting the workflow proceed without specialist involvement. The second customer's receipt extracts cleanly with no confidence issues, but the catalog search returns multiple candidates so the specialist must pick the right one.

**Scenario 1: Direct catalog match (C-3DBZFE)**

1. Switch to the tab/window with the `(NAMESPACE)_TRI_warranty_agent` open.
2. Click the **Reset chat** icon in the top right of **Draft Preview** to start a fresh conversation.
3. In the **Draft Preview** chat window, enter the prompt:
    ```
    Customer C-3DBZFE has a headset they bought from a reseller — it stopped working and they want warranty.
    ```
4. When the **CUSTOMER DETAILS & UPLOAD READINESS** form appears, click **Upload Now**.
5. When the **Wait for customer upload confirmation** form appears, click **Document Uploaded**.
6. Observe the **Review document extraction** output in the chat — click the **View** link to open the review form, then click **Submit** and **Confirm and submit** as before.
7. Observe that no further input is required and the flow ends with an **Out of Warranty** verdict displayed in the chat.

    ![Out of Warranty verdict in chat](Lab%203%20screenshots/exercise-5/ex5-test-out-of-warranty-verdict.png)
    *Figure 5.11: Out of Warranty verdict in chat*

8. Click the three stacked dots (⋮) on the Workflow tool tile, then select **Open flow inspector**.
9. Click the **View details** link for the latest flow instance.
10. Click the **Lookup Catalog Item** step and observe the inputs and outputs:
    - The **Inputs** show the `product_name` extracted from the receipt as the search term.
    - The **Outputs** show `matchingItems` containing a single item with a `confidence` of `100` — a complete name match, so the workflow can proceed without any specialist involvement.

    ![Lookup Catalog Item step in Flow inspector](Lab%203%20screenshots/exercise-5/ex5-test-lookup-catalog-item.png)
    *Figure 5.12: Lookup Catalog Item step in Flow inspector*

11. Click the **Flow parameters** tab and scroll to the bottom. Observe the `catalog_item_id` flow variable set to `CI-A4WER4` — this was assigned in the `Prepare Warranty Check Inputs` logic block from the item with confidence 100.

    ![Flow parameters showing catalog_item_id](Lab%203%20screenshots/exercise-5/ex5-test-flow-params-catalog-item-id.png)
    *Figure 5.13: Flow parameters showing catalog_item_id*

12. Click the **Flow events** tab and select the **Catalog item found?** step. Observe that the **Yes** path was taken, confirming the direct match was used and the specialist selection form was skipped.

    ![Catalog item found? step — Yes path taken](Lab%203%20screenshots/exercise-5/ex5-test-catalog-item-found-yes.png)
    *Figure 5.14: Catalog item found? step — Yes path taken*

13. Click the **Check Warranty Status** step and observe both the inputs — `catalog_item_id` and `purchase_date` — and the output, in particular `"days_expired": 509`, confirming the product is well past its warranty end date.

    > **Note:** The `days_expired` value increases by one each day because it is calculated at runtime from the fixed `purchase_date` in the test data and today's date. The value shown here will differ from what you see when you run the exercise.

    ![Check Warranty Status step in Flow inspector](Lab%203%20screenshots/exercise-5/ex5-test-check-warranty-status.png)
    *Figure 5.15: Check Warranty Status step in Flow inspector*

14. Click the **Warranty Discount Decision Table** step and observe the two condition input values (`customer_tier` and `days_expired`) and the three action output values (`discount_pct`, `discount_note`, `offer_type`) produced by the matching rule.

    ![Warranty Discount Decision Table step in Flow inspector](Lab%203%20screenshots/exercise-5/ex5-test-decision-table.png)
    *Figure 5.16: Warranty Discount Decision Table step in Flow inspector*

15. Click the **In Warranty?** step and observe that the **else** path — **No** (Out of Warranty) — was taken, consistent with the `offer_type` set by the decision table.

    ![In Warranty? step — No path taken](Lab%203%20screenshots/exercise-5/ex5-test-in-warranty-no.png)
    *Figure 5.17: In Warranty? step — No path taken*

16. Close the flow instance details by closing the tab/window that opened.
17. Close the Flow inspector view by clicking the **x** in the top right corner.

**Scenario 2: Ambiguous catalog match with HITL selection (C-11100)**

18. Click the **Reset chat** icon in the top right of **Draft Preview** to start a fresh conversation.
19. In the **Draft Preview** chat window, enter the prompt:
    ```
    Customer C-11100 has a headset they bought from a reseller — it stopped working and they want warranty.
    ```
20. When the **CUSTOMER DETAILS & UPLOAD READINESS** form appears, click **Upload Now**.
21. When the **Wait for customer upload confirmation** form appears, click **Document Uploaded**.
22. Observe that no **Review document extraction** output appears — the receipt data extracted cleanly with no confidence issues, so no specialist review was required.
23. Observe the **Select customer product** form that appears next. Click **View receipt document** to open the receipt — notice that the headphone model appears on a separate line as `Model: 500`. This extra text (`Model: `) prevents a perfect catalog name match. The fuzzy search has returned two possible matches above the confidence threshold.
24. Based on reviewing the receipt, select **Focus Headset Pro 500** from the **Customer product** dropdown and click **Submit**.
25. Observe that the flow ends with an **In Warranty** verdict displayed in the chat.

    ![In Warranty verdict in chat](Lab%203%20screenshots/exercise-5/ex5-test-in-warranty-verdict.png)
    *Figure 5.18: In Warranty verdict in chat*

26. Click the three stacked dots (⋮) on the Workflow tool tile, then select **Open flow inspector**.
27. Click the **View details** link for the latest flow instance.
28. Click the **Lookup Catalog Item** step and observe the input value — it may contain the additional `Model:` text from the receipt (here, present only on a second line) or no model information at all, both of which prevent a perfect match. The output shows three items in `matchingItems` with a confidence above 50.

    ![Lookup Catalog Item step — multiple matches](Lab%203%20screenshots/exercise-5/ex5-test-lookup-catalog-item-multi.png)
    *Figure 5.19: Lookup Catalog Item step — multiple matches*

29. Click the **Prepare Warranty Check Inputs** step and observe the **Outputs** — the `options` output contains the three candidate items formatted as display strings for the selection form.

    ![Prepare Warranty Check Inputs step outputs](Lab%203%20screenshots/exercise-5/ex5-test-prepare-warranty-inputs.png)
    *Figure 5.20: Prepare Warranty Check Inputs step outputs*

30. Click the **Catalog item found?** step and observe that the **else** path — **No** — was taken, which is why the **Select customer product** form was presented to the specialist.

    ![Catalog item found? step — No path taken](Lab%203%20screenshots/exercise-5/ex5-test-catalog-item-found-no.png)
    *Figure 5.21: Catalog item found? step — No path taken*

31. Click the **Check Warranty Status** step and observe the **Outputs** — the `warranty_status` object shows `"days_expired": 0`, confirming the product is still within its warranty period.

    ![Check Warranty Status step — in warranty](Lab%203%20screenshots/exercise-5/ex5-test-check-warranty-in-warranty.png)
    *Figure 5.22: Check Warranty Status step — in warranty*

32. Click the **Warranty Discount Decision Table** step and observe the **Inputs** and **Outputs** — note the values produced for `discount_pct`, `discount_note`, and `offer_type`.

    ![Warranty Discount Decision Table step — in warranty](Lab%203%20screenshots/exercise-5/ex5-test-decision-table-in-warranty.png)
    *Figure 5.23: Warranty Discount Decision Table step — in warranty*

33. Click the **In Warranty?** step and observe that the **Yes** path — **In Warranty** — was taken. Observe that the **In Warranty Msg** step exists as the next step on this path, displaying the in-warranty verdict to the specialist.

    ![In Warranty? step — Yes path taken](Lab%203%20screenshots/exercise-5/ex5-test-in-warranty-yes.png)
    *Figure 5.24: In Warranty? step — Yes path taken*

34. Close the flow instance details by closing the tab/window that opened.
35. Close the Flow inspector view by clicking the **x** in the top right corner.

✅ Exercise 5 complete. You built the catalog lookup and warranty determination segment: a fuzzy `Lookup Catalog Item` search, a `Prepare Warranty Check Inputs` logic block, a HITL `Select customer product` form for ambiguous matches, a `Check Warranty Status` tool call, a flattening logic block, and a `Warranty Discount Decision Table` producing `discount_pct`, `discount_note`, and `offer_type` — confirmed with a direct-match out-of-warranty run (C-3DBZFE) and a specialist-selection in-warranty run (C-11100). In Exercises 6 and 7, you will refactor the workflow for both online and batch use.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercises 6, 7, and 8: Online and Batch Warranty Claim Processing *(Optional)*

So far the workflow you have built handles one warranty claim at a time, triggered by a live customer call. In practice, Focus Corp receives claims that cannot always be resolved during the call — customers who could not upload their document on the spot, or claims that arrived outside business hours through a self-service portal. These pending claims accumulate in the SOR and must be processed as a backlog. Because a specialist may need to step in to correct a low-confidence extraction, the job runs several times a day during business hours rather than as a single overnight sweep.

Rather than building a completely separate batch process from scratch, Focus Corp wants to reuse the review logic that already exists in `(NAMESPACE)_TRI_warranty_claim_workflow`. The document classification, field extraction, HITL quality gate, catalog lookup, and warranty decision steps are identical whether the claim is being processed live during a call or from a backlog. Only the terminal step differs: in a live call, the specialist communicates the outcome to the customer directly in chat; in a batch run, the workflow must return a structured result so the batch orchestrator can decide what follow-up to send.

The three exercises below address this in sequence:

- **Exercise 6** does two things to the existing workflow. First, the shared review logic is extracted into a standalone sub-workflow — `(NAMESPACE)_TRI_warranty_review_workflow` — that accepts three inputs beyond the existing customer fields: `document_ref` (the document to review, passed in by the caller rather than fetched inside the sub-workflow), `user_email_id` (the email of the person to assign any HITL tasks to, so both the online specialist and a named batch reviewer can be targeted correctly), and `is_online_mode` (a Boolean that routes to the appropriate terminal step: `True` for a live specialist call, `False` for a background batch run). Second, the original online workflow is refactored into `(NAMESPACE)_TRI_warranty_claim_workflow_online`, simplified to call the new sub-workflow for everything after the document upload steps.

- **Exercise 7** builds the batch caller — `(NAMESPACE)_TRI_warranty_claim_workflow_batch` — that fetches all pending warranty claims from the SOR and processes them one at a time using a Foreach node, calling the sub-workflow from Exercise 6 for each item. In production, this workflow would run on an automated recurring schedule; in this lab, because scheduling operates in the live environment and lab assets are tested locally in the preview, a dedicated agent — `(NAMESPACE)_TRI_warranty_batch_agent` — is used to trigger batch execution on demand.

- **Exercise 8** provides an architecture deep dive (reading-only) into how scheduling operates in watsonx Orchestrate — covering platform prerequisites, agent vs. workflow scheduling patterns, multi-agent inheritance rules, natural language interactive forms, and schedule lifecycle management.

> **Note:** These exercises are marked **optional**. They introduce wxO Agentic Workflow features — sub-workflow composition (Call Flow node), list iteration (Foreach node), and scheduled triggers — that go beyond the core lab scope. Complete Exercises 1–5 first. If time permits, or if you want to explore how the workflow scales to background processing, continue here.

> **Cross-lab design thread:** Lab 2 and Lab 3 both face a situation where the same core logic needs to serve two slightly different contexts, and they solve it differently by design. Lab 2 keeps the shared review logic inside a single user activity and uses a variable-driven conditional branch to skip one step — appropriate when the deviation is small. Lab 3 extracts the shared logic into a standalone sub-workflow and uses an `is_online_mode` Boolean input to control the terminal step — appropriate when the shared unit is large enough to be independently testable and reused by multiple callers. Neither approach is universally correct; the right choice depends on the size and testability of the shared logic.

---

### Exercise 6: Extracting the Warranty Review Sub-Workflow and Simplifying the Online Caller *(~25-30 mins — Optional)*

With the business context above established, this exercise extracts the shared review logic into a standalone sub-workflow — `(NAMESPACE)_TRI_warranty_review_workflow` — and simplifies the online caller to delegate to it. The sub-workflow handles everything from document classification through the warranty decision, and uses the `is_online_mode` input to route to the appropriate terminal step: the existing specialist-facing message nodes when running online, or a structured output when running in batch mode.

> **Calling a workflow from a workflow.** Up to this point in the lab, every **Call a tool** node has invoked an external service or SOR operation. In Exercises 6 and 7 you use the same **Call a tool** node differently — to call another agentic workflow as a tool, creating a nesting relationship where `(NAMESPACE)_TRI_warranty_claim_workflow_online` and later `(NAMESPACE)_TRI_warranty_claim_workflow_batch` each invoke `(NAMESPACE)_TRI_warranty_review_workflow` as a sub-workflow. wxO also provides a **Call Agent** node — used in Lab 2 — that hands off to an LLM agent instead. Both are variations of the same **Call a tool** pattern; what changes is what you are calling.

> **Transport concern stays in the caller.** The sub-workflow receives a ready `document_ref` file reference and starts immediately at document classification — it has no knowledge of where the file came from or how it was retrieved. That is deliberate: the online caller fetches the PDF via `Fetch PDF from SOR` and passes the result in; the batch caller (Exercise 7) will do the same from its own source. Each caller owns its own transport step. The sub-workflow handles the review and decision logic — and does it the same way regardless of who called it. Extracting shared logic into reusable sub-workflows prevents copy-pasted workflow logic and monolithic sprawl ([Allen Chan #1 — Architectural Pitfalls](https://achan2013.medium.com/ai-agent-anti-patterns-part-1-architectural-pitfalls-that-break-enterprise-agents-before-they-32d211dded43) and [Allen Chan #7 — Tool Sprawl & Duplication](https://achan2013.medium.com/ai-agent-anti-patterns-part-2-tooling-observability-and-scale-traps-in-enterprise-agents-42a451ea84ec)).

> **Design note — a cleaner boundary is possible.** In the current implementation the two specialist-facing message nodes (`In Warranty Msg` and `Out of Warranty Message`) remain inside the sub-workflow, guarded by the `is_online_mode` branch. A purer design would move those nodes into the online caller as well, leaving the sub-workflow to always return a structured output that each caller acts on in its own way — the online caller displays the message, the batch caller queues a follow-up. That design fully separates *what happens* from *how the outcome is delivered*. It is not implemented here for simplicity, but it is a natural next step if you want to take the pattern further.

#### Steps

Rather than building the sub-workflow from scratch, you duplicate the existing warranty claim workflow and alter it into the shape required for reuse. The duplicate starts with the full canvas already in place — all the document processing nodes, the decision branch, and the user activity are there from the start. The steps below trim the online-only nodes, rewire the inputs, add an output contract, and add the batch path to the branch. This approach avoids duplicating the work already done and lets you focus only on what changes.

**Note the naming:** the original workflow you built in Exercises 1–5 is called `(NAMESPACE)_TRI_warranty_claim_workflow`. The sub-workflow you are about to create is called `(NAMESPACE)_TRI_warranty_review_workflow` — *Claim* replaced by *Review* — reflecting that it handles the review and decision logic only, not the full end-to-end claim process. The simplified online caller you build afterwards is called `(NAMESPACE)_TRI_warranty_claim_workflow_online` — *Claim* retained, *Online* appended — reflecting that it still owns the full online claim process, but now delegates the review and decision logic to the sub-workflow.

#### Build the Trinity Warranty Review Workflow

**Create the Sub-Workflow by Duplicating the Existing Workflow**

1. Open the hamburger menu and navigate to **BUILD & RUN** → **Active inventory** → **Agentic workflows**
2. Enter `(NAMESPACE)_TRI_warranty_claim_workflow` in the search field. Duplicating it in the next step creates a copy named `(NAMESPACE)_TRI_warranty_claim_workflow (copy)`
3. Click the three stacked dots (⋮) on the right of the workflow and select **Duplicate**
4. Click the three stacked dots (⋮) on the duplicated workflow and select **Open flow builder**
5. Click the **gear icon** (**Flow settings**) and change the name to `(NAMESPACE)_TRI_warranty_review_workflow`

![Flow settings with the renamed warranty review workflow](Lab%203%20screenshots/exercise-6/ex6-review-workflow-flow-settings.png)

*Figure 6.1: Flow settings with the renamed warranty review workflow*

6. Click the **Parameters** tab
7. Add a **File** input and name it `document_ref`
8. Add a **Boolean** input and name it `is_online_mode`
9. Add a **String** input and name it `user_email_id`
10. Click **Add output +** and add an output named `batch_review_result` of type **Object**, then add a **Boolean** property to it named `is_in_warranty`.

![Parameters tab showing three inputs and batch_review_result output](Lab%203%20screenshots/exercise-6/ex6-review-workflow-parameters.png)

*Figure 6.2: Parameters tab showing three inputs and batch_review_result output*

11. Click the **×** icon to close **Flow settings**
12. Click the **{x}** icon in the top left corner of the canvas to show the flow variables, then click **Add +**. Select **Object** as the data type, enter `batch_review_result` as the name, and click **Add**, then add a **Boolean** property to it named `is_in_warranty`.

    > **Note:** In a full implementation the `batch_review_result` object would carry additional properties such as `discount_code`, `resolution_type`, and `review_required` — enough for the batch orchestrator to decide what follow-up to send to the customer without any further lookups. For this exercise a single Boolean property is sufficient to demonstrate the structured output contract — this applies both to the output defined in step 10 and to the flow variable added here.

13. Click the **{x}** icon again, then click **Add +**. Select **Boolean** as the data type, enter `is_in_warranty` as the name, and click **Add**
14. Click the **End** node of the workflow — it now shows **1 output** — then click **Edit data mapping**. For the `is_in_warranty` child property, click the **{x}** icon and select the `batch_review_result.is_in_warranty` flow variable

![Map data for End showing the Auto-map setting for the batch_review_result output](Lab%203%20screenshots/exercise-6/ex6-end-node-automap.png)

*Figure 6.3: Map data for End showing the Auto-map setting for the batch_review_result output*

**Remove the Steps That Belong to the Online Caller Only**

The sub-workflow starts at document classification — the upload confirmation, customer details, PDF fetch, and deferred-upload paths all belong to the online caller or the process handling the batch, not to the shared review logic. They must be removed here so that neither the online caller nor the batch workflow inherits steps it is responsible for driving itself.

15. Wire the initial link in the **User activity** directly to the **Extract Warranty Doc Text** activity
16. Select and delete the following activities:
    - `Progress - Payment info & fraud risk`
    - `Parallel Pre-Check - Payment + Fraud`
    - `CUSTOMER DETAILS & UPLOAD READINESS`
    - `Wait for customer upload confirmation`
    - `Fetch PDF from SOR`
    - `INSTRUCTIONS FOR FUTURE UPLOAD SENT`
    - `REMINDER FOR FUTURE UPLOAD`

    > **Tip:** Hold the **Shift** key and draw a rectangle around the steps you want to remove, then press the **Delete** key on the keyboard to remove multiple steps at once.

    > **Tip:** After deleting several nodes the canvas can look cluttered. Click the middle icon — **Tidy canvas** — in the top-left toolbar (next to the flow variables icon) to automatically re-arrange the remaining nodes into a clean layout.

![Cleaned-up canvas starting at Extract Warranty Doc Text](Lab%203%20screenshots/exercise-6/ex6-review-workflow-canvas-trimmed.png)

*Figure 6.4: Cleaned-up canvas starting at Extract Warranty Doc Text*

**Resolve the Assignee for the User Activity**

The `Handle Warranty Claim` user activity must be assigned to a specific user at runtime. In the online use case the flow initiator is the specialist who started the review, so assigning the task back to them is natural. For a scheduled hourly invocation, the flow initiator is whoever (or whatever service account) scheduled the run — not necessarily the person who should receive the review — so the assignee must instead be a named user who is responsible for handling reviews when document extraction issues arise. The sub-workflow accepts a `user_email_id` input for exactly this reason: the caller passes in the right person for the context, and a Logic block resolves that name to a typed `User` object the platform can use for assignment.

17. Click the **+** sign on the line before the **Handle Warranty Claim** user activity, then select **Add a flow activity** → **Logic block**
18. Click the pencil icon next to the default name and replace it with `Build User Object`
19. Click **Define outputs**, then click **Add output +**. Set the data type to **User**, enter `user` as the name, and click **Add**
20. Switch to the **Code editor** tab and replace the default code with:

    ```python
    self.output.user = system.user.search_by_email(flow.input.user_email_id)
    ```

    > **Note:** The `user` output is dynamically constructed from the `user_email_id` input parameter passed into the sub-workflow. This allows the batch caller to specify which specialist should receive the HITL task for each claim, rather than always routing it to whoever initiated the workflow. In a scheduled batch run, the flow initiator is the user (or service account) that scheduled the run — not necessarily someone who should receive a review task — so relying on the flow initiator for HITL assignment would route tasks to the wrong person. Passing `user_email_id` explicitly ensures the right person is assigned regardless of how the workflow was triggered.

21. Close the dialog by clicking the **×** in the top right corner

![Build User Object Logic block with user output defined](Lab%203%20screenshots/exercise-6/ex6-build-user-object.png)

*Figure 6.5: Build User Object Logic block with user output defined*

22. Click the **Handle Warranty Claim** user activity node, then change the **Flow initiator** assignment to **User from a variable** and select `user` from the **Build User Object** step

![Handle Warranty Claim user activity assigned via User from a variable](Lab%203%20screenshots/exercise-6/ex6-handle-warranty-claim-user-assignment.png)

*Figure 6.6: Handle Warranty Claim user activity assigned via User from a variable*

**Wire the Sub-Workflow Input to the Document Processing Nodes**

The document processing nodes in the original workflow were reading the PDF URL produced by the `Fetch PDF from SOR` step. Now that step has been removed, each node must instead read from the `document_ref` input parameter. In addition, two of these nodes — **Extract Receipt Fields** and **Extract Warranty Card Fields** — have a user assignment that was previously set to the flow initiator; that assignment must also be updated to use the `user` variable resolved by the **Build User Object** Logic block. The **Document classifier** node has no such assignment, since **User Review** was left disabled for it back in Exercise 3.

23. Click the **Extract Warranty Doc Text** node, click **Edit data mapping**, and select `document_ref` for the **document_ref** input
24. Click the **Document classifier** node, click **Edit data mapping**, and select `document_ref` for the **document_ref** input
25. Click the **Extract Receipt Fields** node, click **Edit data mapping**, and select `document_ref` for the **document_ref** input, then change the **Flow initiator** assignment to **User from a variable** and select `user` from the **Build User Object** step
26. Click the **Extract Warranty Card Fields** node, click **Edit data mapping**, and select `document_ref` for the **document_ref** input, then change the **Flow initiator** assignment to **User from a variable** and select `user` from the **Build User Object** step
27. Click the **Select customer product** form node, then click the **pencil icon** in the **Fields** section to open the form editor. Select the **View receipt document** field and set `document_ref` from the flow inputs as the **Source file**

**Update the In Warranty? Branch for Online and Batch Paths**

The `In Warranty?` branch currently has two paths — **Yes** and **No** — that both route to specialist-facing message nodes. The sub-workflow must also handle the batch case, where no specialist is present and the outcome must instead be written to the flow output. A third path is added for this.

28. Click the **In Warranty?** branch node, then click **Add path +** to add a third path
29. Click the label of the **if** path and rename it to `Yes (Online)`
30. Click the label of the **else if** path and rename it to `No (Online)`
31. Click the **else / default** path label and rename it to `Batch`
32. Click **Edit condition** for the **Yes (Online)** path, click **Add condition +**, select the `is_online_mode` input, set the operator to `==`, and set the value to `True`
33. Click **Edit condition** for the **No (Online)** path and add the same condition: `is_online_mode == True`
34. Verify that the **Yes (Online)** path points at the **In Warranty Msg** node and the **No (Online)** path points at the **Out of Warranty Message** node — rewire either if needed

![In Warranty? branch with Yes Online, No Online, and Batch paths](Lab%203%20screenshots/exercise-6/ex6-in-warranty-three-paths.png)

*Figure 6.7: In Warranty? branch with Yes Online, No Online, and Batch paths*

35. Click **+** on the **Batch** path, then select **Add a flow activity** → **Logic block**
36. Click the pencil icon next to the default name and replace it with `Set Offline Output`
37. Click **Open code editor** and replace the default code with:

    ```python
    flow.private.batch_review_result.is_in_warranty = (flow.private.offer_type == 'In Warranty')
    ```

38. Close the dialog by clicking the **×** in the top right corner

![Completed Batch path with Set Offline Output Logic block](Lab%203%20screenshots/exercise-6/ex6-batch-path-set-offline-output.png)

*Figure 6.8: Completed Batch path with Set Offline Output Logic block*

> **Note:** In a production implementation the workflow would be redesigned so that user activities are reserved exclusively for the exceptional cases where a human genuinely needs to intervene — for example, when document extraction produces ambiguous results or when a product cannot be matched automatically and requires manual selection. All other user activities that exist solely to display informational messages to the specialist would need to be wrapped in `is_online_mode == True` branches. Without those guards, every batch run would create tasks for the named user even when nothing needs their attention and the flow could complete fully autonomously. For simplicity this has not been done in this exercise — the sub-workflow retains its existing user activity structure so you can focus on the structural changes that enable reuse rather than on exhaustive branch wiring.

#### Build the Online Trinity Warranty Claim Workflow

Now that the shared review logic lives in its own sub-workflow, the original warranty claim workflow needs to be updated to delegate to it. Rather than modifying the workflow you built in Exercises 1–5 directly — which would break the working solution you have verified so far — you make a second duplicate of it, rename it, and then adapt it to call `(NAMESPACE)_TRI_warranty_review_workflow` in place of the steps it now shares with the sub-workflow.

**Create the Online Workflow by Duplicating the Existing Workflow**

39. Open the hamburger menu and navigate to **BUILD & RUN** → **Active inventory** → **Agentic workflows**
40. Enter `(NAMESPACE)_TRI_warranty_claim_workflow` in the search field
41. Click the three stacked dots (⋮) on the right of the workflow and select **Duplicate**
42. Click the three stacked dots (⋮) on the duplicated workflow — `(NAMESPACE)_TRI_warranty_claim_workflow (copy)` — and select **Open flow builder**
43. Click the **gear icon** (**Flow settings**) and change the name to `(NAMESPACE)_TRI_warranty_claim_workflow_online`

    > **Note:** Observe that **Scheduling** is disabled on the **General** page — this is as expected, since scheduling was explicitly disabled when the original workflow was created in Exercise 1. The online workflow is always initiated by an agent in response to a live customer interaction, so scheduling is not applicable here.

![Flow settings with the renamed online workflow](Lab%203%20screenshots/exercise-6/ex6-online-workflow-flow-settings.png)

*Figure 6.9: Flow settings with the renamed online workflow*

44. Click the **+** sign on the line after the **Fetch PDF from SOR** step and select **Add a flow activity** → **Logic block**
45. Click the pencil icon next to the default name and replace it with `Determine Current User Name`, click **Define outputs**, add a **String** output named `current_user_email_id`, then switch to the **Code editor** tab and replace the default code with:

    ```python
    # retrieve the email_id of the user who started the flow
    self.output.current_user_email_id = system.context.get_variable('wxo_email_id', )
    ```

46. Click the **+** sign on the line after the **Determine Current User Name** step and select **Add a flow activity** → **Call a tool**
47. Enter `(NAMESPACE)_TRI_warranty_review_workflow` in the search field and drag and drop the workflow onto the line
48. Click the **Call a tool** step and select **Edit data mapping** and configure the following mappings:
    - Map all `customer_` inputs to the corresponding inputs of this flow
    - Map `document_ref` to the output of the **Fetch PDF from SOR** step
    - Set `is_online_mode` to `True` using the **Expression** mode
    - Map `user_email_id` to the `current_user_email_id` output of the **Determine Current User Name** step
49. Select and delete the following steps: **Extract Warranty Doc Text**, **Document classifier**, **Doc Type?**, and all steps following that branch — this includes the **Extract Receipt Fields** and **Extract Warranty Card Fields** extractor nodes, their HITL review forms, and all downstream steps through the warranty decision

    > **Tip:** Hold the **Shift** key and draw a rectangle around the steps you want to remove, then press the **Delete** key on the keyboard to remove multiple steps at once.

50. Click the **Tidy canvas** icon — the middle icon in the top-left toolbar, to the right of the **Flow variables** (**{x}**) icon — to automatically re-arrange the remaining nodes into a clean layout

![Simplified online workflow canvas calling Trinity Warranty Review Workflow](Lab%203%20screenshots/exercise-6/ex6-online-workflow-canvas.png)

*Figure 6.10: Simplified online workflow canvas calling Trinity Warranty Review Workflow*

**Update the Trinity Warranty Agent to Use the Online Workflow**

With the new online workflow in place, the Trinity Warranty Agent needs to be updated to use it instead of the original workflow. You remove the old tool and add the new one.

51. Open the hamburger menu and navigate to **BUILD & RUN** → **Active inventory** → **Agents**
52. Enter `(NAMESPACE)_TRI_warranty_agent` in the search field
53. Click the **`(NAMESPACE)_TRI_warranty_agent`** tile to open the agent builder
54. Click the **Tools** tab
55. Click the three stacked dots (⋮) on the **`(NAMESPACE)_TRI_warranty_claim_workflow`** tool tile, select **Remove**, then confirm the removal in the dialog that appears
56. Click **Add tool +**, then click **Local instance** and enter `(NAMESPACE)_TRI_warranty_claim_workflow_online` in the search field
57. Select **`(NAMESPACE)_TRI_warranty_claim_workflow_online`** from the results and click **Add to agent**

![Adding Trinity Warranty Claim Workflow Online to the agent](Lab%203%20screenshots/exercise-6/ex6-agent-tools-updated.png)

*Figure 6.11: Adding Trinity Warranty Claim Workflow Online to the agent*

**Test the Online Trinity Warranty Claim Workflow**

> **Note:** Do not use customer C-3DBZFE for this test. That customer's receipt triggers a HITL review step inside the Document extractor node, which is currently affected by a platform defect that prevents the sub-workflow from completing correctly in that path. Use customer C-11100 instead — their receipt extracts cleanly with no confidence issues, so the HITL review step is skipped and the flow completes without interruption.

1. Click the **Reset chat** icon in the top right of **Draft Preview** to start a fresh conversation.
2. In the **Draft Preview** chat window, enter the prompt:
    ```
    Customer C-11100 has a headset they bought from a reseller — it stopped working and they want warranty.
    ```
3. When the **CUSTOMER DETAILS & UPLOAD READINESS** form appears, click **Upload Now**.
4. When the **Wait for customer upload confirmation** form appears, click **Document Uploaded**.

The steps above were executed inside `(NAMESPACE)_TRI_warranty_claim_workflow_online`. From this point on, the document processing, extraction, and warranty determination steps run inside `(NAMESPACE)_TRI_warranty_review_workflow`, which was called by the online workflow as a sub-workflow.

5. Observe that no **Review document extraction** output appears — the receipt data extracted cleanly with no confidence issues, so no specialist review was required.
6. Observe the **Select customer product** form that appears next. Select **Focus Headset Pro 500** from the **Customer product** dropdown and click **Submit**.
7. Observe that the flow ends with an **In Warranty** verdict displayed in the chat.

8. Click the three stacked dots (⋮) on the Workflow tool tile, then select **Open flow inspector**.
9. Click the **View details** link for the latest flow instance.
10. Click the first **`(NAMESPACE)_TRI_warranty_review_workflow`** step — this is the `Call a tool` node inside `(NAMESPACE)_TRI_warranty_claim_workflow_online` that invokes the sub-workflow. Observe the **Inputs** and **Outputs**:
    - The **Inputs** show `document_ref`, `is_online_mode` set to `True`, and `user_email_id` populated with your email address.
    - The **Outputs** show `batch_review_result` — observe that it is empty, as expected: the sub-workflow only populates this output on the `Batch` path, and this run used `is_online_mode = True`.

    ![Sub-workflow Call a tool step showing Inputs and Outputs](Lab%203%20screenshots/exercise-6/ex6-test-sub-workflow-call-inputs-outputs.png)
    *Figure 6.12: Sub-workflow Call a tool step showing Inputs and Outputs*

11. Click the second **`(NAMESPACE)_TRI_warranty_review_workflow`** step — this is the sub-workflow itself executing. Observe that it contains all the document processing, catalog lookup, and warranty determination steps that were moved out of the online workflow.

    ![Sub-workflow execution steps in Flow inspector](Lab%203%20screenshots/exercise-6/ex6-test-sub-workflow-execution.png)
    *Figure 6.13: Sub-workflow execution steps in Flow inspector*

12. Click the **In Warranty?** step inside the sub-workflow and observe that the **Yes (Online)** path was taken — confirming that `is_online_mode = True` routed the flow to the specialist-facing message node rather than the batch output path.

    ![In Warranty? step showing Yes Online path taken](Lab%203%20screenshots/exercise-6/ex6-test-in-warranty-yes-online.png)
    *Figure 6.14: In Warranty? step showing Yes Online path taken*

13. Close the flow instance details by closing the tab/window that opened.
14. Close the Flow inspector view by clicking the **x** in the top right corner.

✅ Exercise 6 complete. You refactored the shared review logic into `(NAMESPACE)_TRI_warranty_review_workflow` (document classification, extraction, catalog lookup, warranty decision, dual-mode output) and simplified the online caller to delegate to it, confirmed end-to-end with customer C-11100. In Exercise 7, you will build the batch caller that iterates over pending claims using a Foreach node.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 7: Implementing the Batch Warranty Claim Workflow *(~25 mins — Optional)*

With the shared review logic in its own sub-workflow, this exercise builds the batch caller. `(NAMESPACE)_TRI_warranty_claim_workflow_batch` fetches the list of pending warranty claims from the SOR, iterates over them one at a time using a Foreach node, and invokes `(NAMESPACE)_TRI_warranty_review_workflow` for each item with `is_online_mode = False`. The sub-workflow's structured `batch_review_result` output drives the follow-up communication for each claim.

> **Lab Environment Note — Live vs. Preview Scheduling:** watsonx Orchestrate supports scheduling agentic workflows and agents to run automatically on a recurring schedule in the **Live** environment. In this lab, we build and test all assets locally in the **Agent Preview** without promoting them to live deployment. For testing and demonstration purposes, batch sweeps are triggered on demand using a dedicated agent — `(NAMESPACE)_TRI_warranty_batch_agent`. The workflow architecture is fully schedule-ready: in production, once promoted to Live, the exact same workflow can be scheduled via natural language in chat. Exercise 8 walks through the full scheduling architecture, configuration prerequisites, and operational lifecycle.

#### Steps

**Note the naming:** following the same convention as Exercise 6, the batch caller is called `(NAMESPACE)_TRI_warranty_claim_workflow_batch` — *Claim* retained, *Batch* appended — reflecting that it owns the full batch claim process, delegating the review and decision logic to `(NAMESPACE)_TRI_warranty_review_workflow`.

#### Build the Batch Warranty Claim Workflow

1. Open the hamburger menu and navigate to **BUILD & RUN** → **Active inventory** → **Agentic workflows**
2. Click **Add agentic workflow +** and name it `(NAMESPACE)_TRI_warranty_claim_workflow_batch`

    > **Note:** Unlike interactive workflows called during a live specialist chat, this batch workflow has no runtime caller passing customer data dynamically. For preview testing, we retrieve the current user's email inside the flow via a Logic block. In a production deployment where the workflow is truly scheduled, you would define `user_email_id` as a top-level input parameter of the workflow itself; when scheduling the workflow in chat, the administrator sets this input value directly in the schedule configuration form to designate the review owner or team inbox for any exceptions.

3. Click the **gear icon** (**Flow settings**), navigate to the **General** page, and observe that **Scheduling** is enabled by default — leave it enabled, then close **Flow settings** by clicking the **×** in the top right corner
4. Click **Add your first step +**, then select **Add a flow activity** → **Logic block**
5. Click the pencil icon next to the default name and replace it with `Set HITL user email id`
6. Click **Define outputs**, then click **Add output +**. Set the data type to **String**, enter `user_email_id` as the name, and click **Add**
7. Switch to the **Code editor** tab and replace the default code with:

    ```python
    # Interactive test: passes the current user's email to the sub-workflow.
    # For scheduled runs, replace with a hard-coded email address instead.
    self.output.user_email_id = system.context.get_variable('wxo_email_id', )
    ```

    > **⚠️ Testing note:** In this exercise the workflow is triggered on demand in preview — your email address is retrieved from the session context (`wxo_email_id`) and passed to the sub-workflow, which resolves it to a `User` object for HITL assignment. In a scheduled Live environment where no interactive user session exists at execution time, this parameter is supplied as a workflow input defined when creating the schedule (or hard-coded in the flow), ensuring task assignments route to the designated specialist team.

8. Close the dialog by clicking the **×** in the top right corner

9. Click the **+** sign on the line after the `Set HITL user email id` step, select **Call a tool**, enter `(NAMESPACE)_TRI_get_pending_warranty_requests` into the search field, and drag and drop the tool onto the flow
10. Click the pencil icon next to the default name and replace it with `Get Pending Warranty Documents`
11. Click the `Get Pending Warranty Documents` tool name link to inspect its outputs — it returns an array where each entry contains information about the customer and the document they uploaded

![Get Pending Warranty Documents step showing output array](Lab%203%20screenshots/exercise-7/ex7-get-pending-warranty-docs.png)

*Figure 7.1: Get Pending Warranty Documents step showing output array*

12. Click the **+** sign on the line after the `Get Pending Warranty Documents` step, then select **Add a flow control** → **For each**
13. Click the pencil icon next to the default name and replace it with `Iterate over all documents`
14. Keep execution **Sequential**
15. For **Select a list**, select **A variable** and choose `outstanding_warranty_requests` from the `Get Pending Warranty Documents` step
![Configuring Iterate over all documents flow control](Lab%203%20screenshots/exercise-7/ex7-config-iterate-over-all-docs.png)

*Figure 7.2: Configuring Iterate over all documents flow control*

16. Click **Add +** within the **Iterate over all documents** For each, select **Call a tool**, enter `(NAMESPACE)_TRI_fetch_baw_pdf` into the search field, and drag and drop the tool onto the flow, then click the pencil icon next to the default name and replace it with `Fetch PDF from SOR`
17. Click **Edit data mapping** on the `Fetch PDF from SOR` step, hover over the **customer_id** input variable, click the **{x}** variable icon, and select `current_item.customer_id` from the **Iterate over all documents** For each. Finally, click the **×** in the top-right corner to close the picker.
18. Click **Add +** on the line after the `Fetch PDF from SOR` step within the For each, select **Call a tool**, enter `(NAMESPACE)_TRI_warranty_review_workflow` into the search field, and drag and drop the workflow onto the flow
19. Click **Edit data mapping** on the `(NAMESPACE)_TRI_warranty_review_workflow` step and configure the following mappings:
    - Map `customer_id`, `customer_name`, `customer_email`, and `customer_phone` to the respective `current_item.*` variables from **Iterate over all documents**
    - Map `customer_tier` to `current_item.customer_status` from **Iterate over all documents** — note the name difference between the workflow input and the SOR field
    - Map `document_ref` to the file output of the `Fetch PDF from SOR` step
    - Set `is_online_mode` to `False` using **Expression** mode
    - Map `user_email_id` to the `user_email_id` output of the `Set HITL user email id` step

![(NAMESPACE)_TRI_warranty_review_workflow variable mapping](Lab%203%20screenshots/exercise-7/ex7-warranty-workflow-variable-mapping-docs.png)

*Figure 7.3: Configuring (NAMESPACE)_TRI_warranty_review_workflow data mapping*

20. Click **Add +** on the line after the `(NAMESPACE)_TRI_warranty_review_workflow` step within the For each, then select **Add a flow activity** → **Logic block**
21. Click the pencil icon next to the default name and replace it with `Outcome specific handling`

    > **Note:** This Logic block is a stub representing the outcome-specific handling that would follow each warranty review — for example, sending an email to the customer with their warranty decision or discount code based on the `batch_review_result` returned by the sub-workflow. It is not implemented here as it introduces no new wxO concepts beyond what you have already covered.

#### Build the Trinity Warranty Batch Agent

With the batch workflow built, you need an agent to run it from chat. Unlike `(NAMESPACE)_TRI_warranty_agent` — which is a full conversational agent equipped with multiple tools — this agent has a single purpose: give a specialist a way to trigger the batch run manually. It needs no special instructions beyond what the workflow description already tells it.

22. Open the hamburger menu and navigate to **BUILD & RUN** → **Active inventory** → **Agents**
23. Click **Create agent +**
24. Set the **Name** to `(NAMESPACE)_TRI_warranty_batch_agent`
25. Set the **Description** to: `Runs the Trinity warranty batch processing workflow on demand. Invoke this agent to process all pending warranty claims from the SOR backlog.`
26. Leave all other settings at their defaults and click **Save**
27. Click the **Tools** tab, then click **Add tool +** and select **Local instance**
28. Enter `(NAMESPACE)_TRI_warranty_claim_workflow_batch` in the search field, select it, and click **Add to agent**

#### Test the Batch Warranty Claim Workflow

29. In the **Draft Preview** chat window, enter:
    ```
    Process all pending warranty claims
    ```
30. Wait for the agent to complete — this can take 2-3 minutes, so be patient. It will respond with a message along the lines of:
    ```
    All pending warranty claims have been processed. Let me know if you need any further details or assistance!
    ```
![Testing Draft Batch Warranty Claim Workflow](Lab%203%20screenshots/exercise-7/ex7-warranty-workflow-draft-chat.png)

*Figure 7.4: Batch warranty claim workflow draft chat*

31. Open the **Flow inspector** from the three-dot menu (⋮) on the Workflow tool tile and click **View details** on the most recent run
32. Click the **Get Pending Warranty Documents** step and click **See all** next to the **Output** — observe that two records were returned, each containing the customer information and the binary document the customer uploaded

![Get Pending Warranty Documents Flow Event](Lab%203%20screenshots/exercise-7/ex7-pending-warranty-docs-flow-inspector.png)

*Figure 7.5: Get Pending Warranty Documents output in flow inspector*

33. Observe that the **Iterate over all documents** Foreach node contains an **Iteration 1** and an **Iteration 2** step — these represent the two sequential iterations of the For each loop, one for each retrieved record
34. Click **`(NAMESPACE)_TRI_warranty_review_workflow`** within **Iteration 1** and inspect its **Inputs** and **Outputs**:
    - In the **Inputs**, observe that `is_online_mode` is set to `False` and that the customer data fields are populated with the values from the first record
    - In the **Outputs**, observe the `batch_review_result` — note the out-of-warranty verdict returned by the sub-workflow
    - Click the same step in **Iteration 2** and compare — the customer data differs between the two calls, confirming each iteration processed a separate claim independently

![TRI_warranty_claim_workflow_batch Iteration 1](Lab%203%20screenshots/exercise-7/ex7-iteration-1-flow-inspector.png)

*Figure 7.6: TRI_warranty_claim_workflow_batch Iteration 1*

![TRI_warranty_claim_workflow_batch Iteration 2](Lab%203%20screenshots/exercise-7/ex7-iteration-2-flow-inspector.png)

*Figure 7.7: TRI_warranty_claim_workflow_batch Iteration 2*

35. Freely explore the steps inside the sub-workflow to observe that the document data was successfully extracted and the catalog item was found automatically — no HITL review was required for either claim
36. Click the **In Warranty?** step inside the sub-workflow and observe that the **Batch** path (`else` / default) was taken — because `is_online_mode` was `False`, the flow did not route to the **Yes (Online)** or **No (Online)** paths that display a message to a specialist. Instead, the **Set Offline Output** Logic block was invoked to write the verdict to the structured `batch_review_result` output, in contrast to an online run where the **In Warranty Msg** or **Out of Warranty Message** node would have been invoked instead

![In Warranty? Step Flow Inspection](Lab%203%20screenshots/exercise-7/ex7-in-warranty-batch-path.png)

*Figure 7.8: In Warranty Step Batch path taken*

### Exercise 7 Complete

✅ Exercise 7 complete. You built `(NAMESPACE)_TRI_warranty_claim_workflow_batch` — a batch caller that retrieves all pending warranty claims from the SOR and processes them one at a time using a Foreach node, invoking `(NAMESPACE)_TRI_warranty_review_workflow` as a sub-workflow for each claim with `is_online_mode = False`. You resolved the HITL user assignment using the `Set HITL user email id` Logic block, which retrieves the current user's email for manual preview runs and can be targeted to a designated reviewer in scheduled execution. You created `(NAMESPACE)_TRI_warranty_batch_agent` to trigger the batch run on demand, and verified the end-to-end execution through the Draft Preview chat. Exercise 8 walks through the full scheduling architecture and operational lifecycle in watsonx Orchestrate.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 8: Architecture Deep Dive — Scheduling Agentic Workflows *(~15 mins — Optional, Reading Only)*

In Exercises 6 and 7, you built and tested the batch processing architecture for Focus Corp's warranty backlog. As noted, in production an enterprise would not rely on a specialist manually prompting an agent to trigger batch sweeps; instead, the batch orchestrator would be triggered automatically on a recurring schedule (for example, every weeknight at 11:00 PM or hourly during business peaks).

Watsonx Orchestrate provides built-in task and workflow scheduling capabilities directly within the platform. In a future version of this lab, participants will be able to actively schedule agentic workflows through hands-on steps once the platform environment prerequisites are aligned. For now, this conceptual reading exercise details how scheduling works in wxO, how to configure workflows and agents for scheduling, the interaction model in chat, multi-agent inheritance rules, and the operational lifecycle.

---

#### 1. Platform Prerequisites & Dual-Level Configuration

Scheduling in watsonx Orchestrate is **disabled by default** across all assets. Enabling it requires explicit configuration at two separate levels:

```
┌────────────────────────────────────────────────────────┐
│  1. Workflow Level (Flow settings ⚙️)                  │
│     General → Scheduling: ON                           │
│     (Controls whether the workflow engine permits      │
│      background recurrence triggers)                   │
└───────────────────────────┬────────────────────────────┘
                            │ Added as Tool
                            ▼
┌────────────────────────────────────────────────────────┐
│  2. Agent Level (Agent Configuration)                  │
│     Behavior / Advanced settings → Scheduling: ON      │
│     (Enables the agent's scheduler skill & chat forms) │
└───────────────────────────┬────────────────────────────┘
                            │ Deployed
                            ▼
┌────────────────────────────────────────────────────────┐
│  3. Live Environment Deployment                        │
│     (Required for persistent recurring schedules)      │
└────────────────────────────────────────────────────────┘
```

1. **Workflow-Level Configuration:**
   - In the Agentic Workflow Canvas, open **Flow settings** (⚙️) → **General**.
   - Toggle **Scheduling** to **On**.
   - *Dependency Rule:* If a workflow with an active schedule is deleted or replaced with an incompatible signature, active schedule executions will fail. Always review active schedules prior to modifying inventory.

2. **Agent-Level Configuration:**
   - In the Agent Builder, navigate to **Behavior** (or **Advanced settings**).
   - Toggle **Scheduling** to **On**.
   - Attach the schedulable workflow as a tool (**Tools** → **Add tool** → Select workflow).

3. **Deployment Scope (Preview vs. Live):**
   - **Agent Preview:** Builders can test scheduling intents and observe form generation in the Agent Preview panel. However, preview mode enforces a **strict limit of 2 recurring executions**, and schedule artifacts remain tied only to that ephemeral browser session (reloading the page terminates the preview run context).
   - **Live Environment:** Persistent scheduling across weeks/months with full auditability requires publishing the agent and workflow to the **Live** environment.

---

#### 2. Autonomous Agent Scheduling vs. Deterministic Workflow Scheduling

watsonx Orchestrate supports two distinct scheduling paradigms:

| Scheduling Pattern | How It Works | Best Used For | Runtime Behavior |
| :--- | :--- | :--- | :--- |
| **Agent Prompt Scheduling** *(Autonomous)* | The schedule triggers the agent with a natural language instruction (e.g., *"Triage unassigned Jira defects and summarize escalations"*). | Dynamic investigations, research tasks, complex triage across multiple tools. | The agent uses LLM reasoning at execution time to choose tools and formulate decisions. If parameters are ambiguous, it may post follow-up questions to the chat thread. |
| **Workflow Scheduling** *(Deterministic)* | The schedule directly targets a pre-registered Agentic Workflow with fixed or pre-bound input parameters. | Batch processing (like Trinity warranty batch), system data synchronizations, standardized reporting, ETL jobs. | The workflow engine executes the exact step graph deterministically using pre-configured inputs. The accompanying prompt serves as contextual metadata. |

---

#### 3. Multi-Agent Inheritance & Security Scoping

When deploying schedules across multi-agent topologies (such as Trinity's Orchestrator and Specialist structure), specific boundary rules apply:

- **Top-Level Agent Entry Point:** Scheduling must be enabled on the primary agent the user interacts with. Scheduling capabilities **do not automatically propagate** down to collaborator agents.
- **Collaborator Execution:** A top-level agent with scheduling enabled *can* trigger scheduled workflows that delegate sub-tasks to collaborator agents—even if those collaborator agents have scheduling disabled.
- **Direct Specialist Interaction:** If users or administrators need to schedule tasks directly against a specialist agent (e.g., `TRI_warranty_batch_agent`), scheduling must be explicitly enabled on that specialist's configuration.
- **Identity & Access Context:**
  - Scheduled workflows run under the **identity and security permissions of the user who creates the schedule**.
  - Users can only schedule agents and workflows they have explicit permission to access.
  - The minimum supported scheduling frequency is **5 minutes**.

---

#### 4. Natural Language Scheduling & Interactive Chat Forms

Users do not write raw cron strings or JSON payloads. In wxO, scheduling is conversational and guided by in-chat interactive forms:

```
User Prompt (Natural Language)
  "Schedule the Trinity Warranty Batch Workflow to run every weekday at 11 PM EST"
                          │
                          ▼
Agent Intent Recognition & Form Presentation
  ┌────────────────────────────────────────────────────────┐
  │  Schedule Configuration Form                           │
  ├────────────────────────────────────────────────────────┤
  │  Prompt:        Run nightly warranty claim processing  │
  │  Status:        [ Active / Inactive ]                  │
  │  Workflow:      [ TRI_warranty_claim_workflow_batch ▼] │
  │  Frequency:     [ Once | Minutes | Hourly | Daily |    │
  │                   Weekly | Monthly ]                   │
  │  Timing:        11:00 PM                               │
  │  Timezone:      America/New_York (EST)                 │
  │  Start Date:    Today                                  │
  │  End Date:      (Optional)                             │
  │  Parameters:    user_email_id: warranty-ops@focus.com  │
  └────────────────────────────────────────────────────────┘
                          │ Save & Confirm
                          ▼
Schedule Registered (Generated Cron Expression & Next Occurrence)
```

#### Natural Language Date & Timing Capabilities
The agent's built-in scheduler parser natively interprets:
- **Relative & Natural Timings:** *"every weekday at 9 AM"*, *"every 2 hours"*, *"first day of every month at 8:00"*, *"tomorrow afternoon"*.
- **Timezone Awareness:** Detects the user's browser timezone by default, while supporting explicit overrides (*"10:00 AM UTC"*, *"18:00 CET"*). Daylight Saving Time transitions are resolved automatically without shifting execution hour.

---

#### 5. Schedule Lifecycle Management in Chat

Administrators and specialists manage active schedules entirely through conversational commands:

| Action | Example Natural Language Prompts | Platform Response / Behavior |
| :--- | :--- | :--- |
| **List / View** | • `"Show my active schedules"`<br>• `"List all scheduled tasks"`<br>• `"Show details for the nightly batch schedule"` | Returns a tabular summary displaying Schedule ID, Status (`Active`, `Paused`, `Completed`), Target Workflow, Cron Timing, and Next Run Time. |
| **Update / Modify** | • `"Change the batch workflow to run at midnight instead of 11 PM"`<br>• `"Update the sales report schedule to Fridays"` | Opens the pre-filled interactive configuration form in chat for adjustment and re-saving. |
| **Pause / Resume** | • `"Pause the nightly warranty claim schedule"`<br>• `"Resume the warranty batch schedule"` | Toggles status between `Active` and `Inactive` without deleting the recurrence configuration. |
| **Delete** | • `"Delete the schedule for Trinity Warranty Batch"`<br>• `"Remove schedule SCH-88231"` | Prompts for deletion confirmation. *Note: Schedule deletion is permanent and immediately halts all future runs.* |

---

#### 6. Execution Monitoring, HITL Limitations & Results Handling

#### Results Delivery
- When a scheduled workflow finishes, execution output and diagnostic summaries are posted back to the original chat thread where the schedule was authored.
- If the original thread is closed or archived, wxO initializes a new thread session under that user's workspace to deliver output.
- For purely background batch workflows with structured return codes, completions run quietly, avoiding chat noise unless alert thresholds or errors occur.

#### Execution Audit & Flow Inspector
- Detailed step-level execution history, payload variables, and node logs are tracked within the **Flow Inspector** (accessible via the workflow's ⋮ menu → **Open flow inspector**).
- The inspector maintains historical records containing execution status (Success/Failed), trigger timestamps, run duration, and step-by-step inputs/outputs.

#### Handling Human-in-the-Loop (HITL) in Scheduled Runs
When a scheduled workflow runs in the Live environment and encounters a step requiring human input:
- The platform posts a notification and task form to the chat thread associated with the schedule.
- When multiple scheduled tasks require user input in the same thread, wxO queues the activities, allowing the specialist to select and resolve them.
- If the original thread was closed, wxO opens a new notification thread for the user.

```
                  ┌─────────────────────────────┐
                  │ Scheduled Execution Starts  │
                  └──────────────┬──────────────┘
                                 │
                                 ▼
                  ┌─────────────────────────────┐
                  │ Automated Backend Logic     │ (Runs in background)
                  └──────────────┬──────────────┘
                                 │
                                 ▼
                  ┌─────────────────────────────┐
                  │ Human in the Loop (HITL)?   │
                  └──────┬───────────────┬──────┘
                   No    │               │ Yes
                         ▼               ▼
          ┌─────────────────────────┐  ┌─────────────────────────┐
          │ ✅ Completes quietly to │  │ 🔔 Thread Notification:  │
          │    Structured Output    │  │    Posts task form to    │
          │                         │  │    chat thread for review│
          └─────────────────────────┘  └─────────────────────────┘
```

- **Architectural Best Practice for Batch Operations:** While wxO supports delivering notifications and forms when a scheduled task requires human intervention, high-volume batch jobs are typically designed for **straight-through automated processing**. Discrepancies or edge cases can be flagged in the System of Record or queued for asynchronous specialist review rather than generating repetitive individual chat prompts during nightly batch runs.

---

### Exercise 8 Summary

In this reading exercise, you examined the complete scheduling subsystem in watsonx Orchestrate:
- How **dual-level enablement** (Flow settings ⚙️ + Agent Behavior) controls scheduling capabilities.
- The distinction between **autonomous agent scheduling** and **deterministic workflow scheduling**.
- Multi-agent scoping rules, where scheduling is bound to top-level entry agents and runs under the creator's identity.
- Conversational scheduling with **interactive in-chat forms**, natural language time parsing, and full lifecycle control (list, edit, pause, delete).
- The architectural reason why production scheduled workflows must be designed for **straight-through headless execution** without blocking HITL steps.

**IBM watsonx Orchestrate docs:**
- [Scheduling agentic workflows in chat](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=builder-scheduling-agentic-workflows-in-chat)
- [Enabling scheduling for agents](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=behavior-enabling-scheduling-agents)
- [Scheduling tasks](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=chat-scheduling-tasks)

[↑ Back to Table of Contents](#table-of-contents)

---

## Lab Complete

This concludes the **Build an External Warranty Claim Agentic Workflow** lab.

### What You Built and Learned

- **Built the core warranty claim workflow (`(NAMESPACE)_TRI_warranty_claim_workflow_online`) and its AI agent (`(NAMESPACE)_TRI_warranty_agent`)** — integrating native AI document classification and field extraction with built-in HITL verification, parallel branch processing for concurrent SOR/security tool calls, and decision-table evaluation of customer tier × warranty expiry rules.
- **Extracted the shared review logic into a modular sub-workflow (`(NAMESPACE)_TRI_warranty_review_workflow`)** using the Call Flow activity with dynamic, dual-mode routing between online and batch callers.
- **Built a batch orchestrator (`(NAMESPACE)_TRI_warranty_claim_workflow_batch`) and its agent (`(NAMESPACE)_TRI_warranty_batch_agent`)** that queries pending SOR documents and processes them with the Foreach loop control, reusing the same review sub-workflow with `is_online_mode = False`.
- **Configured variable-driven HITL user assignment**, targeting task forms to active specialists via typed user variables across both the online and batch paths.
- **Explored the scheduling subsystem** — its architecture, prerequisites, multi-agent scoping, and lifecycle management for running agents and workflows on a recurring basis.

### Key References & Further Reading

**IBM watsonx Orchestrate & ADK Documentation:**
- [Agentic Workflow Decision Guide](https://developer.watson-orchestrate.ibm.com/agents/agent_design/agentic_workflow_decision_guide)
- [Foundational Architecture & The Agent-as-Business-Process Fallacy](https://developer.watson-orchestrate.ibm.com/agents/agent_design/foundational_architecture)
- [Tooling Scalability & Anti-Patterns](https://developer.watson-orchestrate.ibm.com/agents/agent_design/tooling_scalability)
- [Knowledge & Document Processing](https://developer.watson-orchestrate.ibm.com/agents/agent_design/knowledge_processing)
- [Flows & Error Handling](https://developer.watson-orchestrate.ibm.com/tools/flows/error_handling)

**Allen Chan's Agent Anti-Patterns Blog Series:**
- [Part 1: Architectural Pitfalls (#1–#6)](https://achan2013.medium.com/ai-agent-anti-patterns-part-1-architectural-pitfalls-that-break-enterprise-agents-before-they-32d211dded43) — *includes #1 The Monolithic Agent and #2 The Agent-as-Business-Process Fallacy*
- [Part 2: Tooling, Observability, and Scale Traps (#7–#15)](https://achan2013.medium.com/ai-agent-anti-patterns-part-2-tooling-observability-and-scale-traps-in-enterprise-agents-42a451ea84ec) — *includes #7 Tool Sprawl & Duplication and #9 Agent-Washing*
- [Part 3: Knowledge & Document Processing (#16–#23)](https://achan2013.medium.com/ai-agent-anti-patterns-part-3-knowledge-document-processing-0caf472856ff) — *includes #22 Mixing Extraction with Processing and #23 Lazy Field Definitions*
- [Part 4: MCP Tools & Integration Layer (#24–#33)](https://achan2013.medium.com/ai-agent-anti-patterns-part-4-b72d77b95d61)
- [Part 5: Prompt Design & The Illusion of Control (#34–#41)](https://achan2013.medium.com/agent-anti-patterns-part-5-05da1c3c1828) — *includes #37 Natural Language Workflow Engine*
- [Part 6: Testing, Evaluation & Governance (#42–#48)](https://achan2013.medium.com/agent-anti-patterns-part-6-257c6b7ff437) — *includes #43 The Copilot-as-Autopilot Fallacy*

### Next Steps

- **Explore the other workflow lab (Lab 2):** If you haven't completed Lab 2 (*Billing Dispute Resolution*), explore it to see an alternative approach to workflow generalization, User Activities, and multi-agent interaction.
- **Explore more document processing capabilities:** Dive deeper into the configuration options for the native Document AI and OCR nodes in Agentic Workflows, including custom field definitions, confidence thresholds, and alternative document schemas.
- **Discover additional Agentic Workflow capabilities:** While Labs 2 and 3 cover the core foundation—parallel branches, logic blocks, decision tables, Document AI, sub-workflows (Call Flow), and collection loops (Foreach)—watsonx Orchestrate offers many more flow activities and controls to explore for enterprise automation.
- **Connect with the broader Trinity solution:** Review the remaining Trinity labs to see how multi-agent collaboration, specialist delegation, tools, and front-end channels work together end-to-end.

Congratulations on completing the lab!

[↑ Back to Table of Contents](#table-of-contents)

---

## Appendix: Full Warranty Discount Decision Table

The simplified three-rule table in Exercise 5 is sufficient to complete the lab. The full Trinity solution uses the 17-rule table below, which covers all customer tiers, in-warranty and out-of-warranty scenarios, and graduated expiration bands. Review this as a reference to understand how the complete business logic is modelled.

The table uses 5 condition columns for `days_expired` because each comparison operator requires a separate column in the wxO UI: **Exact match** for the in-warranty check (days_expired = 0), **Maximum** for the 0–90 day band, **Range inclusive** for the 91–180 and 181–365 bands, and **Minimum** for the over-365 band. A blank cell means "skip this condition for this row". Rule order is critical — more specific conditions (e.g. Platinum + exact days band) must appear before general ones, or the general rule fires first.

The 17 rules are:

**Condition Columns:**

<table border="1" cellpadding="5" cellspacing="0">
<thead>
<tr>
<th rowspan="2">Rule</th>
<th rowspan="2">Days Expired (Exact)</th>
<th rowspan="2">Customer Tier</th>
<th rowspan="2">Days Expired (Max)</th>
<th colspan="2">Days Expired (Range Inclusive)</th>
<th rowspan="2">Days Expired (Min)</th>
</tr>
<tr>
<th>Minimum inclusive</th>
<th>Maximum inclusive</th>
</tr>
</thead>
<tbody>
<tr><td>1</td><td>0</td><td>Platinum</td><td></td><td></td><td></td><td></td></tr>
<tr><td>2</td><td>0</td><td>Gold</td><td></td><td></td><td></td><td></td></tr>
<tr><td>3</td><td>0</td><td>Silver</td><td></td><td></td><td></td><td></td></tr>
<tr><td>4</td><td>0</td><td></td><td></td><td></td><td></td><td></td></tr>
<tr><td>5</td><td></td><td>Platinum</td><td>90</td><td></td><td></td><td></td></tr>
<tr><td>6</td><td></td><td></td><td>90</td><td></td><td></td><td></td></tr>
<tr><td>7</td><td></td><td>Platinum</td><td></td><td>91</td><td>180</td><td></td></tr>
<tr><td>8</td><td></td><td>Gold</td><td></td><td>91</td><td>180</td><td></td></tr>
<tr><td>9</td><td></td><td></td><td></td><td>91</td><td>180</td><td></td></tr>
<tr><td>10</td><td></td><td>Platinum</td><td></td><td>181</td><td>365</td><td></td></tr>
<tr><td>11</td><td></td><td>Gold</td><td></td><td>181</td><td>365</td><td></td></tr>
<tr><td>12</td><td></td><td>Silver</td><td></td><td>181</td><td>365</td><td></td></tr>
<tr><td>13</td><td></td><td></td><td></td><td>181</td><td>365</td><td></td></tr>
<tr><td>14</td><td></td><td>Platinum</td><td></td><td></td><td></td><td>365</td></tr>
<tr><td>15</td><td></td><td>Gold</td><td></td><td></td><td></td><td>365</td></tr>
<tr><td>16</td><td></td><td>Silver</td><td></td><td></td><td></td><td>365</td></tr>
<tr><td>17</td><td></td><td></td><td></td><td></td><td></td><td>365</td></tr>
</tbody>
</table>

**Action Columns:**

<table border="1" cellpadding="5" cellspacing="0">
<thead>
<tr>
<th>Rule</th>
<th>discount_pct</th>
<th>discount_note</th>
<th>offer_type</th>
</tr>
</thead>
<tbody>
<tr><td>1</td><td>30</td><td>Platinum loyalty - 30%</td><td>In Warranty</td></tr>
<tr><td>2</td><td>20</td><td>Gold loyalty - 20%</td><td>In Warranty</td></tr>
<tr><td>3</td><td>15</td><td>Silver loyalty - 15%</td><td>In Warranty</td></tr>
<tr><td>4</td><td>10</td><td>Standard loyalty - 10%</td><td>In Warranty</td></tr>
<tr><td>5</td><td>30</td><td>Platinum loyalty beats 20% SOR (0-90 days)</td><td>Out of Warranty</td></tr>
<tr><td>6</td><td>20</td><td>Within 90 days expired - 20% SOR policy</td><td>Out of Warranty</td></tr>
<tr><td>7</td><td>30</td><td>Platinum loyalty beats 15% SOR (91-180 days)</td><td>Out of Warranty</td></tr>
<tr><td>8</td><td>20</td><td>Gold loyalty beats 15% SOR (91-180 days)</td><td>Out of Warranty</td></tr>
<tr><td>9</td><td>15</td><td>Within 180 days expired - 15% SOR policy</td><td>Out of Warranty</td></tr>
<tr><td>10</td><td>30</td><td>Platinum loyalty beats 10% SOR (181-365 days)</td><td>Out of Warranty</td></tr>
<tr><td>11</td><td>20</td><td>Gold loyalty beats 10% SOR (181-365 days)</td><td>Out of Warranty</td></tr>
<tr><td>12</td><td>15</td><td>Silver loyalty beats 10% SOR (181-365 days)</td><td>Out of Warranty</td></tr>
<tr><td>13</td><td>10</td><td>Within 365 days expired - 10% SOR policy</td><td>Out of Warranty</td></tr>
<tr><td>14</td><td>30</td><td>Platinum loyalty - over 1 year expired</td><td>Out of Warranty</td></tr>
<tr><td>15</td><td>20</td><td>Gold loyalty - over 1 year expired</td><td>Out of Warranty</td></tr>
<tr><td>16</td><td>15</td><td>Silver loyalty - over 1 year expired</td><td>Out of Warranty</td></tr>
<tr><td>17</td><td>10</td><td>Over 1 year expired - standard loyalty 10% applied</td><td>Out of Warranty</td></tr>
</tbody>
</table>

[↑ Back to Table of Contents](#table-of-contents)


