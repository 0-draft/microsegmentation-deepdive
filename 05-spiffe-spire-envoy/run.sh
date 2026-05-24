#!/usr/bin/env bash
# Pattern 05: SPIFFE/SPIRE workload identity issuance.

set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ms-05-spire

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
ng()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; exit 1; }

say "1/6 kind cluster"
if kind get clusters | grep -qx "$CLUSTER"; then
  echo "  reusing existing cluster"
else
  kind create cluster --config kind-config.yaml
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

say "2/6 SPIRE via Helm"
helm repo add spiffe https://spiffe.github.io/helm-charts-hardened/ 2>/dev/null || true
helm repo update spiffe >/dev/null

if ! helm -n spire-mgmt list 2>/dev/null | grep -q spire-crds; then
  helm install spire-crds spiffe/spire-crds --namespace spire-mgmt --create-namespace --wait
fi
if ! helm -n spire-mgmt list 2>/dev/null | grep -q '^spire '; then
  helm install spire spiffe/spire \
    --namespace spire-mgmt \
    --values spire-values.yaml \
    --wait --timeout=10m
fi
kubectl -n spire-mgmt rollout status ds/spire-agent --timeout=300s
kubectl -n spire-mgmt rollout status statefulset/spire-server --timeout=300s

# The Helm chart installs a fallback ClusterSPIFFEID that issues an identity
# to every pod outside the spire namespaces. Delete it so this lab's "unknown"
# pod genuinely fails to attest.
kubectl delete clusterspiffeid spire-mgmt-spire-default --ignore-not-found
sleep 3

say "3/6 Workloads + ClusterSPIFFEID registrations"
kubectl delete -f manifests/workloads.yaml --ignore-not-found=true >/dev/null 2>&1 || true
sleep 3
kubectl apply -f manifests/workloads.yaml
echo "  waiting for pods (cart/payments must reach Running; unknown will Restart loop without SVID)..."
kubectl -n shop wait --for=condition=Ready pod/cart --timeout=120s
kubectl -n shop wait --for=condition=Ready pod/payments --timeout=120s

# Let watch capture initial SVIDs and let entries propagate
sleep 20

say "4/6 cart pod SVID"
CART_LOG=$(kubectl -n shop logs cart --tail=1000 2>&1 || true)
echo "$CART_LOG" | grep -m1 -B0 -A0 "SPIFFE ID" || true
if echo "$CART_LOG" | grep -q "spiffe://example.org/ns/shop/sa/cart-sa"; then
  ok "cart      SVID = spiffe://example.org/ns/shop/sa/cart-sa"
else
  ng "cart did not log expected SVID:\n$CART_LOG"
fi

say "5/6 payments pod SVID (must differ)"
PAY_LOG=$(kubectl -n shop logs payments --tail=1000 2>&1 || true)
echo "$PAY_LOG" | grep -m1 "SPIFFE ID" || true
if echo "$PAY_LOG" | grep -q "spiffe://example.org/ns/shop/sa/payments-sa"; then
  ok "payments  SVID = spiffe://example.org/ns/shop/sa/payments-sa"
else
  ng "payments did not log expected SVID:\n$PAY_LOG"
fi

say "6/6 unknown pod (no matching ClusterSPIFFEID -> no SVID)"
UNK_LOG=$(kubectl -n shop logs unknown --tail=1000 2>&1 || true)
echo "$UNK_LOG" | tail -10
if echo "$UNK_LOG" | grep -q "spiffe://example.org/ns/shop/sa/unknown-sa"; then
  ng "unknown unexpectedly received an SVID"
else
  ok "unknown got no SVID (PermissionDenied / no identity issued)"
fi

printf '\n\033[1;32mDone.\033[0m  Tear down with: ./cleanup.sh\n'
