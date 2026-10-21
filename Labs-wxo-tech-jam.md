# IBM watsonx Orchestrate Labs

## 1. Overview

On this page you can find all required information to start with the wxO Labs. 

To run the labs, you will first need access to our system of record (SOR). Once you have that, you will be ready to access wxO. You have access to **wxO tenant**:
**Tenant  - TechJamAPAC**: To build your own Agents as part of the other labs and perform End to end scenario.

You will then need to connect the ADK CLI to TechJamAPAC.

Next, you have to get a copy of this GitHub onto your local machine.

And before you can start one of the Labs, please complete the mandatory lab first: **Introduction to watsonx Orchestrate**. Without that, you will not be able to run the other labs.

Finally, you will be ready to pick your lab and start it. The table in section below lists all **watsonx Orchestrate labs** that we currently have. It is recommended that during the Jam, you prioritize the labs in which you are interested most. **You do not have to perform the labs in a specific order**.

In case you have **questions or issues related to a specific lab**, use the **Slack Channel** linked in the table below. For any **broad questions, comments and feedback** please go to the **[#wxo-tech-jam-main-lobby](https://ibm.enterprise.slack.com/archives/C0CACKBQUJJ)** Slack channel.

## 2. Clone this GitHub

While working on the labs, you will require some solution artifacts that can be found in this GitHub. To copy them onto your local machine, there are several options:

**Option 1:** Clone the github using git CLI.

If you have git CLI installed on your local machine, please run this command to clone it:

```
git clone https://github.com/IBM/ba-wxo-tech-jam.git
```

**Option 2:** Download as ZIP file.

If you don't have the git CLI installed, you can download the content of this GitHub as ZIP file:

1. Open **https://github.com/IBM/ba-wxo-tech-jam**.
   
2. Click the green button **Code**.
   
3. Select **Download ZIP**.
   
   ![Download ZIP](DownloadZIP.png)
   
4. Once the download completed, please extract the ZIP onto your local machine.


## 3. Grab your system of record credentials, retrieve wxo tenant's particulars and connect ADK CLI to TechJamAPAC.

To run the labs, 

a. you will first need access to our system of record (SOR). Therefore, you will first grab your user ID and password for that one.


b. Once you have that, you will be ready to access wxO. You have access to **wxO tenant**:
1) Tenant  - TechJamAPAC: To build your own Agents as part of the other labs and perform End to end scenario.


c. You will access the wxo tenant and retrieve Service Instance URL along with the API key. 

d. You will connect the ADK CLI to TechJamAPAC.

To perform all the steps mentioned above, follow the instructions mentioned in **[Setup and Event Credentials](lab-guides/Setup%20%26%20Event%20Credentials.md)** from **1.2 section - On Event Day — Retrieve Credentials & Configure**.
   
   Hint: In case you have trouble retrieving your SOR credentials, please contact us in the **[#wxo-tech-jam-main-lobby](https://ibm.enterprise.slack.com/archives/C0CACKBQUJJ)** Slack channel.
   
The **SOR base URL** you will need is:
   
   **https://cpd-ibm-cp4ba.swat-dev-roks-vpc-02-464887bc828751e1b00625ca9211fbca-0000.eu-de.containers.appdomain.cloud/bas**
   
   **Please take a note of this URL**, you will require it multiple times while performing the labs.


## 4. wxO Lab List

You are now ready to start with the Labs! But, before you can start one of the Labs, please complete the mandatory lab first: **[Introduction to watsonx Orchestrate](lab-guides/Introduction%20to%20watsonx%20Orchestrate.md)**. Without that, you will not be able to run the other labs. Once you completed the introduction lab, pick your Lab from the following list:

| Lab Title and Link to Lab Instructions                        | Environment   | Approximate Duration | Slack Channel |
| ------------------------------------------------------------- | :-----------: | :------------------: | ------------- |
| [Mandatory: Introduction to watsonx Orchestrate](lab-guides/Introduction%20to%20watsonx%20Orchestrate.md) | n/a (read-only) | ~0.5 hours | [#wxo-tech-jam-main-lobby](https://ibm.enterprise.slack.com/archives/C0CACKBQUJJ) |
| [Lab 0 — The Trinity Scenario: End-to-End Experience](lab-guides/Lab%20Guide%20-%20Lab%200%20-%20e2e.md) | TechJamAPAC | ~0.5-1 hours | [#wxo-tech-jam-e2e](https://ibm.enterprise.slack.com/archives/C0CAGFJUHAM) |
| [Lab 1.0 — Worker Agent: Building Your First Agent](lab-guides/Lab%20Guide%20-%20Lab%201.0%20-%20first-agent.md) | TechJamAPAC | ~1-1.5 hours | [#wxo-tech-jam-first-agent](https://ibm.enterprise.slack.com/archives/C0C9Z7JUW95) |
| [Lab 1.1 — Worker Agent: Building Tools and Choosing Tool Types](lab-guides/Lab%20Guide%20-%20Lab%201.1%20-%20agents-tools.md) | TechJamAPAC | ~2–3 hours | [#wxo-tech-jam-agents-tools](https://ibm.enterprise.slack.com/archives/C0CACKLLLQN) |
| [Lab 1.2 — Worker Agent: RAG / Knowledge Base](lab-guides/Lab%20Guide%20-%20Lab%201.2%20-%20agents-knowledge-base.md) | TechJamAPAC | ~2.5–3 hours | [#wxo-tech-jam-agents-knowledge-base](https://ibm.enterprise.slack.com/archives/C0CAJ9G9Z9A) |
| [Lab 1.3 — Multi-Agent Systems: Supervisor + Collaborator Patterns](lab-guides/Lab%20Guide%20-%20Lab%201.3%20-%20multi-agent.md) | TechJamAPAC | ~2-3 hours | [#wxo-tech-jam-multi-agent](https://ibm.enterprise.slack.com/archives/C0CAED7F6BC) |
| [Lab 2 — Agentic Workflow: Billing Dispute](lab-guides/Lab%20Guide%20-%20Lab%202%20-%20workflow-billing.md) | TechJamAPAC | ~3-4 hours | [#wxo-tech-jam-workflow-billing](https://ibm.enterprise.slack.com/archives/C0CA9A80PNZ) |
| [Lab 3 — Agentic Workflow: External Warranty Claim](lab-guides/Lab%20Guide%20-%20Lab%203%20-%20workflow-warranty.md) | TechJamAPAC | ~ 4-5 hours | [#wxo-tech-jam-workflow-warranty](https://ibm.enterprise.slack.com/archives/C0CA8C2ATPD) |
| [Lab 4 — Quick Usage of Agent Ops](lab-guides/Lab%20Guide%20-%20Lab%204%20-%20Quick%20usage%20for%20AgentOps.md) | TechJamAPAC | ~ 1 hour | [#wxo-tech-jam-agent-ops](https://ibm.enterprise.slack.com/archives/C0CAJ992336) |

**Enjoy our October 2026 watsonx Orchestrate Tech Jam!**

Powered by the IBM Business Automation & watsonx Orchestrate Tiger Team (formerly SWAT), IBM Software Support
