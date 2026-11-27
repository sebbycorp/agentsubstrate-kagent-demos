#!/usr/bin/env bash
# Is the wall around a sandbox real? Agent Substrate creates a NetworkPolicy
# that lets only its router reach the Worker pod that hosts sandboxes. A policy
# only counts if the network plugin enforces it, so this tries to break in.
#
# Two ordinary pods should be blocked. A control pod that carries the router's
# label should connect, which proves the ports are open and that the policy is
# what blocks the others.
set -euo pipefail

POOL=kagent-default
IP=$(kubectl get pod -n kagent -l "ate.dev/worker-pool=$POOL" -o jsonpath='{.items[0].status.podIP}')
echo "Worker pod IP: $IP"
kubectl get networkpolicy -n kagent "substrate-$POOL" \
  -o jsonpath='{"Policy allows ingress from: "}{.spec.ingress[0].from[0]}{"\n"}'

PROBE='for p in 443 8443 8080; do if nc -z -w 3 '"$IP"' $p 2>/dev/null; then echo "port $p: CONNECTED"; else echo "port $p: blocked (timed out)"; fi; done'
probe() {  # probe <pod name> <namespace> [extra kubectl run flags]
  local name="$1" ns="$2"; shift 2
  kubectl run "$name" -n "$ns" --image=busybox:1.36 --restart=Never --rm -i --quiet "$@" \
    --command -- sh -c "$PROBE" 2>&1 | grep '^port'
}

printf '\n== Pod in namespace default, no labels\n'
probe np-test-outsider default
printf '\n== Pod in namespace kagent, the same namespace as the worker\n'
probe np-test-neighbor kagent
printf '\n== Control: pod in ate-system labeled app=atenet-router\n'
probe np-test-control ate-system --labels=app=atenet-router
