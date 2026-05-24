#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
CLUSTER=ms-07-gatekeeper
echo "==> Deleting kind cluster $CLUSTER"
kind delete cluster --name "$CLUSTER"
