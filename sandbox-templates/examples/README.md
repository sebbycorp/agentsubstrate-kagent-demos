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
| 4 | **Claude Code runs its code in your cluster.** The agent loop stays on your laptop. | `04-claude-code/run.sh` | Claude Code reads a local CSV, runs the analysis in a Sandbox through kagent's MCP endpoint, and deletes the Sandbox. |
| 5 | **Pi does the same.** Same task, same Sandbox, different harness. | `PI_MODEL=openai/gpt-4.1 05-pi/run.sh` | Pi answers the same question with the same numbers. |
| 6 | **Prove the wall is real.** Try to connect to the pod that hosts sandboxes. | `06-isolation-test/run.sh` | Two ordinary pods time out. A control pod with the router's label connects. |

Example 1 output:

```console
[blocked] phone home to example.com: URLError: <urlopen error [Errno -2] Name or service not known>
[blocked] read cloud metadata service: URLError: <urlopen error [Errno 113] No route to host>
[blocked] reach the Kubernetes API: gaierror: [Errno -2] Name or service not known
[blocked] read a service account token: FileNotFoundError: ... serviceaccount/token
[blocked] find credentials in env vars: LookupError: no credentials in the environment
```

Examples 4 and 5 give both harnesses the same task, in [`task.md`](task.md):
"what drove churn last quarter?" with the data in a local `churn.csv`. Output
from the Claude Code run:

```console
By plan
  starter                customers= 36 churned= 17 churn_rate= 47.2%
  team                   customers= 15 churned=  0 churn_rate=  0.0%
  enterprise             customers=  9 churned=  1 churn_rate= 11.1%

By support tickets
  5+ tickets             customers= 32 churned= 15 churn_rate= 46.9%
  <5 tickets             customers= 28 churned=  3 churn_rate= 10.7%

Sandbox used and deleted: 01a21d24-b7a4-742c-8894-91727d9a7bfe (final state RUNTIME_STATE_DELETED).
```

## Is the isolation real?

Four things separate a Sandbox from everything else, and none of them depend
on the agent behaving:

1. **A separate kernel.** gVisor by default, or a micro-VM for the `microvm` class.
2. **Its own files.** The image and a `/data` volume. No node disk, no service account token.
3. **One way in.** A NetworkPolicy admits only the Substrate router to the Worker pod.
4. **No way out unless granted.** The egress gateway denies by default.

Example 1 tests the second and fourth. Example 6 tests the third:

```console
== Pod in namespace default, no labels
port 443: blocked (timed out)
port 8443: blocked (timed out)
port 8080: blocked (timed out)

== Pod in namespace kagent, the same namespace as the worker
port 443: blocked (timed out)
port 8443: blocked (timed out)
port 8080: blocked (timed out)

== Control: pod in ate-system labeled app=atenet-router
port 443: CONNECTED
port 8443: CONNECTED
port 8080: CONNECTED
```

The control proves the ports are open, so the timeouts are the policy at work.
It also shows who you have to trust: anyone who can create pods in `ate-system`
can wear the router's label. Not every CNI enforces NetworkPolicy, so run this
on your own cluster. This result is from kind with its default `kindnet`.

## How does a person or an agent reach a Sandbox?

Every route goes to the same service on the kagent controller, port `8083`.
A Sandbox created through one route is visible from the others under the same
identity.

| Who | Route | How |
| --- | --- | --- |
| A person, a script, a CI job | `kagent sandbox` CLI | `create`, `exec`, `upload`, `download`, `suspend`, `resume`, `delete`. Examples 1 to 3 use this. |
| A kagent agent in the cluster | MCP tools from the built-in `kagent-api` server | Bind the sandbox tools in the AgentTemplate. See [`manifests/agent-code-runner.yaml`](../manifests/agent-code-runner.yaml). |
| A coding harness on your machine (Claude Code, Pi, Codex, Cursor) | MCP over HTTP at `/mcp` | Register the URL as an MCP server. Examples 4 and 5, and the section below. |
| Any other bot or app with a tool-calling model | MCP over HTTP at `/mcp` | The same endpoint. It is plain JSON-RPC over HTTP. |
| Your own application | gRPC `kagent.api.v1.SandboxService` | For files over 1 MiB, which the MCP tools cannot move. |

### Connect Claude Code or Pi

Both need the controller reachable first:

```bash
kubectl port-forward -n kagent svc/kagent-controller 8083:8083 &
```

**Claude Code.** For everyday use, register the server once:

```bash
claude mcp add --transport http kagent http://localhost:8083/mcp
```

Then ask in plain language: "Use the kagent sandbox tools to run this script in
a temporary sandbox from the python template in the kagent namespace, report
the output, and delete the sandbox."

[`04-claude-code/run.sh`](04-claude-code/run.sh) does it headless and locked
down instead. It loads only [`mcp.json`](04-claude-code/mcp.json), and it gives
Claude Code the `Read` tool and the nine sandbox tools, with no Bash, Edit, or
Write. Claude Code cannot run the analysis on your machine even if it tried.

**Pi.** Pi reads project MCP servers from `.pi/mcp.json`, which is checked in at
[`05-pi/.pi/mcp.json`](05-pi/.pi/mcp.json). To create one yourself:

```bash
pi mcp add kagent --url http://localhost:8083/mcp -l --exposure direct
```

[`05-pi/run.sh`](05-pi/run.sh) runs Pi headless with its bash, edit, and write
tools excluded. Four things that cost time to find:

- Pi ignores `.pi/mcp.json` until the folder is trusted. `--approve` trusts it for one run.
- `--exposure direct` declares the tools to the model like built-in tools. The
  default, `codemode`, only makes them callable from scripts.
- `pi -p` waits on stdin when it is not a terminal. Redirect it from `/dev/null`
  in a script, or the run hangs silently.
- Pi's default model is whatever your Pi settings say. Set `PI_MODEL` to pick one.

**What both runs taught us about the task prompt.** The first Pi run, on
`gpt-4.1`, failed: the model hand-encoded base64 for `write_sandbox_file`, got
it wrong, gave up, and left a Sandbox running. [`task.md`](task.md) now tells
the model to create files with a shell heredoc through `start_sandbox_process`,
and to delete the Sandbox even when a step fails. Both harnesses pass with that
wording. Claude Code had chosen the heredoc route on its own.

## Before you expose this beyond your laptop

- **Turn on authentication.** By default the controller runs in `insecure`
  mode, where a caller names its own identity. Anyone who can reach port `8083`
  can create Sandboxes. With auth on, clients send `Authorization: Bearer <token>`
  (`claude mcp add --header`, or `pi mcp add --bearer-token-env-var`).
- **Keep templates narrow.** One template per job, each with only the egress it
  needs. A bot that analyzes data does not need the template that can reach PyPI.
- **Keep lifetimes short.** A Sandbox that a bot forgets lives until its TTL.
- **Remember the 1 MiB limit** on file writes and output reads through MCP.
