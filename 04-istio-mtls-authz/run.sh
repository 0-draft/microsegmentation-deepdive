#!/usr/bin/env bash
# Pattern 04: Istio STRICT mTLS + principal-based AuthorizationPolicy.

set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ms-04-istio

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
ng()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; exit 1; }

say "1/7 kind cluster"
if kind get clusters | grep -qx "$CLUSTER"; then
  echo "  reusing existing cluster"
else
  kind create cluster --config kind-config.yaml
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

say "2/7 Istio install (default profile, minimal)"
if ! kubectl get ns istio-system >/dev/null 2>&1; then
  istioctl install --set profile=minimal -y
fi
kubectl -n istio-system rollout status deployment/istiod --timeout=300s

say "3/7 Workloads + sidecar injection"
echo "  waiting for istiod webhook endpoints..."
for _ in $(seq 1 30); do
  if kubectl -n istio-system get endpoints istiod -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q .; then
    break
  fi
  sleep 2
done
sleep 5
# retry apply: occasionally the first call races the webhook
for i in 1 2 3; do
  if kubectl apply -f manifests/workloads.yaml; then break; fi
  echo "  retry $i..."; sleep 10
done
kubectl -n shop    wait --for=condition=Ready pod -l app=httpbin --timeout=180s
kubectl -n shop    wait --for=condition=Ready pod -l app=cart --timeout=180s
kubectl -n shop    wait --for=condition=Ready pod -l app=attacker --timeout=180s
kubectl -n outside wait --for=condition=Ready pod -l app=outsider --timeout=180s

say "4/7 Baseline: everyone can reach httpbin (no policy yet)"
for src in shop/cart shop/attacker outside/outsider; do
  ns="${src%%/*}"; name="${src##*/}"
  CODE=$(kubectl -n "$ns" exec "$name" -c curl -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://httpbin.shop.svc.cluster.local:8000/get" || true)
  echo "  $src -> httpbin = $CODE"
done

say "5/7 STRICT mTLS"
kubectl apply -f manifests/peer-auth-strict.yaml
sleep 5
CODE=$(kubectl -n outside exec outsider -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://httpbin.shop.svc.cluster.local:8000/get" 2>/dev/null || true)
[ "$CODE" = "000" ] || [ "$CODE" = "503" ] || [ "$CODE" = "56" ] && ok "outsider (no sidecar) -> httpbin  blocked at TLS ($CODE)" || ng "expected TLS-level failure, got '$CODE'"
CODE=$(kubectl -n shop exec cart -c curl -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://httpbin.shop.svc.cluster.local:8000/get" || true)
[ "$CODE" = "200" ] && ok "cart (sidecar)        -> httpbin  $CODE" || ng "expected 200, got '$CODE'"

say "6/7 Principal-based AuthorizationPolicy: only cart SA"
kubectl apply -f manifests/authz-httpbin-cart-only.yaml
sleep 5
CODE=$(kubectl -n shop exec cart -c curl -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://httpbin.shop.svc.cluster.local:8000/get" || true)
[ "$CODE" = "200" ] && ok "cart-sa     -> httpbin  $CODE  (principal allowed)" || ng "expected 200, got '$CODE'"
CODE=$(kubectl -n shop exec attacker -c curl -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://httpbin.shop.svc.cluster.local:8000/get" || true)
[ "$CODE" = "403" ] && ok "attacker-sa -> httpbin  $CODE  (RBAC: access denied)" || ng "expected 403, got '$CODE'"

say "7/7 Done"
echo "  Inspect mTLS:   istioctl proxy-config secret -n shop cart"
echo "  Tear down:      ./cleanup.sh"
