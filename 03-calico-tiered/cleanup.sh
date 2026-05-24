#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
CLUSTER=ms-03-calico-global
echo "==> Deleting kind cluster $CLUSTER"
kind delete cluster --name "$CLUSTER"
