# Sandbox templates

A local kagent 1.0 + Agent Substrate environment in a kind cluster. This page
is the full walkthrough: every command and config you need is here or in this
folder. Each step also has a script in `scripts/` that runs it for you.

A **Sandbox** is a throwaway, locked-down environment that a person, a script,
or an agent can create to run commands. A **SandboxTemplate** defines what is
inside it: a digest-pinned image, the WorkerPool that runs it, and the network
access that it gets, which is none unless you grant it.

Once the template exists (step 3), see [`examples/`](examples/) for real-world
scenarios: opening an untrusted file, checking agent-written code, reproducing
a bug across pinned versions, and connecting your own bot such as Grok.

## Prerequisites

- Docker Desktop (8 GB of memory is enough; the cluster idles at about 2.7 GB)
- kind v0.32.0+, kubectl, helm 3, jq
- kagent CLI v1.0.1: `curl -sL https://kagent.dev/install | bash -s -- --version v1.0.1`
- `export OPENAI_API_KEY=...`

Run every command below from this folder.

## 1. Create the cluster

Script: `scripts/01-cluster.sh`

Agent Substrate needs Kubernetes 1.37 or later.

```bash
kind create cluster --name kagent --image kindest/node:v1.37.0
```

## 2. Install kagent and Agent Substrate

Script: `scripts/02-install.sh`

```bash
kagent install --timeout 20m
kubectl rollout status deployment/kagent-controller -n kagent --timeout=300s
kubectl get workerpools -n kagent
```

This takes about 5 minutes. It installs Agent Substrate into `ate-system`, a
development PostgreSQL, and kagent into `kagent`. The WorkerPool should read:

```console
NAME             DESIRED   REPLICAS   READY   SANDBOXCONFIG    RESOLVED
kagent-default   1         1          1       gvisor-default   True
```

## 3. Turn on Sandboxes and create the template

Script: `scripts/03-sandbox-template.sh`

**Set the guest image.** kagent runs its own guest program in every Sandbox to
serve process and file operations. The chart ships no default image for it, so
a template never becomes ready until you set one. The values are in
[`manifests/sandbox-values.yaml`](manifests/sandbox-values.yaml):

```yaml
config:
  sandboxes:
    guestImage: ghcr.io/kagent-dev/kagent/sandbox-guest@sha256:354825706868fc4d39300fe7795f4fa04d1eb53c3c93fb5b65b5da76f8222db7
    cpu: "1"          # per Sandbox
    memory: 1Gi       # per Sandbox
    defaultTtl: 3600s # lifetime when the caller does not ask for one
    maxTtl: 86400s    # upper bound on any requested lifetime
```

Apply them to the existing release:

```bash
KAGENT_CHART_VERSION=$(helm list -n kagent -o json \
  | jq -er '.[] | select(.name == "kagent") | .chart | ltrimstr("kagent-")')
helm upgrade kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent \
  --namespace kagent --version "$KAGENT_CHART_VERSION" \
  --reuse-values -f manifests/sandbox-values.yaml --wait
```

**Pin the tools image.** The API server rejects an image referenced by tag
alone. Look up the digest of the image index, so each node pulls the variant
for its own architecture:

```bash
DIGEST=$(docker buildx imagetools inspect python:3.13-slim \
  --format '{{json .Manifest.Digest}}' | tr -d '"')
export PYTHON_IMAGE="docker.io/library/python:3.13-slim@${DIGEST}"
```

**Create the template.** The manifest is
[`manifests/sandboxtemplate-python.yaml`](manifests/sandboxtemplate-python.yaml),
with `${PYTHON_IMAGE}` as a placeholder:

```yaml
apiVersion: api.kagent.dev/v1alpha3
kind: SandboxTemplate
metadata:
  name: python
  namespace: kagent
spec:
  workload:
    image: ${PYTHON_IMAGE}
  env:
    - name: LANG
      value: C.UTF-8
  substrate:
    workerPoolRef:
      name: kagent-default
    snapshotPolicy:
      location: s3://ate-snapshots/kagent/
```

```bash
sed "s|\${PYTHON_IMAGE}|${PYTHON_IMAGE}|" manifests/sandboxtemplate-python.yaml | kubectl apply -f -
kubectl wait sandboxtemplate/python -n kagent --for=condition=Ready --timeout=10m
kagent sandbox templates
```

```console
NAMESPACE  NAME    IMAGE
kagent     python  docker.io/library/python:3.13-slim@sha256:7249d558...
```

If the wait times out, read the reason:

```bash
kubectl get sandboxtemplate python -n kagent \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status} {.reason} {.message}{end}'
```

`True Prepared` is healthy. `Preparing` means the snapshot is still building.
A retrying or failed reason usually means the guest image is unset or the
Workers cannot pull the tools image.

What to know about the tools image:

- kagent replaces the image's entrypoint, so its own `ENTRYPOINT` and `CMD` do not run.
- A durable volume is mounted at `/data`, which hides anything the image put there.
- Commands start in `/data/workspace`.

## 4. Use a Sandbox from the CLI

Script: `scripts/04-cli-demo.sh`

```bash
SANDBOX_ID=$(kagent sandbox create python --request-id "cli-$(uuidgen)" \
  --name churn-analysis --ttl 30m -o json | jq -er '.id | select(length > 0)')
kagent sandbox get $SANDBOX_ID

kagent sandbox exec $SANDBOX_ID -- python --version
kagent sandbox upload $SANDBOX_ID demo/churn.csv churn.csv
kagent sandbox upload $SANDBOX_ID demo/analyze_churn.py analyze_churn.py
kagent sandbox exec $SANDBOX_ID -- python analyze_churn.py
kagent sandbox download $SANDBOX_ID report.json ./report.json
```

```console
Process proc-40f9... in sandbox 01a21cf8-...: started (stdout offset 0, stderr offset 0)
Python 3.13.18
Process proc-40f9...: PROCESS_STATE_EXITED, exit_code=0
```

The `--request-id` makes the create safe to retry: the same ID returns the same
Sandbox. The `--` before the command is required, and the command runs without
a shell, so use `-- sh -c '...'` for pipes or variables.

Prove the network is closed:

```bash
kagent sandbox exec $SANDBOX_ID -- bash -c \
  'exec 3<>/dev/tcp/pypi.org/443 && echo reachable || echo blocked'
```

```console
blocked
bash: line 1: pypi.org: Name or service not known
```

Suspend, resume, and delete:

```bash
kagent sandbox suspend $SANDBOX_ID
kagent sandbox exec $SANDBOX_ID -- ls /data/workspace   # fails: not ready
kagent sandbox resume $SANDBOX_ID
kagent sandbox exec $SANDBOX_ID -- ls /data/workspace   # files are back
kagent sandbox delete $SANDBOX_ID
```

## 5. Grant network access with an EgressPolicy

Script: `scripts/05-egress-demo.sh`

[`manifests/egresspolicy-pypi.yaml`](manifests/egresspolicy-pypi.yaml) grants
exactly two origins:

```yaml
apiVersion: api.kagent.dev/v1alpha3
kind: EgressPolicy
metadata:
  name: pypi
  namespace: kagent
spec:
  destinations:
    - origin: https://pypi.org
    - origin: https://files.pythonhosted.org
```

```bash
kubectl apply -f manifests/egresspolicy-pypi.yaml
kubectl patch sandboxtemplate python -n kagent --type merge \
  -p '{"spec":{"egressPolicyRefs":[{"name":"pypi"}]}}'
```

Wait about 15 seconds, then in a Sandbox that was already running:

```console
pypi.org reachable
github.com blocked
```

`pip install pandas` now works in the Sandbox. The egress gateway logs each
allowed request with the identity of the Sandbox that sent it:

```bash
kubectl logs -n ate-system deploy/atenet-egress -c agentgateway --since=5m \
  | awk -F'\t' '$2=="info" && $3 ~ /^request /'
```

```console
http.method=GET http.host=pypi.org http.path=/simple/pandas/ http.status=200 ate.actor.name=session-01a21cf8-... ate.atespace=kagent
```

To remove the grant:

```bash
kubectl patch sandboxtemplate python -n kagent --type json \
  -p '[{"op":"remove","path":"/spec/egressPolicyRefs"}]'
```

## 6. An agent that runs the code it writes

Script: `scripts/06-agent-demo.sh`

[`manifests/agent-code-runner.yaml`](manifests/agent-code-runner.yaml) defines
an AgentTemplate and an Agent. The agent gets the sandbox tools from kagent's
own MCP server, `kagent-api`, and its prompt tells it to create one Sandbox per
request and to delete it before answering.

```bash
kubectl apply -f manifests/agent-code-runner.yaml
kubectl wait agent/code-runner -n kagent --for=condition=Ready --timeout=10m

SESSION_ID=$(kagent agent session create --agent code-runner -o json | jq -r '.session.id')
kagent agent invoke --session $SESSION_ID --timeout 10m --task \
"What drove churn last quarter? Break churn rate down by plan and by support ticket volume (5+ tickets vs fewer). Here is the data as CSV:

$(cat demo/churn.csv)"

kagent sandbox list   # empty: the agent cleaned up
```

For screenshots of each tool call, run `kagent dashboard`, open
http://localhost:8082, and open the `code-runner` agent's Session.

## 7. Put agentgateway in front of the model

Scripts: `scripts/07-agentgateway.sh`, then `scripts/08-agentgateway-demo.sh`

```bash
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.3/standard-install.yaml
helm upgrade -i --create-namespace -n agentgateway-system --version v1.7.0 \
  agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds \
  --set agentgatewayModels.enabled=true
helm upgrade -i -n agentgateway-system --version v1.7.0 \
  agentgateway oci://cr.agentgateway.dev/charts/agentgateway \
  --set agentgatewayModels.enabled=true --wait

kubectl create secret generic openai-key -n agentgateway-system \
  --from-file=Authorization=<(printf '%s' "$OPENAI_API_KEY")
kubectl apply -f manifests/agentgateway/gateway.yaml
kubectl apply -f manifests/agentgateway/model.yaml
kubectl apply -f manifests/agentgateway/modelconfig.yaml
kubectl patch agenttemplate code-runner -n kagent --type merge \
  -p '{"spec":{"modelConfig":{"name":"agentgateway-model-config"}}}'
```

| File | What it sets |
| --- | --- |
| [`gateway.yaml`](manifests/agentgateway/gateway.yaml) | A Gateway listener that accepts `AgentgatewayModel` routes |
| [`model.yaml`](manifests/agentgateway/model.yaml) | The `gpt-4o-mini` model, the provider key, and a prompt guard that masks emails, SSNs, and card numbers |
| [`modelconfig.yaml`](manifests/agentgateway/modelconfig.yaml) | A kagent ModelConfig that points at the gateway. The `/v1` suffix on the URL is required. |

`AgentgatewayModel` is experimental and off by default, which is why both Helm
commands set `agentgatewayModels.enabled=true`.

Test the guard:

```bash
kubectl port-forward -n agentgateway-system service/agentgateway-proxy 8080:80 &
curl -s http://localhost:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Repeat this sentence back to me exactly: contact alex@example.com about the renewal."}]}' \
  | jq -r '.choices[0].message.content'
```

```console
contact <EMAIL_ADDRESS> about the renewal.
```

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

## Things that are easy to get wrong

- **Suspend keeps files, not memory.** Files under `/data` survive suspend and
  resume. Running processes and anything outside `/data` do not.
- **A blocked destination does not resolve.** The client sees a DNS error, not
  an HTTP 403, and the request never appears in the gateway log.
- **A grant reaches running Sandboxes.** Patching `egressPolicyRefs` on the
  template applies to existing Sandboxes within about 10 seconds.
- **A Sandbox expires on a fixed clock.** Activity and resume do not extend the TTL.
- **A merge patch replaces the whole `egressPolicyRefs` list.** Include every
  policy the template needs each time.

## Tear down

```bash
kind delete cluster --name kagent
```
