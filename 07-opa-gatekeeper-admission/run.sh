#!/usr/bin/env bash
# Pattern 07: OPA Gatekeeper admission-time enforcement.

set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=ms-07-gatekeeper
GK_VERSION=3.18.2

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

say "2/6 Gatekeeper install ($GK_VERSION)"
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts 2>/dev/null || true
helm repo update gatekeeper >/dev/null
if ! helm -n gatekeeper-system list 2>/dev/null | grep -q gatekeeper; then
  helm install gatekeeper gatekeeper/gatekeeper \
    --version "$GK_VERSION" \
    --namespace gatekeeper-system \
    --create-namespace \
    --wait --timeout=5m
fi
kubectl -n gatekeeper-system rollout status deployment/gatekeeper-controller-manager --timeout=180s

say "3/6 ConstraintTemplates + sync"
kubectl apply -f manifests/template-required-labels.yaml
kubectl apply -f manifests/template-no-pod-without-netpol.yaml
kubectl apply -f manifests/sync-config.yaml
# Wait for the templates to register their CRDs
for kind in k8srequiredlabels k8snopodwithoutnetpol; do
  for _ in $(seq 1 30); do
    kubectl get crd "${kind}.constraints.gatekeeper.sh" >/dev/null 2>&1 && break
    sleep 2
  done
done

say "4/6 Constraints + target namespace"
kubectl create namespace prod 2>/dev/null || true
kubectl apply -f manifests/constraint-required-labels.yaml
kubectl apply -f manifests/constraint-no-pod-without-netpol.yaml
sleep 5

say "5/6 Try to create a Pod without labels (should be denied)"
set +e
OUT=$(kubectl -n prod apply -f - <<EOF 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: nolabel
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
EOF
)
RC=$?
set -e
echo "$OUT"
[ "$RC" -ne 0 ] && echo "$OUT" | grep -q "missing required labels" \
  && ok "Pod without labels rejected (K8sRequiredLabels)" \
  || ng "expected reject by K8sRequiredLabels, got rc=$RC"

say "6/6 Try to create a labelled Pod in a netpol-less namespace, then with a netpol"
set +e
OUT=$(kubectl -n prod apply -f - <<EOF 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: cart
  labels:
    app: cart
    env: prod
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
EOF
)
RC=$?
set -e
echo "$OUT"
[ "$RC" -ne 0 ] && echo "$OUT" | grep -q "no NetworkPolicy" \
  && ok "Pod rejected (namespace has no NetworkPolicy)" \
  || ng "expected reject for missing NetworkPolicy, got rc=$RC"

# Add a NetworkPolicy and retry
kubectl -n prod apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny }
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF
sleep 8  # wait for Gatekeeper sync to pick it up

kubectl -n prod apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cart
  labels: { app: cart, env: prod }
spec:
  containers:
    - name: c
      image: nginx:1.27-alpine
EOF
kubectl -n prod wait --for=condition=Ready pod/cart --timeout=120s && ok "Pod admitted after NetworkPolicy added"

printf '\n\033[1;32mDone.\033[0m  Tear down with: ./cleanup.sh\n'
