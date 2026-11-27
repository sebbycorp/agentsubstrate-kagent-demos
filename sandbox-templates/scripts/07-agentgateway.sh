#!/usr/bin/env bash
# Puts agentgateway in front of the model: the provider key moves to the
# gateway, and a prompt guard masks PII before it leaves the cluster.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${OPENAI_API_KEY:?export OPENAI_API_KEY first}"
GWAPI_VERSION=1.6.3
AGW_VERSION=v1.7.0

kubectl apply --server-side -f \
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${GWAPI_VERSION}/standard-install.yaml"
helm upgrade -i --create-namespace -n agentgateway-system --version "$AGW_VERSION" \
  agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds \
  --set agentgatewayModels.enabled=true
helm upgrade -i -n agentgateway-system --version "$AGW_VERSION" \
  agentgateway oci://cr.agentgateway.dev/charts/agentgateway \
  --set agentgatewayModels.enabled=true --wait

kubectl create secret generic openai-key -n agentgateway-system \
  --from-file=Authorization=<(printf '%s' "$OPENAI_API_KEY") \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f manifests/agentgateway/gateway.yaml
kubectl apply -f manifests/agentgateway/model.yaml
kubectl wait gateway/agentgateway-proxy -n agentgateway-system --for=condition=Programmed --timeout=3m
kubectl get agentgatewaymodel gpt-4o-mini -n agentgateway-system \
  -o jsonpath='{range .status.parents[0].conditions[?(@.type=="Accepted")]}{.status} {.reason} {.message}{"\n"}{end}'

kubectl apply -f manifests/agentgateway/modelconfig.yaml
# Point the code-runner agent at the gateway instead of at OpenAI directly.
kubectl patch agenttemplate code-runner -n kagent --type merge \
  -p '{"spec":{"modelConfig":{"name":"agentgateway-model-config"}}}'
kubectl wait agent/code-runner -n kagent --for=condition=Ready --timeout=10m
