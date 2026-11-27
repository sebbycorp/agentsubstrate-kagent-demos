# Sandbox templates

A local kagent 1.0 + Agent Substrate environment in a kind cluster, with
runnable demos of standalone Sandboxes, egress policies, and agentgateway.

Based on the kagent docs: [Set up a sandbox template](https://kagent.dev/docs/kagent/latest/get-started/sandbox-template/),
[Run commands with the CLI](https://kagent.dev/docs/kagent/latest/sandboxes/cli/),
[Egress policies](https://kagent.dev/docs/kagent/latest/agents/egress-policies/), and
[agentgateway model routing](https://kagent.dev/docs/kagent/latest/setup/model-providers/byo-agentgateway/).

## Prerequisites

- Docker Desktop (8 GB of memory is enough; the cluster idles at about 2.7 GB)
- kind v0.32.0+, kubectl, helm 3, jq
- kagent CLI v1.0.1: `curl -sL https://kagent.dev/install | bash -s -- --version v1.0.1`
- `export OPENAI_API_KEY=...`

## Run it

| Step | Script | What it does |
| --- | --- | --- |
| 1 | `scripts/01-cluster.sh` | kind cluster `kagent` on Kubernetes 1.37 |
| 2 | `scripts/02-install.sh` | `kagent install`: CRDs, Agent Substrate (`ate-system`), dev PostgreSQL, kagent. About 5 minutes. |
| 3 | `scripts/03-sandbox-template.sh` | Sets the sandbox guest image, creates the digest-pinned `python` SandboxTemplate, waits for `Ready` |
| 4 | `scripts/04-cli-demo.sh` | Create a Sandbox, upload `demo/churn.csv`, run the analysis, download the report, show the network is closed, suspend, resume, delete |
| 5 | `scripts/05-egress-demo.sh` | Blocked by default, then an EgressPolicy grants PyPI only. `pip install pandas` works, `github.com` stays blocked. Prints the egress gateway's per-Actor log. |
| 6 | `scripts/06-agent-demo.sh` | The `code-runner` agent answers "what drove churn?" by writing Python and running it in its own Sandbox |
| 7 | `scripts/07-agentgateway.sh` | Installs agentgateway v1.7.0, moves the OpenAI key to the gateway, adds a PII prompt guard, repoints the agent |
| 8 | `scripts/08-agentgateway-demo.sh` | Shows the guard masking an email, then the agent running through the gateway |
| — | `scripts/99-teardown.sh` | Deletes the kind cluster |

For screenshots of the agent's tool calls, run `kagent dashboard` and open
http://localhost:8082, then open the `code-runner` agent's Session.

## Request path

```
person / CLI / agent
      │  kagent API (gRPC, MCP)
      ▼
Sandbox (gVisor, on a Worker)          one Actor per Sandbox, files in /data
      │  all outbound traffic
      ▼
atenet-egress (agentgateway)           default deny, per-Actor SPIFFE identity,
      │                                EgressPolicy grants, credential injection
      ├──► granted origins (for example pypi.org)
      ▼
agentgateway-proxy (agentgateway)      provider key, prompt guards, token usage
      ▼
model provider
```

## Things the demos show that are easy to get wrong

- **Suspend keeps files, not memory.** Files under `/data` survive suspend and
  resume. Running processes and anything outside `/data` do not.
- **A blocked destination does not resolve.** The client sees a DNS error, not
  an HTTP 403, and the request never appears in the gateway log.
- **A grant reaches running Sandboxes.** Patching `egressPolicyRefs` on the
  template applies to existing Sandboxes within about 10 seconds.
- **A Sandbox expires on a fixed clock.** Activity and resume do not extend the TTL.
- **Images must be digest-pinned.** The API server rejects a tag-only reference.
