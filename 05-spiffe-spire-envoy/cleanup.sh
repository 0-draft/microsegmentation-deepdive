#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
CLUSTER=ms-05-spire
echo "==> Deleting kind cluster $CLUSTER"
kind delete cluster --name "$CLUSTER"
