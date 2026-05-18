# freeipa_nfs_service

NFS サーバー用の Kerberos サービスプリンシパル `nfs/<fqdn>@HOME.ARPA` を FreeIPA に一括登録するロール

## 概要

### このドキュメントの目的

NFS サーバーで `sec=krb5` エクスポートを利用するには `nfs/<fqdn>` サービスプリンシパルが必要である。本ロールは複数の NFS サーバーに対する登録を冪等にまとめて実施することを目的とする。Ansible による自動設定と、それと等価な手動手順の両方を記載する。

### 実現される機能

- 指定されたホスト群それぞれについて `nfs/<fqdn>` サービスプリンシパルを作成（存在すれば no-op）
- 当該ホストに `allow_create_keytab_host` および `allow_retrieve_keytab_host` を付与
- ホストごとのキータブ取得は別ロール（`storage/nfs_server_kerberos`）が担当

## 要件と前提条件

### 共通要件

- **対象システム**: FreeIPA/IdM サーバー（本ロールは IPA サーバー上で実行する）
- **権限**: FreeIPA 管理者
- **前提条件**: 対象ホストが事前に FreeIPA に登録済み（`host/<fqdn>` プリンシパル存在）

### Ansible 固有の要件

- **Ansible バージョン**: 2.14 以上
- **コレクション**: `freeipa.ansible_freeipa`
- **認証情報**: 変数 `ipaadmin_password` が定義されていること

### 手動設定の要件

- IPA サーバー上で `ipa` コマンドが利用可能
- `kinit admin` で管理者チケットを取得できること

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名                       | 説明                                                   | デフォルト値 | 必須   |
| ---------------------------- | ------------------------------------------------------ | ------------ | ------ |
| `ipaadmin_password`          | FreeIPA 管理者パスワード                               | -            | はい   |
| `freeipa_nfs_service_hosts`  | サービスプリンシパルを登録する対象 FQDN のリスト       | `[]`         | はい   |

#### 依存関係

`freeipa.ansible_freeipa` コレクションが導入済みであること

#### タグとハンドラー

このロールにはタグもハンドラーも定義されていない。

#### 使用例

```yaml
- hosts: ipaservers
  become: true
  gather_facts: false
  roles:
    - role: authentication/freeipa_nfs_service
      vars:
        freeipa_nfs_service_hosts: "{{ groups['nas'] }}"
```

### 方法2: 手動での設定手順

任意の IPA サーバー上で次を実行する。

```bash
kinit admin
ipa service-add nfs/<fqdn>
ipa service-allow-create-keytab nfs/<fqdn> --hosts=<fqdn>
ipa service-allow-retrieve-keytab nfs/<fqdn> --hosts=<fqdn>
```

## 運用管理

### 基本操作

- 登録済みプリンシパルの一覧: `ipa service-find nfs/`
- 個別の詳細表示: `ipa service-show nfs/<fqdn>`

### トラブルシューティング

#### 問題1: `ipaservice` モジュールが `Operation failed!` を返す

**原因**: 対象ホストが事前に IPA に登録されていない。
**対処**: 当該ホストで `ipa-client-install` を実施するか、IPA 側で `ipa host-add <fqdn>` を行う。

## アンインストール（手動）

```bash
ipa service-del nfs/<fqdn>
```
