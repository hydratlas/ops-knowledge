# nfs_server_kerberos

NFS サーバーに対する Kerberos サービスプリンシパル `nfs/<fqdn>@HOME.ARPA` を FreeIPA に登録し、ローカルの `/etc/krb5.keytab` に取り込むロール

## 概要

### このドキュメントの目的

このロールは、Kerberos NFS（`sec=krb5` エクスポート）を提供する NFS サーバーに不足しがちな `nfs/` サービスプリンシパルを冪等に整備することを目的とする。Ansible による自動設定と、それと等価な手動手順の両方を記載する。

### 実現される機能

- FreeIPA 上に `nfs/<fqdn>` サービスプリンシパルを作成（既存なら no-op）
- 対象ホスト自身に `allow_create_keytab` / `allow_retrieve_keytab` を付与
- 対象ホストの `/etc/krb5.keytab` に `nfs/<fqdn>` の鍵を追記
- 鍵が追記された場合に `exportfs -r` で `sec=krb5` エクスポートを再展開
- Debian 系で `rpc-svcgssd.service` を `reset-failed` してから起動

`/etc/krb5.keytab` に既に `nfs/<fqdn>@HOME.ARPA` が存在する場合は IPA への問い合わせ・キータブ取得・ハンドラー実行のすべてをスキップする。

## 要件と前提条件

### 共通要件

- **対象ホスト**: 既に FreeIPA に登録済み（`/etc/krb5.keytab` に `host/<fqdn>@HOME.ARPA` がある）
- **OS**: Debian 系 (`nfs-kernel-server`) または RHEL 系 (`nfs-utils`)
- **ネットワーク**: FreeIPA サーバーへの 88/tcp,udp（Kerberos）および 443/tcp（IPA API）が到達可能
- **権限**: `root`

### Ansible 固有の要件

- **Ansible バージョン**: 2.14 以上
- **コレクション**: `freeipa.ansible_freeipa`
- **認証情報**: 変数 `ipaadmin_password` が定義されていること
- **委譲先**: `ipaclient_servers` の先頭ホストにコントロールノードから ssh で接続できること

### 手動設定の要件

- 対象 NFS サーバー上で `ipa-getkeytab` コマンドが使えること（`freeipa-client` 同梱）
- 管理者 Kerberos チケット（`kinit admin`）が取得可能なこと

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名                          | 説明                                              | デフォルト値                   | 必須 |
| ------------------------------- | ------------------------------------------------- | ------------------------------ | ---- |
| `ipaadmin_password`             | FreeIPA 管理者パスワード                          | -                              | はい |
| `nfs_server_kerberos_realm`     | Kerberos レルム名                                 | `HOME.ARPA`                    | いいえ |
| `nfs_server_kerberos_ipa_server`| サービス登録・キータブ取得に使用する IPA サーバー | `ipaclient_servers[0]`         | いいえ |

#### 依存関係

`storage/nfs_server_install` の後段で実行することを想定する（このロール自体は `nfs-kernel-server` パッケージを導入しない）。`storage/nfs_server_export` よりも前で実行することで、エクスポート再読み込み時に `sec=krb5` 行が確実に展開される。

#### タグとハンドラー

- タグ: `nfs_server_kerberos`
- ハンドラー: `nfs-server-kerberos-keytab-changed`（`exportfs -r` と `rpc-svcgssd.service` の再起動を一括で実行）

#### 使用例

```yaml
- hosts: nas
  become: true
  roles:
    - role: storage/nfs_server_install
    - role: storage/nfs_server_kerberos
    - role: storage/nfs_server_export
```

### 方法2: 手動での設定手順

#### ステップ1: 現状確認

```bash
# 対象 NFS サーバー側で nfs/ プリンシパルの有無を確認
sudo klist -k /etc/krb5.keytab | grep -E '\snfs/'
```

`nfs/<fqdn>@HOME.ARPA` が出力されない場合のみ以降の手順を実施する。

#### ステップ2: IPA でサービスプリンシパルを作成

任意の IPA サーバー上で実施する。

```bash
kinit admin
ipa service-add nfs/<fqdn>
ipa service-allow-create-keytab nfs/<fqdn> --hosts=<fqdn>
ipa service-allow-retrieve-keytab nfs/<fqdn> --hosts=<fqdn>
```

#### ステップ3: 対象 NFS サーバー上でキータブを取得

```bash
sudo kinit -k -t /etc/krb5.keytab host/<fqdn>@HOME.ARPA
sudo ipa-getkeytab -s <ipa-server-fqdn> -p nfs/<fqdn> -k /etc/krb5.keytab
sudo kdestroy
```

#### ステップ4: NFS サービスを再展開し rpc-svcgssd を起動

```bash
sudo exportfs -r
sudo systemctl reset-failed rpc-svcgssd.service
sudo systemctl start rpc-svcgssd.service
sudo exportfs -v | grep -i krb5
```

## 運用管理

### 基本操作

- キータブの内容確認: `sudo klist -k /etc/krb5.keytab`
- `sec=krb5` エクスポートの展開確認: `sudo exportfs -v | grep krb5`
- `rpc-svcgssd.service` 状態: `systemctl status rpc-svcgssd.service`

### ログとモニタリング

- `journalctl -u rpc-svcgssd.service`
- `journalctl -u nfs-server.service`（Debian 系では `nfs-kernel-server.service`）
- IPA 側: `/var/log/krb5kdc.log`、`/var/log/httpd/error_log`

### トラブルシューティング

#### 問題1: `ipa-getkeytab` が `KDC has no support for encryption type` を返す

**原因**: `host/<fqdn>` キータブの暗号化方式と IPA の許容方式が不整合。
**対処**: 対象ホストで `ipa-client-install --force-join` を再実行し、`host/` プリンシパルを再発行する。

#### 問題2: `ipa-getkeytab` が `Operation failed! Insufficient access rights` を返す

**原因**: 対象ホストに `allow_create_keytab` が付与されていない。
**対処**: IPA サーバー上で `ipa service-allow-create-keytab nfs/<fqdn> --hosts=<fqdn>` を実行する。

#### 問題3: キータブ追記後も `rpc-svcgssd.service` が failed のまま

**原因**: `systemctl reset-failed` 前に start を試みると start-limit に阻まれることがある。
**対処**: `systemctl reset-failed rpc-svcgssd.service && systemctl start rpc-svcgssd.service`。

### メンテナンス

- プリンシパルのローテーション: `sudo ipa-getkeytab -s <ipa> -p nfs/<fqdn> -k /etc/krb5.keytab` を再実行すると鍵が再生成される。生成後は `nfs-kernel-server` の再起動が必要になる場合がある。

## アンインストール（手動）

```bash
# IPA からサービスを削除
ipa service-del nfs/<fqdn>

# キータブから対象プリンシパルを除去
sudo ktutil <<'EOF'
rkt /etc/krb5.keytab
list
# nfs/ の slot を delent N で全削除
wkt /etc/krb5.keytab.new
EOF
sudo mv /etc/krb5.keytab.new /etc/krb5.keytab
sudo chmod 600 /etc/krb5.keytab
```
