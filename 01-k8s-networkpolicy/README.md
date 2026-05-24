# 01. K8s NetworkPolicy with Calico

> 🇯🇵 [日本語](./README.ja.md) ・ 🇺🇸 English

The starter-pack version of microsegmentation. Plain `networking.k8s.io/v1` NetworkPolicy, enforced by Calico CNI at L3/L4. Same YAML works on any CNI that implements NetworkPolicy (kindnet doesn't, which is why we install Calico).

## What gets verified

Before any policy: `attacker` can `nc -zv db 5432` and connect. Flat. That's the failure mode Maersk had with NotPetya.

After applying [`policy-default-deny.yaml`](./manifests/policy-default-deny.yaml) and [`policy-allow-cart-to-db.yaml`](./manifests/policy-allow-cart-to-db.yaml): `attacker` times out, `cart` still gets through.

The script asserts both outcomes and prints PASS/FAIL.

## What's actually doing the work

Calico's per-node agent **Felix** watches NetworkPolicy and Pod events from the API server, computes which IPs match which selectors, and renders the result as iptables rules (or eBPF programs, if you switch the dataplane). The PEP is the kernel netfilter chain in front of each pod's veth. The PDP is the K8s control plane plus Felix's translator.

NetworkPolicy is **additive allow-list**: once any rule selects a pod for `Ingress`, every other path into it becomes implicitly denied. The "default-deny" trick is to write a policy that selects everything (`podSelector: {}`) with no `ingress:` block.

## Run

```bash
./run.sh
```

About 2 minutes the first time (image pulls). The script reuses an existing cluster if you've run it before.

Expected output: [`expected/output.txt`](./expected/output.txt).

## Cleanup

```bash
./cleanup.sh
```

deletes the kind cluster.
