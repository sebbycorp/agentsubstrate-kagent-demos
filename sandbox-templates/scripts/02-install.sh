#!/usr/bin/env bash
# Installs the CRDs, Agent Substrate (ate-system), a dev PostgreSQL, and kagent.
# Reads the model provider key from OPENAI_API_KEY.
set -euo pipefail
: "${OPENAI_API_KEY:?export OPENAI_API_KEY first}"
kagent install --timeout 20m
kubectl rollout status deployment/kagent-controller -n kagent --timeout=300s
kubectl get pods -n kagent
kubectl get workerpools -n kagent
