# 05. SPIFFE / SPIRE: ワークロード ID 配布をゼロから

> 🇯🇵 日本語 ・ 🇺🇸 [English](./README.md)

Pattern 04 は Istio の内蔵 CA を使ったが、便利な反面メカニズムが隠れる。このラボは SPIRE を素で動かす。server、agent、ワークロード認証 (attestation)、X.509-SVID 発行。SPIFFE ID が発行されて Pod に渡るのを目で見るためのラボ。

## 何を検証するか

同じ Linux UID、同じコンテナイメージの 2 Pod を別 ServiceAccount で動かす。SPIRE Agent の Kubernetes attestor は `sa.name + ns + pod label` を見て、**別々の** SVID を渡す。各 Pod 内で `spire-agent api fetch x509` を叩くと、証明書の SPIFFE URI が出る。

登録エントリが存在しない 3 つ目の Pod (別 ServiceAccount) には SVID が返らない。SPIRE が attest を拒否する。

スクリプトがチェック:

1. `cart` Pod が SVID `spiffe://example.org/ns/shop/sa/cart-sa` を取得
2. `payments` Pod が SVID `spiffe://example.org/ns/shop/sa/payments-sa` を取得
3. `unknown` Pod は何も取得できない (timeout / no entry)

これが、Pattern 04・Envoy 経由の L7 mTLS・ztunnel・Linkerd など、すべての identity 駆動セグメンテーションが土台に置いている ID 発行フロー。

## 中で何が起きているか

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

`k8sPSAT` (Pod Service Account Token) attestor: agent が pod の projected token を渡し、server が kube-apiserver で検証してマッチした登録エントリの SVID を発行する。

## 実行

```bash
./run.sh
```

3 分くらい。期待出力は [`expected/output.txt`](./expected/output.txt)。

## 後片付け

```bash
./cleanup.sh
```
