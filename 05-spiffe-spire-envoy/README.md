# 05. SPIFFE / SPIRE: workload identity from scratch

> 🇯🇵 [日本語](./README.ja.md) ・ 🇺🇸 English

Pattern 04 used Istio's built-in CA, which is fine but hides the mechanics. This one runs SPIRE directly: server, agent, workload attestation, X.509-SVID issuance. The point is to see the SPIFFE ID being minted and handed to a pod.

## What gets verified

Two pods share the same Linux UID and the same container image, but run under different ServiceAccounts. The SPIRE Agent's Kubernetes attestor checks `sa.name + ns + pod label`, and hands out **different** SVIDs to each. From inside each pod, `spire-agent api fetch x509` shows the SPIFFE URI in the cert.

A third pod, running under a ServiceAccount with **no registration entry**, gets no SVID back. SPIRE refuses to attest it.

The script asserts:

1. `cart` pod gets SVID `spiffe://example.org/ns/shop/sa/cart-sa`
2. `payments` pod gets SVID `spiffe://example.org/ns/shop/sa/payments-sa`
3. `unknown` pod gets nothing (timeout / no entry)

That's the full identity provisioning path that everything Pattern 04, 02-L7-via-Envoy, ztunnel, Linkerd, etc., builds on top of.

## What's actually happening

```text
Pod                spire-agent (DS)         spire-server
 |                       |                       |
 | UDS socket bind-mount |                       |
 | (CSI driver)          |                       |
 |--fetchX509SVID()----->|                       |
 |                       |--attest pod----------->|
 |                       |    (k8s sa, pod-meta)  |
 |                       |<-- entries match ------|
 |                       |--mint SVID via CA ---->|
 |<--SVID + bundle-------|                       |
```

`k8sPSAT` (Pod Service Account Token) attestor: agent submits the pod's projected token, server validates it against the kube-apiserver and issues an SVID for the matched registration entry.

## Run

```bash
./run.sh
```

About 3 minutes. Expected output: [`expected/output.txt`](./expected/output.txt).

## Cleanup

```bash
./cleanup.sh
```
