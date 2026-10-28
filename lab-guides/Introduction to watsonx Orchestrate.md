# Introduction to watsonx Orchestrate

Version 1.0.1 / Authors: Olaf Hahnl, Juergen Lukas / Duration: ~20–25 min read

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
2. [Core Concepts](#2-core-concepts)
   - [What is watsonx Orchestrate?](#what-is-watsonx-orchestrate)
   - [Form factors: SaaS, on-premises, and Developer Edition](#form-factors-saas-on-premises-and-developer-edition)
   - [Low-code vs. pro-code authoring](#low-code-vs-pro-code-authoring)
   - [Core terminology](#core-terminology)
3. [Next Steps](#3-next-steps)
4. [Appendix: Abbreviations and Acronyms](#appendix-abbreviations-and-acronyms)

---

## 1. Getting Oriented

watsonx Orchestrate (wxO) is IBM's platform for building and running LLM-based agents and multi-agent systems in enterprise environments. This guide orients you to wxO's core concepts and vocabulary before you proceed to any of the labs — whether you want to experience Trinity in Lab 0, build agents and tools in Labs 1.0–1.3, or work with structured workflows in Labs 2 & 3.

This guide is conceptual reading material only. There are no hands-on development or lab exercises here — those begin in the subsequent lab guides. For local environment setup and event-day credential retrieval, see [Setup & Event Credentials](Setup%20&%20Event%20Credentials.md).

### 1.1 Lab Scenario

Trinity is an agentic AI assistant for contact center specialists on watsonx Orchestrate. **Lab 0 (recommended first)** lets you experience the complete Focus Corp scenario end-to-end as a customer support specialist: identifying customers, troubleshooting a USB-C charging issue, processing a warranty replacement, resolving a billing dispute, and validating external warranty claims. No development work — just see how all the agents and workflows fit together before you start building pieces of it in Labs 1.0–1.3, 2, and 3.

The hands-on development labs teach you how to build agents, tools, and workflows by rebuilding pieces of Trinity. You can explore any lab based on your interests, but doing them in order provides the strongest foundation for understanding the full picture. During the event, there's also an Operations & Governance presentation covering monitoring, governing, and managing agents at scale — the observability and control plane that keeps agent systems reliable and trustworthy in production.

This guide gives you the terminology and concepts you will meet at each step, so the hands-on labs teach you *how* to build, not *what* watsonx Orchestrate is.


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

wxO is available in three form factors. This event uses **SaaS** — a fully managed, IBM-hosted deployment, with continuous platform updates roughly every two weeks. It is the fastest way to get started and the form factor almost all lab exercises in this program use directly.

SaaS is available on two cloud providers: **AWS** and **IBM Cloud**. Both offer the core wxO capabilities, but the feature sets are not always identical — some capabilities ship on one platform before the other, and a small number of features remain provider-specific. This event uses the AWS-hosted SaaS tenant.

**On-premises** deployment (via Cloud Pak for Data / CP4D, running on Red Hat OpenShift) runs wxO inside your own infrastructure. It exists for regulated environments, air-gapped networks, or organizations with data-residency requirements that rule out a shared cloud tenant. On-premises releases follow a slower cadence — roughly every few months — so the on-premises version will typically be a release or two behind the SaaS version at any given time. If you see a feature in these labs that does not appear in your organisation's on-premises install, that is the most likely reason. You will not touch on-premises deployment in these labs — it is mentioned here so you know the option exists.

The **Developer Edition** is a local install used for authoring and testing agents before deploying to SaaS or on-premises. It runs a full wxO environment on your laptop inside a Docker-based virtual machine — a set of containers for the platform runtime, vector database, object storage, search index, observability, and more. The hardware requirement is a minimum of 8 CPU cores and 16 GB RAM (24 GB if document processing is enabled), and Docker Desktop must be installed and running. Even then, the Developer Edition does not include an LLM: you must separately supply access to watsonx.ai, Groq, or another supported inference provider. Setting all of this up takes meaningful time, and it is not uncommon to hit environment-specific issues with Docker networking, WSL on Windows, or corporate proxies.

For this event, SaaS is the simpler choice: nothing to install beyond the ADK CLI, no hardware constraint, and everyone works from the same running environment. That is why these labs use SaaS throughout. The Developer Edition is the right tool when you want a local sandbox that works offline or mirrors a specific platform version.

The ADK CLI you installed in the setup steps is the same regardless of which form factor you target — the same `orchestrate` commands work against a local Developer Edition and against the SaaS tenant. Several pro-code paths referenced later in these labs use the CLI directly, regardless of where it is pointed.

---

### Low-code vs. pro-code authoring

Every capability in wxO can be authored two ways: **low-code**, through the wxO UI (the Agent Builder, Flow Builder, Tool Builder, and so on), or **pro-code**, by writing agent, tool, workflow, and knowledge base definitions as YAML or Python in a text editor or IDE (such as the VS Code ADK extension). In either case, the ADK CLI is used to deploy those artifacts to a wxO instance — `orchestrate agents import`, `orchestrate tools import`, and so on. The CLI is the deployment mechanism; it is not itself the authoring environment.

**In these labs:** Labs 1.0–1.3, Lab 2, and Lab 3 use the low-code UI path as the primary track — you will build agents through the Agent Builder and workflows through the Flow Builder. However, some artifacts in these labs are authored or imported via the ADK CLI because the UI does not expose all features — notably, Python-based tools and some knowledge base configurations — or because pre-built artifacts need to be deployed to your environment. You will encounter this hands-on in Lab 1.1 (importing tools) and Lab 1.2 (knowledge bases).

**In general:** Pro-code paths exist for every operation you perform in the UI. New wxO capabilities typically become available in the ADK and YAML first and are surfaced in the UI later — so the pro-code path is sometimes the only path for the newest features. Pro-code artifacts are plain text files that live in a repository alongside the rest of your code, which means AI coding assistants — IBM Bob, GitHub Copilot, or any other — can read, generate, and iterate on them directly. Describing what you want an agent to do and having an assistant draft the YAML is often faster than clicking through the UI, and the result is immediately version-controlled.

This program highlights pro-code equivalents where relevant — usually as an optional "Going further" callout, not a required step. You do not need to choose between the two: low-code is the default track for these labs, and the pro-code equivalent is there when you want to see how the same result looks as YAML or Python.

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

In the Trinity scenario, `TRI_orchestrator` is the supervisor, routing to five collaborator agents (CRM, Orders, Billing, Technical Policy, Warranty) — one per backend domain. "Supervisor" and "collaborator" are the terms this program uses; you will also see "orchestrator" (Trinity's own artifact name), "primary agent" (the IBM Knowledge Center's term), or "manager" (used by frameworks like LangGraph and OpenAI) for the same two roles elsewhere. One collision worth flagging now: Lab 2's billing dispute also uses "supervisor" — there, for the **human** who approves a workflow step, a different role entirely. Context always makes clear which one is meant.

Forward pointer: You will build a functioning supervisor with two collaborator agents in Lab 1.3 — Multi-Agent Systems.

#### Knowledge Base

A knowledge base is a set of domain documents ingested into wxO, automatically split into smaller passages (chunks), and indexed for search. When a question arrives, the agent retrieves the most relevant chunk and generates its answer from that passage — a pattern called Retrieval-Augmented Generation (RAG).

This matters because a language model's training data is frozen at a point in time and contains nothing about your company's specific products, policies, or procedures. A knowledge base gives the agent access to exactly that content, without retraining the model. In the Trinity scenario, the Technical Policy Agent uses a knowledge base of Focus Corp troubleshooting guides and hardware policies — content that exists nowhere in the model's training data.

Forward pointer: You will build a knowledge base and connect a technical policy agent to it in Lab 1.2 — Building an Agent with RAG / Knowledge Base.

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

What the Catalog changes is the build-vs-reuse calculation. Without it, connecting wxO to Salesforce, ServiceNow, or Workday means locating the API documentation, writing the tool definitions, handling authentication, and testing each operation. With a Catalog entry, that integration is already packaged — you register it, configure the connection, and the tools are available to any agent. For organizations that run standard enterprise software, the Catalog is often the fastest path to a working agent.

The Catalog grows continuously as IBM and partners publish new entries, so what is available today will be broader in six months. Browsing it early — even before you need a specific integration — is a useful way to understand what wxO considers in scope.

Forward pointer: You will browse the Catalog during the Explore exercise in Lab 1.0.

#### Agentic Control Plane & Controls

wxO includes an **Agentic Control Plane** — a governance and orchestration layer that manages agent behavior, security, and observability across your entire fleet. Think of it as "air traffic control for AI agents": it sits above the agents themselves (the Data Plane) and enforces policies, monitors health, and prevents sprawl across your organization.

Within the Control Plane, **Controls** are platform-level policy rules that enforce security, compliance, and operational bounds — things like masking sensitive data, rate-limiting tool calls, enforcing model fallbacks, or blocking requests. Unlike Guidelines (which are agent-specific and evaluated by the LLM), Controls operate at the platform gateway and impose no extra inference cost.

The Control Plane and Controls are governance concepts that you will encounter in the governance presentation portion of this event and in your agent designs as you scale from development to production.

[↑ Back to Table of Contents](#table-of-contents)

---

## 3. Next Steps

You now have the foundational concepts you need to start building.

In this guide, you learned:

- What watsonx Orchestrate is and the problem it is designed to solve — the long tail of tasks too conversational, varied, or infrequent for traditional automation
- The three wxO form factors — SaaS, on-premises, and Developer Edition — and which one this event uses
- The low-code vs. pro-code authoring distinction and which path these labs use by default
- The nine core terms the coming labs assume you already know — what makes an agent different from a chatbot, how a knowledge base grounds an agent in your own content, why connections keep credentials out of prompts, how MCP toolkits register tools in bulk, why scoping tools to each agent matters, what an Agentic Workflow adds over plain agent reasoning, what the Catalog offers, how Controls differ from Guidelines, and how the Agentic Control Plane enforces security and compliance

When the event begins, you can choose which labs to complete based on your interests. The labs themselves are independent and can be completed in any order:

- **Lab 1.0–1.3**: Agent fundamentals and architecture — build progressively from your first agent, to connecting tools, to building a multi-agent supervisor/collaborator system
- **Lab 2**: Agentic workflows with HITL approval and multi-user collaboration — design a billing dispute workflow with role-based approval gates and specialist/supervisor handoff
- **Lab 3**: Agentic workflows with document processing — design a warranty claim workflow that classifies and extracts information from uploaded documents

[↑ Back to Table of Contents](#table-of-contents)

---

## Appendix: Abbreviations and Acronyms

(See [Setup & Event Credentials](Setup%20&%20Event%20Credentials.md) for setup-specific acronyms; this appendix includes general terms used throughout.)

| Abbreviation | Full term | Notes |
|---|---|---|
| **ADK** | Agent Development Kit | IBM's CLI and Python SDK for building, testing, and deploying agents, tools, and workflows to watsonx Orchestrate. |
| **API** | Application Programming Interface | A defined contract through which one software system calls another. |
| **AWS** | Amazon Web Services | Cloud provider hosting the wxO SaaS tenant used in this event. |
| **BAW** | IBM Business Automation Workflow | The workflow engine inside CP4BA used to host the Focus Corp System of Record (SOR) backend. |
| **BPM** | Business Process Management | Discipline and tooling for modeling, automating, and monitoring structured business processes. |
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
| **YAML** | YAML Ain't Markup Language | A human-readable data serialization format used for wxO agent and tool configuration files. |

[↑ Back to Table of Contents](#table-of-contents)
