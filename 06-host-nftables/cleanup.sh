#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
echo "==> Removing containers and network"
for c in ms06-db ms06-web ms06-attacker; do
  docker rm -f "$c" >/dev/null 2>&1 || true
done
docker network rm ms06-net >/dev/null 2>&1 || true
echo "done"
