#!/usr/bin/env bash
# The whole lifecycle from a terminal: create, upload, run, download,
# prove the network is closed, suspend, resume, delete.
set -euo pipefail
cd "$(dirname "$0")/../demo"
run() { printf '\n\033[1;36m$ %s\033[0m\n' "$*"; "$@"; }

REQUEST_ID="cli-$(uuidgen)"
SANDBOX_ID=$(kagent sandbox create python --request-id "$REQUEST_ID" \
  --name churn-analysis --ttl 30m -o json | jq -er '.id | select(length > 0)')
echo "Sandbox: $SANDBOX_ID"
run kagent sandbox get "$SANDBOX_ID"

run kagent sandbox exec "$SANDBOX_ID" -- python --version
run kagent sandbox upload "$SANDBOX_ID" ./churn.csv churn.csv
run kagent sandbox upload "$SANDBOX_ID" ./analyze_churn.py analyze_churn.py
run kagent sandbox exec "$SANDBOX_ID" -- python analyze_churn.py
run kagent sandbox download "$SANDBOX_ID" report.json ./report.json

echo; echo "--- No network unless you grant it ---"
run kagent sandbox exec "$SANDBOX_ID" -- bash -c \
  'exec 3<>/dev/tcp/pypi.org/443 && echo reachable || echo blocked' || true

echo; echo "--- Suspend releases compute, /data survives ---"
run kagent sandbox suspend "$SANDBOX_ID"
run kagent sandbox exec "$SANDBOX_ID" -- ls /data/workspace || true
run kagent sandbox resume "$SANDBOX_ID"
run kagent sandbox exec "$SANDBOX_ID" -- ls /data/workspace

run kagent sandbox delete "$SANDBOX_ID"
