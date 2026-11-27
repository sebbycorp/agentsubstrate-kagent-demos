#!/usr/bin/env bash
# Run the tests for code that an agent wrote, before a human reviews it and
# away from your real CI runners and their secrets. The exit code of the tests
# becomes the exit code of this script, so it drops into a pipeline as a gate.
source "$(dirname "$0")/../lib.sh"; cd "$(dirname "$0")"

ID=$(new_sandbox python ai-pr-check)
trap 'kagent sandbox delete "$ID" >/dev/null' EXIT

say "Sandbox $ID: uploading the change"
COPYFILE_DISABLE=1 tar --no-xattrs -czf /tmp/project.$$.tgz -C project .
kagent sandbox upload "$ID" /tmp/project.$$.tgz project.tgz >/dev/null; rm -f /tmp/project.$$.tgz
sbx "$ID" tar --no-same-owner -xzf project.tgz

say "Running the tests"
set +e
kagent sandbox exec "$ID" -- python -m unittest -v 2>&1 | grep -v -E '^Process proc-|^Error: sandbox process'
RC=${PIPESTATUS[0]}
set -e
say "Tests exit code: $RC  ->  $([ "$RC" = 0 ] && echo 'safe to send to a reviewer' || echo 'send back to the agent')"
exit "$RC"
