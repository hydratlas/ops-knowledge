# tftp_server

PXE ブート用の TFTP サーバーをインストール・設定するロール

## 概要

### このドキュメントの目的

このロールは Alpine Linux 上に tftp-hpa を使用した TFTP サーバーを構築する。Ansible による自動設定と手動設定の両方の手順を説明する。

### 実現される機能

- tftp-hpa パッケージのインストール
- TFTP ルートディレクトリーの作成
- 設定ファイルのテンプレートデプロイ
- サービスの有効化と起動
- chroot モード（--secure）による安全なファイル提供

### 用途

PXE ブート環境で、ネットワーク経由でブートローダーやカーネルイメージを提供する。ドキュメントルートは静的ファイルサーバー（nginx）と共有し、HTTP と TFTP の両方でファイルにアクセスできる構成を想定している。

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
| `tftp_server_root` | TFTP ルートディレクトリー | `/var/www/files` |
| `tftp_server_address` | リッスンアドレス | `0.0.0.0` |
| `tftp_server_port` | リッスンポート | `69` |
| `tftp_server_options` | tftpd の追加オプション | `--secure` |

#### 依存関係

なし

#### タグとハンドラー

- ハンドラー `Restart in.tftpd`: 設定ファイル変更時にサービスを再起動する

#### 使用例

```yaml
- hosts: tftp_servers
  become: true
  roles:
    - role: os_base/tftp_server
```

```yaml
- hosts: tftp_servers
  become: true
  roles:
    - role: os_base/tftp_server
      vars:
        tftp_server_root: /srv/tftp
        tftp_server_address: 10.120.0.10
```

### 方法2: 手動での設定手順

#### ステップ1: インストール

```bash
sudo apk add tftp-hpa
```

#### ステップ2: TFTP ルートディレクトリーの作成

```bash
sudo mkdir -p /var/www/files
```

#### ステップ3: 設定

`/etc/conf.d/in.tftpd` を編集し、以下の設定を記述する。

- `INTFTPD_PATH`: TFTP ルートディレクトリー（デフォルト: `/var/www/files`）
- `INTFTPD_OPTS`: tftpd のオプション。`--secure` で chroot モードを有効化し、`--address` でリッスンアドレスとポートを指定する

#### ステップ4: 起動と有効化

```bash
sudo rc-update add in.tftpd default
sudo rc-service in.tftpd start
```

## 運用管理

### ファイル配置

TFTP ルートディレクトリー（デフォルト: `/var/www/files`）にファイルを配置すると、TFTP 経由でアクセス可能になる。

```bash
# PXE ブートローダーの配置
sudo cp pxelinux.0 /var/www/files/

# 配置したファイルの確認
ls -la /var/www/files/
```

### 基本操作

```bash
# サービスの状態確認
sudo rc-service in.tftpd status

# サービスの再起動
sudo rc-service in.tftpd restart
```

### トラブルシューティング

1. **サービスが起動しない場合**: `/etc/conf.d/in.tftpd` の設定内容を確認し、TFTP ルートディレクトリーが存在するか確認する
2. **ファイルが取得できない場合**: TFTP ルートディレクトリーのパーミッションと、ファイルの読み取り権限を確認する。`--secure` オプション使用時はルートディレクトリーからの相対パスでアクセスする必要がある
3. **ネットワークの問題**: ファイアウォールで UDP ポート 69 が許可されているか確認する

## メンテナンス

```bash
# ディスク使用量の確認
du -sh /var/www/files/
```

## アンインストール（手動）

```bash
sudo rc-service in.tftpd stop
sudo rc-update del in.tftpd default
sudo apk del tftp-hpa
```
