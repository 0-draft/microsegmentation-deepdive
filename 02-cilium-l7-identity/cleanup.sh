#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
CLUSTER=ms-02-cilium
echo "==> Deleting kind cluster $CLUSTER"
kind delete cluster --name "$CLUSTER"
