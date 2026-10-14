# Introduction to watsonx Orchestrate

Version 1.0.0 / Authors: Olaf Hahnl, Juergen Lukas / Duration: ~15–20 min read

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

1. [Getting Oriented](#1-getting-oriented)
   - 1.1 [Lab Scenario](#11-lab-scenario)
   - 1.2 [Event Preparation & Access](#12-event-preparation--access)
     - 1.2.1 [Before the Event — Prepare Your Local Environment](#121-before-the-event--prepare-your-local-environment)
     - 1.2.1 [On Event Day — Information from GitHub Repository](#121-continued-on-event-day--information-from-github-repository)
     - 1.2.2 [Shared Tenant Environment: Access Control and Collaboration Model](#122-shared-tenant-environment-access-control-and-collaboration-model)
2. [Core Concepts](#2-core-concepts)
   - [What is watsonx Orchestrate?](#what-is-watsonx-orchestrate)
   - [Form factors: SaaS, on-premises, and Developer Edition](#form-factors-saas-on-premises-and-developer-edition)
   - [Low-code vs. pro-code authoring](#low-code-vs-pro-code-authoring)
   - [Core terminology](#core-terminology)
3. [Next Steps](#3-next-steps)
4. [Appendix: ADK CLI Setup Guide](#appendix-adk-cli-setup-guide)
   - A.1 [Prerequisites & Python Setup](#a1-prerequisites--python-setup)
   - A.2 [Installing the ADK CLI on Windows](#a2-installing-the-adk-cli-on-windows)
   - A.3 [Installing the ADK CLI on macOS / Linux](#a3-installing-the-adk-cli-on-macos--linux)
   - A.4 [Updating an Existing ADK CLI Installation](#a4-updating-an-existing-adk-cli-installation)
   - A.5 [Connecting to the AWS wxO Environment](#a5-connecting-to-the-aws-wxo-environment)
5. [Appendix: Abbreviations and Acronyms](#appendix-abbreviations-and-acronyms)

---

## 1. Getting Oriented

watsonx Orchestrate (wxO) is IBM's platform for building and running LLM-based agents and multi-agent systems in enterprise environments. This guide orients you to wxO's core concepts and vocabulary before you proceed to any of the labs — whether you want to experience Trinity in Lab 0, build agents and tools in Labs 1.0–1.3, or work with structured workflows in Labs 2 & 3. It is a reading resource — there are no hands-on steps here, only the shared terminology every subsequent lab assumes you already know.

### 1.1 Lab Scenario

Trinity is an agentic AI assistant for contact-centre specialists on watsonx Orchestrate. In **Lab 0**, you can experience the Focus Corp contact-centre scenario as a customer support specialist: identifying customers, troubleshooting a USB-C charging issue, processing a warranty replacement, resolving a billing dispute, and validating an external warranty claim — all through a single conversational entry point, with multiple specialist agents and workflows working behind the scenes.

**Lab 0 is optional and comes first if you want to see Trinity in action before building.** It shows you the finished product without requiring any development work.

Once you understand what wxO can do, you have multiple paths forward, all equally valid and independent of each other:

- **Development path (Labs 1.0–1.3, Lab 2, Lab 3)**: Rebuild pieces of the Trinity solution yourself. Start with your first agent in Lab 1.0, then progressively build up to the supervisor/collaborator pattern that powered Trinity in Lab 0. Labs 2 and 3 add structured workflows with approval gates, multi-user collaboration, and document processing. These labs teach you *how* to build agents, tools, and workflows.
- **Operations & Governance path**: Covered in the Subject Matter Expert presentation during the event. This session focuses on monitoring, governing, and managing agents at scale — the observability and control plane that keeps agent systems reliable and trustworthy in production.

This guide gives you the terminology and concepts you will meet at each step, so the hands-on labs teach you *how* to build, not *what* watsonx Orchestrate is.

### 1.2 Event Preparation & Access

> **ℹ️ For pre-event readers:** This section is split into two phases. The first subsection (Before the Event) contains actionable steps you can take now to prepare your local environment. The second subsection (On Event Day) describes what information you'll receive from the GitHub repository when the event begins. Section 1.2.2 (Shared Tenant Environment) is valuable pre-reading to understand the architecture you'll be working in.

#### 1.2.1 Before the Event — Prepare Your Local Environment

Start now by ensuring your local environment is ready. These steps are self-contained and do not require access to wxO:

1. **Python 3.11 or later** — Ensure Python 3.11+ is installed on your machine. You will need it for the ADK CLI. See [Appendix: ADK CLI Setup Guide](#appendix-adk-cli-setup-guide) for installation instructions by platform.
2. **The ADK CLI (version 2.15+)** — Install locally before the event. You will use it throughout Labs 1.0–1.3, Lab 2, and Lab 3 (including importing pre-built artifacts, Python tools, and agentic workflows). See [Appendix: ADK CLI Setup Guide](#appendix-adk-cli-setup-guide) for step-by-step installation. If you already have it installed, verify your version using `orchestrate --version`; if the version is below 2.15, see the upgrade section in the appendix. *(See also the official [ADK Installation Guide](https://developer.watson-orchestrate.ibm.com/getting_started/installing).)*
   
   > **Note:** You can test your ADK CLI installation locally without connecting to wxO yet. Once the event begins, you will configure the CLI to connect to the **TechJam** tenant (see 1.2.2 below).

3. *(Optional)* **IBM Bob account** — Only needed if you want to try the optional "Build with Bob" exercises in Lab 1.0. You can set this up anytime before or during the event.

#### 1.2.1 (continued) On Event Day — Information from GitHub Repository

On the first day of the event, the event GitHub repository will provide all required URLs and credentials. You will need the following:

1. **Access to two wxO SaaS tenants:**
   
   Log in to wxO using your **IBM ID**. A tenant selection dialog will appear where you can select between two tenants:
   - **wxO-Playground** — Select this for **Lab 0** only. You have the **User** role here (read-only), allowing you to experience the Trinity scenario end-to-end as a contact-centre specialist.
   - **TechJam{EMEA|APAC|Americas}** — Select this for **Labs 1.0–1.3, Lab 2, and Lab 3**. You have the **Builder** role here, giving you full access to build and test agents, tools, and workflows in a shared development environment with other participants from your region.

2. **Trinity System of Record (SOR) credentials** — The labs page of the event GitHub repository, section **2. Grab your system of record credentials**, explains how to retrieve your pre-assigned SOR user ID and password (for example: `usr001`) and gives you the SOR base URL. This SOR user ID also serves as the prefix for all lab artifacts you create in the **TechJam** tenant (for example: `usr001_TRI_order_agent`).

#### 1.2.2 Shared Tenant Environment: Access Control and Collaboration Model

**How wxO on AWS works:**

Trinity runs on watsonx Orchestrate deployed on AWS. wxO's access model varies by deployment platform: wxO on IBM Cloud uses a Projects and Catalogs approach with Workspace Collaborator Roles, while wxO on AWS uses a Tenant-based access model with Platform Personas. For all development labs (Labs 1.0–1.3, 2, 3, and 4), this event uses the AWS model on the **TechJam{EMEA|APAC|Americas}** tenant, where multiple participants collaborate within a single shared environment with access controlled through standardized roles that determine what you can build, test, and deploy.

SaaS Docs: [`users/roles-watsonx-orchestrate`](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=users-roles-watsonx-orchestrate) · ADK Docs: [`connections/overview`](https://developer.watson-orchestrate.ibm.com/connections/overview)

**Platform Personas (Roles):**

| Role | What They Can Do |
|---|---|
| **Builder** | Access the Agent Development Kit (ADK), build agents, tools, and configurations. All Builders share the Draft development environment. |
| **Analyst** | Import, test, and publish skills to the Catalog; train natural language prompts. |
| **User** | Chat with deployed Live agents only through Orchestrate Chat. Zero development access. |
| **Admin** | Manage tenant settings, user roles, and system configuration. |

**For this event:** You have been assigned the **Builder** role on the **TechJam{EMEA|APAC|Americas}** tenant, giving you full access to develop in the shared Draft environment. This means:
- You can see, modify, and test all draft artifacts created by other Builders
- Your work is visible to other Builders in real time
- When you deploy to Live, your agents become available to Users (read-only chat access)
- In contrast, your **User** role on **wxO-Playground** (for Lab 0) is read-only — you can only chat with Trinity, not build or modify anything

**Naming convention to keep shared workspace organized:**

Because all Builders share the Draft environment, every artifact you create must follow this strict naming convention to prevent conflicts: prefix all artifact names with `(NAMESPACE)_TRI_`, where `(NAMESPACE)` is your assigned user ID (for example: `usr001_TRI_order_agent`, `usr002_TRI_knowledge_base`).

**Critical rule: Only modify and delete artifacts that belong to you.** Always verify that an artifact is prefixed with your own `(NAMESPACE)_` before making changes or running operations. If you see an artifact with a different participant's prefix, do not modify it — it belongs to someone else. If you accidentally modify another participant's artifact, inform your facilitator immediately so they can investigate and restore it if needed.

This naming convention is foundational to all labs in this series. You will see it reinforced in Labs 1.0, 1.1, and beyond. Following it carefully keeps the shared workspace functioning smoothly for everyone.

**Why this model matters:**

This shared-tenant, role-based approach enables tight collaboration during development (all Builders see each other's work in Draft) while maintaining separation between development and production (Live is where Users access deployed agents). Everyone builds in the same space, but the naming convention and role boundaries keep the workspace organized and safe.

#### 1.2.3 Lab Solution Artifacts

This document has no hands-on steps and builds no artifacts — there is nothing to import or reset here.

[↑ Back to Table of Contents](#table-of-contents)

---

## 2. Core Concepts

### What is watsonx Orchestrate?

watsonx Orchestrate is IBM's **agent control plane** — the enterprise platform for building, running, governing, and integrating LLM-based agents and multi-agent systems at scale. Just as a container orchestration platform like Kubernetes manages the lifecycle, networking, and scaling of containers, wxO manages the lifecycle, connectivity, routing, and governance of AI agents: from first authoring in the UI through deployment, tool integration, multi-agent coordination, evaluation, and operational monitoring.

At its core, wxO provides four things every enterprise agentic solution needs:

- **A runtime** that executes agent reasoning loops — the ReAct (Think → Act → Observe) loop that makes an agent actually *do* things rather than just talk.
- **A connectivity layer** that lets agents call real backend systems as tools — through MCP servers, OpenAPI specs, Python tools, or the growing Catalog of pre-built IBM and partner integrations.
- **Orchestration patterns** for combining specialist agents into a coherent multi-agent system — where one supervisor receives all user requests and routes them to the right domain expert, with full context carried across the conversation.
- **A governance layer** that spans the entire agent lifecycle — model selection and policy, tool access control, deployment stages (Draft → Live), evaluation, usage monitoring, and channel integration.

This control-plane positioning is what separates wxO from a bare LLM API or a simple chat widget. Any application can call a language model. An enterprise agent control plane ensures those calls are observable, controllable, and trustworthy — that the right model is used for the right task, that credentials never leak through prompts, that a human can pause and review a high-stakes decision, and that what worked last week still works after a platform update.

wxO is designed to work **alongside** the IT assets you already have, not to replace them. That includes existing applications and data sources, API backends, integration middleware, and automation platforms — RPA, BPM, rules engines. Each of these remains the right tool for what it does best: high-volume, predictable, well-defined processes and structured data access. wxO extends that landscape by adding a conversational, reasoning layer on top: agents that can reach across all of these systems, interpret natural language, and handle the tasks that structured rules cannot.

When a task requires a deterministic outcome — an eligibility check, a document extraction with a human review gate, a billing approval — wxO has its own answer: the **Agentic Workflow**. This is a wxO-native construct that combines deterministic logic (decision tables, code blocks), agent reasoning nodes, and Human-in-the-Loop approval gates inside a single callable unit. An agent invokes it as one tool call and receives one outcome. No external automation platform is required — you can build the workflow entirely inside wxO. And if you already have workflows running in an existing platform such as IBM Business Automation Workflow, you can expose them as tools and call them from an agent directly, reusing what you have without reimplementing it. Both approaches can run side by side: new agentic workflows built in wxO, and existing workflows called as tools — whichever fits the situation. Labs 2 and 3 build the wxO-native path hands-on.

The result is a new kind of solution where each layer does what it does best: structured automation where the process is known, agentic reasoning where flexibility and natural language matter, and wxO Agentic Workflows bridging the two inside a single platform. The Trinity scenario you experienced in Lab 0 is exactly this combination in action.

Everything you build in Labs 1.0 through 1.3, Lab 2, and Lab 3 is a piece of that control plane: agents, knowledge bases, tools, agentic workflows, and the orchestration pattern that ties them together.

---

### Form factors: SaaS, on-premises, and Developer Edition

wxO is available in three form factors. This event uses **SaaS** — a fully managed, IBM-hosted deployment, with continuous platform updates roughly every two weeks. It is the fastest way to get started and the form factor almost all lab exercises in this programme use directly.

SaaS is available on two cloud providers: **AWS** and **IBM Cloud**. Both offer the core wxO capabilities, but the feature sets are not always identical — some capabilities ship on one platform before the other, and a small number of features remain provider-specific. This event uses the AWS-hosted SaaS tenant.

**On-premises** deployment (via Cloud Pak for Data / CP4D, running on Red Hat OpenShift) runs wxO inside your own infrastructure. It exists for regulated environments, air-gapped networks, or organisations with data-residency requirements that rule out a shared cloud tenant. On-premises releases follow a slower cadence — roughly every few months — so the on-premises version will typically be a release or two behind the SaaS version at any given time. If you see a feature in these labs that does not appear in your organisation's on-premises install, that is the most likely reason. You will not touch on-premises deployment in these labs — it is mentioned here so you know the option exists.

The **Developer Edition** is a local install used for authoring and testing agents before deploying to SaaS or on-premises. It runs a full wxO environment on your laptop inside a Docker-based virtual machine — a set of containers for the platform runtime, vector database, object storage, search index, observability, and more. The hardware requirement is a minimum of 8 CPU cores and 16 GB RAM (24 GB if document processing is enabled), and Docker Desktop must be installed and running. Even then, the Developer Edition does not include an LLM: you must separately supply access to watsonx.ai, Groq, or another supported inference provider. Setting all of this up takes meaningful time, and it is not uncommon to hit environment-specific issues with Docker networking, WSL on Windows, or corporate proxies.

For this event, SaaS is the simpler choice: nothing to install beyond the ADK CLI, no hardware constraint, and everyone works from the same running environment. That is why these labs use SaaS throughout. The Developer Edition is the right tool when you want a local sandbox that works offline or mirrors a specific platform version.

The ADK CLI you installed in the setup steps is the same regardless of which form factor you target — the same `orchestrate` commands work against a local Developer Edition and against the SaaS tenant. Several pro-code paths referenced later in these labs use the CLI directly, regardless of where it is pointed.

---

### Low-code vs. pro-code authoring

Every capability in wxO can be authored two ways: **low-code**, through the wxO UI (the Agent Builder, Flow Builder, Tool Builder, and so on), or **pro-code**, by writing agent, tool, workflow, and knowledge base definitions as YAML or Python in a text editor or IDE (such as the VS Code ADK extension). In either case, the ADK CLI is used to deploy those artifacts to a wxO instance — `orchestrate agents import`, `orchestrate tools import`, and so on. The CLI is the deployment mechanism; it is not itself the authoring environment.

**In these labs:** Labs 1.0–1.3, Lab 2, and Lab 3 use the low-code UI path as the primary track — you will build agents through the Agent Builder and workflows through the Flow Builder. However, some artifacts in these labs are authored or imported via the ADK CLI because the UI does not expose all features — notably, Python-based tools and some knowledge base configurations — or because pre-built artifacts need to be deployed to your environment. You will encounter this hands-on in Lab 1.1 (importing tools) and Lab 1.2 (knowledge bases).

**In general:** Pro-code paths exist for every operation you perform in the UI. New wxO capabilities typically become available in the ADK and YAML first and are surfaced in the UI later — so the pro-code path is sometimes the only path for the newest features. Pro-code artifacts are plain text files that live in a repository alongside the rest of your code, which means AI coding assistants — IBM Bob, GitHub Copilot, or any other — can read, generate, and iterate on them directly. Describing what you want an agent to do and having an assistant draft the YAML is often faster than clicking through the UI, and the result is immediately version-controlled.

This programme highlights pro-code equivalents where relevant — usually as an optional "Going further" callout, not a required step. You do not need to choose between the two: low-code is the default track for these labs, and the pro-code equivalent is there when you want to see how the same result looks as YAML or Python.

---

### Core terminology

For each term below: a plain explanation of what it is and why it matters, then a pointer to the lab where you will meet it hands-on.

#### Chatbot vs. Agent

You have almost certainly used a chatbot like ChatGPT or Claude in its standard form. wxO agents are a different category, and the distinction is worth understanding now.

Both chatbots and agents can hold a conversation and remember what was said earlier in that same session. The difference is the ability to act. A chatbot answers from what it knows: its training data and whatever you have typed so far. It can produce text, explain things, and summarise — but it cannot reach into a live system to look something up, update a record, trigger a workflow, or call a backend API. When the conversation ends, nothing has changed in the world.

An agent can do all of those things. It receives a goal, reasons about what steps are needed, calls tools connected to real systems, observes the results, and continues until the task is done. The underlying language model may be the same — what makes it an agent is that it is connected to tools that let it act.

Forward pointer: You will test your agent before it has any tools attached in Lab 1.0 — Building Your First Agent, and watch it behave exactly like a chatbot, answering from training knowledge alone. Attaching tools in Lab 1.1 is what lets it act.

#### Supervisor and Collaborator Agents (Multi-Agent Systems)

A **supervisor** is an agent that routes a request to the right specialist rather than handling it itself; a **collaborator** is one of those specialists, scoped to a single domain and invoked by the supervisor. Together they let a task be handled by multiple agents instead of one.

This matters because a single agent breaks down as its job grows: LLMs lose reliability as instructions and tools pile into one prompt — context compresses, tool selection between near-duplicates gets error-prone, and responses grow harder to predict and reproduce. This is a general limitation of agentic AI, not a wxO-specific one. wxO architecture guidance recommends the same fix: split a monolithic agent into focused sub-agents, each with a well-scoped task (ADK Docs: [`agents/agent_design/foundational_architecture`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/foundational_architecture)).

Supervisor/collaborator is one of several known coordination patterns — others include a fixed sequential pipeline, an evaluator-optimizer critic loop, and unstructured peer-to-peer collaboration — and it's the one wxO's agent layer (the `collaborators:` schema field) natively supports. The others aren't unsupported so much as one layer down: the decision guide for agents vs. workflows is explicit that patterns like critic loops or parallel agents with aggregated results need to be built as an agentic workflow instead — a construct covered in its own right later in this list — with individual Agent nodes doing the reasoning at the steps that need it while the surrounding workflow enforces sequencing and structure (ADK Docs: [`agents/agent_design/agentic_workflow_decision_guide`](https://developer.watson-orchestrate.ibm.com/agents/agent_design/agentic_workflow_decision_guide)).

In the Trinity scenario, `TRI_orchestrator` is the supervisor, routing to five collaborator agents (CRM, Orders, Billing, Technical Policy, Warranty) — one per backend domain. "Supervisor" and "collaborator" are the terms this programme uses; you will also see "orchestrator" (Trinity's own artifact name), "primary agent" (the IBM Knowledge Center's term), or "manager" (used by frameworks like LangGraph and OpenAI) for the same two roles elsewhere. One collision worth flagging now: Lab 2's billing dispute also uses "supervisor" — there, for the **human** who approves a workflow step, a different role entirely. Context always makes clear which one is meant.

Forward pointer: You will build a functioning supervisor with two collaborator agents in Lab 1.3 — Multi-Agent Systems.

#### Knowledge Base

A knowledge base is a set of domain documents ingested into wxO, automatically split into smaller passages (chunks), and indexed for search. When a question arrives, the agent retrieves the most relevant chunk and generates its answer from that passage — a pattern called Retrieval-Augmented Generation (RAG).

This matters because a language model's training data is frozen at a point in time and contains nothing about your company's specific products, policies, or procedures. A knowledge base gives the agent access to exactly that content, without retraining the model. In the Trinity scenario, the Technical Support Agent uses a knowledge base of Focus Corp troubleshooting guides and hardware policies — content that exists nowhere in the model's training data.

Forward pointer: You will build a knowledge base and connect a technical support agent to it in Lab 1.2 — Building an Agent with RAG / Knowledge Base.

#### Connection

A connection is the security anchor for every external tool integration in wxO. It keeps credentials — API keys, usernames and passwords, endpoint URLs, SSL configuration — separate from the tool definition, the source code, and the agent's instructions. You define a connection once; every tool that needs those credentials references it by name, and wxO injects the credentials at invocation time rather than exposing them anywhere in the agent's reasoning.

This separation has two practical benefits. First, reuse: if you have ten tools that all call the same backend system, they all reference one connection — if the password rotates, you update it in one place. Second, security: because credentials are injected at runtime rather than written into a prompt or tool definition, they never appear in the agent's context window and cannot be leaked through the agent's output. Naively embedding credentials in prompts or tool descriptions is a real attack vector in agent systems — connections are how wxO avoids it by design. In the Trinity scenario, all five collaborator agents reach the Focus Corp backend through a single connection that holds the BAW endpoint URL and credentials. None of those details appear anywhere in an agent instruction or tool definition.

Forward pointer: Lab 1.1 — Tools, MCP section, is where you will create and use your first connection.

#### MCP Servers and Toolkits

An MCP server — called a *toolkit of kind `mcp`* in the ADK CLI — is a named container that automatically discovers and packages a backend system's capabilities as individual wxO tools. Instead of defining tools one at a time, registering an MCP server imports every tool it exposes into the tool registry in a single action. In the Trinity scenario, a single MCP toolkit called `TRI_SOR_MCP` wraps the entire Focus Corp backend: all 33 tools across eight service groups (CRM, Orders, Catalog, Billing, Shipping, Warranty, Utilities, Admin), registered in one step.

One detail worth understanding before you get to the lab: in the Agent Builder you click **Add Tool**, then select **Add from MCP Server**. The tool list that opens is empty until you select a toolkit from the filter dropdown — only then does the list populate with the tools that toolkit contains. Typing in the search field without selecting a toolkit first returns nothing. Knowing to apply the filter first will save you a moment of confusion when you reach this step in Lab 1.1.

Forward pointer: You will create your first MCP toolkit in Lab 1.1 — Tools, MCP section.

#### Tools and Scoping

A tool is an individual callable action attached to an agent — the thing that lets an agent act rather than just talk. Even when an MCP server or an OpenAPI spec registers dozens of tools on the platform at once, you as the agent author choose to attach only the specific tools that agent needs.

This selectivity matters because the agent uses tool descriptions to decide which tool to call for a given request. The more tools are attached, the more descriptions it has to reason across — and the more likely it is to pick the wrong one, call an unnecessary tool, or hesitate. Scope deliberately: give each agent only the tools it genuinely needs for its assigned tasks. In the Trinity scenario, each of the five collaborator agents carries a small, focused set of tools scoped to its domain — the CRM agent handles customer lookups, the Order agent handles orders and catalog, and so on. The supervisor carries no tools at all: its job is to route requests to the right collaborator, not to call tools itself.

Forward pointer: Lab 1.1 — Tools covers this hands-on, including how to test each tool individually before attaching it.

#### Agentic Workflow

An Agentic Workflow is a special kind of tool that deserves its own mention because of how much it packs into one callable unit. Unlike a regular tool call, an Agentic Workflow combines deterministic steps (decision tables, code blocks), agent reasoning nodes, and Human-in-the-Loop (HITL) approval gates — all inside one construct that the calling agent sees as a single tool call.

The reason to reach for a workflow rather than just letting the agent keep reasoning is predictability and control. An agent is flexible and conversational — exactly what you want for information lookup and troubleshooting. But when a task involves writing to a system of record, approving a refund, or making a decision that affects money, you want the outcome to be deterministic, auditable, and human-reviewed before anything changes. An Agentic Workflow gives you that: the agent hands off to a structured process, a human can review and approve at a defined gate, and the result comes back to the agent as a clean outcome.

What makes Agentic Workflows distinctive is that they cover the full spectrum from fully structured to fully agentic — and any mix in between. A workflow can be entirely deterministic: a decision table checks an eligibility rule, a code block formats a result, done. Or it can include agent reasoning nodes that handle the parts of the process where natural language understanding is needed — classifying an uploaded document, for example — while keeping the approval gate and the write operation deterministic. You choose how much structure and how much reasoning each step needs.

In the Trinity scenario you experienced both ends: the billing dispute runs a decision table to check approval thresholds and pauses for a supervisor to approve before any record is updated; the warranty claim for a reseller product uses an agent reasoning node to classify the uploaded document before a structured warranty rule check determines the outcome. Both are Agentic Workflows called as a single tool by the relevant agent.

Forward pointer: Lab 2 (Billing Dispute) and Lab 3 (Document Processing) build this hands-on.

#### Catalog

The Catalog is wxO's library of pre-built agents, tools, and MCP toolkits, published by IBM and by ISV partners such as SAP, Workday, and Salesforce. You can add a Catalog agent as a collaborator in your own supervisor/collaborator system, or use one as a starting point instead of building from scratch. It also contains pre-built tools and remote MCP servers you can register directly.

What the Catalog changes is the build-vs-reuse calculation. Without it, connecting wxO to Salesforce, ServiceNow, or Workday means locating the API documentation, writing the tool definitions, handling authentication, and testing each operation. With a Catalog entry, that integration is already packaged — you register it, configure the connection, and the tools are available to any agent. For organisations that run standard enterprise software, the Catalog is often the fastest path to a working agent.

The Catalog grows continuously as IBM and partners publish new entries, so what is available today will be broader in six months. Browsing it early — even before you need a specific integration — is a useful way to understand what wxO considers in scope.

Forward pointer: You will browse the Catalog during the Explore exercise in Lab 1.0.

#### Agentic Control Plane & Controls

wxO includes an **Agentic Control Plane** — a governance and orchestration layer that manages agent behavior, security, and observability across your entire fleet. Think of it as "air traffic control for AI agents": it sits above the agents themselves (the Data Plane) and enforces policies, monitors health, and prevents sprawl across your organization.

Within the Control Plane, **Controls** are platform-level policy rules that enforce security, compliance, and operational bounds — things like masking sensitive data, rate-limiting tool calls, enforcing model fallbacks, or blocking requests. Unlike Guidelines (which are agent-specific and evaluated by the LLM), Controls operate at the platform gateway and impose no extra inference cost.


[↑ Back to Table of Contents](#table-of-contents)

---

## 3. Next Steps

You now have the foundational concepts you need to start building.

In this guide, you learned:

- What watsonx Orchestrate is and the problem it is designed to solve — the long tail of tasks too conversational, varied, or infrequent for traditional automation
- The three wxO form factors — SaaS, on-premises, and Developer Edition — and which one this event uses
- The low-code vs. pro-code authoring distinction and which path these labs use by default
- The seven core terms the coming labs assume you already know — what makes an agent different from a chatbot, how a knowledge base grounds an agent in your own content, why connections keep credentials out of prompts, how MCP toolkits register tools in bulk, why scoping tools to each agent matters, what an Agentic Workflow adds over plain agent reasoning, and what the Catalog offers

When the event begins, you can choose which labs to complete based on your interests. The labs themselves are independent and can be completed in any order:

- **Lab 1.0–1.3**: Agent fundamentals and architecture — build progressively from your first agent, to connecting tools, to building a multi-agent supervisor/collaborator system
- **Lab 2**: Agentic workflows with HITL approval and multi-user collaboration — design a billing dispute workflow with role-based approval gates and specialist/supervisor handoff
- **Lab 3**: Agentic workflows with document processing — design a warranty claim workflow that classifies and extracts information from uploaded documents

[↑ Back to Table of Contents](#table-of-contents)

---

## Appendix: ADK CLI Setup Guide

> **Important:** The Agent Development Kit (ADK) CLI is **mandatory** for this event. You will need it to import pre-built artifacts, Python tools, and agentic workflows in Labs 1.0–1.3, Lab 2, and Lab 3. Install it before the event using the steps below.

The Agent Development Kit (ADK) CLI (`orchestrate`) provides developer-focused command-line tooling to build, test, package, and deploy agents, tools, knowledge bases, and workflows to watsonx Orchestrate.

For full details and reference on the ADK CLI, refer to the official documentation:
- [Installing the ADK](https://developer.watson-orchestrate.ibm.com/getting_started/installing)
- [ADK CLI Reference](https://developer.watson-orchestrate.ibm.com/getting_started/cli)
- [Configuring Remote Environments](https://developer.watson-orchestrate.ibm.com/environment/initiate_environment)

> **Version Requirement:** These labs require ADK CLI version **2.15** or higher.

---

### Automated Setup with Scripts (Recommended)

Instead of following the manual steps below, you can use automated setup scripts that handle all steps in one go:

- **Windows:** `labs/adk-setup/setup-adk.ps1`
- **macOS/Linux:** `labs/adk-setup/setup-adk.sh`

**Key features:**
- Checks for existing Python, virtual environment, and ADK installations — **only installs or upgrades what is needed**
- Does not modify configurations that are already in place and meet the requirements
- Safe to re-run multiple times without side effects
- Supports pre-event mode (install ADK only, skip environment configuration) with the `-SkipEnv` / `--skip-env` flag

**Pre-event setup:**
```powershell
# Windows
.\labs\adk-setup\setup-adk.ps1 -SkipEnv
```
```bash
# macOS/Linux
./labs/adk-setup/setup-adk.sh --skip-env
```

**After the event begins (with credentials):**

The script needs the **Service instance URL** and an **API key** for the **TechJam{EMEA|APAC|Americas}** instance. To get them, complete [Step 1 of A.5](#step-1-obtain-credentials-from-wxo). You do not need Steps 2 to 4 of A.5, because the script registers and activates the environment for you.

The script will prompt you interactively for your API key. You can also provide it via environment variable or parameter to avoid the prompt:

```powershell
# Windows — script will prompt for API key
.\labs\adk-setup\setup-adk.ps1 -Url <service-instance-url>

# Windows — API key from environment variable (recommended)
$env:WXO_API_KEY = "<your-api-key>"
.\labs\adk-setup\setup-adk.ps1 -Url <service-instance-url>
```

```bash
# macOS/Linux — script will prompt for API key (hidden input)
./labs/adk-setup/setup-adk.sh -u <service-instance-url>

# macOS/Linux — API key from environment variable (recommended)
export WXO_API_KEY="<your-api-key>"
./labs/adk-setup/setup-adk.sh -u <service-instance-url>

# macOS/Linux — API key via parameter (visible in history; use env var instead)
./labs/adk-setup/setup-adk.sh -u <service-instance-url> -k <your-api-key>
```

> **Security note:** The environment variable approach (`WXO_API_KEY`) is preferred over the command-line parameter, as the parameter is visible in your shell history and process list.

**Manual steps below** provide a detailed reference for understanding each step, or if you prefer to set up your environment manually.

---

### A.1 Prerequisites & Python Setup

The ADK CLI requires **Python 3.11** (or later).

#### Checking Python on Windows

1. Open **PowerShell** or **Command Prompt** and verify if Python 3.11+ is installed:
   ```powershell
   python --version
   ```
   *(or `py --version`)*

2. If Python is not installed or the version is older than 3.11:
   - Download the Python 3.11 installer from [python.org/downloads/windows](https://www.python.org/downloads/windows/).
   - Run the installer and **be sure to check the box: "Add python.exe to PATH"** before clicking **Install Now**.
   - Alternatively, install via Windows Package Manager:
     ```powershell
     winget install Python.Python.3.11
     ```
   - Restart your terminal and re-run `python --version` to confirm.

#### Checking Python on macOS / Linux

1. Open your terminal and check:
   ```bash
   python3 --version
   ```
2. If Python is not installed or older than 3.11:
   - **macOS:** Install via Homebrew: `brew install python@3.11`
   - **Ubuntu/Debian:** `sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv`
   - **RHEL/Fedora:** `sudo dnf install -y python3 python3-pip`

---

### A.2 Installing the ADK CLI on Windows

Follow these steps to create a dedicated lab workspace and install the ADK CLI inside a Python virtual environment using `pip` (see official [System and Virtual Environment Installation](https://developer.watson-orchestrate.ibm.com/getting_started/installing#setting-up-and-installing-the-adk)):

1. Open **PowerShell** and create a dedicated workspace directory:
   ```powershell
   mkdir wxo-labs
   cd wxo-labs
   ```

2. Create a Python virtual environment:
   ```powershell
   python -m venv .venv
   ```

3. Activate the virtual environment:
   ```powershell
   .\.venv\Scripts\activate
   ```
   *(Your terminal prompt will now show `(.venv)`)*

4. Install the ADK CLI package via `pip`:
   ```powershell
   pip install --upgrade ibm-watsonx-orchestrate
   ```

5. Verify the version:
   ```powershell
   orchestrate --version
   ```
   Confirm that the output reports **2.15.x** or higher.

---

### A.3 Installing the ADK CLI on macOS / Linux

Follow these steps to create a dedicated lab workspace and install the ADK CLI inside a Python virtual environment using `pip`:

1. Open your terminal and create a dedicated workspace directory:
   ```bash
   mkdir wxo-labs
   cd wxo-labs
   ```

2. Create a Python virtual environment:
   ```bash
   python3 -m venv .venv
   ```

3. Activate the virtual environment:
   ```bash
   source .venv/bin/activate
   ```
   *(Your terminal prompt will now show `(.venv)`)*

4. Install the ADK CLI package via `pip`:
   ```bash
   pip install --upgrade ibm-watsonx-orchestrate
   ```

5. Verify the version:
   ```bash
   orchestrate --version
   ```
   Confirm that the output reports **2.15.x** or higher.

---

### A.4 Updating an Existing ADK CLI Installation

If you already have the ADK CLI installed from a prior event or project, verify your current version:

```bash
orchestrate --version
```

If the reported version is below **2.15**, upgrade the package:

1. Activate your existing virtual environment:
   - **Windows:** `.\.venv\Scripts\activate`
   - **macOS / Linux:** `source .venv/bin/activate`
2. Run the upgrade command:
   ```bash
   pip install --upgrade ibm-watsonx-orchestrate
   ```
3. Verify that the version has been updated:
   ```bash
   orchestrate --version
   ```

---

### A.5 Connecting to the AWS wxO Environment

> **ℹ️ Event-day only:** The steps in this section can only be completed once the event has begun and you have been invited to the wxO tenants (wxO-Playground and TechJam{EMEA|APAC|Americas}). You cannot connect to these environments before the event starts.

Once installed, connect the ADK CLI to the **TechJam{EMEA|APAC|Americas}** watsonx Orchestrate instance. The actual tenant name depends on the event you are participating in (for example, TechJamEMEA, TechJamAPAC, or TechJamAmericas).

#### Step 1: Obtain Credentials from wxO

You have access to two wxO tenants: **wxO-Playground** and **TechJam{EMEA|APAC|Americas}**. You use the ADK CLI only in the build labs, which run on **TechJam{EMEA|APAC|Americas}**.

1. Open the following link in your browser and sign in:
   ```
   https://dl.watson-orchestrate.ibm.com
   ```
2. Select the **TechJam{EMEA|APAC|Americas}** tenant.
3. Click your user profile icon (top-right) → **Settings**.
4. Select the **API details** tab.
5. Copy and save the **Service instance URL**. You will need it later.
6. Click **Generate API key**. The IBM SaaS Console opens in a new browser tab.
7. If the IBM SaaS Console asks you to sign in, sign in.
8. Confirm that the page shows **Access management** and **Managing Instance: TechJam{EMEA|APAC|Americas}**.
9. Select the **API keys** tab.
10. Click **Generate key**.
11. In the **API key name** field, enter your assigned user ID (for example, `usr012`).
12. In the **Expiration date** field, enter a date after the end of the event, in `MM/DD/YYYY` format.
13. Click **Generate key**.
14. Click **Copy to clipboard**, and save your API key in a secure place.

> **Note:** The API key is shown only once, for about 5 minutes. You cannot retrieve it later. If you lose it, generate a new key.

> **Note:** The API key has the same access as your user. In the **Generate API key** dialog, **Roles** shows **Builder** and **Service user**. The key is for the instance shown in step 8, so it does not work for other instances.

> **Note:** If you see the message `API key not created, try to create it again`, or a page that lists accounts but no instance, ask a facilitator to check your role assignment.

#### Step 2: Add the Remote Environment

Register the remote environment in the CLI using the `mcsp` authentication type for AWS instances:

```bash
orchestrate env add -n trinity-lab -u <service-instance-url> --type mcsp
```
*(Replace `<service-instance-url>` with the Service instance URL you saved in Step 1.)*

#### Step 3: Activate the Environment

Authenticate and set `trinity-lab` as your active target environment:

```bash
orchestrate env activate trinity-lab
```

Alternatively, pass your API key directly to avoid the interactive prompt:

```bash
orchestrate env activate trinity-lab -a <API-KEY>
```

If using the interactive method, paste your **API key** when prompted.

> **Note on Authentication Expiry:**
> Remote environment authentication tokens expire after **2 hours**. If a CLI command fails later with an authentication or token error, re-run the activation command:
> ```bash
> orchestrate env activate trinity-lab
> ```

#### Step 4: Verify Connectivity

Test that the CLI can communicate with the **TechJam{EMEA|APAC|Americas}** instance:

```bash
orchestrate agents list
```
The command lists the agents in the instance. A new instance shows only the built-in agents, such as `AskOrchestrate`.

[↑ Back to Table of Contents](#table-of-contents)

---

## Appendix: Abbreviations and Acronyms

| Abbreviation | Full term | Notes |
|---|---|---|
| **ADK** | Agent Development Kit | IBM's CLI and Python SDK for building, testing, and deploying agents, tools, and workflows to watsonx Orchestrate. |
| **API** | Application Programming Interface | A defined contract through which one software system calls another. |
| **AWS** | Amazon Web Services | Cloud provider hosting the wxO SaaS tenant used in this event. |
| **BAW** | IBM Business Automation Workflow | The workflow engine inside CP4BA used to host the Focus Corp System of Record (SOR) backend. |
| **BPM** | Business Process Management | Discipline and tooling for modelling, automating, and monitoring structured business processes. |
| **CLI** | Command-Line Interface | A text-based interface for interacting with software via commands. The ADK CLI is `orchestrate`. |
| **CP4BA** | IBM Cloud Pak for Business Automation | The IBM platform that includes BAW and other automation capabilities. Hosts the Focus Corp SOR in this lab scenario. *Not the same as CP4D.* |
| **CP4D** | IBM Cloud Pak for Data | The IBM platform used for on-premises deployments of watsonx Orchestrate (and other IBM data and AI services). Runs on Red Hat OpenShift. *Not the same as CP4BA.* |
| **CRM** | Customer Relationship Management | System of record for customer profile data. In the Trinity scenario, accessed via `TRI_crm_agent`. |
| **HITL** | Human-in-the-Loop | A workflow pattern where execution pauses and a human must review or approve before it continues. |
| **IBM** | International Business Machines | IBM Corporation. |
| **ISV** | Independent Software Vendor | A third-party software company that builds and sells software products — e.g., SAP, Workday, Salesforce. |
| **KB** | Knowledge Base | A set of documents ingested into wxO for RAG-based retrieval by an agent. |
| **LLM** | Large Language Model | A deep learning model trained on large text corpora that generates human-like text; the reasoning engine inside an agent. |
| **MCP** | Model Context Protocol | An open standard (introduced by Anthropic, November 2024) that defines how agents discover and call tools. Solves the N×M integration problem. |
| **MCSP** | Multi-Cloud Services Platform | IBM's authentication platform used for wxO SaaS on AWS. Authentication type `mcsp` in `orchestrate env add`. |
| **NLU** | Natural Language Understanding | The capability of a model to interpret the meaning and intent of text written in human language. |
| **RAG** | Retrieval-Augmented Generation | A pattern where an agent retrieves relevant passages from a knowledge base before generating a response, grounding the answer in real documents rather than training knowledge alone. |
| **RHOAI** | Red Hat OpenShift AI | IBM/Red Hat's AI platform on OpenShift. *Not the same as the platform used to host watsonx Orchestrate on-premises — that is CP4D.* |
| **RPA** | Robotic Process Automation | Software that automates repetitive UI-level tasks by mimicking human interactions with applications. |
| **SaaS** | Software as a Service | A software delivery model where the vendor hosts and manages the platform; users access it via a browser or API. |
| **SOR** | System of Record | The authoritative backend system for a given data domain (CRM, Orders, Billing, etc.). In this scenario, hosted in IBM BAW / CP4BA. |
| **SOAP** | Simple Object Access Protocol | An XML-based messaging protocol for web services. Used in the CRM Python tool integration in Lab 1.1. |
| **SSL** | Secure Sockets Layer | The predecessor to TLS; the term is still commonly used to refer to transport encryption for HTTPS connections. |
| **TLS** | Transport Layer Security | The protocol that encrypts data in transit between a client and a server. |
| **UC** | Use Case | A numbered scenario definition describing an end-to-end agent interaction. Trinity defines UC-00 through UC-04. |
| **UI** | User Interface | The visual surface through which a user interacts with a system — in this context, the wxO Agent Builder in the browser. |
| **WSDL** | Web Services Description Language | An XML format that describes the interface of a SOAP web service. |
| **wxO** | watsonx Orchestrate | IBM's enterprise platform for building, running, and governing LLM-based agents and multi-agent systems. |
| **YAML** | YAML Ain't Markup Language | A human-readable data serialisation format used for wxO agent and tool configuration files. |

[↑ Back to Table of Contents](#table-of-contents)
