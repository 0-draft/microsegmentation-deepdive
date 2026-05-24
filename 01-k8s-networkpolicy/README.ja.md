# 01. K8s NetworkPolicy + Calico

[English](README.md) | **日本語**

マイクロセグメンテーション入門編。素の `networking.k8s.io/v1` NetworkPolicy を Calico CNI で L3/L4 enforcement する。同じ YAML は NetworkPolicy を実装している任意の CNI で動く (kindnet は実装してないので Calico を入れる)。

## 何を検証するか

ポリシーなしの状態だと、`attacker` から `nc -zv db 5432` が通る。フラット。Maersk が NotPetya でやられた構造そのもの。

[`policy-default-deny.yaml`](./manifests/policy-default-deny.yaml) と [`policy-allow-cart-to-db.yaml`](./manifests/policy-allow-cart-to-db.yaml) を当てると、`attacker` はタイムアウト、`cart` だけ通る。スクリプトが両方を assert して PASS/FAIL を出す。

## 何が仕事をしているか

Calico の per-node エージェント **Felix** が NetworkPolicy と Pod イベントを API server から watch して、どの IP がどのセレクタに合致するかを計算し、iptables ルール (データプレーンを切り替えれば eBPF プログラム) として展開する。PEP は各 Pod の veth 直前のカーネル netfilter チェイン。PDP は K8s 制御プレーン + Felix の変換ロジック。

NetworkPolicy は **加算型の allow-list**。ある Pod を Ingress で選択するルールが 1 つでも入れば、それ以外の経路は暗黙的に deny される。"default-deny" は `podSelector: {}` で全 Pod を選択しつつ `ingress:` 節を空にする書き方で実現する。

## 実行

```bash
./run.sh
```

初回は image pull で 2 分くらいかかる。スクリプトは前回のクラスタが残っていれば再利用する。

期待出力は [`expected/output.txt`](./expected/output.txt) を参照。

## 後片付け

```bash
./cleanup.sh
```

kind クラスタを消す。
