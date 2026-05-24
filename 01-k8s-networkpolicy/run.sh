#!/usr/bin/env bash
# Pattern 01: K8s NetworkPolicy enforced by Calico.

set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ms-01-netpol
CALICO_VERSION=v3.32.0

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
ng()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; exit 1; }

say "1/6 kind cluster ($CLUSTER)"
if kind get clusters | grep -qx "$CLUSTER"; then
  echo "  reusing existing cluster"
else
  kind create cluster --config kind-config.yaml
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

say "2/6 Calico ($CALICO_VERSION)"
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml" 2>&1 | grep -v "already exists" || true
echo "  waiting for tigera-operator deployment..."
kubectl -n tigera-operator wait --for=condition=Available --timeout=180s deployment/tigera-operator
echo "  waiting for installations CRD..."
for _ in $(seq 1 60); do
  if kubectl get crd installations.operator.tigera.io >/dev/null 2>&1; then break; fi
  sleep 2
done
kubectl wait --for=condition=Established --timeout=60s crd/installations.operator.tigera.io
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml" 2>&1 | grep -v "already exists" || true
echo "  waiting for calico-system namespace..."
for _ in $(seq 1 60); do
  kubectl get ns calico-system >/dev/null 2>&1 && break
  sleep 5
done
echo "  waiting for calico-node DaemonSet..."
kubectl rollout status daemonset/calico-node -n calico-system --timeout=300s
kubectl wait --for=condition=Available --timeout=180s deployment/calico-kube-controllers -n calico-system

say "3/6 Workloads"
kubectl apply -f manifests/workloads.yaml
kubectl -n shop wait --for=condition=Ready pod --all --timeout=180s
DB_IP=$(kubectl -n shop get pod db -o jsonpath='{.status.podIP}')
echo "  db pod IP = $DB_IP"

say "4/6 Flat baseline (no policy yet)"
if kubectl -n shop exec attacker -- nc -zv -w 3 "$DB_IP" 5432 2>&1 | grep -q "succeeded\|open"; then
  ok "attacker -> db:5432  reachable (flat)"
else
  ng "attacker -> db:5432  expected reachable"
fi

say "5/6 Applying default-deny + cart-only allow"
kubectl apply -f manifests/policy-default-deny.yaml
kubectl apply -f manifests/policy-allow-cart-to-db.yaml
sleep 3

say "6/6 Enforcement check"
if ! kubectl -n shop exec attacker -- nc -zv -w 3 "$DB_IP" 5432 2>&1 | grep -q "succeeded\|open"; then
  ok "attacker -> db:5432  blocked"
else
  ng "attacker -> db:5432  expected blocked"
fi
if kubectl -n shop exec cart -- nc -zv -w 3 "$DB_IP" 5432 2>&1 | grep -q "succeeded\|open"; then
  ok "cart    -> db:5432  reachable"
else
  ng "cart    -> db:5432  expected reachable"
fi

printf '\n\033[1;32mDone.\033[0m  Tear down with: ./cleanup.sh\n'
