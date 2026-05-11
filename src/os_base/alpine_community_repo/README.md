# alpine_community_repo

Alpine Linux の `/etc/apk/repositories` における community リポジトリの有効・無効を切り替えるロールである。

## 概要

このインフラでは、Alpine Linux 上で community リポジトリを既定では無効化する方針を採っている。community リポジトリは必要なホストでのみ明示的に有効化する。

このロールは `/etc/apk/repositories` 内の `v<バージョン>/community` 行のみを対象とし、ミラー URL や Alpine のバージョン、`edge/*` などの他の行には一切手を加えない。setup-alpine やイメージ作成時に決定された設定をそのまま尊重する。

## ロール変数

| 変数               | 既定値  | 説明                                                                |
| ------------------ | ------- | ------------------------------------------------------------------- |
| `community_enabled` | `false` | `true` のとき community 行をアンコメント、`false` のときコメントアウト |

## 動作

1. `ansible_distribution == "Alpine"` のときのみ動作する
2. `community_enabled: false` の場合、`/etc/apk/repositories` 内の `^https?://.../v<数字>/community` 行を `#` でコメントアウトする
3. `community_enabled: true` の場合、`^#https?://.../v<数字>/community` 行をアンコメントする
4. ファイルに変更があった場合は `apk update` を実行する

`edge/community` や `edge/testing`、`edge/main` などのバージョン番号を含まない行は対象外である。community 行が存在しない環境では何も起きない。

## 使用例

### 既定（community を無効化）

```yaml
- hosts: alpine_hosts
  roles:
    - os_base/alpine_community_repo
```

### 特定のホストで community を有効化

```yaml
- hosts: needs_community_group
  roles:
    - role: os_base/alpine_community_repo
      vars:
        community_enabled: true
```

site.yml では、まず全 Alpine ホストに既定値で適用し、community が必要なグループに対して後段で `community_enabled: true` を渡して再適用する流れになる。

## 手動での適用手順

### community を無効化する場合

1. `/etc/apk/repositories` を開く
2. `https://dl-cdn.alpinelinux.org/alpine/v<バージョン>/community` のような行の先頭に `#` を付ける
3. `apk update` を実行する

### community を有効化する場合

1. `/etc/apk/repositories` を開く
2. `#https://dl-cdn.alpinelinux.org/alpine/v<バージョン>/community` の `#` を削除する
3. `apk update` を実行する

## 注意事項

community を無効化したホストで community 由来のパッケージをインストールしようとすると失敗する。community に依存するパッケージがあるホストでは `community_enabled: true` を指定する必要がある。
