# Real-world examples

Finish steps 1 to 3 of the [walkthrough](../README.md) first, so the cluster is
up and the `python` SandboxTemplate is `Ready`. Then each example is one command.

## Why would I do this?

An agent that can only talk is limited. An agent that can run code can check
its own work, analyze your data, and reproduce your bugs. The question is where
that code runs.

| Where the code runs | What goes wrong |
| --- | --- |
| On the agent's own host or pod | The code has the agent's credentials, network, and files. One bad prompt or one poisoned document and it can use all three. |
| On your laptop | Same problem, with your SSH keys and cloud logins. |
| On a CI runner | The runner holds deploy secrets, and the code was written by a model nobody has reviewed yet. |
| In a Sandbox | The code gets an empty box: its own files, no credentials, and no network unless you grant a destination. |

So the reason to let an agent do this is that you are not really trusting the
agent. You are trusting the box. The operator decides what is in the box by
writing a SandboxTemplate, and the agent can only pick a template that exists.

| The operator controls, in the template | The agent or person controls |
| --- | --- |
| Which image, pinned by digest | Which template to start from |
| Which destinations are reachable | What commands to run |
| CPU, memory, and maximum lifetime | When to suspend, resume, and delete |

## The examples

| # | Scenario | Run | What you see |
| --- | --- | --- | --- |
| 1 | **Open a file you do not trust.** A customer upload or a script from a ticket. | `01-untrusted-file/run.sh` | The script tries to phone home, read cloud metadata, reach the Kubernetes API, and find credentials. Every attempt is blocked. |
| 2 | **Check code that an agent wrote.** Run the tests before a human reviews the PR, away from your CI secrets. | `02-check-ai-written-code/run.sh` | One test fails on an off-by-one bug. The script exits with the tests' exit code, so it works as a pipeline gate. |
| 3 | **Reproduce a bug from a ticket.** "It crashes since we upgraded." | `03-reproduce-a-bug/run.sh` | The same repro runs on two digest-pinned templates. Python 3.11 passes, Python 3.13 raises `ModuleNotFoundError`. |
| 4 | **Bring your own agent.** Grok, OpenAI, or any model with an OpenAI-compatible API. | `04-bring-your-own-agent/bot.py "your question"` | The model writes Python, the bot runs it in a Sandbox through kagent's MCP endpoint, and deletes the Sandbox. |

Example 1 output:

```console
[blocked] phone home to example.com: URLError: <urlopen error [Errno -2] Name or service not known>
[blocked] read cloud metadata service: URLError: <urlopen error [Errno 113] No route to host>
[blocked] reach the Kubernetes API: gaierror: [Errno -2] Name or service not known
[blocked] read a service account token: FileNotFoundError: ... serviceaccount/token
[blocked] find credentials in env vars: LookupError: no credentials in the environment
```

Example 4 output:

```console
> What is the 50th Fibonacci number, and how many digits does 2**1000 have?

  tool  create_sandbox("namespace": "kagent", "template": "python", ...)
  tool  write_sandbox_file("sandbox_id": "01a21d0e-...", "path": "main.py", "text": "def fibonacci(n):...")
  tool  start_sandbox_process("sandbox_id": "01a21d0e-...", "command": ["python3", "main.py"])
  tool  get_sandbox_process(...)
  tool  read_sandbox_outputs(...)
  out   50th Fibonacci number: 12586269025
        Number of digits in 2**1000: 302
  tool  delete_sandbox("sandbox_id": "01a21d0e-...")

The 50th Fibonacci number is 12,586,269,025, and the number 2^1000 has 302 digits.
```

## How does a person or an agent reach a Sandbox?

Every route goes to the same service on the kagent controller, port `8083`.
A Sandbox created through one route is visible from the others under the same
identity.

| Who | Route | How |
| --- | --- | --- |
| A person, a script, a CI job | `kagent sandbox` CLI | `create`, `exec`, `upload`, `download`, `suspend`, `resume`, `delete`. Examples 1 to 3 use this. |
| A kagent agent in the cluster | MCP tools from the built-in `kagent-api` server | Bind the sandbox tools in the AgentTemplate. See [`manifests/agent-code-runner.yaml`](../manifests/agent-code-runner.yaml). |
| An outside agent or bot (Grok, a Slack bot, your own app) | MCP over HTTP at `/mcp` | Any tool-calling model works. Example 4 is a complete client in about 150 lines with no dependencies. |
| A coding assistant (Claude Code, Cursor, Codex) | MCP over HTTP at `/mcp` | Register the URL as an MCP server. See below. |
| Your own application | gRPC `kagent.api.v1.SandboxService` | For files over 1 MiB, which the MCP tools cannot move. |

### Connect a bot such as Grok

Expose the controller, then point the bot at it:

```bash
kubectl port-forward -n kagent svc/kagent-controller 8083:8083 &

export XAI_API_KEY=...          # or OPENAI_API_KEY
export LLM_MODEL=<model name>   # required for Grok; defaults to gpt-4o for OpenAI
./04-bring-your-own-agent/bot.py "How many prime numbers are there below 10,000?"
```

The bot was tested with OpenAI `gpt-4o`. Grok uses the same chat API, at
`https://api.x.ai/v1`, but that path has not been run here.

What [`bot.py`](04-bring-your-own-agent/bot.py) does, which is what any
integration has to do:

1. Calls `tools/list` on `/mcp` and keeps only the eight sandbox tools. The model
   never sees the tools that manage agents and Sessions.
2. Hands those tool schemas to the model and runs the tool-calling loop.
3. Translates plain text to base64 for file writes and back for process output,
   because models make mistakes when they encode base64 themselves.
4. Deletes any Sandbox the model created and forgot, so nothing is left running.

### Connect a coding assistant

```bash
claude mcp add --transport http kagent http://localhost:8083/mcp   # Claude Code
codex mcp add kagent --url http://localhost:8083/mcp               # Codex
```

Then ask in plain language: "Use the kagent sandbox tools to run this script in
a temporary sandbox from the python template in the kagent namespace, report
the output, and delete the sandbox."

## Before you expose this beyond your laptop

- **Turn on authentication.** By default the controller runs in `insecure`
  mode, where a caller names its own identity. Anyone who can reach port `8083`
  can create Sandboxes. With auth on, clients send `Authorization: Bearer <token>`
  (`bot.py` reads it from `KAGENT_TOKEN`).
- **Keep templates narrow.** One template per job, each with only the egress it
  needs. A bot that analyzes data does not need the template that can reach PyPI.
- **Keep lifetimes short.** A Sandbox that a bot forgets lives until its TTL.
- **Remember the 1 MiB limit** on file writes and output reads through MCP.
