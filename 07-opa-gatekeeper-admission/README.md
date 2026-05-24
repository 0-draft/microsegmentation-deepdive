# 07. OPA Gatekeeper: policy at admission

**English** | [日本語](README.ja.md)

The previous labs all enforce at the dataplane: packets arrive, something decides. This one moves the decision **before** the workload exists, into the API server's admission chain. Misconfigured manifests never get past `kubectl apply`.

This isn't a substitute for L3/L4 segmentation. It's the guardrail that makes the segmentation policies in patterns 01–06 actually correct in production: "no Pod ships without a NetworkPolicy", "every Service must have an `env` label", "no Deployment may run as root", etc.

## What gets verified

Two ConstraintTemplates loaded into Gatekeeper:

1. `K8sRequiredLabels`: every Pod must carry an `app` and `env` label
2. `K8sNoPodWithoutNetpol` (custom): a Pod cannot be admitted into a namespace that has no `NetworkPolicy`

Then the script:

- creates a namespace `prod`
- tries to create a Pod without labels → **rejected** by ConstraintTemplate 1
- creates a Pod with labels but no NetworkPolicy → **rejected** by ConstraintTemplate 2
- applies a NetworkPolicy and creates the same Pod → **admitted**

All decisions happen at admission time. By the time the kubelet sees the spec, it's already known-good.

## Why this matters

Pattern 01 stops lateral movement once a workload exists. But if developers can deploy a workload that opts out of policy in the first place, the wall has a hole. Admission control is how org-wide guardrails get enforced without anyone having to remember.

## Run

```bash
./run.sh
```

About 2 minutes. Expected output: [`expected/output.txt`](./expected/output.txt).

## Cleanup

```bash
./cleanup.sh
```
