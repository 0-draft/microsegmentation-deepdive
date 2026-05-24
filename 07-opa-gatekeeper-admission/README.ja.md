# 07. OPA Gatekeeper: admission 時のポリシー

[English](README.md) | **日本語**

これまでのラボは全部 dataplane で enforcement していた (パケットが届いてから判定)。このラボは判定をワークロードが存在する **前**、API server の admission チェインに移す。設定ミス manifest は `kubectl apply` を超えられない。

L3/L4 セグメンテーションの代わりではない。Pattern 01–06 のセグメンテーションポリシーが本番で「ちゃんと正しい状態」であり続けるためのガードレール。「NetworkPolicy 無しの Pod は許さない」「Service には必ず `env` ラベル」「root では走らせない」みたいな組織標準の自動 enforcement。

## 何を検証するか

Gatekeeper に 2 つの ConstraintTemplate を入れる:

1. `K8sRequiredLabels`: 全 Pod に `app` と `env` ラベル必須
2. `K8sNoPodWithoutNetpol` (自作): NetworkPolicy が 1 つも無い namespace に Pod を作るのは禁止

スクリプトの流れ:

- namespace `prod` を作る
- ラベル無しの Pod を作ろうとする → ConstraintTemplate 1 で **拒否**
- ラベル有り + NetworkPolicy 無しの Pod → ConstraintTemplate 2 で **拒否**
- NetworkPolicy を当ててから同じ Pod を作る → **許可**

判定は全部 admission 時点。kubelet が spec を見る時にはもう known-good。

## なぜ重要か

Pattern 01 はワークロードが存在した後の横移動を止める。しかしポリシーから opt-out した状態でデプロイできてしまうなら、壁に穴がある。Admission 制御は組織横断ガードレールを「誰も覚えてなくて」自動で当てる仕組み。

## 実行

```bash
./run.sh
```

2 分くらい。期待出力は [`expected/output.txt`](./expected/output.txt)。

## 後片付け

```bash
./cleanup.sh
```
