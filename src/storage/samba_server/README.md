# samba_server

読み取り専用の CIFS (Samba) 共有を提供するサーバーをインストール・設定するロール

## 概要

### このドキュメントの目的

このロールは Alpine Linux 上に Samba を使用した読み取り専用の CIFS ファイルサーバーを構築する。Ansible による自動設定と手動設定の両方の手順を説明する。

### 実現される機能

- Samba パッケージのインストール
- 共有ディレクトリーの作成
- 設定ファイルのテンプレートデプロイ
- サービスの有効化と起動
- ユーザー認証による読み取り専用共有の提供
- OS イメージファイルの自動ダウンロードと配置

### 用途

BMC（IPMI/Redfish）から OS イメージ（ISO）をマウントしてリモート OS インストールを行う際に、mgmt ネットワーク上で CIFS 共有を提供する。

## 要件と前提条件

### 共通要件

- Alpine Linux
- root 権限または sudo 権限

### Ansible 固有の要件

- Ansible 2.9 以降
- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件

- apk コマンドが利用可能であること
- rc-service / rc-update コマンドが利用可能であること

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `samba_server_share_name` | 共有名 | `images` |
| `samba_server_share_path` | 共有ディレクトリーのパス | `/srv/images` |
| `samba_server_share_comment` | 共有のコメント | `OS Images` |
| `samba_server_username` | Samba ユーザー名 | `samba` |
| `samba_server_password` | Samba パスワード（Vault暗号化推奨） | （必須） |
| `samba_server_files` | ダウンロードして配置するファイルのリスト | `[]` |

`samba_server_files` の各要素は以下のキーを持つ辞書である。

| キー | 説明 |
|------|------|
| `url` | ダウンロード元の URL |
| `dest` | `samba_server_share_path` 内のファイル名 |

#### 依存関係

なし

#### タグとハンドラー

- ハンドラー `Restart samba`: 設定ファイル変更時にサービスを再起動する

#### 使用例

```yaml
- hosts: cifs_servers
  become: true
  roles:
    - role: storage/samba_server
```

```yaml
- hosts: cifs_servers
  become: true
  roles:
    - role: storage/samba_server
      vars:
        samba_server_files:
          - url: https://releases.ubuntu.com/noble/ubuntu-24.04.4-live-server-amd64.iso
            dest: ubuntu-24.04.4-live-server-amd64.iso
```

### 方法2: 手動での設定手順

#### ステップ1: インストール

```bash
sudo apk add samba
```

#### ステップ2: 共有ディレクトリーの作成

```bash
sudo mkdir -p /srv/images
```

#### ステップ3: 設定

`/etc/samba/smb.conf` を編集し、以下の設定を記述する。

- `[global]` セクション: `security = user` でユーザー認証を有効化する
- 共有セクション: `read only = yes` と `valid users` で読み取り専用の認証アクセスを設定する

#### ステップ4: ユーザー作成とパスワード設定

```bash
sudo adduser -S -D -H -s /sbin/nologin samba
sudo smbpasswd -a samba
```

#### ステップ5: 起動と有効化

```bash
sudo rc-update add samba default
sudo rc-service samba start
```

## 運用管理

### ファイル配置

共有ディレクトリー（デフォルト: `/srv/images`）にファイルを配置すると、CIFS 経由でアクセス可能になる。

```bash
# ファイルの配置
sudo cp ubuntu-24.04.4-live-server-amd64.iso /srv/images/

# 配置したファイルの確認
ls -la /srv/images/
```

### BMC からのマウント

iDRAC の仮想メディア機能で CIFS 共有を指定する場合、以下の形式を使用する。

- 共有パス: `//cifs.mgmt.home.arpa/images/ubuntu-24.04.4-live-server-amd64.iso`
- ユーザー名: `samba`（`samba_server_username` で設定した値）
- パスワード: `samba_server_password` で設定した値

### 基本操作

```bash
# サービスの状態確認
sudo rc-service samba status

# サービスの再起動
sudo rc-service samba restart

# 設定テスト
testparm -s
```

### ログとモニタリング

- Samba ログ: `/var/log/samba/`

### トラブルシューティング

1. **サービスが起動しない場合**: `testparm -s` で設定の構文エラーを確認し、ログディレクトリーを調べる
2. **BMC からマウントできない場合**: BMC と CIFS サーバーが同じ mgmt ネットワーク上にあるか確認する。`smbclient -U samba //cifs.mgmt.home.arpa/images` で共有にアクセスできるか確認する
3. **ファイルにアクセスできない場合**: 共有ディレクトリーのパーミッションと、ファイルの読み取り権限を確認する

## メンテナンス

```bash
# ログの確認
ls -la /var/log/samba/

# ディスク使用量の確認
du -sh /srv/images/
```

## アンインストール（手動）

```bash
sudo rc-service samba stop
sudo rc-update del samba default
sudo apk del samba
sudo rm -rf /srv/images /etc/samba
```
