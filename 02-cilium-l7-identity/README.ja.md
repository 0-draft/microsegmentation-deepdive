# 02. Cilium L7 + Identity (Hubble 付き)

[English](README.md) | **日本語**

Pattern 01 でできないことを見るためのラボ。ワークロードは同じだが、ポリシーが「`web` から `cart` への通信は `GET` と `POST` のみ許可」になっていて、eBPF データプレーンがマッチした接続を Envoy にリダイレクトして enforcement する。

## 何を検証するか

`web -> cart` の `GET` は 200。同じソースからの `DELETE` は Envoy 直の `403` (リクエストは cart Pod 内の nginx に届かない)。`attacker` は TCP connect も通らない (同じポリシーの L4 部分が `app=web` だけを source として許可しているため)。Hubble UI でこの 3 つの verdict が並んで見える。

L3/L4 + L7 が 1 つのポリシーオブジェクト、identity 駆動、観測がデータプレーンに組み込み済み。これが Cilium の売り。

## Pattern 01 との違い

Cilium は iptables に IP を書かない。ユニークなラベルセットごとに安定した数値 **Cilium Identity** を割り振り、パケットメタデータに identity を載せて、各ノードの eBPF プログラムが identity ペアを見て allow/deny を判定する。HTTP レベルの enforcement を要求すると、Cilium が接続を Envoy リスナ (ノードあたり 1 つ、組み込み) に透過リダイレクトする。これが「拒否が TCP タイムアウトではなく本物の `403`」である理由。

## 実行

```bash
./run.sh
```

初回は 3 分くらい。スクリプトは Hubble UI を有効化するがブラウザは開かない。見たければあとから `cilium hubble ui`。

期待出力は [`expected/output.txt`](./expected/output.txt)。

## 後片付け

```bash
./cleanup.sh
```
