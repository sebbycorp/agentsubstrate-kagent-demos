#!/usr/bin/env bash
# Turns on Sandboxes (guest image) and creates the digest-pinned python template.
set -euo pipefail
cd "$(dirname "$0")/.."

KAGENT_CHART_VERSION=$(helm list -n kagent -o json \
  | jq -er '.[] | select(.name == "kagent") | .chart | ltrimstr("kagent-")')
helm upgrade kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent \
  --namespace kagent --version "$KAGENT_CHART_VERSION" \
  --reuse-values -f manifests/sandbox-values.yaml --wait

# Use the digest of the image index so each node pulls its own architecture.
DIGEST=$(docker buildx imagetools inspect python:3.13-slim --format '{{json .Manifest.Digest}}' | tr -d '"')
export PYTHON_IMAGE="docker.io/library/python:3.13-slim@${DIGEST}"
echo "Pinning $PYTHON_IMAGE"
sed "s|\${PYTHON_IMAGE}|${PYTHON_IMAGE}|" manifests/sandboxtemplate-python.yaml | kubectl apply -f -

kubectl wait sandboxtemplate/python -n kagent --for=condition=Ready --timeout=10m
kagent sandbox templates
