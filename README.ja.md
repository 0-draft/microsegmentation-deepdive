# microsegmentation-deepdive

[English](README.md) | **日本語**

マイクロセグメンテーションは語られまくっているが、end-to-end で動かす場が少ない。このリポは 8 種類の実装をラップトップ 1 台で実際に走らせて、パケットに何が起きるかを目で見て確認するためのもの。

## 中身

| # | 方式 | ツール | 実際に動かすこと |
| --- | --- | --- | --- |
| [01](./01-k8s-networkpolicy/) | K8s NetworkPolicy | Calico CNI | kind クラスタで attacker Pod の `nc` がポリシー適用後にブロックされる |
| [02](./02-cilium-l7-identity/) | Cilium L7 + Hubble | Cilium eBPF + Envoy | `curl DELETE` が Envoy 由来の 403 を返し、attacker は L4 でタイムアウト、Hubble UI に verdict が出る |
| [03](./03-calico-tiered/) | Calico tiered global policy | Calico GlobalNetworkPolicy | 名前空間横断で order/tier 評価 |
| [04](./04-istio-mtls-authz/) | Istio mTLS + AuthZ | Istio サイドカー | STRICT mTLS と principal ベース拒否 |
| [05](./05-spiffe-spire-envoy/) | SPIFFE/SPIRE + Envoy | SPIRE Server/Agent + Envoy | Envoy が SDS 経由で X.509-SVID を取得し、mTLS に使う |
| [06](./06-host-nftables/) | ホストファイアウォール (エージェント風) | privileged Docker 内の nftables | controller から各ホストにルール配布 |
| [07](./07-opa-gatekeeper-admission/) | Admission 時制御 | OPA Gatekeeper | 必須ラベルがない Pod が `kubectl apply` の時点で拒否される |
| [08](./08-localstack-aws-sg/) | AWS Security Group as code | LocalStack + OpenTofu | オフライン環境で VPC/SG を作って API を眺める |

各ディレクトリに固有の README、`run.sh`、`cleanup.sh`、manifests が入っている。スクリプトは idempotent で、自分で後片付けもする。

## 必要なもの

Docker (Docker Desktop / Rancher Desktop / OrbStack のいずれか) と `kind` `kubectl` `helm`。パターンごとに追加で `cilium` `istioctl` `tofu` `jq` が要る場合がある。

```bash
make check-tools
```

で入っているもの / 足りないものが一覧表示される。

## ラボの走らせ方

```bash
cd 02-cilium-l7-identity
./run.sh
# ... 接続性チェックの PASS/FAIL が出力される
./cleanup.sh
```

全部を一気に消したい時は `make clean-all` で各ディレクトリの `cleanup.sh` を順に走らせる。

## License

MIT。
