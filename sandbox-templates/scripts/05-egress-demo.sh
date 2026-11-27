#!/usr/bin/env bash
# Default-deny egress, then a grant for exactly PyPI. The grant reaches the
# running Sandbox without recreating it.
set -euo pipefail
cd "$(dirname "$0")/.."
run() { printf '\n\033[1;36m$ %s\033[0m\n' "$*"; "$@"; }
probe() { kagent sandbox exec "$SANDBOX_ID" -- bash -c \
  "exec 3<>/dev/tcp/$1/443 && echo $1 reachable || echo $1 blocked" 2>&1 | grep -E 'reachable|blocked' | head -1; }

SANDBOX_ID=$(kagent sandbox create python --request-id "egress-$(uuidgen)" \
  --ttl 30m -o json | jq -er '.id | select(length > 0)')
echo "Sandbox: $SANDBOX_ID"

echo; echo "--- Before the grant ---"
probe pypi.org; probe github.com

run kubectl apply -f manifests/egresspolicy-pypi.yaml
run kubectl patch sandboxtemplate python -n kagent --type merge \
  -p '{"spec":{"egressPolicyRefs":[{"name":"pypi"}]}}'
sleep 15   # the egress gateway caches each policy for 10 seconds
kubectl get sandboxtemplate python -n kagent \
  -o jsonpath='{range .status.conditions[?(@.type=="EgressPoliciesApplied")]}{.status} {.reason} {.message}{"\n"}{end}'

echo; echo "--- After the grant (same Sandbox) ---"
probe pypi.org; probe github.com

run kagent sandbox exec "$SANDBOX_ID" -- pip install --quiet --root-user-action=ignore pandas || true
run kagent sandbox exec "$SANDBOX_ID" -- python -c 'import pandas; print("pandas", pandas.__version__)' || true

echo; echo "--- What the egress gateway saw ---"
# The egress gateway is agentgateway. It logs every request with the identity
# of the Actor that sent it. A blocked name never resolves, so it never gets here.
kubectl logs -n ate-system deploy/atenet-egress -c agentgateway --since=5m 2>/dev/null \
  | awk -F'\t' '$2=="info" && $3 ~ /^request /' | grep "$SANDBOX_ID" \
  | grep -oE '(http\.(method|host|path|status)|ate\.(actor\.name|atespace))=[^ ]+' \
  | paste -d' ' - - - - - - | cut -c1-200 | head -6 || true

run kagent sandbox delete "$SANDBOX_ID"
