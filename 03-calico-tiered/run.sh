#!/usr/bin/env bash
# Pattern 03: Calico GlobalNetworkPolicy with explicit order.

set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ms-03-calico-global
CALICO_VERSION=v3.32.0

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

say "2/6 Calico ($CALICO_VERSION)"
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml" 2>&1 | grep -v "already exists" || true
kubectl -n tigera-operator wait --for=condition=Available --timeout=180s deployment/tigera-operator
for _ in $(seq 1 60); do
  kubectl get crd installations.operator.tigera.io >/dev/null 2>&1 && break
  sleep 2
done
kubectl wait --for=condition=Established --timeout=60s crd/installations.operator.tigera.io
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml" 2>&1 | grep -v "already exists" || true
for _ in $(seq 1 60); do
  kubectl get ns calico-system >/dev/null 2>&1 && break
  sleep 5
done
kubectl rollout status daemonset/calico-node -n calico-system --timeout=300s
kubectl wait --for=condition=Available --timeout=180s deployment/calico-kube-controllers -n calico-system

say "3/6 Workloads"
kubectl apply -f manifests/workloads.yaml
kubectl -n prod    wait --for=condition=Ready pod --all --timeout=180s
kubectl -n staging wait --for=condition=Ready pod --all --timeout=180s
PROD_IP=$(kubectl -n prod get pod api -o jsonpath='{.status.podIP}')
echo "  prod/api IP = $PROD_IP"

say "4/6 Baseline: staging -> prod (no policy)"
if kubectl -n staging exec api -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://$PROD_IP/" | grep -q "200"; then
  ok "staging/api -> prod/api  200"
else
  ng "baseline expected 200"
fi

say "5/6 Apply Deny: staging cannot reach prod"
kubectl apply -f manifests/policy-deny-staging-to-prod.yaml
sleep 3
CODE=$(kubectl -n staging exec api -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://$PROD_IP/" 2>/dev/null || true)
[ "$CODE" = "000" ] && ok "staging/api    -> prod/api  blocked ($CODE)" || ng "expected blocked, got '$CODE'"
CODE=$(kubectl -n staging exec api-auditor -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://$PROD_IP/" 2>/dev/null || true)
[ "$CODE" = "000" ] && ok "staging/auditor -> prod/api  blocked ($CODE)" || ng "expected blocked, got '$CODE'"

say "6/6 Apply lower-order Allow for audit=true (exception)"
kubectl apply -f manifests/policy-allow-audit-exception.yaml
sleep 3
CODE=$(kubectl -n staging exec api-auditor -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://$PROD_IP/" 2>/dev/null || true)
[ "$CODE" = "200" ] && ok "staging/auditor -> prod/api  allowed via lower order ($CODE)" || ng "expected 200, got '$CODE'"
CODE=$(kubectl -n staging exec api -- curl -s -o /dev/null --max-time 5 -w "%{http_code}" "http://$PROD_IP/" 2>/dev/null || true)
[ "$CODE" = "000" ] && ok "staging/api    -> prod/api  still blocked ($CODE)" || ng "expected still blocked, got '$CODE'"

printf '\n\033[1;32mDone.\033[0m  Tear down with: ./cleanup.sh\n'
