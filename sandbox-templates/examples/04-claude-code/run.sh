#!/usr/bin/env bash
# Claude Code runs its agent loop on your machine. The code it writes runs in
# a Sandbox in the cluster, through kagent's MCP endpoint.
#
# Claude Code is given the sandbox tools and Read, and nothing else: no Bash,
# no Edit, no Write. It cannot run the analysis locally even if it wanted to.
set -euo pipefail
cd "$(dirname "$0")"

curl -fsS -o /dev/null -X POST http://localhost:8083/mcp \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' || {
  echo "Start the port-forward first: kubectl port-forward -n kagent svc/kagent-controller 8083:8083 &"; exit 1; }

SANDBOX_TOOLS="mcp__kagent__list_sandbox_templates,mcp__kagent__create_sandbox,mcp__kagent__get_sandbox,mcp__kagent__write_sandbox_file,mcp__kagent__start_sandbox_process,mcp__kagent__get_sandbox_process,mcp__kagent__read_sandbox_outputs,mcp__kagent__read_sandbox_file,mcp__kagent__delete_sandbox"

cd ../../demo   # so that churn.csv is a local file Claude Code can read
claude -p "$(cat ../examples/task.md)" \
  --mcp-config ../examples/04-claude-code/mcp.json --strict-mcp-config \
  --tools "Read" --allowedTools "Read,$SANDBOX_TOOLS" </dev/null

echo; echo "--- Sandboxes left behind (should be empty) ---"
kagent sandbox list
