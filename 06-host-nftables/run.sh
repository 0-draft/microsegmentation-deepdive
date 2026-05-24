#!/usr/bin/env bash
# Pattern 06: host firewall microsegmentation using nftables in Docker.

set -euo pipefail
cd "$(dirname "$0")"

NET=ms06-net
SUBNET=10.99.0.0/16
DB_IP=10.99.0.10
WEB_IP=10.99.0.20
ATK_IP=10.99.0.30

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
ng()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; exit 1; }

cleanup_existing() {
  for c in ms06-db ms06-web ms06-attacker; do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  docker network rm "$NET" >/dev/null 2>&1 || true
}

say "1/5 Docker network and containers"
cleanup_existing
docker network create --subnet "$SUBNET" "$NET" >/dev/null

# db: Postgres + nftables. Needs NET_ADMIN to manipulate its own netns.
docker run -d --name ms06-db --network "$NET" --ip "$DB_IP" \
  --cap-add NET_ADMIN \
  -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_PASSWORD=postgres \
  postgres:16-alpine >/dev/null

# web and attacker: just need nc (alpine ships with busybox nc)
docker run -d --name ms06-web      --network "$NET" --ip "$WEB_IP" alpine:3.20 sleep infinity >/dev/null
docker run -d --name ms06-attacker --network "$NET" --ip "$ATK_IP" alpine:3.20 sleep infinity >/dev/null

echo "  waiting for postgres to accept connections..."
for _ in $(seq 1 30); do
  if docker exec ms06-web nc -z -w 1 "$DB_IP" 5432 >/dev/null 2>&1; then break; fi
  sleep 1
done

say "2/5 Baseline: both web and attacker reach db:5432"
if docker exec ms06-web nc -zv -w 3 "$DB_IP" 5432 2>&1 | grep -q open; then
  ok "web      -> db:5432  reachable"
else
  ng "web baseline failed"
fi
if docker exec ms06-attacker nc -zv -w 3 "$DB_IP" 5432 2>&1 | grep -q open; then
  ok "attacker -> db:5432  reachable (flat)"
else
  ng "attacker baseline failed"
fi

say "3/5 Install nftables into db container"
docker exec ms06-db apk add --no-cache nftables iproute2 >/dev/null
docker cp policy.nft ms06-db:/etc/policy.nft

say "4/5 Push policy: docker exec db nft -f /etc/policy.nft"
docker exec ms06-db nft -f /etc/policy.nft
echo "  current ruleset:"
docker exec ms06-db nft list ruleset | sed 's/^/    /'

say "5/5 Enforcement check"
if docker exec ms06-web nc -zv -w 3 "$DB_IP" 5432 2>&1 | grep -q open; then
  ok "web      -> db:5432  still reachable"
else
  ng "web unexpectedly blocked after policy"
fi
if ! docker exec ms06-attacker nc -zv -w 3 "$DB_IP" 5432 2>&1 | grep -q open; then
  ok "attacker -> db:5432  blocked (host nftables)"
else
  ng "attacker unexpectedly reachable after policy"
fi

printf '\n\033[1;32mDone.\033[0m  Tear down with: ./cleanup.sh\n'
