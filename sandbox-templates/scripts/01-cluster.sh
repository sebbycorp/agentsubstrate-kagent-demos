#!/usr/bin/env bash
# Local kind cluster. Agent Substrate needs Kubernetes 1.37+ (PodCertificateRequest
# and ClusterTrustBundle are GA there) and kind v0.32.0+.
set -euo pipefail
kind get clusters | grep -qx kagent || kind create cluster --name kagent --image kindest/node:v1.37.0
kubectl config use-context kind-kagent
kubectl wait --for=condition=Ready node --all --timeout=180s
