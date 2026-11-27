#!/usr/bin/env bash
# Pi runs its agent loop on your machine. The code it writes runs in a Sandbox
# in the cluster, through kagent's MCP endpoint (configured in .pi/mcp.json).
#
# Pi keeps its read tool and the kagent sandbox tools. Its bash, edit, and
# write tools are turned off, so it cannot run the analysis locally. Set
# PI_MODEL to choose a model, such as PI_MODEL=openai/gpt-4.1.
set -euo pipefail
cd "$(dirname "$0")"

curl -fsS -o /dev/null -X POST http://localhost:8083/mcp \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' || {
  echo "Start the port-forward first: kubectl port-forward -n kagent svc/kagent-controller 8083:8083 &"; exit 1; }

cp ../../demo/churn.csv ./churn.csv   # a local file for Pi to read
trap 'rm -f churn.csv' EXIT

# --approve trusts this folder's .pi/mcp.json for this one run.
# The exclude list removes local execution and the kagent tools that manage
# agents and Sessions, which this task does not need.
EXCLUDE='bash,edit,write,subagent,mcp__kagent__*session*,mcp__kagent__*agent*,mcp__kagent__*task*'
pi --approve -p --no-session --exclude-tools "$EXCLUDE" \
  ${PI_MODEL:+--model "$PI_MODEL"} "$(cat ../task.md)" </dev/null   # without this, pi -p waits on stdin

echo; echo "--- Sandboxes left behind (should be empty) ---"
kagent sandbox list
