# 03. Calico Global / Ordered Policy

> 🇯🇵 日本語 ・ 🇺🇸 [English](./README.md)

Calico の `GlobalNetworkPolicy` は、アップストリームの `NetworkPolicy` ではカバーできない領域を担う。クラスタ横断ルール、明示的な `order` フィールド、リッチなセレクタ、`Allow` と混在できる `Deny` アクション。このラボはバニラ NetworkPolicy で書けない 2 つを動かす。

## 何を検証するか

`prod` と `staging` の 2 つの namespace、それぞれに `api` Pod を 1 つ置く。1 つ目の GlobalNetworkPolicy:

- ソースが `env=staging`、宛先が `env=prod` の通信を **クラスタ全体で** Deny

そのあと、より **低い** `order` の GlobalNetworkPolicy で例外を 1 つ切る (staging の中で `audit=true` ラベルを持つ Pod だけは prod に到達可)。Calico は order の低いものから評価するので、例外が勝つ。

スクリプトが assert する:

1. ベースライン: `staging/api -> prod/api` 到達可
2. Deny ポリシー適用後: 同じ呼び出しが **ブロック**
3. 低 order の allow 例外を追加後: `audit=true` の Pod だけ prod に再到達可

## NetworkPolicy で済まない理由

バニラ `NetworkPolicy` は加算 allow + namespace スコープ。`Deny` も `order` もなく、複数 namespace を 1 オブジェクトで横断するルールが書けない。`GlobalNetworkPolicy` でこの 3 つが揃う。代償は Calico ロックイン (このリソースは Calico データプレーンが必要)。

## 実行

```bash
./run.sh
```

2 分くらい。期待出力は [`expected/output.txt`](./expected/output.txt)。

## 後片付け

```bash
./cleanup.sh
```
