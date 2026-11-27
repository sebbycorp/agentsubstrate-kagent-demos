#!/usr/bin/env bash
# The same run as run.sh, but prints each tool call as Pi makes it.
set -euo pipefail
cd "$(dirname "$0")"
cp ../../demo/churn.csv ./churn.csv
trap 'rm -f churn.csv' EXIT
EXCLUDE='bash,edit,write,subagent,mcp__kagent__*session*,mcp__kagent__*agent*,mcp__kagent__*task*'
echo "Pi: what drove churn last quarter? (data in churn.csv, local execution tools off)"
pi --approve -p --no-session --mode json --exclude-tools "$EXCLUDE" \
  ${PI_MODEL:+--model "$PI_MODEL"} "$(cat ../task.md)" </dev/null | python3 live.py
