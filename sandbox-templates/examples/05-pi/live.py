#!/usr/bin/env python3
"""Reads Pi's JSON event stream on stdin and prints each tool call as it
happens, then the final answer. Used by run-live.sh."""
import json
import sys

CYAN, DIM, BOLD, OFF = "\033[36m", "\033[2m", "\033[1m", "\033[0m"
answer = ""
for line in sys.stdin:
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get("type") == "tool_execution_start":
        name = e.get("toolName", "").replace("mcp__kagent__", "kagent → ")
        args = e.get("args") or {}
        shown = ", ".join(f"{k}={json.dumps(v)[:48]}" for k, v in args.items() if k != "sandbox_id")
        print(f"{CYAN}  {name}{OFF} {DIM}{shown[:110]}{OFF}", flush=True)
    elif e.get("type") == "message_end":
        m = e.get("message") or {}
        if m.get("role") == "assistant":
            text = "".join(c.get("text", "") for c in m.get("content") or [] if c.get("type") == "text")
            answer = text or answer
print(f"\n{BOLD}Answer{OFF}\n{answer.strip()}")
