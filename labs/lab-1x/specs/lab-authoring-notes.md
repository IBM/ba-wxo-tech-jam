# Lab 1.x — Authoring Notes

> **Owner:** Ramy (Introduction to watsonx Orchestrate through Lab 1.2); Jürgen (Lab 1.3)
> **Status:** Introduction to watsonx Orchestrate and Lab 1.0 content complete. Lab 1.1 brief released and publication-candidate guide authored with import artifacts; live screenshots and tenant dry run remain. Lab 1.2 released for authoring. Lab 1.3 is not yet released.
>
> **What this document is:** Chapter-by-chapter authoring guidance for writing the participant lab guides. It captures the topic breakdowns, field-by-field notes, anti-patterns to introduce, experiments to run, forward references, and Trinity anchor files for each chapter. It sits between the programme-level spec (`specs/lab-design.md`) and the actual guide documents (`lab-guides/`).
>
> **What this document is not:** The lab guides themselves (those are in `lab-guides/`), the programme-level intent (that is in `specs/lab-design.md`), or the formatting and style conventions (those are in `lab-guides/LAB-GUIDE-CONVENTIONS.md`). Do not duplicate content from those files here.

---

## Cross-chapter authoring rules

These apply to every section Ramy writes. They extend the conventions in `lab-guides/LAB-GUIDE-CONVENTIONS.md` with Lab 1.x-specific constraints.

### Artifact naming
Every artifact name in every input table must include the `(NAMESPACE)_TRI_` prefix (e.g. `usr001_TRI_order_agent`, where `usr001` is the participant's assigned BAW user ID). The convention is explained once in section 1.2 of **Introduction to watsonx Orchestrate** — do not re-explain it per table, just include the placeholder consistently in every subsequent table. See `lab-guides/LAB-GUIDE-CONVENTIONS.md` § "Input tables".

### "If you are starting here" callout
Every chapter (Lab 1.0, 1.1, 1.2) must open with a brief callout that lists which pre-built artifacts participants need to import if they are starting from that chapter, and the ADK CLI command to do so. Format:

> **If you are starting here:** Import the pre-built `(NAMESPACE)_TRI_order_agent` (bare frame) using:
> ```bash
> orchestrate agents import -f order_agent.yaml --prefix (NAMESPACE)_
> ```

This makes each chapter self-contained. Participants who skip earlier chapters or recover from a broken state are never blocked.

### Bob touchpoints are optional
All references to IBM Bob (Build with Bob, Bob-generated YAML) must be framed as optional exercises. Every Bob touchpoint must be completable by reading the text and following along via screenshots alone. A participant without a Bob account must never be blocked.

### Integration technology framing
Frame tool integration examples around the type of backend capability they represent — a backend that exposes an MCP server, a backend that exposes a REST API, a backend that exposes a Web Service — not around IBM BAW or CP4BA. Do not name IBM BAW in participant-facing content except where the specific package name or endpoint URL is required to complete a step (e.g. the `uvx` install command for the BAW MCP server). See `lab-guides/LAB-GUIDE-CONVENTIONS.md` § Content design principle 8.

### Narrative thread across chapters
The agent built in Lab 1.0 (`TRI_order_agent` bare frame) carries forward into Lab 1.1. Lab 1.1 does not build a new agent from scratch — it attaches tools to the agent participants already built. The narrative thread is: agent hallucinating → MCP tools attached (order lookup fixed) → OpenAPI tool attached (catalog search fixed) → Python tools attached (date arithmetic fixed + CRM agent built fresh). Preserve this thread; do not break it by introducing a new agent in the middle.

### Before/after pattern
Where practical, show the wrong approach or misconfiguration before the correct one. The most memorable lab moments are when something breaks in an instructive way and the participant understands exactly why. The ✨ marker from the reference lab guide is valid when a section genuinely has a before/after arc — do not use it decoratively.

---

## Introduction to watsonx Orchestrate

**Lab guide file:** `lab-guides/Introduction to watsonx Orchestrate.md`
**Type:** Reading only — no hands-on steps, no artifacts built; not a numbered lab.
**Duration target:** ~15–20 min read.

The entire **Introduction to watsonx Orchestrate** guide is Section 1 (Lab Introduction) followed by reading sections only — no Exercise structure, no steps. It ends with a Lab Complete section listing the terminology items covered and forward-pointing to Lab 1.0.

### Topic 1 — What wxO is and what it is for
2–3 paragraphs. Cover: wxO is an AI platform for building and running LLM-based agents and multi-agent systems in enterprise environments. It provides the runtime, the tool connectivity, the orchestration patterns, and the governance layer. The goal is not to replace existing automation — it is to handle the tasks that were previously too conversational, too varied, or too infrequent to automate with rules. Forward pointer: "The Trinity scenario you experienced in Lab 0 is exactly this kind of task."

### Topic 2 — Form factors: SaaS, on-premises, Developer Edition
Keep to 2–3 paragraphs. Orientation only — not a deployment decision guide. Three form factors:
- **SaaS** — fully managed, bi-weekly updates, shared or dedicated tenant. What you are using in this event.
- **On-premises (CP4BA / RHOAI)** — enterprise-managed deployment. For regulated environments or air-gapped networks.
- **Developer Edition (ADK)** — local install via `orchestrate server start`. Used for authoring and testing before deploying to SaaS or on-prem. Participants are expected to have the ADK CLI installed locally (required for importing Python tools and pre-built artifacts).

Link to docs for depth. Do not attempt exhaustive comparison.

### Topic 3 — Low-code vs. pro-code authoring
2–3 paragraphs. The lab uses low-code throughout (wxO UI). Pro-code paths exist for every operation (ADK CLI, YAML import, VS Code extension) and are highlighted where applicable — typically as "Going further" callouts. Participants do not need to choose; low-code is the default track.

### Topic 4 — Core terminology items
Each item: 2–4 sentences giving a working mental model, then a forward pointer to the chapter where the concept is used hands-on. Do not expand beyond that here — the lab is where participants learn by doing.

**Chatbot**
A chatbot is stateless: prompt in → response out → done. It knows things from training but cannot act in external systems. Use the canonical framing verbatim from `lab-guides/LAB-GUIDE-CONVENTIONS.md` § "Standard framing patterns". Forward pointer: "Lab 1.0 — Building Your First Agent establishes the contrast when you test your agent without any tools attached."

**Agent**
An LLM agent is goal-directed: it receives a goal, plans, calls tools, observes results, and iterates until done. It does things in real systems. The difference from a chatbot is not the underlying model — it is whether the system can act in the world. Use the canonical framing verbatim. Forward pointer: "Lab 1.0."

**Knowledge Base**
Domain documents ingested and chunked to ground agent responses via RAG (Retrieval-Augmented Generation). Prevents reliance on training data alone — the agent retrieves the relevant excerpt before generating its response. Forward pointer: "Lab 1.2 — Worker Agent: RAG / Knowledge Base."

**Connection**
The security anchor for all external tool integrations. A connection keeps credentials (API keys, usernames/passwords, endpoint URLs, SSL configuration) separate from tool definitions, source code, and agent instructions. Connections are defined once and referenced by tools; wxO injects the credentials at invocation time. Forward pointer: "Lab 1.1 — Tools (MCP section)."

**MCP Servers and Toolkits**
An MCP server (called a *toolkit of kind `mcp`* in the ADK CLI) is a named container that discovers and packages backend capabilities as wxO tools automatically. Instead of defining tools one by one, registering an MCP server imports all its exposed operations into the tool registry in a single action.

> ⚠️ **Critical authoring note:** The toolkit-vs-tool distinction is the concept that consistently confuses first-timers in the UI. The "Add tools" dialog in the Agent Builder shows individual tools (e.g. `TSOR_Orders_get_order_by_id`) — not the toolkit name. Participants who do not understand the container relationship cannot make sense of the `toolkit_name:tool_name` format they see everywhere. Explain this container relationship explicitly here. End with: "You will create your first MCP toolkit in Lab 1.1 — Tools, MCP section."

**Tools and Scoping**
Individual callable actions attached to an agent. Even when an MCP server or OpenAPI spec registers dozens of tools on the platform, an agent author selectively attaches *only* the specific tools that agent needs. Attaching unnecessary tools increases selection ambiguity and degrades routing accuracy (Allen Chan #7 Tool Soup). Forward pointer: "Lab 1.1 — Tools."

**Agentic Workflow**
A special kind of tool that warrants its own mention. Unlike a regular tool call, an Agentic Workflow is a callable unit that combines deterministic steps (decision tables, code), agent reasoning nodes, and Human-in-the-Loop (HITL) approval gates in one encapsulated construct. The calling agent sees it as a single tool call. Forward pointer: "Lab 2 (Billing Dispute) and Lab 3 (Document Processing) build this hands-on."

**Catalog**
The platform's library of pre-built IBM and partner agents, tools, and MCP toolkits. IBM and ISVs (SAP, Workday, Salesforce, and others) publish ready-to-use agents here — they can be added as collaborators or used as starting points. Also contains pre-built tools and remote MCP servers. Forward pointer: "Lab 1.0 — you will browse the Catalog during the Explore exercise."

---

## Lab 1.0 — Building Your First Agent

**Lab guide file:** `lab-guides/Lab Guide - Lab 1.0 - first-agent.md`
**Trinity anchor:** `solution/agents/TRI_order_agent.yaml` — open alongside the UI as the reference throughout. By end of lab, the participant's agent should match it exactly, minus the tools (attached in Lab 1.1).

### Exercise structure
Three exercises for Lab 1.0:
1. **Create the agent** — authoring options orientation + build the bare `TRI_order_agent` frame (name, description, model, instructions, style)
2. **Define behavioural boundaries** — instructions vs. the `guidelines:` construct (hands-on experiment)
3. **Deploy, test, and evaluate** — deploy to Live, test in Orchestrate Chat, save test conversations, run Evaluate

The Catalog exploration and model excursion sit inside Exercise 1 as embedded teaching points, not separate exercises. The "Optional: Build with Bob" sits as a callout at the end of Exercise 1.

### Exercise 1 — Create the agent

**Opening:** Before participants build, orient them to the authoring options available when clicking **Create new agent** in wxO. This is a brief orientation (2–3 minutes) — not a full tour. Cover:

**Three UI paths:**
1. *Create from scratch (Manual)* — the primary lab track. Step-by-step configuration of all fields.
2. *Build with AI / Build with Bob (Preview)* — conversational agent authoring using pre-loaded ADK skills. **Optional** — see callout at end of this exercise.
3. *Build from a template (Catalog)* — starting from a pre-built IBM or ISV agent.

**Pro-code paths (brief callout / "Going further"):**
- ADK Extension in VS Code / Bob — generates and refines agent YAML
- Raw YAML authoring — `orchestrate agents import`
- AI coding assistant (Bob, Cursor, Claude Code) — generate YAML outside wxO, then import

**Agent Builder UI tabs — table (not prose):**

| Tab | Sub-tabs | What happens here |
|---|---|---|
| **Build** | Behavior, Knowledge, Tools, Agents | Configure all fields; attach KBs, tools, collaborators |
| **Evaluate** | Evaluations, Tests | Save test conversations; run bulk evaluations |
| **Deploy** | Draft, Live | Deploy to Live; configure channels |

**Build the bare frame — field by field:**

| Field | Value to enter | Teaching point |
|---|---|---|
| **Name** | `(NAMESPACE)_TRI_order_agent` | Machine-readable identifier — used by other agents, ADK tooling, test cases. Choose deliberately; renaming after deployment requires full re-import and breaks agent references. |
| **Description** | One sentence summary | Keep brief here. Forward reference: when this agent is registered as a collaborator under an orchestrator, this description becomes the routing signal the orchestrator reads. Covered in Lab 1.3. |
| **Model** | Select **Default** | Instruct participants to select the model labelled "Default" in the dropdown — do not name a specific model string. Add parenthetical: *(currently `groq/openai/gpt-oss-120b`)* so it is traceable but the step stays correct if the default changes. |
| **Instructions** | 3 lines (match `TRI_order_agent.yaml`) | What the agent's own LLM reads per turn. Concise by design — Trinity agents average 3 lines. Introduce the three anti-patterns here (see below). |
| **Style** | Leave on `react_core` (Default) | Acknowledge the dropdown exists so participants are not confused. Make clear there is nothing to decide: leave it on the default. The other styles (`default`, `react`, `planner`) are deprecated. Brief description: ReAct Core is a Think → Act → Observe loop using the model's built-in function calling, optimised for multi-agent collaboration. Docs: [`agents/agent_styles`](https://developer.watson-orchestrate.ibm.com/agents/agent_styles). |

**Three anti-patterns to introduce at the Instructions field** (reference Allen Chan numbers and wxO docs links; do not expand beyond one sentence each):
- **#1 Monolithic Mega-Prompt** — resist writing a wall of text; 500-line prompts cause context compression and nondeterministic behaviour. Docs: [`agents/agent_design/foundational_architecture`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/foundational_architecture)
- **Agent-as-Business-Process** — agents approximate and reason; they do not reliably execute rigid linear processes. Deterministic sequences belong in workflows. Same docs link.
- **Agent-Washing** — wrapping a single deterministic API call in an agent loop adds ReAct overhead with no benefit. Docs: [`agents/agent_design/tooling_scalability`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/tooling_scalability)

**Test the bare agent without guidelines (end of Exercise 1):**
After building the bare agent frame (and before adding behavioral boundaries in Exercise 2), test the agent in Draft preview with an off-topic question (e.g. general knowledge/weather). Show that without any boundaries, the agent freely answers out of training knowledge. This establishes the baseline for Exercise 2 where guidelines/inline boundaries are introduced and tested.

**Catalog exploration (embedded teaching point, not a separate exercise):**
Browse the Catalog, find a pre-built IBM or ISV domain agent, open its configuration. Read the description and instructions. Teaching point: the description contract (capability, required input, return value) is the same pattern participants are learning to write. IBM and partners follow the same convention. This takes ~3 minutes and lands the "description-as-contract" concept before participants encounter it in Lab 1.3.

**Optional — Build with Bob callout:**
At the end of Exercise 1, add a clearly-marked optional callout: participants reproduce `TRI_order_agent` using the Build with AI / Build with Bob path and the pre-loaded ADK skills (`solution-architect`, `sop-builder`, `wxo-builder`). Participants without a Bob account follow along via text and screenshots. The outcome is the same deployed agent; the path is conversational rather than form-by-form.

### Exercise 2 — Define behavioural boundaries

**Opening sentence:** "In this exercise you will learn the difference between inline instructions and the `guidelines:` construct — and understand the performance cost of each."

**The two meanings of "guidelines" in wxO** (conceptual text before Step 1):

1. *Guidelines as content inside instructions* — plain-text behavioural rules written directly in the `instructions:` field. Evaluated once per turn as part of the normal agent reasoning loop. Zero latency overhead.
2. *The `guidelines:` YAML construct* — a platform feature using structured "When `<condition>` → then `<action>`" rules. Triggers a **two-phase evaluation** on every turn: Phase 1 is an extra dedicated LLM call before the agent loop; Phase 2 is the normal loop with matched guidelines injected. Cost: ~40% more LLM calls and +0.5–3 seconds latency per turn even when no guideline matches.

**Decision framework (table):**

| Use | When |
|---|---|
| `guidelines:` construct | Behaviour must dynamically activate/deactivate based on observable conversation text only (e.g. off-topic redirection, urgency detection). ⚠️ Do NOT use guidelines to route to collaborators. Docs: [`agents/agent_design/guidelines`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/guidelines) |
| Plain `instructions:` | Behaviour is constant (always applies), or conditions depend on tools, state, or multi-step logic |

**Hands-on experiment — Steps:**
1. Add an off-topic guideline block: "When the user asks about topics unrelated to Focus Corp customer support → redirect to customer inquiries." Test with a general question (e.g. weather forecast).
2. Replace it with an equivalent one-line plain instruction: "Do not answer questions unrelated to Focus Corp customer support." Re-test with the same query.
3. Observe equivalent behaviour. Discuss why Trinity uses plain instructions for all production agents (`TRI_orchestrator`, `TRI_order_agent`, etc.) — to eliminate the 40% LLM call penalty.

This is the ✨ before/after pattern — it has a genuine before/after arc.

### Exercise 3 — Deploy, test, and evaluate

**Opening sentence:** "In this exercise you will deploy your agent to Live, observe what changes, and save test conversations to run a bulk evaluation."

**Deploy to Live:**
Agents exist in Draft state while being configured and tested — they are not accessible in Orchestrate Chat until explicitly deployed. Step: click **Deploy to Live**, verify the agent appears in Orchestrate Chat. This step is easy to forget and is the most common source of the "why can't I see my agent?" confusion in the event.

> ⚠️ Authoring note: add a Note callout clarifying that in SaaS, `orchestrate agents import` imports into Draft and requires `orchestrate agents deploy --name <agent>` to go to Live (while in local Developer Edition only draft exists, so deploy commands are not supported).

**"Going further" callout from the Deploy tab** (not a hands-on step):
- Channels: once live, the agent can be connected to external channels (Microsoft Teams, WhatsApp, Slack, SMS, Facebook Messenger, Genesys Bot Connector) via "Add channel". Docs: [`channels/overview`](https://developer.watson-orchestrate.ibm.com/channels/overview)
- Voice: Build tab → Behavior → Voice — speech-to-text/text-to-speech providers. Docs: [`agent_builder/voice_configuration`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=agent_builder/voice_configuration)

**Test in Draft Preview (the hallucination cliffhanger):**
Before deploying (or after — the order in the actual guide can be adjusted), ask the agent to look up order `O-DF340K`. Observe: invented or hedged data from training knowledge. Ask it to find gaming laptops around €1,500. Observe: invented product list. Name the problem explicitly: *"The agent is reasoning from training knowledge, not your systems."* This is the motivating hook for Lab 1.1 — do not resolve it here.

> ⚠️ Authoring note: Use order `O-DF340K` (from the Trinity SOR seed data) as the example order ID throughout — not `O-D412F3`. Both exist in seed data but `O-DF340K` is the primary end-to-end scenario order.

**Save test conversations and Evaluate:**
In the Evaluate tab, save 3 named test conversations, then click "Evaluate all". The platform runs them in bulk and reports pass/fail results with relevance and correctness metrics. ~5–10 minutes. Teaching point: this is the built-in quality gate participants will use in every subsequent chapter after making changes.

**Model excursion — AI Gateway (embedded, not a hands-on step):**
After Evaluate, include a "Going further" section on model selection and the AI Gateway. Teaching points:
- wxO is model-agnostic — any LLM can be registered via the AI Gateway
- Different models interpret instruction phrasing differently; a model swap can silently change routing behaviour
- Virtual models: registered via YAML + `orchestrate models import`. Supported providers: watsonx.ai (IBM Granite), OpenAI, Anthropic, Google, AWS Bedrock, Azure OpenAI, Mistral, Groq, OpenRouter, Ollama, x.ai. Docs: [`llm/managing_llm`](https://developer.watson-orchestrate.ibm.com/llm/managing_llm)
- Model policies (advanced, public preview): pseudo-LLM that load-balances across virtual models. Docs: [`llm/model_policies`](https://developer.watson-orchestrate.ibm.com/llm/model_policies)

**No participant exercise for model registration.** The team pre-registers an IBM Granite model from watsonx.ai on the shared tenant before lab day. Participants see it appear in the dropdown and may optionally switch their agent to observe the difference.

> **Facilitator setup note (not in participant guide):** To pre-register a watsonx.ai model, create a YAML file:
> ```yaml
> kind: VirtualModel
> version: 1.0.0
> spec_version: "1.0"
> name: watsonx/ibm/granite-3-8b-instruct
> display_name: IBM Granite 3 8B Instruct
> type: chat
> provider_config:
>   watsonxProjectId: "<your-watsonx-project-id>"
>   watsonxVersion: "2024-05-31"
>   api_key: "<your-watsonx-api-key>"
> ```
> Then: `orchestrate env activate playground && orchestrate models import -f granite-3-8b.yaml`
