# 03. Calico Global / Ordered Policy

**English** | [日本語](README.ja.md)

Calico's `GlobalNetworkPolicy` is the part the upstream `NetworkPolicy` doesn't cover: cluster-wide rules with explicit `order`, rich selectors, and a `Deny` action you can mix with `Allow`. This lab shows two things you can't express with vanilla NetworkPolicy alone.

## What gets verified

Two namespaces, `prod` and `staging`, each running an `api` pod. One GlobalNetworkPolicy:

- denies any traffic where source `env=staging` and destination `env=prod`, **cluster-wide**

Then a second GlobalNetworkPolicy with a **lower** `order` value carves out one exception (a single staging pod tagged `audit=true` is allowed). Calico evaluates lowest order first, so the exception wins.

The script asserts:

1. baseline: `staging/api -> prod/api` reachable
2. after the deny policy: same call **blocked**
3. after the lower-order allow with `audit=true`: that specific pod can reach prod again

## Why this isn't just NetworkPolicy

Vanilla `NetworkPolicy` is additive-allow and namespace-scoped. There's no `Deny`, no `order`, and you can't write a rule that crosses namespaces in a single object. `GlobalNetworkPolicy` gives you all three. The price is Calico-specific: this only runs where Calico is the dataplane.

## Run

```bash
./run.sh
```

## Cleanup

```bash
./cleanup.sh
```
