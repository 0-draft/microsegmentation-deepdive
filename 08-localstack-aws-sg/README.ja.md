# 08. AWS Security Group as code (LocalStack + OpenTofu)

[English](README.md) | **日本語**

マイクロセグメンテーションのクラウドネイティブ版。VPC・subnet・SG を IaC で宣言して、クラウドプラットフォーム側に enforcement させる。このラボはその AWS API 表面を LocalStack で完全オフラインに動かすので、Terraform モデルを AWS の請求書なしで回せる。

## このラボは何で、何ではないか

LocalStack は EC2/VPC/SG の **AWS API** をエミュレートする。`terraform apply` で本物っぽいリソースが作れて、SG メンバーシップもクエリできる。公式ドキュメントによると、SG の ingress ルールは dockerised モック EC2 インスタンスに **作成時にのみ** 適用される (作成後の SG ルール変更は走ってるコンテナまで届かない)。なのでこのラボは「IaC と API の練習」として読んでほしい。パケットレベルの強制プルーフが欲しければ Pattern 01 (K8s NetworkPolicy) を回して、SG ルールをクラスタ版として読み替える。

## 何を検証するか

OpenTofu (Terraform のオープンソースフォーク) が作るもの:

- VPC 1 つ
- subnet 2 つ (`web`, `app`)
- security group 3 つ (`web-sg`, `app-sg`, `db-sg`) を以下で結線:
  - web-sg は `0.0.0.0/0` からの `:80` を受け入れる
  - app-sg は web-sg からの `:8080` を受け入れる
  - db-sg は app-sg からの `:5432` のみ受け入れる

スクリプトが `aws ec2 describe-security-groups --endpoint-url ...` を叩いて、ルール構造がマッチすることを assert する。

エンタープライズのプラットフォームチームが Git で管理しているのはこれ。SG-as-code が、何百もの AWS アカウントを横断してマイクロセグメンテーションをスケールさせる方法。

## 実行

```bash
./run.sh
```

1 分くらい (LocalStack の pull が時間を食う)。期待出力は [`expected/output.txt`](./expected/output.txt)。

## 後片付け

```bash
./cleanup.sh
```
