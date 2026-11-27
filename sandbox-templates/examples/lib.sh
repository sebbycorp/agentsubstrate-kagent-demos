# Shared helpers for the examples.
set -euo pipefail
say() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
new_sandbox() {  # new_sandbox <template> <name>
  kagent sandbox create "$1" --request-id "$2-$(uuidgen)" --name "$2" --ttl 15m \
    -o json | jq -er '.id | select(length > 0)'
}
# Runs a command in the Sandbox and prints only what the command printed.
sbx() { local id="$1"; shift; kagent sandbox exec "$id" -- "$@" 2>&1 | { grep -v -E '^Process proc-' || true; }; }
