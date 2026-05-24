#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"

CLUSTER=ms-01-netpol
echo "==> Deleting kind cluster $CLUSTER"
kind delete cluster --name "$CLUSTER"
