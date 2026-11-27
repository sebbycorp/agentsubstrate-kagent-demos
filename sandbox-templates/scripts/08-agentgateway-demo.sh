#!/usr/bin/env bash
# Shows the two gateways working together: agentgateway guards the prompt on
# the way to the model, and the agent's code still runs in a closed Sandbox.
set -euo pipefail
cd "$(dirname "$0")/.."

kubectl port-forward -n agentgateway-system service/agentgateway-proxy 8080:80 >/dev/null 2>&1 &
PF=$!; trap 'kill $PF 2>/dev/null' EXIT; sleep 3

echo "--- Direct to the gateway: the email is masked before OpenAI sees it ---"
curl -s http://localhost:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Repeat this sentence back to me exactly: contact alex@example.com about the renewal."}]}' \
  | jq -r '.choices[0].message.content // .'

echo; echo "--- Through the agent: model call via agentgateway, code in a Sandbox ---"
SESSION_ID=$(kagent agent session create --agent code-runner -o json | jq -r '.session.id')
kagent agent invoke --session "$SESSION_ID" --timeout 10m \
  --task "Compute the count and the sum of the numbers [2, 3, 5] in Python, and print them as JSON."

echo; echo "--- What agentgateway logged for those model calls ---"
kubectl logs -n agentgateway-system deploy/agentgateway-proxy --since=5m \
  | grep -E 'gen_ai|chat/completions' | tail -3 | cut -c1-500
