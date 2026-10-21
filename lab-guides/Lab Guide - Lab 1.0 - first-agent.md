# Lab 1.0 — Worker Agent: Building Your First Agent

Version 1.0.0 / Authors: Ramy Shosha, Olaf Hahnl, Juergen Lukas / Duration: ~1 hour (1.5 hours including optional)

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
2. [Lab Instructions](#2-lab-instructions)
   - [Exercise 1: Create Your First Agent](#exercise-1-create-your-first-agent-25-min) *(~25 min)*
   - [Exercise 2 *(Optional)*: Build the Same Agent with Bob](#exercise-2-optional-build-the-same-agent-with-bob-20-min) *(~20 min)*
   - [Exercise 3: Define Behavioural Boundaries](#exercise-3-define-behavioural-boundaries-15-min) *(~15 min)*
   - [Exercise 4: Evaluate and Deploy](#exercise-4-evaluate-and-deploy-25-min) *(~25 min)*
3. [Lab Complete](#lab-complete)

---

## 1. Lab Introduction

The difference between a chatbot and an agent — an agent can act on live systems through tools, while a chatbot can only answer from what it knows — is covered in **Introduction to watsonx Orchestrate → Core terminology → Chatbot vs. Agent**. This lab puts that distinction to the test.

In this lab you build your first wxO agent from scratch, mastering every mandatory field and the authoring decisions that underpin every agent you will build from here on. It ends deliberately without a tool attached — your finished agent will still behave like a chatbot, answering from training knowledge alone, because it has nothing to act with yet. That gap is the point: it is what motivates Lab 1.1, where you attach real tools and watch the same agent start acting instead of guessing.

### 1.1 Lab Scenario

Focus Corp customer support specialists help customers resolve a wide range of issues — from technical problems and warranty claims to billing disputes and order enquiries. Handling any of these typically means accessing customer data spread across multiple backend systems: order history, product catalog, billing records, and more. The Order Management agent you build in this lab is the piece of the Trinity solution that brings order and catalog lookups together into a single conversational entry point.

In this lab you will build the bare frame of `TRI_order_agent` — the Order Management agent in the full Trinity solution — covering name, description, model, instructions, and style.

[SCREENSHOT NEEDED — Figure 1. Solution architecture diagram showing `TRI_order_agent` in context of the full Trinity multi-agent system, with Tools not yet attached (greyed out / marked "added in Lab 1.1").]

### 1.2 Lab Setup Instructions

#### 1.2.1 Prerequisites

1. Completed **Introduction to watsonx Orchestrate** (or familiar with the core terminology covered there).
2. Your SOR user ID, SOR password, and SOR base URL. Your SOR user ID is your assigned namespace. To get these values, see the labs page of the event GitHub repository, section **2. Grab your system of record credentials**.
3. The ADK CLI (version 2.15 or later) installed, connected to the event tenant, and authenticated.
4. The Trinity-Event repository (the event GitHub repository) cloned or downloaded to your machine. To get it, see the labs page of the event GitHub repository, section **4. Clone this GitHub**.
5. *(Exercise 2 only, optional)* IBM Bob installed and signed in on your machine, with permission to install a VS Code extension and uv. You will also need a wxO API key, which Bob asks for when it connects to the tenant.

> 💡 **Tip:** To install, update, or connect the ADK CLI, see **Setup & Event Credentials**, sections **1.1 Before the Event** and **1.2 On Event Day**. If a command fails with an authentication or token error, see the note on Authentication Expiry in section 1.2.

**Namespace prefix convention:** All participants work on a shared wxO tenant. Every artifact you create must be prefixed with your assigned user ID (for example: `usr001`, `usr002`) followed by `_TRI_` to avoid naming conflicts (for example: `usr001_TRI_order_agent`). You will see `(NAMESPACE)_TRI_` as a placeholder throughout this lab — in instructions, tables, and commands — replace `(NAMESPACE)` with your assigned user ID (e.g. `usr001`) wherever it appears.

#### 1.2.2 Lab Solution Artifacts

Solution artifacts for this lab are stored in `labs/lab-1x/solution/` and organized by artifact type (agents/, tools/, knowledge_bases/). Artifact filenames include a lab prefix (e.g., `lab-1-0_`, `lab-1-1_`) to clearly indicate which lab or lab phase they belong to. Filenames may also include suffixes that indicate the state of the artifact (e.g., `_start` for the beginning state, `_complete` for the end state after all exercises in that phase). These artifacts can be reviewed as references. At specific points in each exercise, "If you are starting here" sections explicitly mention which artifact file to import if you skipped earlier exercises or need to reset your work.

#### 1.2.3 Test Prompts Used in This Lab

You will send these prompts to your agent during the lab. They are repeated in each step where they are used.

| Prompt | Used in |
|---|---|
| `Can you look up order O-DF340K?` | Exercise 1 — test the bare agent |
| `What is the capital of France?` | Exercise 1 (no boundaries) and Exercise 3 (with boundaries) |
| `Look up order O-DF340K.` | Exercise 4 — first evaluation test case |
| `Find replacement gaming laptops in the price range $1,000–$2,000.` | Exercise 4 — second evaluation test case |

[↑ Back to Table of Contents](#table-of-contents)

---

## 2. Lab Instructions

---

### Exercise 1: Create Your First Agent (~25 min)

In this exercise, you will create `TRI_order_agent` — the Order Management worker agent — from scratch in the wxO UI, mastering every mandatory field and the authoring decisions that underpin every agent you will build from here on.

IBM watsonx Orchestrate docs: [`Getting started with building agents`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=agents-getting-started-building)

**If you are starting here:** No artifacts need to be imported — this exercise builds the agent from scratch.

> **Note:** The Agent Builder has no explicit **Save** button — it automatically saves each field once you step out of it or make a change in a dropdown or similar control. Use **Create version +** in the top-right corner only when you want to snapshot the current configuration as a named version (not required for this lab).

> **Tip:** Code values shown in the tables throughout this exercise are selectable — highlight and copy them directly into the UI fields.

#### Steps

1. Expand the hamburger menu (☰) in the top left, click **Active inventory** under the **BUILD & RUN** category, then click **Agents**. This is the "Build agents and tools" landing page — a left-hand rail (**All agents** / **All tools** / **All knowledge**) and a searchable grid of every agent on the shared tenant, each card showing its description, tool/agent counts, and Draft or Live status.

   > **Note:** This same page is where you reopen an agent later — search for `(NAMESPACE)_TRI_order_agent` and click its card (or the arrow in the card's bottom-right corner) to return to the editor. You do not need to repeat the creation flow to make further changes.

![The "Build agents and tools" page showing the left-hand rail (All agents / All tools / All knowledge) and the agent grid with sample cards](Lab%201.0%20screenshots/exercise-1/ex1-step1-build-agents-page.png)

*Figure 2. The "Build agents and tools" page showing the left-hand rail (All agents / All tools / All knowledge) and the agent grid with sample cards.*

2. Click **Create agent +** in the top-right corner.

   The dialog offers four low-code paths built into the wxO UI — this lab uses the first:

   | Path | Description |
   |---|---|
   | **Create from scratch** | Configure every field step by step. *(This is what you will do.)* |
   | **Build with AI (Preview) → Build with Bob** | Conversational agent authoring using IBM Bob and pre-loaded ADK skills. Optional — see Exercise 2. |
   | **Build from template** | Start from a pre-built IBM or ISV agent from the Catalog. |
   | **Import LangGraph agent** | Import an existing LangGraph agent definition directly into wxO and expose it as a native agent. |

![The "Create an agent" dialog showing all four creation paths](Lab%201.0%20screenshots/exercise-1/ex1-step2-create-agent-dialog.png)

*Figure 3. The "Create an agent" dialog showing all four creation paths.*

   > **Note:** Agents can also be created outside the UI using pro-code paths — for reference only, not used in this lab:
   > - ADK Extension in VS Code or Bob — generates and refines agent YAML
   > - Raw YAML import — `orchestrate agents import -f <file.yaml>`
   > - AI coding assistant (Bob, Cursor, Claude Code) — generate YAML externally, then import

3. Select **Create from scratch**.

   You land on the **Behavior** tab of the new agent — a single editor screen with fields on the left and a live **Draft Preview** chat on the right. At the top, a segmented control switches between three modes:

   ![The Agent Builder showing the Build / Evaluate / Deploy mode selector and the Behavior tab open](Lab%201.0%20screenshots/exercise-1/ex1-step3-agent-builder-modes.png)

   *Figure 4. The Agent Builder showing the Build / Evaluate / Deploy mode selector and the Behavior tab open.*

   | Mode | What happens here |
   |---|---|
   | **Build** | Configure all fields; attach knowledge, tools, and collaborator agents |
   | **Evaluate** | Save test conversations; run bulk evaluations; review pass/fail results |
   | **Deploy** | Deploy to Draft preview or Live; configure channels |

   Within **Build** mode, a second row of tabs appears just below: **Behavior** (name, model, description, instructions, guidelines, voice, advanced settings — everything in this exercise), **Knowledge** (covered in Lab 1.2), **Tools** (covered in Lab 1.1), and **Agents** (collaborators — covered in Lab 1.3). You stay on **Behavior** for all of Exercise 1.

4. Under **Profile**, in the **Agent name** field, enter:

   | Field | Value |
   |---|---|
   | **Agent name** | `(NAMESPACE)_TRI_order_agent` |

   > **Note:** The name you enter is a display name — it's what appears throughout the UI and can be changed freely. When the agent is created, wxO derives a machine-readable identifier from the display name (converting to lowercase, replacing spaces with underscores, removing special characters). This derived identifier is fixed and used internally in exported YAMLs, test case definitions, and when this agent is referenced as a collaborator in other agents. The display name is for you; the derived identifier is for the system.

5. Leave the **Model** dropdown on its **default** entry (currently **GPT-OSS 120B — OpenAI (via Groq)**).

   > **Note:** All agents in this lab use the default model. Do not experiment with other models during the exercises — behavioural differences between models can make the steps harder to diagnose.

   > **Going further — Model selection and the AI Gateway**
   >
   > wxO is model-agnostic — any LLM can be registered and made available in the model dropdown via the AI Gateway. Models are defined in a short YAML spec and imported with `orchestrate models import`. Supported providers include watsonx.ai (IBM Granite), OpenAI, Anthropic, Google, AWS Bedrock, Azure OpenAI, Mistral, Groq, and others.
   >
   > You may also see an IBM Granite model from watsonx.ai that the team has pre-registered on the shared tenant — it is listed to show what the AI Gateway makes possible. Keep the default model selected for this lab.
   >
   > ADK Docs: [`llm/managing_llm`](https://developer.watson-orchestrate.ibm.com/llm/managing_llm) · [`llm/model_policies`](https://developer.watson-orchestrate.ibm.com/llm/model_policies)

6. In the **Description** field, enter a short one-sentence summary of what this agent does. For example:

   | Field | Value |
   |---|---|
   | **Description** | `Handles order and catalog lookups for Focus Corp customer support specialists.` |

   > **Note:** Keep the description brief here — one sentence is enough. When this agent is later registered as a collaborator under an orchestrator, this description becomes the routing signal the orchestrator reads to decide when to call it. That pattern is covered in Lab 1.3.

7. In the **Instructions** field, enter the following:

   | Field | Value |
   |---|---|
   | **Instructions** | `Order worker agent. Use available tools to handle order and catalog lookup requests.`<br>`Return tool responses in full. Do not summarise, omit, or paraphrase any field.`<br>`If a tool fails, tell the specialist which lookup could not be completed and ask them to try again or provide the information manually. Never suggest actions or capabilities beyond your available tools.` |

   > **Note:** These three lines are all `TRI_order_agent` needs — concise, one job per sentence. Trinity's production agents average 3 lines of instructions for exactly this reason. This is also the field where first-timers make three common mistakes — notice what was deliberately avoided here:
   > - **Monolithic Mega-Prompt** — resist writing a wall of text. A 500-line prompt causes context compression and nondeterministic behaviour, not better control. ADK Docs: [`agents/agent_design/foundational_architecture`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/foundational_architecture)
   > - **Agent-as-Business-Process** — agents approximate and reason; they do not reliably execute a rigid, linear sequence of steps every time. A fixed sequence belongs in a workflow, not in instructions.
   > - **Agent-Washing** — wrapping a single deterministic API call in an agent reasoning loop "because it seems agentic" adds ReAct overhead with no benefit. ADK Docs: [`agents/agent_design/tooling_scalability`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/tooling_scalability)

8. Leave **Guidelines** and **Voice** untouched for now — you will use Guidelines in Exercise 3, and this lab does not use a voice configuration.

9. Expand **Advanced settings** at the bottom of the panel and confirm the **Style** field is set to **ReAct Core** (`react_core`). Leave it on the default — do not change it.

   ![Advanced settings panel showing the Style field set to ReAct Core](Lab%201.0%20screenshots/exercise-1/ex1-step9-advanced-settings-style.png)

   *Figure 5. Advanced settings panel showing the Style field set to ReAct Core.*

   > **Note:** ReAct Core is a Think → Act → Observe loop using the model's built-in function calling. The other styles (`default`, `react`, `planner`) are deprecated — leave the dropdown on the default. IBM watsonx Orchestrate docs: [`Choosing a style for the agent`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=agents-choosing-style-agent) · ADK Docs: [`agents/agent_styles`](https://developer.watson-orchestrate.ibm.com/agents/agent_styles).

![Completed Behavior tab showing the agent name, description, model, and instructions fields filled in](Lab%201.0%20screenshots/exercise-1/ex1-step9-completed-behavior-tab.png)

*Figure 6. Completed Behavior tab showing the agent name, description, model, and instructions fields filled in.*

#### Test the Bare Agent

Test the agent in Draft preview to observe its default behaviour before any tools or boundaries are added:

10. In the **Draft preview** panel on the right side of the Agent Builder, ask:

      `Can you look up order O-DF340K?`

11. The agent responds using training knowledge — it invents or hedges an answer because it has no tools to reach a live system. You may see something like one of these two variations.

   Variation A — an invented order record:

   ```json
   {
     "order_id": "O-DF340K",
     "status": "Shipped",
     "items": [
       { "product_id": "P-12345", "name": "Wireless Mouse", "quantity": 2, "price_per_unit": 25.99 },
       { "product_id": "P-67890", "name": "Mechanical Keyboard", "quantity": 1, "price_per_unit": 89.99 }
     ],
     "total_amount": 141.97,
     "shipping_address": {
       "name": "John Doe", "street": "456 Elm Street", "city": "Springfield",
       "state": "IL", "zip": "62704", "country": "USA"
     },
     "estimated_delivery": "2024-10-12",
     "tracking_number": "1Z999AA10123456784"
   }
   ```

   Variation B — an invented tool call, as if a lookup tool already existed:

   ```json
   {
     "tool": "order_lookup",
     "tool_input": { "order_id": "O-DF340K" }
   }
   ```

   > **Note:** It is the nature of LLM-based systems that responses vary — you may see Variation A, Variation B, something that blends the two, or a hedged answer admitting it cannot look up the order. If your response doesn't resemble either variation above, click the **Reset Chat** icon in the top-right corner of the **Draft Preview** window and ask the same question again; a few resets are usually enough to see one of these patterns. None of these are correct: Variation A invents order data with no basis in a real system, and Variation B invents a tool call to a tool that was never attached to this agent — the agent has no tools at all yet. Either way, the real order contains Focus Corp catalog items with `CI-*` IDs, a real named customer with a `C-*` ID, and no `tracking_number` or `estimated_delivery` fields. This is what a hallucination looks like: confident, well-structured, and wrong. You will replace this with grounded data in Lab 1.1.

![Draft preview showing the bare agent's hallucinated response to the order lookup question](Lab%201.0%20screenshots/exercise-1/ex1-step11-hallucinated-response.png)

*Figure 7. Draft preview showing the bare agent's hallucinated response to the order lookup question.*

12. Click the debug icon (a small bug symbol, the rightmost icon below the response next to the Like 👍 and Dislike 👎 buttons) to open the agent debug window. The debugger provides step-by-step visibility into how the agent processes information and generates responses. You can inspect how the agent interpreted your input, view the tools or memory it referenced, and understand the execution path from request to response. This will be useful throughout the lab whenever you need to understand why an agent produced a particular output or to troubleshoot unexpected behavior.

#### Explore the Agent Debugger Window

The debugger has two major components:

| Component | Purpose |
|---|---|
| **Agent flow** (left) | Visual map showing the agent's structure, tools, and collaborators available to it |
| **Execution timeline** (right) | Step-by-step flow showing exactly how the agent processed your request and generated the response |

You can expand or collapse details at each step, navigate forward and backward through the execution, inspect variables (input, output, logs), and view node properties to understand configuration and logic.

IBM watsonx Orchestrate docs: [`Debugging your agent`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=testing-debugging-your-agent)

13. On the **Agent flow** (left side), observe the agent's structure. Then, on the **Execution timeline** (right side), walk through the execution steps by clicking through or expanding each step:
    - Notice that the agent first attempts to locate a tool to fulfill your request — since this is a bare agent with no tools attached, no tool is invoked.
    - Follow the execution path to the final reasoning step, which should be labeled `WatsonxChatModel.chat` or similar — this is where the agent's configured language model processes the prompt directly.
    - Observe the output of that step, which contains the agent's response based on training data. This is why the answer is hallucinated — there is no tool to ground the response in real system data.

![Agent debug window showing the execution timeline with no tools invoked and the final WatsonxChatModel.chat step generating the response](Lab%201.0%20screenshots/exercise-1/ex1-step13-debugger-timeline.png)

*Figure 8. Agent debug window showing the execution timeline with no tools invoked and the final WatsonxChatModel.chat step generating the response.*

> **Looking ahead:** In Lab 1.1, when we attach real tools to the agent (MCP, OpenAPI, and Python), the execution timeline will show the agent invoking those tools, passing parameters, receiving structured results, and grounding responses in real data. The debugger will then reveal exactly which tool was called, what parameters were passed, and how the tool output shaped the final answer. We will revisit the debugger in Lab 1.1 to validate tool integration and understand agent behavior with grounding in place.

14. Close the debugger by clicking the topmost **X** button in the top-right corner of the debug window.

15. Now ask an off-topic question:

      `What is the capital of France?`

   The agent answers freely with no resistance. This is the no-boundaries limitation; it is addressed in Exercise 3.

![Draft preview showing the bare agent answering an off-topic question without restriction](Lab%201.0%20screenshots/exercise-1/ex1-step15-off-topic-answer.png)

*Figure 9. Draft preview showing the bare agent answering an off-topic question without restriction.*

16. Click the debug icon again to open the debugger for this off-topic response. On the **Execution timeline** (right side), walk through the execution steps:
    - Follow the execution path to the `WatsonxChatModel.chat` step. Expand the **output** field in the response section to see the LLM's reasoning and response generation.
    - Notice that the agent's response reasoning directly addresses the question based on training knowledge, with no tool involvement. This confirms that when a request falls outside the scope of the agent's tools and instructions, the model answers conversationally using its training data.

![Agent debug window showing the off-topic question execution timeline ending in WatsonxChatModel.chat with no tools invoked](Lab%201.0%20screenshots/exercise-1/ex1-step16-off-topic-debugger.png)

*Figure 10. Agent debug window showing the off-topic question execution timeline ending in WatsonxChatModel.chat with no tools invoked.*

17. Close the debugger by clicking the topmost **X** button in the top-right corner of the debug window.

#### Explore the Catalog

Before moving on to defining boundaries, take a few minutes to browse the platform catalog:

18. Open the hamburger menu (☰) in the top-left corner and navigate to **BUILD & RUN** → **Catalog**.
19. The **Agents** tab is selected by default above the results grid. Leave the source filter (**All** / **External** / **Native**) on **All**.
20. Open the **Categories** drop-down in the filter bar at the top and select one or more categories relevant to Focus Corp (e.g. **Customer Care**, **Customer Service**, **Sales**, or **HR**).
21. Click an **agent card** to open its details and read its **Description**.

   Notice how these descriptions explain what the agent offers in broad terms — useful for a human browsing the catalog, but too vague for an orchestrator that needs to decide programmatically whether to call this agent. When your agent is registered as a collaborator under `TRI_orchestrator` in Lab 1.3, its description must be precise: what it does, what input it needs, and what it returns. That is a different kind of writing for a different kind of reader.

   > **Note:** The agent's **Instructions** are not visible in the Catalog — they are only accessible once you create an agent from that template.

![Catalog page with the Agents tab selected and the Categories drop-down open, showing pre-built agent cards with their descriptions](Lab%201.0%20screenshots/exercise-1/ex1-step21-catalog-agent-card.png)

*Figure 11. Catalog page with the Agents tab selected and the Categories drop-down open, showing pre-built agent cards with their descriptions.*

✅ Exercise 1 complete. You have built the `(NAMESPACE)_TRI_order_agent` bare frame — configured its core properties (name, description, model, instructions, style) and tested its unconstrained default behaviour in Draft preview. You also learned how to use the agent debugger to inspect the execution timeline and understand how the agent processes requests and generates responses. In the optional Exercise 2, you will build the same agent with IBM Bob. If you skip it, continue to Exercise 3, where you will add behavioural boundaries and test how to restrict what the agent will and will not answer.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 2 *(Optional)*: Build the Same Agent with Bob (~20 min)

In this exercise, you will build an equivalent agent — `(NAMESPACE)_TRI_order_agent_bob` — using the **Build with Bob** conversational path, and compare what Bob generates with what you configured manually in Exercise 1.

**Why this matters:** The conversational authoring path is not just a shortcut — it is a different way of working. Instead of filling in fields, you describe what you want and let Bob draft the agent configuration for you. Understanding both paths makes you a more versatile agent author.

**What to expect:** Build with Bob does not run in your browser. **Launch Bob** opens the IBM Bob desktop application, installs the watsonx Orchestrate ADK extension, and initializes a local workspace connected to your wxO tenant. The first launch walks you through several one-time setup prompts (Steps 3–9); later launches go straight to the chat. Keep this guide open in your browser while you work in Bob.

IBM watsonx Orchestrate docs: [`Building agents with IBM Bob`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=agents-building-bob)

**Prerequisite:** IBM Bob installed and signed in on your machine (see 1.2.1). If you do not have Bob, read through the steps and screenshots to understand the flow — then continue to Exercise 3.

**If you are starting here:** No artifacts need to be imported. The comparison values are listed in Step 14.

#### Steps

**Launch Bob and set up the workspace (first launch only)**

1. Expand the hamburger menu (☰) in the top left, click **Active inventory** under the **BUILD & RUN** category, then click **Agents**. Click **Create agent +**.

2. In the **Create an agent** dialog, under **Build with AI (Preview)**, select **Build with Bob**, then click **Launch Bob**.

   !["Create an agent" dialog with "Build with Bob" selected and the "Launch Bob" button highlighted](Lab%201.0%20screenshots/exercise-2/ex2-step2-launch-bob.png)

   *Figure 12. "Create an agent" dialog with "Build with Bob" selected and the "Launch Bob" button highlighted.*

   > **Note:** If Bob is not installed, click **Don't have Bob? Click here to learn more**, complete the installation and sign in to Bob, then click **Launch Bob** again.

3. When your browser asks whether to open IBM Bob, click **Open IBM Bob**.

   > **Tip:** If nothing appears to happen, Bob may have opened in the background — check your active applications. If necessary, return to wxO and click **Try again**.

4. Bob prompts you to install the watsonx Orchestrate ADK extension. Click **Install Extension and Open URI**, review the publisher information, then click **Trust Publishers & Install**.

   ![Bob prompt to install the watsonx Orchestrate ADK extension](Lab%201.0%20screenshots/exercise-2/ex2-step4-adk-extension.png)

   *Figure 13. Bob prompt to install the watsonx Orchestrate ADK extension.*

   > **Note:** The extension is installed once — you will not see this prompt on later launches.

5. Bob asks where to initialize the watsonx Orchestrate workspace:
   - If Bob already has a folder open, click **Continue with current folder**.
   - If Bob shows **No workspace folder is open**, click **Open Folder** and create a new empty folder (for example `lab-1-0-bob`).

   Bob writes its workspace files — a Python environment and the generated agent YAML — into this folder.

   ![Bob prompt to initialize the watsonx Orchestrate workspace in a folder](Lab%201.0%20screenshots/exercise-2/ex2-step5-workspace-folder.png)

   *Figure 14. Bob prompt to initialize the watsonx Orchestrate workspace in a folder.*

6. When Bob asks whether you trust the authors of the files in this folder, click **Yes, I trust the authors**.

7. If Bob reports that **uv** is required, click **Install**. Initialization continues, and the status bar shows `Initializing watsonx Orchestrate Workspace: Step X/5`.

   To confirm uv is installed, run the following in a terminal. It should print a version number (for example `uv 0.x.y`):

   ```
   uv --version
   ```

   *Figure 15. Confirming that uv is installed and on your PATH.*

   > ⚠️ **If the setup prompts keep repeating:** In testing, after uv was installed Bob showed **Initialize Workspace** again, then the folder prompt, then the uv prompt again — in a loop. If the uv prompt appears a second time, stop clicking through it:
   > 1. Open a terminal and install uv manually:
   >    - macOS / Linux: `curl -LsSf https://astral.sh/uv/install.sh | sh`
   >    - Windows (PowerShell): `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
   > 2. Open a **new** terminal and run `uv --version` to confirm uv is on your PATH.
   > 3. Quit Bob completely and reopen it so it picks up the updated PATH.
   > 4. Click **Initialize Workspace** again.
   >
   > If Bob still cannot detect uv, read through the rest of this exercise, continue to Exercise 3, and ask the facilitator for help after the lab.

8. Wait for initialization to complete. The status bar shows the workspace is ready and the watsonx Orchestrate tools are loaded.

   ![Bob status bar showing the watsonx Orchestrate workspace is ready](Lab%201.0%20screenshots/exercise-2/ex2-step8-workspace-ready.png)

   *Figure 16. Bob status bar showing the watsonx Orchestrate workspace is ready.*

9. Bob connects to the wxO tenant you launched it from. When it prompts for an API key, generate one for the tenant and paste it in.

   ![Bob prompt asking for the watsonx Orchestrate API key](Lab%201.0%20screenshots/exercise-2/ex2-step9-api-key.png)

   *Figure 17. Bob prompt asking for the watsonx Orchestrate API key.*

   > **Note:** For how to generate an API key, see **Setup & Event Credentials → 1.2 On Event Day → Step 2**. If automatic environment activation cannot be completed, you can continue working locally and connect later.

**Describe the agent to Bob**

10. In the Bob chat panel, paste the following prompt — replace `(NAMESPACE)` with your user ID — and send it. The prompt follows IBM's recommended structure (Purpose, Actions, Systems, Restrictions):

    ```
    Create a watsonx Orchestrate native agent named (NAMESPACE)_TRI_order_agent_bob.

    Purpose: Help Focus Corp customer support specialists with order and product catalog lookups.

    Actions:
    - Handle order lookup and product catalog lookup requests
    - Return lookup results in full, without summarising

    Systems:
    - No tools yet. Order and catalog tools will be attached later.

    Restrictions:
    - Use the model groq/openai/gpt-oss-120b and the react_core style
    - Never invent order or product data
    - Never suggest actions beyond the agent's available tools
    ```

    > **Note:** Bob may ask follow-up questions — for example about tools or constraints. Answer based on what you built in Exercise 1. Bob's wording will differ from other participants' — LLM output varies, and that is expected.

    ![Bob chat showing the prompt and Bob's response](Lab%201.0%20screenshots/exercise-2/ex2-step10-bob-chat.png)

    *Figure 18. Bob chat showing the prompt and Bob's response.*

11. Open the agent YAML file Bob created in your workspace folder and review its `name`, `description`, `instructions`, `llm`, and `style`.

    ![Agent YAML generated by Bob, open in the editor](Lab%201.0%20screenshots/exercise-2/ex2-step11-generated-yaml.png)

    *Figure 19. Agent YAML generated by Bob, open in the editor.*

12. Ask Bob to import the agent:

    ```
    Import (NAMESPACE)_TRI_order_agent_bob into my active watsonx Orchestrate environment.
    ```

    If Bob asks for permission to run a command, approve it.

    > **Note:** This is equivalent to running `orchestrate agents import -f <file>.yaml`. The agent lands in **Draft** — do not deploy it.

**Compare with your manual agent**

13. Return to wxO in your browser. Click the hamburger menu (☰), click **Active inventory** under **BUILD & RUN**, then click **Agents**. Search for `(NAMESPACE)_TRI_order_agent_bob` and open it.

    ![Bob-generated agent open in the Agent Builder Behavior tab](Lab%201.0%20screenshots/exercise-2/ex2-step13-bob-agent-in-builder.png)

    *Figure 20. Bob-generated agent open in the Agent Builder Behavior tab.*

14. Compare each field with what you built in Exercise 1 and note Bob's values in the right-hand column:

    | Field | What you built manually (Exercise 1) | What Bob generated |
    |---|---|---|
    | **Name** | `(NAMESPACE)_TRI_order_agent` | *(note Bob's value)* |
    | **Description** | `Handles order and catalog lookups for Focus Corp customer support specialists.` | *(note Bob's value)* |
    | **Instructions** | The three lines from Exercise 1, Step 7 | *(note Bob's value)* |
    | **Model** | GPT-OSS 120B — OpenAI (via Groq) | *(note Bob's value)* |
    | **Style** | ReAct Core (`react_core`) | *(note Bob's value)* |

    > **Note:** Bob's description and instructions will likely differ from yours. That is the teaching point: the comparison shows what the model infers from a natural-language brief versus what a human author specifies deliberately. Neither version is automatically "better." Check Bob's **Instructions** against the Monolithic Mega-Prompt anti-pattern from Exercise 1, Step 7 — is it still one job per sentence?

15. *(Optional)* Edit any field in the Builder to align it with Exercise 1. Changes save automatically when you step out of the field.

    > **Note:** If you later re-import Bob's YAML file, it overwrites any edits you made in the UI.

✅ Exercise 2 complete. You have seen the manual and conversational authoring paths side by side. The manual path gives you explicit control over every field; the conversational path gives you a fast first draft that you then refine. In practice, many teams use Bob to draft and then tune manually — both skills are worth having. Exercises 3 and 4 continue with your manually built `(NAMESPACE)_TRI_order_agent`, not the `_bob` agent. In Exercise 3, you will add behavioural boundaries.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 3: Define Behavioural Boundaries (~15 min)

In Exercise 1 you saw your agent answer "What is the capital of France?" — freely, confidently, and completely off-topic. That is the default: no boundaries, no restrictions. In this exercise you will add them, and you will discover that wxO gives you two ways to do it with very different cost implications.

Before you start, one naming point worth flagging: wxO uses the word "guidelines" for two different things. Both appear in the UI. Keeping them distinct matters for this exercise:

- **Instructions field** — plain text rules you type directly into the Instructions field. Always present, always evaluated. Zero extra cost.
- **Guidelines section** (Behavior tab) — structured "When `<condition>` → then `<action>`" rules. A separate LLM call runs on every turn to check them, whether they fire or not.

IBM watsonx Orchestrate docs: [`Adding guidelines`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=behavior-adding-guidelines)

You will use both in this exercise and see what the difference actually means in practice.

**If you are starting here:** Only needed if you did not complete Exercise 1. If `(NAMESPACE)_TRI_order_agent` is already in your **Agents** list, skip this. Otherwise, import the bare frame:

1. Prepare namespace-safe copies of the lab agent files. The script writes your user ID into the agent name:

   ```bash
   python3 labs/lab-1x/solution/scripts/prepare_lab_1_1.py --sor-user-id (YOUR-SOR-USER-ID) --sor-base-url "(YOUR-SOR-BASE-URL)" --output labs/lab-1x/solution/lab-1-prepared
   ```

   > **Note:** On Windows, use `python` if `python3` is not available. Keep the double quotes around `"(YOUR-SOR-BASE-URL)"`.

2. Import the prepared bare frame. It matches the agent you build in Exercise 1:

   ```bash
   orchestrate agents import --file labs/lab-1x/solution/lab-1-prepared/agents/lab_1_1_TRI_order_agent_start.yaml
   ```

> **Tip:** Code values shown in the tables throughout this exercise are selectable — highlight and copy them directly into the UI fields.

#### Steps

1. Expand the hamburger menu (☰) in the top left, click **Active inventory** under the **BUILD & RUN** category, then click **Agents**. Find and open `(NAMESPACE)_TRI_order_agent` and navigate to the **Behavior** tab.

2. In the **Guidelines** section, click **Add +** to add a new guideline block and enter the following values:

   | Field | Value |
   |---|---|
   | **Name** | `Off-topic redirect` |
   | **Condition** | `When the user asks about topics unrelated to Focus Corp customer support` |
   | **Action** | `Redirect to customer inquiries` |

3. Click **Save** to save the new guideline.

![Guidelines section showing the completed "Off-topic redirect" guideline with Name, Condition, and Action fields filled in](Lab%201.0%20screenshots/exercise-3/ex3-step3-guideline-filled-in.png)

*Figure 21. Guidelines section showing the completed "Off-topic redirect" guideline with Name, Condition, and Action fields filled in.*

4. Open the **Draft preview** panel and ask: *"What is the capital of France?"*

   Observe that the agent redirects rather than answering.

![Draft preview showing the agent redirecting an off-topic question using the Guidelines section](Lab%201.0%20screenshots/exercise-3/ex3-step4-guideline-redirect.png)

*Figure 22. Draft preview showing the agent redirecting an off-topic question using the Guidelines section.*

5. Click the debug icon (the small bug symbol below the response) to open the agent debugger. The **Execution timeline** (right side) opens with every step already expanded.

   > **Note:** For a detailed walkthrough of the debugger's major components and capabilities, see Exercise 1, where you first explored the agent debugger window.

6. Select the **Agent Reasoning** step. In the **Node properties** panel below the timeline, open the **Guidelines** tab and confirm that **Off-topic redirect** is listed with its Condition and Action — the guideline is now part of the context the LLM receives. Then select the first `WatsonxChatModel.chat` step below it and review its **Input** and **Output** to see how the LLM identified the guideline as relevant and generated a response based on the guardrail condition.

![Agent debugger with the Agent Reasoning step selected and the Node properties Guidelines tab showing the Off-topic redirect guideline](Lab%201.0%20screenshots/exercise-3/ex3-step6-debugger-guideline-input.png)

*Figure 23. Agent debugger with the Agent Reasoning step selected and the Node properties Guidelines tab showing the Off-topic redirect guideline.*

7. Close the debugger by clicking the topmost **X** button in the top-right corner of the debug window.

8. Click on the **Off-topic redirect** guideline to select and expand it, then click **Delete**.

9. Confirm the deletion when prompted.

10. In the **Instructions** field, add the following line at the end:

   | Field | Value |
   |---|---|
   | **Instructions** (add to end) | `Do not answer questions unrelated to Focus Corp customer support.` |

11. Click the **Reset Chat** icon in the top-right corner of the **Draft preview** window so the earlier redirect in this conversation does not influence the next answer.

12. In the **Draft preview**, ask the same question again: *"What is the capital of France?"*

   Observe the agent still redirects — same result as before.

![Draft preview showing the agent redirecting the same off-topic question using the inline instruction](Lab%201.0%20screenshots/exercise-3/ex3-step11-instruction-redirect.png)

*Figure 24. Draft preview showing the agent redirecting the same off-topic question using the inline instruction.*

   > **Note:** The result looks identical — but the performance difference is significant. The Guidelines section adds an extra inference pass on every single turn, including every normal business question that has nothing to do with guidelines. This extra pass adds latency to every turn. The inline instruction runs inside the existing reasoning loop at no additional cost. For rules that stay constant throughout a conversation, the Instructions field is the right place.
   >
   > **Guidelines then vs. now:** Before watsonx Orchestrate introduced Controls, Guidelines were often used for static policies like off-topic blocking. Today, **Controls** (platform-level policy rules) are the better choice for deterministic guardrails — they enforce policies at the gateway layer with no extra LLM call. Guidelines are now best reserved for truly dynamic, conversational behavior that must adapt based on LLM reasoning — for example, if a customer says mid-conversation "this is the third time I've called about this", a guideline can fire immediately, stop the normal task, and inject a de-escalation response for that one turn. An instruction cannot do that reliably because instructions don't observe mid-turn context changes; Controls cannot do it because they lack LLM reasoning. Guidelines solve this specific problem — just not the static off-topic case taught here.
   >
   > **In production:** Off-topic handling is now implemented using **Controls** — platform-level governance rules managed by IT/Security teams that sit outside the agent and add no inference overhead. This exercise uses Guidelines to show you the agent-builder perspective and the latency trade-off, so you understand when each tool is the right choice.

   ✨ Trinity agents use plain instructions for off-topic handling. In fully mature enterprise deployments with Control Plane adoption, deterministic policies like this would move to platform governance — leaving Guidelines for dynamic mid-turn behavior only.

13. *(Optional)* Open the agent debugger again by clicking the debug icon below the response. Explore the **Execution timeline** to see how introducing this new instruction into the Instructions field has changed the execution path and the agent's response reasoning compared to when the Guidelines were active. Notice how the LLM now integrates the inline instruction into its reasoning without requiring a separate inference pass.

14. Remove the line you added in Step 10 from the **Instructions** field, restoring the agent to match the Trinity anchor exactly.

   > **Note:** This off-topic redirect is a teaching device, not part of the production configuration. When `TRI_order_agent` runs as a collaborator under `TRI_orchestrator` in Lab 1.3, the orchestrator already scopes which requests reach it — a worker agent does not need its own off-topic guardrail on top of that.

✅ Exercise 3 complete. You have seen both approaches in action and understand when each is the right choice. In Exercise 4, you will evaluate your agent and deploy it.

[↑ Back to Table of Contents](#table-of-contents)

---

### Exercise 4: Evaluate and Deploy (~25 min)

Building and configuring an agent in the Builder is only half the loop. The other half is saving a measurable baseline and deploying — so that when you make changes in Lab 1.1, you can see the difference rather than just guess at it.

**If you are starting here:** Only needed if you did not complete Exercise 1. If `(NAMESPACE)_TRI_order_agent` is already in your **Agents** list, skip this. Otherwise, import the bare frame:

1. Prepare namespace-safe copies of the lab agent files. The script writes your user ID into the agent name:

   ```bash
   python3 labs/lab-1x/solution/scripts/prepare_lab_1_1.py --sor-user-id (YOUR-SOR-USER-ID) --sor-base-url "(YOUR-SOR-BASE-URL)" --output labs/lab-1x/solution/lab-1-prepared
   ```

   > **Note:** On Windows, use `python` if `python3` is not available. Keep the double quotes around `"(YOUR-SOR-BASE-URL)"`.

2. Import the prepared bare frame. It matches the agent you build in Exercise 1:

   ```bash
   orchestrate agents import --file labs/lab-1x/solution/lab-1-prepared/agents/lab_1_1_TRI_order_agent_start.yaml
   ```

#### Evaluate

**Why save an evaluation baseline now:** The Evaluate tab lets you save named test conversations and run them in bulk. A pass rate against a toolless agent is not useful on its own — but it becomes the reference point you compare against after every significant change. The habit of saving a baseline before you change something is more valuable than any single result.

**Why test a broken agent:** The agent has no tools yet — it will invent answers to both queries below. That is intentional. You are capturing what hallucination looks like *before* the fix, so you have something concrete to compare against *after* attaching tools in Lab 1.1.

#### Understanding Evaluation Time

Evaluation can take 5–10 minutes or longer for just a few test cases. This might seem surprising, but it reflects how wxO evaluates agents:

**What's happening under the hood:**

1. **Multi-turn simulation** — For each test case, wxO spins up a synthetic user agent that engages your agent in a back-and-forth conversation. A 4-turn test case generates 8+ LLM calls just to simulate the dialogue.

2. **Trajectory scoring** — The framework scores the entire conversation path, not just the final answer. It evaluates whether your agent called the right tool, extracted the correct parameters, and executed steps in the expected order.

3. **Environment provisioning** — The system provisions execution hooks, loads your agent configuration, and authenticates connections to backend tools before the first message.

4. **Asynchronous processing** — Results are aggregated and telemetry is collected before the evaluation completes.

**What this means for you:** Two test cases with multi-turn conversations can easily consume 5–10 minutes. You can monitor progress in the **View queue** tab. If you need faster iteration during drafting, the ADK CLI offers a lightweight quick-eval command that skips the multi-turn simulation.

IBM watsonx Orchestrate docs: [`Evaluating with simulated users`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=testing-evaluating-simulated-users)

ADK Docs: [`evaluate/overview`](https://developer.watson-orchestrate.ibm.com/evaluate/overview) · [`evaluate/quick_eval`](https://developer.watson-orchestrate.ibm.com/evaluate/quick_eval)

#### Steps

1. Expand the hamburger menu (☰) in the top left, click **Active inventory** under the **BUILD & RUN** category, then click **Agents**. Find and open `(NAMESPACE)_TRI_order_agent` and navigate to the **Evaluate** tab, then click **Tests**.

2. To start a fresh test conversation and ensure you're testing from a clean state, click the **Reset Chat** icon in the top-right corner of the **Draft Preview** window. This ensures the next test isn't influenced by previous exchanges.

![Draft Preview window showing the Reset Chat icon in the top-right corner](Lab%201.0%20screenshots/exercise-4/ex4-step2-reset-chat.png)

*Figure 25. Draft Preview window showing the Reset Chat icon in the top-right corner.*

3. Send the following query:

   ```
   Look up order O-DF340K.
   ```

   Observe the response — the agent has no tools yet and will invent or hedge an answer.

4. Click **Save as test** in the top-right corner. In the dialog that appears, keep the pre-filled defaults and click **Save**.

   Observe the new test case listed on the left-hand side under **Tests**.

![Evaluate tab showing the first saved test case in the Tests list](Lab%201.0%20screenshots/exercise-4/ex4-step4-first-test-case.png)

*Figure 26. Evaluate tab showing the first saved test case in the Tests list.*

5. Repeat Steps 2–4 with the following query:

   ```
   Find replacement gaming laptops in the price range $1,000–$2,000.
   ```

   Observe the response — without a catalog tool the agent will tell you it cannot search for products right now. Save it as a test case in the same way.

![Evaluate tab showing both saved test cases in the Tests list](Lab%201.0%20screenshots/exercise-4/ex4-step5-both-test-cases.png)

*Figure 27. Evaluate tab showing both saved test cases in the Tests list.*

6. Click the **Evaluations** tab, then click **Start new evaluation**.

![Evaluate tab with Evaluations tab selected and "Start new evaluation" button visible](Lab%201.0%20screenshots/exercise-4/ex4-step6-start-new-evaluation.png)

*Figure 28. Evaluate tab with Evaluations tab selected and "Start new evaluation" button visible.*

7. In the test-case selection drop-down, check both test cases you just created. Click **Next**.

![Test-case selection step with both test cases checked](Lab%201.0%20screenshots/exercise-4/ex4-step7-select-test-cases.png)

*Figure 29. Test-case selection step with both test cases checked.*

8. Leave all settings on the second page as they are and click **Run**.

![Second page of the new evaluation wizard with default settings and Run button highlighted](Lab%201.0%20screenshots/exercise-4/ex4-step8-run-evaluation.png)

*Figure 30. Second page of the new evaluation wizard with default settings and Run button highlighted.*

9. While the evaluation is running it appears in **View queue**. Once complete — this can take 5–10 minutes — the **Evaluations** list shows the completed entry. Observe the information displayed in the table.

   > **Tip:** Evaluation runs in the background on the tenant. You can proceed directly to the **Deploy** section below while the evaluation completes, then check back for the results.

![Evaluations list showing the completed evaluation entry in the table](Lab%201.0%20screenshots/exercise-4/ex4-step9-evaluations-list.png)

*Figure 31. Evaluations list showing the completed evaluation entry in the table.*

10. Click the date in the date column of the new entry to open the detailed results for this evaluation and study the output.

![Detailed evaluation results view showing per-test-case pass/fail output](Lab%201.0%20screenshots/exercise-4/ex4-step10-evaluation-results.png)

*Figure 32. Detailed evaluation results view showing per-test-case pass/fail output.*

   > **Note:** Expect failures on the order and catalog queries — the agent has no tools. After attaching tools in Lab 1.1, re-run evaluation and compare the pass rate.

   > **Note:** The evaluated conversations may contain more turns than the single question you saved. The simulated user extends the dialogue to test how your agent handles follow-ups — this is part of why evaluation takes several minutes.

#### Deploy

**Draft vs Live:** While building, you have been using the Draft environment — a shared development space where all Builders on this tenant can create and iterate on agents. Draft is separated from Live (the runtime environment where end-users access agents), so your experimental changes do not affect production. The Evaluate tab runs against Draft, giving you a safe place to test before deploying.

However, Draft is not private in the sense of isolating one Builder's work from another — on wxO's AWS infrastructure, all participants with the **Builder** role on this shared Tenant can see and access Draft agents created by their colleagues. This is by design: the development environment is shared across the Builder group. The **User** role is restricted to chatting with deployed Live agents only (zero development visibility).

In wxO you can only deploy a named version — not the draft directly. Creating a version is a snapshot of your agent and its dependencies at a point in time; deploying that version to Live is what makes it visible to end-users. This is a deliberate two-step: iterate in the shared Draft environment, then publish deliberately to Live.

IBM watsonx Orchestrate docs: [`Working with agent and tool versions`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=agents-working-agent-tool-versions)

#### Steps

11. Navigate to **Orchestrate Chat** by clicking the hamburger menu (☰) in the top left and selecting **Chat**. In the agent selector drop-down, click the **×** and type your user ID (e.g. `usr001`) — `(NAMESPACE)_TRI_order_agent` does not appear. The agent exists in Draft but has not been published to Live yet, so it is invisible here.

![Orchestrate Chat agent selector showing the participant's agent absent before deployment](Lab%201.0%20screenshots/exercise-4/ex4-step11-chat-agent-absent.png)

*Figure 33. Orchestrate Chat agent selector showing the participant's agent absent before deployment.*

12. Return to your agent. Click the hamburger menu (☰), expand **Active inventory**, then click **Agents** under **BUILD & RUN**. Find and open `(NAMESPACE)_TRI_order_agent` and navigate to the **Deploy** tab.

13. Click **Deploy to Live** to open the **Deploy agent version** dialog.

14. The **Deploy agent version** dialog shows any existing versions and a **Create new version +** button. Click **Create new version +**. The **Create an agent version** dialog opens. Enter the following values and click **Create**:

   | Field | Value |
   |---|---|
   | **Version name** | `v1 — no tools` |
   | **Description** *(optional)* | `Initial agent configuration — behavioural boundaries only, no tools attached` |
   | **Version number** | `1.0.0` |

!["Create an agent version" dialog with all fields filled in](Lab%201.0%20screenshots/exercise-4/ex4-step14-create-version.png)

*Figure 34. "Create an agent version" dialog with all fields filled in.*

   > **Known issue:** The **Version number** field may show *"Incorrect version format, only numerical values accepted. For example: 1.1.9"* even though `1.0.0` is a valid value. If the field contains exactly `1.0.0` (no spaces before or after), ignore the message and click **Create**. The version is still created.

   > **Note:** When you create a version snapshot, it captures not only the agent configuration (name, description, instructions) but also any linked artifacts at that point in time, such as attached tools, knowledge bases, or collaborator agents. This ensures version consistency across related components. If you later update a tool or knowledge base, existing versions still reference the definitions that were present when the version was created.

15. Select the version you just created and click **Deploy**.

![Deploy agent version dialog with the version selected and "Deploy" button highlighted](Lab%201.0%20screenshots/exercise-4/ex4-step15-deploy-version.png)

*Figure 35. Deploy agent version dialog with the version selected and "Deploy" button highlighted.*

16. Review the **Pre-deployment summary** — it lists what will be deployed to Live. Once satisfied, click **Deploy**.

![Pre-deployment summary page with the Deploy button highlighted](Lab%201.0%20screenshots/exercise-4/ex4-step16-pre-deployment-summary.png)

*Figure 36. Pre-deployment summary page with the Deploy button highlighted.*

   > **Note:** In the ADK CLI on SaaS, running `orchestrate agents import` imports the agent into **Draft** state; you must subsequently run `orchestrate agents deploy --name <agent_name>` to deploy it to **Live** (in Developer Edition / local mode, only the draft environment exists, so deploy commands are not supported).

17. Navigate to **Orchestrate Chat** again by clicking the hamburger menu (☰) in the top left and selecting **Chat**. In the agent selector drop-down, click the **×** and type your user ID (e.g. `usr001`) — `(NAMESPACE)_TRI_order_agent` now appears. Select it to confirm the deployment succeeded.

![Orchestrate Chat agent selector showing the participant's agent now present after deployment](Lab%201.0%20screenshots/exercise-4/ex4-step17-chat-agent-present.png)

*Figure 37. Orchestrate Chat agent selector showing the participant's agent now present after deployment.*

---

✅ Exercise 4 complete. You have saved a baseline evaluation showing two hallucination patterns and deployed `(NAMESPACE)_TRI_order_agent` to Live. In Lab 1.1, you will attach real tools to this agent and watch the hallucinations disappear one by one.

[↑ Back to Table of Contents](#table-of-contents)

---

## Lab Complete

This concludes the **Lab 1.0 — Building Your First Agent** lab.

In this lab you:

- Learned the three UI authoring paths and when to use each
- Built `(NAMESPACE)_TRI_order_agent` from scratch — name, description, model, instructions, style
- Understood the three most important agent authoring anti-patterns (mega-prompt, agent-as-business-process, agent-washing)
- *(Optional)* Built the same agent using the conversational Build with Bob path and compared the two approaches
- Learned how to use the agent debugger to inspect the execution timeline and understand how agents process requests and generate responses
- Learned when to use the Guidelines feature vs. inline instructions — and the performance cost of each
- Tested the agent and observed two flavours of hallucination from an agent with no tools
- Saved a baseline evaluation to compare against after adding tools in Lab 1.1
- Deployed your agent to Live and observed what changes

Congratulations on completing the lab!

Continue to **Lab 1.1 — Worker Agent: Building Tools and Choosing Tool Types (REST, MCP, OpenAPI, Python, Langflow)** to attach real tools to your agent and replace every hallucinated response with grounded data from your systems.

[↑ Back to Table of Contents](#table-of-contents)
