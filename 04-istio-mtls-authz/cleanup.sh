#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
CLUSTER=ms-04-istio
echo "==> Deleting kind cluster $CLUSTER"
kind delete cluster --name "$CLUSTER"
