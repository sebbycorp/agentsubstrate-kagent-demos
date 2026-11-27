#!/usr/bin/env bash
# Open a file you do not trust. It runs, you see what it tried, and nothing
# it tried reaches your cluster, your cloud account, or the internet.
source "$(dirname "$0")/../lib.sh"; cd "$(dirname "$0")"

ID=$(new_sandbox python untrusted-file)
say "Sandbox $ID: uploading suspicious.py and running it"
kagent sandbox upload "$ID" ./suspicious.py suspicious.py >/dev/null
sbx "$ID" python suspicious.py
kagent sandbox delete "$ID" >/dev/null
say "Sandbox deleted. Nothing it wrote survives."
