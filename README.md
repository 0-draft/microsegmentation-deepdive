# microsegmentation-deepdive

> 🇯🇵 [日本語](./README.ja.md) ・ 🇺🇸 English

Microsegmentation talked about everywhere, almost never shown end-to-end. This repo runs eight different implementations on a laptop, so you can see what each pattern actually does to packets.

Sibling to the dev.to article [microsegmentation-deep-dive](https://github.com/0-draft/dev.to/blob/main/articles/microsegmentation-deep-dive.md).

## What's in here

| # | Pattern | Tool | What you actually run |
| --- | --- | --- | --- |
| [01](./01-k8s-networkpolicy/) | K8s NetworkPolicy | Calico CNI | kind cluster, `nc` from attacker pod gets blocked once you apply the policy |
| [02](./02-cilium-l7-identity/) | Cilium L7 + Hubble | Cilium eBPF + Envoy | `curl DELETE` returns 403 from Envoy, attacker times out at L4, Hubble UI shows the verdict |
| [03](./03-calico-tiered/) | Calico tiered global policy | Calico GlobalNetworkPolicy | order/tier evaluation across namespaces |
| [04](./04-istio-mtls-authz/) | Istio mTLS + AuthZ | Istio sidecar | STRICT mTLS plus principal-based deny |
| [05](./05-spiffe-spire-envoy/) | SPIFFE/SPIRE + Envoy | SPIRE Server/Agent + Envoy | Envoy fetches an X.509-SVID via SDS and uses it for mTLS |
| [06](./06-host-nftables/) | Host firewall, agent-style | nftables in a privileged Docker container | per-host rules pushed from a controller |
| [07](./07-opa-gatekeeper-admission/) | Admission-time control | OPA Gatekeeper | a Pod missing the required label is rejected at `kubectl apply` |
| [08](./08-localstack-aws-sg/) | AWS Security Group as code | LocalStack + OpenTofu | VPC/SG provisioned offline, API surface explored |

Each directory has its own README, `run.sh`, `cleanup.sh`, and manifests. The scripts are idempotent and clean up after themselves.

## What you need

Docker (any of Docker Desktop / Rancher Desktop / OrbStack), plus `kind`, `kubectl`, `helm`. For specific patterns also `cilium`, `istioctl`, `tofu`, `jq`.

```bash
make check-tools
```

prints what's installed and what's missing.

## Running a lab

```bash
cd 02-cilium-l7-identity
./run.sh
# ... outputs PASS/FAIL for each connectivity check
./cleanup.sh
```

`make clean-all` runs every `cleanup.sh` if you want to wipe everything.

## License

MIT.
