# 02. Cilium L7 + Identity (with Hubble)

**English** | [日本語](README.ja.md)

This is the lab that shows what Pattern 01 can't do. Same workloads, but the policy now reads "from `web` to `cart`, only `GET` and `POST` are allowed", and the eBPF dataplane redirects matching connections through Envoy to enforce it.

## What gets verified

`web -> cart` `GET` returns 200. The same source doing `DELETE` gets `403` straight from Envoy (the request never reaches nginx in the cart pod). `attacker` doesn't even get a TCP connect, because the L4 portion of the same policy only allows `app=web` as a source. Hubble UI shows all three verdicts inline.

L3/L4 + L7 in one policy object, identity-aware, with observation built into the dataplane. That's the Cilium pitch.

## What's different from Pattern 01

Cilium does not write IP addresses into iptables. It assigns a stable numeric **Cilium Identity** to each unique label set, packs the identity into packet metadata, and lets the per-node eBPF program decide allow/deny by looking up the identity pair. When you ask for HTTP-level enforcement, Cilium transparently redirects the connection to an Envoy listener (one per node, embedded). That's why the rejection is a real `403` and not a TCP timeout.

## Run

```bash
./run.sh
```

Expected output: [`expected/output.txt`](./expected/output.txt).

## Cleanup

```bash
./cleanup.sh
```
