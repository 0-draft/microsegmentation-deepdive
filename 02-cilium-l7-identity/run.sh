#!/usr/bin/env bash
# Pattern 02: Cilium L7 + identity-based segmentation, with Hubble enabled.

set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ms-02-cilium
CILIUM_VERSION=1.19.4

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
ng()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; exit 1; }

say "1/7 kind cluster ($CLUSTER)"
if kind get clusters | grep -qx "$CLUSTER"; then
  echo "  reusing existing cluster"
else
  kind create cluster --config kind-config.yaml
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

say "2/7 Cilium $CILIUM_VERSION"
if ! kubectl -n kube-system get ds cilium >/dev/null 2>&1; then
  cilium install --version "$CILIUM_VERSION" \
    --set kubeProxyReplacement=true \
    --set hubble.enabled=true \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true
fi
cilium status --wait --wait-duration 3m

say "3/7 Workloads"
kubectl apply -f manifests/workloads.yaml
kubectl -n shop wait --for=condition=Ready pod --all --timeout=180s
DB_IP=$(kubectl -n shop get pod db -o jsonpath='{.status.podIP}')
CART_IP=$(kubectl -n shop get pod cart -o jsonpath='{.status.podIP}')
echo "  db=$DB_IP  cart=$CART_IP"

say "4/7 L4 policy: db only reachable from cart"
kubectl apply -f manifests/policy-db-l4.yaml
sleep 3
if ! kubectl -n shop exec attacker -- nc -zv -w 3 "$DB_IP" 5432 2>&1 | grep -q "succeeded\|open"; then
  ok "attacker -> db:5432  blocked"
else
  ng "attacker -> db:5432  expected blocked"
fi
if kubectl -n shop exec cart -- nc -zvw 3 "$DB_IP" 5432 2>&1 | grep -q "open\|succeeded"; then
  ok "cart    -> db:5432  reachable"
else
  ng "cart    -> db:5432  expected reachable"
fi

say "5/7 L7 policy: web->cart GET/POST only"
kubectl apply -f manifests/policy-cart-l7.yaml
sleep 5

GET=$(kubectl -n shop exec web -- curl -s -o /dev/null -w "%{http_code}" "http://$CART_IP/")
[ "$GET" = "200" ] && ok "web   GET    /  -> $GET" || ng "web GET expected 200, got $GET"

DEL=$(kubectl -n shop exec web -- curl -s -o /dev/null -w "%{http_code}" -X DELETE "http://$CART_IP/")
[ "$DEL" = "403" ] && ok "web   DELETE /  -> $DEL  (Envoy-level reject)" || ng "web DELETE expected 403, got $DEL"

ATK=$(kubectl -n shop exec attacker -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://$CART_IP/" 2>/dev/null || true)
[ "$ATK" = "000" ] && ok "atk   GET    /  -> $ATK  (L4 drop, no HTTP at all)" || ng "attacker GET expected 000 (timeout), got '$ATK'"

say "6/7 Hubble flows for the last 30s"
hubble_pf_pid=""
if cilium hubble port-forward >/tmp/cilium-hubble-pf.log 2>&1 & then
  hubble_pf_pid=$!
  sleep 2
  hubble observe --namespace shop --last 20 --type policy-verdict 2>&1 | tail -10 || true
  kill "$hubble_pf_pid" 2>/dev/null || true
fi

say "7/7 Done"
echo "  Hubble UI:    cilium hubble ui   (http://localhost:12000)"
echo "  Tear down:    ./cleanup.sh"
