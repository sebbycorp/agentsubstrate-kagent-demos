#!/usr/bin/env python3
"""Bring your own agent: any model that speaks the OpenAI chat API (Grok,
OpenAI, a local model) gets a Sandbox to run code in.

The agent loop runs here, on your machine. The code the model writes runs in
a Sandbox in the cluster, reached through kagent's MCP endpoint. Standard
library only.

  kubectl port-forward -n kagent svc/kagent-controller 8083:8083 &
  ./bot.py "How many prime numbers are there below 10,000?"

Pick the model with environment variables:
  Grok:    XAI_API_KEY=...  LLM_MODEL=<a Grok model name>
  OpenAI:  OPENAI_API_KEY=...            (LLM_MODEL defaults to gpt-4o)
  Other:   LLM_BASE_URL=... LLM_API_KEY=... LLM_MODEL=...
"""
import base64
import json
import os
import ssl
import sys
import urllib.request
import uuid

MCP_URL = os.environ.get("KAGENT_MCP_URL", "http://localhost:8083/mcp")
MCP_TOKEN = os.environ.get("KAGENT_TOKEN")  # only if the controller requires auth

if os.environ.get("LLM_BASE_URL"):
    BASE, KEY = os.environ["LLM_BASE_URL"], os.environ.get("LLM_API_KEY", "")
elif os.environ.get("XAI_API_KEY"):
    BASE, KEY = "https://api.x.ai/v1", os.environ["XAI_API_KEY"]
elif os.environ.get("OPENAI_API_KEY"):
    BASE, KEY = "https://api.openai.com/v1", os.environ["OPENAI_API_KEY"]
    os.environ.setdefault("LLM_MODEL", "gpt-4o")
else:
    sys.exit("Set XAI_API_KEY, OPENAI_API_KEY, or LLM_BASE_URL + LLM_API_KEY.")
MODEL = os.environ.get("LLM_MODEL") or sys.exit("Set LLM_MODEL to the model name.")

# The only tools the model gets. It cannot touch agents or Sessions.
ALLOWED = ["list_sandbox_templates", "create_sandbox", "write_sandbox_file",
           "start_sandbox_process", "get_sandbox_process",
           "read_sandbox_outputs", "read_sandbox_file", "delete_sandbox"]

SYSTEM = """You answer questions by writing Python and running it in a kagent Sandbox.
Never guess a number: compute it.
1. Create exactly one Sandbox, in a turn of its own: create_sandbox with namespace "kagent", template "python", a new request_id,
   and ttl_seconds 600.
2. write_sandbox_file to save your code as main.py (pass the source as `text`).
3. start_sandbox_process with command ["python3", "main.py"], then poll
   get_sandbox_process until the state is PROCESS_STATE_EXITED.
4. read_sandbox_outputs to read what it printed.
5. delete_sandbox, then answer briefly.
The Sandbox has only the Python standard library and no network access."""


# python.org builds on macOS ship without CA certificates. Fall back to the
# system bundle rather than turning verification off.
TLS = ssl.create_default_context()
if not TLS.cert_store_stats()["x509_ca"] and os.path.exists("/etc/ssl/cert.pem"):
    TLS.load_verify_locations("/etc/ssl/cert.pem")


def post(url, body, headers):
    req = urllib.request.Request(url, json.dumps(body).encode(),
                                 {"Content-Type": "application/json", **headers})
    with urllib.request.urlopen(req, timeout=120, context=TLS) as r:
        return r.read().decode()


_id = 0


def mcp(method, params=None):
    """One JSON-RPC call to kagent's MCP endpoint. The reply is an event stream."""
    global _id
    _id += 1
    headers = {"Accept": "application/json, text/event-stream"}
    if MCP_TOKEN:
        headers["Authorization"] = f"Bearer {MCP_TOKEN}"
    raw = post(MCP_URL, {"jsonrpc": "2.0", "id": _id, "method": method,
                         "params": params or {}}, headers)
    for line in raw.splitlines():
        if line.startswith("data: "):
            msg = json.loads(line[6:])
            if "error" in msg:
                raise RuntimeError(msg["error"]["message"])
            return msg["result"]
    raise RuntimeError("no MCP result")


def call_tool(name, args):
    """Calls a sandbox tool. Models are bad at base64, so this adapter lets the
    model send and receive plain text and does the encoding on its behalf."""
    if name == "write_sandbox_file" and "text" in args:
        args["data_base64"] = base64.b64encode(args.pop("text").encode()).decode()
    result = mcp("tools/call", {"name": name, "arguments": args})
    text = "\n".join(c["text"] for c in result.get("content", []) if c.get("type") == "text")
    data = result.get("structuredContent") or {}
    if result.get("isError"):
        return {"error": text}
    for key in list(data):  # stdout_base64 -> stdout
        if key.endswith("_base64") and isinstance(data[key], str):
            data[key[:-7]] = base64.b64decode(data.pop(key)).decode(errors="replace")
    return data or {"text": text}


def tool_schemas():
    schemas = []
    for t in mcp("tools/list")["tools"]:
        if t["name"] not in ALLOWED:
            continue
        params = t["inputSchema"]
        if t["name"] == "write_sandbox_file":
            props = params["properties"]
            props.pop("data_base64", None)
            props["text"] = {"type": "string", "description": "The file content, as plain text."}
            params["required"] = ["sandbox_id", "path", "text"]
        schemas.append({"type": "function", "function": {
            "name": t["name"], "description": t.get("description", "")[:1000],
            "parameters": params}})
    return schemas


def main():
    question = " ".join(sys.argv[1:]) or "How many prime numbers are there below 10,000?"
    mcp("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                       "clientInfo": {"name": "byo-agent", "version": "0"}})
    tools = tool_schemas()
    print(f"model: {MODEL} at {BASE}\nsandbox tools: {len(tools)} via {MCP_URL}\n\n> {question}\n")

    messages = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": question}]
    open_sandboxes = set()
    try:
        for _ in range(30):
            reply = json.loads(post(f"{BASE}/chat/completions",
                                    {"model": MODEL, "messages": messages, "tools": tools},
                                    {"Authorization": f"Bearer {KEY}"}))["choices"][0]["message"]
            messages.append(reply)
            if not reply.get("tool_calls"):
                print(f"\n{reply['content']}")
                return
            for tc in reply["tool_calls"]:
                name, args = tc["function"]["name"], json.loads(tc["function"]["arguments"] or "{}")
                if name == "create_sandbox":
                    args.setdefault("request_id", f"byo-{uuid.uuid4()}")
                shown = {k: (v if len(str(v)) < 70 else str(v)[:67] + "...") for k, v in args.items()}
                print(f"  tool  {name}({json.dumps(shown)[1:-1]})")
                result = call_tool(name, args) if name in ALLOWED else {"error": "tool not allowed"}
                if name == "create_sandbox" and result.get("id"):
                    open_sandboxes.add(result["id"])
                if name == "delete_sandbox" and "error" not in result:
                    open_sandboxes.discard(args.get("sandbox_id"))
                if name == "read_sandbox_outputs" and result.get("stdout"):
                    print("  out   " + result["stdout"].strip().replace("\n", "\n        "))
                messages.append({"role": "tool", "tool_call_id": tc["id"],
                                 "content": json.dumps(result)[:20000]})
        print("Stopped after 30 steps.")
    finally:
        for sid in open_sandboxes:  # never leave a Sandbox behind
            call_tool("delete_sandbox", {"sandbox_id": sid})
            print(f"  cleanup: deleted sandbox {sid}")


if __name__ == "__main__":
    main()
