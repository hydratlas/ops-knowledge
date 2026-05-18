# ipa_topology_segments

FreeIPA/IdM のレプリカ間トポロジーセグメントを宣言的に管理するロール。

## 概要

### このドキュメントの目的

FreeIPA のレプリカ同士を結ぶトポロジーセグメント（`domain` および `ca` サフィックス）を、インベントリで定義したリストに従って作成・維持する。フルメッシュ構成や任意のトポロジーをコード化することで、レプリカ追加時の同期経路を一元管理できる。

### 実現される機能

- `freeipa.ansible_freeipa.ipatopologysegment` モジュールによるセグメントの宣言的管理
- `ipatopology_segments` 変数によるトポロジー全体の集中定義
- いずれか 1 ノードでの実行（`run_once`）

## 要件と前提条件

### 共通要件

- **システム**: FreeIPA/IdM サーバー 4.x 以上
- **権限**: FreeIPA 管理者権限
- **前提条件**: 対象となる全レプリカが `ipareplica` で構築済みであること

### Ansible 固有の要件

- **コレクション**: `freeipa.ansible_freeipa`
- **実行対象**: `ipaservers` グループ（`run_once` でいずれか 1 ノードのみが API を呼び出す）
- **認証**: `ipaadmin_password`

## 設定方法

### 方法 1: Ansible Role を使用

#### ロール変数

| 変数名                 | 説明                                                      | デフォルト値 | 必須 |
| ---------------------- | --------------------------------------------------------- | ------------ | ---- |
| `ipaadmin_password`    | FreeIPA 管理者パスワード                                  | -            | はい |
| `ipatopology_segments` | セグメント定義のリスト（`suffix`、`left`、`right` を含む） | -            | はい |

`ipatopology_segments` の各要素の形式：

| キー     | 説明                                              |
| -------- | ------------------------------------------------- |
| `suffix` | `domain`、`ca`、`domain+ca` のいずれか            |
| `left`   | セグメントの一端となるレプリカの FQDN             |
| `right`  | セグメントのもう一端となるレプリカの FQDN         |

#### 依存関係

- `freeipa.ansible_freeipa` コレクション
- 全レプリカが事前に `ipareplica` ロールで構築済みであること

#### タグとハンドラー

このロールにはタグやハンドラーは定義されていない。プレイ側でタグを付与する。

### 方法 2: 手動での設定手順

`ipa topologysegment-add` コマンドでセグメントを追加できる。例えば `domain+ca` サフィックスで idm-01 と idm-02 を結ぶ場合は以下のように実行する。

```bash
kinit admin
ipa topologysegment-add domain --left=idm-01.int.home.arpa --right=idm-02.int.home.arpa
ipa topologysegment-add ca     --left=idm-01.int.home.arpa --right=idm-02.int.home.arpa
```

既存セグメントの一覧確認は `ipa topologysegment-find domain` および `ipa topologysegment-find ca` で行う。

## アンインストール（手動）

不要になったセグメントは `ipa topologysegment-del` で削除する。削除前に残りのセグメントでレプリカ間が連結された状態を保つよう、トポロジー全体を確認すること。

```bash
ipa topologysegment-find domain
ipa topologysegment-del domain <segment-cn>
```
