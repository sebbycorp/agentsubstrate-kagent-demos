#!/usr/bin/env bash
# An agent that runs the code it writes. The model's code executes in a
# Sandbox, never in the agent's own Session and never on the cluster.
set -euo pipefail
cd "$(dirname "$0")/.."
kubectl apply -f manifests/agent-code-runner.yaml
kubectl wait agent/code-runner -n kagent --for=condition=Ready --timeout=10m

SESSION_ID=$(kagent agent session create --agent code-runner -o json | jq -r '.session.id')
echo "Session: $SESSION_ID"
kagent agent invoke --session "$SESSION_ID" --timeout 10m --task \
"What drove churn last quarter? Break churn rate down by plan and by support ticket volume (5+ tickets vs fewer). Here is the data as CSV:

$(cat demo/churn.csv)"

echo; echo "--- Sandboxes left behind (should be empty) ---"
kagent sandbox list
