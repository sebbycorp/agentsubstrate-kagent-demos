#!/usr/bin/env bash
# "Works on my machine." Run the same repro steps on two digest-pinned
# runtimes and get an exact answer about which one breaks.
source "$(dirname "$0")/../lib.sh"; cd "$(dirname "$0")"

if ! kubectl get sandboxtemplate python311 -n kagent >/dev/null 2>&1; then
  say "Creating the python311 template"
  DIGEST=$(docker buildx imagetools inspect python:3.11-slim --format '{{json .Manifest.Digest}}' | tr -d '"')
  sed "s|\${PYTHON_IMAGE}|docker.io/library/python:3.11-slim@${DIGEST}|" sandboxtemplate-python311.yaml | kubectl apply -f -
fi
kubectl wait sandboxtemplate/python311 -n kagent --for=condition=Ready --timeout=10m >/dev/null
kagent sandbox templates

for TEMPLATE in python311 python; do
  ID=$(new_sandbox "$TEMPLATE" bug-repro)
  say "Template '$TEMPLATE' (sandbox $ID)"
  kagent sandbox upload "$ID" ./repro.py repro.py >/dev/null
  sbx "$ID" python repro.py | grep -v '^Error: sandbox process' || true
  kagent sandbox delete "$ID" >/dev/null
done
