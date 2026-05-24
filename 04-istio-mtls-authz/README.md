# 04. Istio mTLS + AuthorizationPolicy

**English** | [日本語](README.ja.md)

This is where the source of trust shifts. Patterns 01–03 still authenticate "by pod label", which the kubelet writes. Once Istio is in the picture, every service has its own X.509 cert (a SPIFFE ID minted by Istiod), and policy is written against `principals` rather than label selectors.

## What gets verified

Two pods, `cart` and `attacker`, both with sidecars and both running in PERMISSIVE-then-STRICT mode. A `PeerAuthentication` flips the whole namespace to STRICT mTLS. An `AuthorizationPolicy` on the `httpbin` server only allows the SPIFFE principal `cluster.local/ns/shop/sa/cart-sa`.

The script checks:

1. STRICT mode: a non-mesh `curl` (from a sidecar-less pod) is rejected at the TLS layer
2. `cart` (correct SA) can talk to `httpbin`: 200
3. `attacker` (different SA, has sidecar) gets a 403 from Envoy with the message `RBAC: access denied`

Same TCP packets in all three cases. The decision happens entirely inside the mesh.

## Why this isn't NetworkPolicy

NetworkPolicy trusts the network. If a malicious pod takes the same label, it gets through. mTLS-based authz trusts the certificate: the policy says "I want a request signed by the cart ServiceAccount's key", which only the cart pod has.

## Run

```bash
./run.sh
```

About 4 minutes (Istio install dominates). Expected output: [`expected/output.txt`](./expected/output.txt).

## Cleanup

```bash
./cleanup.sh
```
