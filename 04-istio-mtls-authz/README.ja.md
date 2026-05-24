# 04. Istio mTLS + AuthorizationPolicy

> 🇯🇵 日本語 ・ 🇺🇸 [English](./README.md)

ここで「信頼の根拠」が切り替わる。Pattern 01–03 はあくまで「Pod のラベル」で認証していて、ラベルは kubelet が書く。Istio が入ると、各サービスが自分の X.509 証明書 (Istiod が発行する SPIFFE ID) を持ち、ポリシーは label セレクタではなく `principals` で書かれる。

## 何を検証するか

`cart` と `attacker` の 2 Pod、両方にサイドカー、PERMISSIVE から STRICT へ切り替え。`PeerAuthentication` で namespace 全体を STRICT mTLS に。`AuthorizationPolicy` で `httpbin` サーバには SPIFFE principal `cluster.local/ns/shop/sa/cart-sa` のみ許可。

スクリプトがチェックする:

1. STRICT モード: メッシュ外 (サイドカーなし Pod) からの `curl` が TLS 層で拒否される
2. `cart` (正しい SA) は `httpbin` に到達できる: 200
3. `attacker` (別 SA、サイドカーあり) は Envoy から 403 (`RBAC: access denied`)

TCP パケットは 3 ケースで全く同じ。判定は完全にメッシュ内で行われる。

## NetworkPolicy で済まない理由

NetworkPolicy はネットワークを信頼する。同じラベルを持つ悪意ある Pod が立てば通る。mTLS ベースの認可は証明書を信頼する。「cart ServiceAccount の鍵で署名された要求が欲しい」と書け、その鍵は cart Pod しか持たない。

## 実行

```bash
./run.sh
```

4 分くらい (Istio インストールが時間を食う)。期待出力は [`expected/output.txt`](./expected/output.txt)。

## 後片付け

```bash
./cleanup.sh
```
