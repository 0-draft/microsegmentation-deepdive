# 06. ホストファイアウォール (nftables in Docker)

[English](README.md) | **日本語**

Illumio、Akamai Guardicore、Cisco Secure Workload のホスト型エージェントは、最終的にどれもホストの packet filter にポリシーを書き出すところに収束する (Windows なら Windows Filtering Platform、Linux なら `iptables` / `nftables`)。このラボはその最後のステップだけを Linux コンテナと `nftables` + `CAP_NET_ADMIN` で再現する。

## 何を検証するか

3 つのコンテナ (`web`, `db`, `attacker`) を共有 Docker ブリッジに静的 IP で配置。`db` は Postgres。ベースライン: `web` も `attacker` も `nc 5432` で到達。

そのあと `db` の netns に `nft` ルールを流し込む:

- established / related は accept
- `web` (10.99.0.20) からの new 接続を accept
- それ以外の inbound は drop

これで `web` は通り続け、`attacker` はタイムアウトする。ここでのポリシー配布は `docker cp ... && docker exec db nft -f` で済ませているが、概念的にはエンタープライズの VEN 系エージェントが大規模にやっていることそのもの。

## なぜいまも知っておく価値があるか

クラウドネイティブな話題ばかりが目立つが、現実の企業システムは Linux VM とベアメタルの長い尾を抱えていて、そこでの enforcement ポイントはホストの nftables (古くは iptables) しかない。このラボはそのループの最小再現。

## 実行

```bash
./run.sh
```

30 秒くらい。Kubernetes 不要。期待出力は [`expected/output.txt`](./expected/output.txt)。

## 後片付け

```bash
./cleanup.sh
```
