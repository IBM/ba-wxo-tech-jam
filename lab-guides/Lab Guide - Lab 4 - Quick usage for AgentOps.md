
# Introduction

These hands-on lab exercises give you a quick tour of the AgentOps
features in IBM watsonx Orchestrate. AgentOps does for AI agents what
DevOps does for software. It gives you visibility, quality control, and
continuous improvement across the whole agent lifecycle, so you know
what your agents are doing, how well they do it, and how to make them
better.

In this lab, you will use the two main AgentOps areas of the platform:
Observability and Optimization.

Closing the loop

Together, Observability and Optimization form a continuous improvement
cycle:

<img src="./Lab 4 screenshots/image1.png"
style="width:6.76806in;height:0.80486in" />

## Observability: understand <u>what</u> your agents are doing

Start by opening the Observability menu. This is where you monitor and
troubleshoot agent behaviour in production:

- **Agent analytics:** View usage and performance metrics for each
  agent, including number of conversations, LLM calls, tool calls, token
  consumption, latency, and errors.

- **Chat history:** Look through past conversations to see how users
  interact with your agents.

- **Trace Inspector:** Follow the full execution path of any agent run,
  step by step. See which tools were called, with which inputs, in what
  order, and find the exact point where behaviour went off track.

- **Debugging:** Find the root cause of failures by looking at LLM
  calls, tool invocations, spans, and events, without having to piece
  together what happened.

## Optimization: evaluate and improve your agents with AI

Next, open the Optimization menu. This opens the AgentOps agent, an AI
assistant that handles the full evaluate → optimize → deploy cycle
through natural-language conversation. It does the work that would
usually take a dedicated AI engineer.

With the AgentOps agent, you can:

- **Explore your agent inventory:** List the agents in your workspace
  and view each one's details: description, tools, agent type, and
  instructions.

- **Create and review test cases:** Have the AgentOps agent generate
  test cases, or bring your own. Then review and adjust the starting
  prompt, expected outcome, and expected tool calls.

- **Run evaluations:** Test your agent against simulated user
  conversations before it reaches production. Tool calls and parameters
  are checked deterministically, so you know the agent calls the right
  tools, in the right order, with the right inputs.

- **Root cause analysis (RCA):** When an evaluation fails, the AgentOps
  agent explains why, not just the score.

- **Optimize instructions with GEPA:** Automatically generate improved
  agent instructions, re-test them against your test cases, compare
  candidates, and apply the best-performing version.

- **Optimize guidelines with ACE (Agentic Context Engineering):**
  Instead of rewriting instructions, ACE builds a curated playbook of
  rules and measures how much each rule actually improves evaluation
  results.

- **Look into observability data:** Ask for recent execution sessions or
  open a specific trace right from the chat.

- **Learn as you go:** Ask the agent to explain optimization concepts,
  evaluation metrics, and best practices.

Every optimization is verified before you promote it. An underperforming
agent can be diagnosed, improved, and validated in a single conversation
instead of over several sprints.

For more information, see IBM documentation and other useful links:

- [IBM watsonx Orchestrate AgentOps
  Documentation](https://www.ibm.com/docs/en/watsonx/watson-orchestrate/base?topic=operating-agentops-preview)

# Lab Setup Instructions

## Objective

In this hands-on lab, you will learn how to use AgentOps in watsonx
Orchestrate. You will:

- Observe your agents: review analytics, chat history, and execution
  traces to understand and debug their behavior.

- Optimize your agents: use the AgentOps agent to create test cases, run
  evaluations, find the root cause of failures, and apply verified
  improvements.

This lab consists of two exercises; see below:

- [Exercise 01 – Create your Agent](#exercise-1-create-your-agent).

- [**Exercise 02** – Observability](#exercise-2-observability).

- [**Exercise 03** – Optimization](#exercise-3-optimization).

## Access the environment

You received this email with instructions on how to access the
environment using your IBMid. Otherwise, access
[here](https://dl.watson-orchestrate.ibm.com/).

Next, the first exercise begins. Happy studying!

# Exercises

## Exercise 1: Create your Agent

The first step is creating a new simple agent before starting to perform
evaluations using AgentOps.

For this example, we will create a basic agent with two tools to check
the weather, receiving as input parameters the full address or city,
estate/province/region, country, start date, and end date using the
format YYYY-MM-DD.

Access your WatsonX Orchestrate tenant.

- Click on the left menu “*Active inventory*” and then on “*Agents*”

<img src="./Lab 4 screenshots/image2.png"
style="width:2.12295in;height:2.87349in" />

- Click the “*Create agent*” button

<img src="./Lab 4 screenshots/image3.png"
style="width:6.76806in;height:2.00347in" />

- Click the “*Create from scratch*” button

<img src="./Lab 4 screenshots/image4.png"
style="width:4.60656in;height:1.94358in" />

- In the “**Agent name**” field, use “*(NAMESPACE)\_weather_agent*”
  using your correct NAMESPACE, same as previous labs.

- In the “**Description**” field, use “*You are an agent that will fetch
  real-time weather data*”.

<img src="./Lab 4 screenshots/image5.png"
style="width:4.42623in;height:2.66092in" />

- In the “**Instructions**” field, copy and paste the prompt below:

“*ROLE*

*You are a weather delivery-confidence assistant for a carrier delivery
application. Handle only weather delivery-confidence forecast requests.
If the user asks for anything else, reply briefly that you only handle
weather delivery-confidence forecasts and ask for Start Date, End Date,
and City or Address if they want that service.*

*INPUTS*

*Accept either: (a) one shared Start Date, one shared End Date, and one
or more cities/addresses, or (b) multiple rows where each row contains
its own Start Date, End Date, and City or Address. Never reuse a
location or date from an earlier unrelated request.*

*DATE HANDLING*

*Require exact dates in YYYY-MM-DD. If the current date is unavailable,
ask the user for exact dates instead of guessing. Start Date must not be
later than End Date.*

*LOCATION NORMALIZATION*

*The location input may be a city, a city with region/country, or a full
street address. When a street address clearly includes the city or
municipality, strip street number, street name, unit, suite, floor,
building name, and postal code, and keep city or municipality plus
province/state and country when available. If the city cannot be
reliably identified, ask for city, province/state, and country.*

*VALIDATION*

*Before calling tools, ensure every requested item has valid Start Date,
End Date, and resolvable location. Ask only for missing or corrected
information, and do not invent missing inputs. If the requested forecast
range is unsupported, ask for a supported range.*

*MULTI-LOCATION PROCESSING*

*When the user requests multiple locations with one shared date range,
process every unique normalized location independently and do not stop
after the first one. When the user provides multiple rows, parse each
row independently and process every row. Do not ask for locations again
if they were already provided clearly.*

*TOOL ORDER*

*For each unique normalized location, call tools in this order only: (1)
Get coordinates and timezone for a city, then (2) Get daily delivery
weather forecast. Never call the forecast tool before obtaining an
unambiguous latitude, longitude, and timezone from the same selected
location result.*

*LOCATION TOOL*

*Call Get coordinates and timezone for a city with: name = normalized
location, count = 5, language = en, format = json. Prefer an exact
city-name match, then match supplied province/state and country, and use
latitude, longitude, and timezone from the same result only. If multiple
plausible matches remain, ask the user to clarify; if none match,
explain that the location could not be resolved.*

*FORECAST TOOL*

*Call Get daily delivery weather forecast exactly once per unique
parameter set using: start_date = exact user date, end_date = exact user
date, latitude/longitude/timezone from the selected location result,
daily = precipitation_sum,snowfall_sum,wind_speed_10m_max,
wind_speed_unit = kmh. Do not duplicate calls for the same dates and
coordinates, but ensure every requested location receives its own
required forecast call. Do not estimate or invent weather values.*

*CLASSIFICATION*

*Use only returned daily.time, daily.precipitation_sum,
daily.snowfall_sum, and daily.wind_speed_10m_max, aligned by index, and
confirm the returned units before applying thresholds. A day is adverse
only if precipitation_sum \>= 10 mm or snowfall_sum \>= 5 cm or
wind_speed_10m_max \>= 90 km/h; otherwise it is No adverse weather. If
multiple thresholds are met on one day, list all matching conditions.*

*CONFIDENCE*

*For each processed location or row, compute totalDays, adverseDays, and
safeDays, verify adverseDays + safeDays = totalDays, and set confidence
= Low only if adverseDays \> safeDays; otherwise set confidence = High.
Never return Low when adverseDays \<= safeDays. The first-line
confidence, daily classifications, and summary counts must all agree.*

*OUTPUT*

*If the user requested a single location, return that location's
confidence result. If the user requested multiple locations, return a
separate block for each location in the same order requested, each with
its own confidence, day-by-day explanation, and summary; after all
blocks, include a brief comparison line only if the user asked to
compare. Each block must list every forecast date once, in chronological
order, with blank lines between date paragraphs.*

*NUMERIC VALUES*

*If the user explicitly asks for actual daily precipitation, snowfall,
or wind values, include those numeric values directly from the forecast
tool alongside each day's classification. Do not include raw tool dumps
or unsupported variables.*

*ERRORS AND INCOMPLETE DATA*

*If a tool returns an error, briefly explain that the weather forecast
could not be retrieved. If the forecast returns fewer dates than
requested, or any required daily value is missing or null, explain that
the forecast is incomplete or unreliable and do not fabricate a High or
Low confidence rating. Do not treat missing values as zero.*

*FINAL FORMAT RULES*

*Do not include markdown tables, bullet points, tool names, coordinates,
timezone, JSON, internal reasoning, or recommendations. For a normal
assessed result, the first line of each block must be exactly High or
Low, followed by a blank line, then one paragraph per forecast date,
then a blank line and the summary paragraph. If the request is unrelated
to weather delivery-confidence forecasting, do not call any tools.*”

<img src="./Lab 4 screenshots/image6.png"
style="width:4.60656in;height:1.22797in" />

- On the top menu, click “*Tools*”

<img src="./Lab 4 screenshots/image7.png"
style="width:3.2377in;height:1.18105in" />

- Click the “*Add Tool*” button

<img src="./Lab 4 screenshots/image8.png"
style="width:5.46721in;height:1.22404in" />

- Click the “*Local instance*” button

<img src="./Lab 4 screenshots/image9.png"
style="width:4.92342in;height:4.10656in" />

- In the “**Search**” field, look for “*Get coordinates and timezone for
  a city*”

- Select both options: “*Get coordinates and timezone for a city*” and
  “*Get daily delivery weather forecast*”.

<img src="./Lab 4 screenshots/image10.png"
style="width:6.76806in;height:1.62431in" />

- Click the “*Add to agent*” button on the bottom right side.

<img src="./Lab 4 screenshots/image11.png"
style="width:3.02479in;height:0.58197in" />

- On the right side at the chat preview, type “*1 New Orchard Road,
  Armonk, NY 10504*” and press the “*return*” key to do the first test
  with your agent.

<img src="./Lab 4 screenshots/image12.png"
style="width:4.5323in;height:5.47541in" />

- The agent returned a message requesting more information. We need to
  provide start and end dates in the format “*YYYY-MM-DD*”. So, the
  agent has been working fine until now. That message was expected.

<img src="./Lab 4 screenshots/image13.png"
style="width:4.53194in;height:1.35549in" />

- For the second test, let's pass all the information the agent needs to
  work, so type “*1 New Orchard Road, Armonk, NY 10504, 2026-10-10 -
  2026-10-20*”.

<img src="./Lab 4 screenshots/image14.png"
style="width:4.61475in;height:3.00437in" />

- Ok, the agent is performing well. It's time to publish it.

- In the top menu, click the “*Deploy*” button.

<img src="./Lab 4 screenshots/image15.png"
style="width:4.02459in;height:0.35761in" />

- Click the “*Deploy to Live*” button.

<img src="./Lab 4 screenshots/image16.png"
style="width:4.07361in;height:0.46772in" />

- Click the “*Create new version*” button.

<img src="./Lab 4 screenshots/image17.png"
style="width:4.46721in;height:3.30618in" />

- In the “**Version name**” field, use the same name as your agent
  “*(NAMESPACE)\_weather_agent*”.

- In the “**Version number**” field, use “*1.0.1*”.

<img src="./Lab 4 screenshots/image18.png"
style="width:4.4663in;height:3.09836in" />

- In the bottom right corner, click the “*Create*” button.

<img src="./Lab 4 screenshots/image19.png"
style="width:3.10656in;height:0.58644in" />

- In the bottom right corner, click the “*Deploy*” button **twice
  (2x)**.

<img src="./Lab 4 screenshots/image20.png"
style="width:3.36885in;height:0.63596in" />

- Awaiting completion of the deployment.

<img src="./Lab 4 screenshots/image21.png"
style="width:3.7541in;height:0.37094in" />

- When you see the “**green live**” icon, congratulations, your Agent is
  deployed and ready for use at the next exercises.

<img src="./Lab 4 screenshots/image22.png"
style="width:5.12746in;height:1.38525in" />

**\* Remember to use your agent during the next exercises. \***

## Exercise 2: Observability

Access your WatsonX Orchestrate tenant.

- On the left-side menu, click on “*Observability*”.

<img src="./Lab 4 screenshots/image23.png"
style="width:5.62237in;height:3.90123in" />

- In the first filter option, it's possible to choose between all
  available environments to do the best analysis. For our lab, let's
  keep all selected.

<img src="./Lab 4 screenshots/image24.png"
style="width:2.95902in;height:3.15989in" />

- In the filters it’s possible to choose with agents you like to use, in
  our example let’s keep all agents too.

<img src="./Lab 4 screenshots/image25.png"
style="width:3.64754in;height:3.89515in" />

- On the right side, you can select the corresponding period for which
  you want to do this analysis. Let's keep the last 24 hours to see a
  small amount of data.

<img src="./Lab 4 screenshots/image26.png"
style="width:3.59722in;height:2.72222in" />

- The agent trend will be able to compare agent performance over time
  using the selected metrics, including conversations, unique users, and
  average conversation duration. These metrics help to identify trends
  such as growth, decline, or consistency in the agents.

- It's possible to select the top 5, 10, or 15 results and see the
  charts

<img src="./Lab 4 screenshots/image27.png"
style="width:5.07334in;height:3.61475in" />

- It's possible to run the comparison based on Conversation, Unique
  Users, and Average conversation duration.

<img src="./Lab 4 screenshots/image28.png"
style="width:3.67213in;height:1.79308in" />

- In the Agent Activity windows, you will see the thumbs-up and
  thumbs-down feedback submitted by users at the message-level and
  explore in detail the conversation history.

<img src="./Lab 4 screenshots/image29.png"
style="width:4.5267in;height:1.54668in" />

- On the menu, click on “*Conversation*”.

<img src="./Lab 4 screenshots/image30.png"
style="width:3.15984in;height:1.89344in" />

- On the left side, you will see all conversation history for the
  selected agent; choose any one to inspect and debug.

<img src="./Lab 4 screenshots/image31.png"
style="width:2.64754in;height:3.48975in" />

- On that screen, it is possible to follow the entire conversation, see
  the user interactions, and the agent responses

<img src="./Lab 4 screenshots/image32.png"
style="width:5.68852in;height:4.047in" />

- Find in the conversation list which message you will inspect, and
  click the debug button at the bottom of the conversation

<img src="./Lab 4 screenshots/image33.png"
style="width:2.99131in;height:2.4011in" />

- On the left side is the Agent flow with all the steps of this
  conversation.

<img src="./Lab 4 screenshots/image34.png"
style="width:4.54098in;height:4.90824in" />

- The right side is split into three groups: Execution timeline,
  Variable, and Node Properties

<img src="./Lab 4 screenshots/image35.png"
style="width:5.22131in;height:5.64359in" />

- Clicking at Agent Reasoning to see details. Scroll down to see the
  Node properties.

<img src="./Lab 4 screenshots/image36.png"
style="width:4.22066in;height:2.77869in" />

- At Node Properties, there are all details about the agent’s name,
  prompt, tools, LLM Model and validation steps.

<img src="./Lab 4 screenshots/image37.png"
style="width:6.5in;height:7.02569in" />

- On that screen, you can see all interactions your agent had during the
  conversation.

With this information, you will be able to do a lot of analysis on your
agents.

**\* This feature is still in tech preview. Some changes are expected
without announcements until the G.A. announcement. \***

## Exercise 3: Optimization

- Now, on the left menu, click “*Optimization*”.

<img src="./Lab 4 screenshots/image38.png"
style="width:6.36726in;height:3.85246in" />

- On the Optimization main screen, it's possible to see some
  functionality shortcuts and the agent description.

<img src="./Lab 4 screenshots/image39.png"
style="width:4.65556in;height:3.20492in" />

- Start by clicking *“Show available agents”* to see one of the AgentOps
  capabilities

<img src="./Lab 4 screenshots/image40.png"
style="width:5.01639in;height:5.74366in" />

- You can filter the agents by name or view the entire list.

- Now let's ask “*Show me all agents with test cases*”

<img src="./Lab 4 screenshots/image41.png"
style="width:5.35246in;height:3.4425in" />

- Let's type *“Use (NAMESPACE)\_weather_agent”*.

**\* Remember to use your agent created in the previous exercise. \***

<img src="./Lab 4 screenshots/image42.png"
style="width:4.73225in;height:0.96673in" />

- No test cases are currently defined for this agent. We need to create
  at least 4. Then, type *“Create a new test case, full-address
  forecast: 20 York Rd, London SE1 7ND, United Kingdom, from yesterday
  to tomorrow”*.

<img src="./Lab 4 screenshots/image43.png"
style="width:4.87705in;height:1.3281in" />

The AgentOps identified a potential issue in our test case, but this is
intentional.

- So, type: “*Keep it as is*” and then click the “*Save*” button

<img src="./Lab 4 screenshots/image44.png"
style="width:5.85331in;height:3.15438in" />

- Create at least 4 more test cases:

1.  “*Create a new test case, full-address forecast:* *1 New Orchard
    Road, Armonk, NY 10504, 2026-10-10, 2026-10-20*”

2.  “*Create a new test case, full-address forecast:* *8200 Warden Ave.,
    Markham, Ontario L6G 1C7, Canada – 2026-01-01 to 2026-10-01*”

3.  “*Create a new test case, full-address forecast:* *2026-10-10,
    2026-10-20 - No. 8, First Avenue, Persiaran Bandar Utama, 47800
    Petaling Jaya, Selangor Darul Ehsan, Malaysia*”

4.  “*Create a new test case, full-address forecast:* *Markham, Ontario,
    Canada, for the period from 2026-01-01 to 2026-01-10*”

<img src="./Lab 4 screenshots/image45.png"
style="width:2.8569in;height:3.68852in" />

- Now type *“run evaluations”* to start running all the test cases you
  have. This operation can take a while to complete.

<img src="./Lab 4 screenshots/image46.png"
style="width:4.80328in;height:2.90688in" />

- When done, you can check individual conversations that have failed.

- Using our test case as an example, it's possible to identify the error
  by clicking the “*Analyze*” button.

<img src="./Lab 4 screenshots/image47.png"
style="width:4.25385in;height:5.17327in" />

- Looking at the conversation history, we can identify part of this
  scenario error: the agent doesn't support the start date or the
  longest range: “*The requested dates are outside the range that can be
  forecast. Please provide a start and end date
  between 2026‑07‑13 and 2026‑10‑29.*”

Sometimes errors are due to incorrect test cases, and sometimes to
issues with the agent or tools. That’s way analyze all conversations
one-by-on it’s important to grant the best results.

**If you selected a different conversation, you would see a different
message history and a different problem. Don't worry about it.**

<img src="./Lab 4 screenshots/image48.png"
style="width:4.46379in;height:5.87883in" />

- To try to fix this, you will need to create a new test case with the
  correct date range or other necessary modifications related to the
  error.

- Type “*Modify test case*”

- Find and copy the “*Test case ID*” related to the test case you would
  like to modify. Paste the ID in the conversation.

<img src="./Lab 4 screenshots/image49.png"
style="width:4.8668in;height:6.40984in" />

- Now, type “*Change the date range: Markham, Ontario, Canada, for the
  period from 2026-10-01 to 2026-10-10*”.

<img src="./Lab 4 screenshots/image50.png"
style="width:4.65574in;height:1.98583in" />

- Click the “*Save*” button.

<img src="./Lab 4 screenshots/image51.png"
style="width:5.22131in;height:2.82131in" />

- Now, you can see on the list both use cases at the top of your list.
  Select them to perform the evaluation.

- Click the “*Evaluate*” button.

<img src="./Lab 4 screenshots/image52.png"
style="width:3.93053in;height:3.16594in" />

- Both tests will fail again, but why? Let's ask AgentOps why our tests
  are failing again.

- So, type “*analyse the overall results*” and see the detailed review
  of our Agent and test case created.

<img src="./Lab 4 screenshots/image53.png"
style="width:5.25903in;height:4.38525in" />

<img src="./Lab 4 screenshots/image54.png"
style="width:5.24361in;height:3.77049in" />

- In this scenario, I can assume that my agent needs an optimization or
  a rebuild something to make it clear. Time to run *“Optimize my
  agent”*

<img src="./Lab 4 screenshots/image55.png"
style="width:4.53944in;height:3.27049in" />

- In the optimization method, there are two options:

  - **Optimize instructions with GEPA:** Automatically generate improved
    agent instructions, re-test them against your test cases, compare
    candidates, and apply the best-performing version.

  - **Optimize guidelines with ACE (Agentic Context Engineering):**
    Instead of rewriting instructions, ACE builds a curated playbook of
    rules and measures how much each rule actually improves evaluation
    results.

- Choose “*GEPA*” to proceed.

<img src="./Lab 4 screenshots/image56.png"
style="width:3.02087in;height:1.07377in" />

- For the optimization metric, we will follow the recommendation and use
  "*Tool Call Recall*". This assesses whether the agent called the right
  tools in the right order, detecting any missed calls.

<img src="./Lab 4 screenshots/image57.png"
style="width:2.92623in;height:1.73355in" />

- Remember to adjust both properties to your needs in the future.

- Click the “*Start Optimization*” button.

<img src="./Lab 4 screenshots/image58.png"
style="width:3.37211in;height:1.59016in" />

- This process can take a while to complete.

<img src="./Lab 4 screenshots/image59.png"
style="width:4.78978in;height:6.14251in" />

<img src="./Lab 4 screenshots/image60.png"
style="width:5.19672in;height:5.21165in" />

- After running the evaluation with 5 different iterations, they assume
  the baseline has the best results, so nothing needs to be applied. If
  you are seen a different result, you can apply to use the best result
  or keep using the same.

- To try to get a best result, you can run again the optimization
  selecting different parameters.

Congratulations, you have completed this lab.

**\* This feature is still in tech preview. Some changes are expected
without announcements until the G.A. announcement. \***
