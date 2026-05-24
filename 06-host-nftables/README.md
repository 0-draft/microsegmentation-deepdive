# 06. Host firewall, agent-style (nftables in Docker)

**English** | [日本語](README.ja.md)

This is what an Illumio / Akamai Guardicore / Cisco Secure Workload agent ultimately does: render policies into the host's own packet filter. We don't need a fancy product to see the mechanic, just a Linux container with `nftables` and `CAP_NET_ADMIN`.

## What gets verified

Three containers (`web`, `db`, `attacker`) on a shared Docker bridge with static IPs. `db` is a Postgres pod. Baseline: both `web` and `attacker` can `nc 5432`.

An `nft` rule set is then loaded into `db`'s netns:

- accept established / related
- accept new connections from `web` (10.99.0.20)
- drop everything else inbound

After that, `web` keeps working, `attacker` times out. The "policy push" here is a simple `docker cp ... && docker exec db nft -f`, but conceptually it's exactly what a VEN-style agent does at scale.

## Why it's still worth knowing

Cloud-native segmentation gets all the airtime, but most enterprises still run a long tail of Linux VMs and bare metal where host-level nftables (or its older sibling iptables) is the only enforcement point available. This lab is the smallest reproduction of that loop.

## Run

```bash
./run.sh
```

About 30 seconds, no Kubernetes. Expected output: [`expected/output.txt`](./expected/output.txt).

## Cleanup

```bash
./cleanup.sh
```
