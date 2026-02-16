# nfs_server_install

NFSサーバーパッケージインストール・サービス管理ロール

## 概要

### このドキュメントの目的
このロールは、NFSサーバーのパッケージインストールとサービスの起動・有効化のみを行います。ディストリビューション別に適切なパッケージ（RedHat系ではnfs-utils、Debian系ではnfs-kernel-server）を自動判定してインストールし、対応するNFSサービスを起動・有効化します。エクスポート設定は別ロール（nfs_server_export等）で管理します。Ansible自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- NFSサーバーパッケージの自動インストール
- NFSサービスの起動と有効化

## 要件と前提条件

### 共通要件
- Linux OS（Debian/Ubuntu/RHEL/CentOS/AlmaLinux）
- root権限またはsudo権限
- クライアントからのネットワークアクセス

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- bashシェル
- sudo権限を持つユーザー
- ファイアウォール管理ツール（firewalld、ufw等）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
なし

#### 依存関係
なし

#### タグとハンドラー
- タグ: なし
- ハンドラー: なし

#### 使用例

基本的な使用例：
```yaml
- hosts: nfs_servers
  become: true
  roles:
    - storage/nfs_server_install
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# ファイアウォールの状態確認
sudo firewall-cmd --list-all  # RHEL/CentOS
sudo ufw status               # Ubuntu/Debian
```

#### ステップ2: NFSサーバーパッケージのインストール

Debian/Ubuntu系：
```bash
# パッケージリストの更新
sudo apt-get update

# NFSサーバーのインストール
sudo apt-get install -y nfs-kernel-server

# サービスの状態確認
sudo systemctl status nfs-kernel-server
```

RHEL/CentOS/AlmaLinux系：
```bash
# NFSユーティリティのインストール
sudo yum install -y nfs-utils
# または
sudo dnf install -y nfs-utils

# 必要なサービスの有効化と起動
sudo systemctl enable --now nfs-server
sudo systemctl enable --now rpcbind
```

#### ステップ3: ファイアウォールの設定

RHEL/CentOS/AlmaLinux（firewalld）：
```bash
# NFSサービスを許可
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=rpc-bind
sudo firewall-cmd --permanent --add-service=mountd

# 設定をリロード
sudo firewall-cmd --reload

# 確認
sudo firewall-cmd --list-services
```

Debian/Ubuntu（ufw）：
```bash
# NFSポートを開放
sudo ufw allow from 192.168.1.0/24 to any port 2049  # NFS
sudo ufw allow from 192.168.1.0/24 to any port 111   # rpcbind

# 確認
sudo ufw status verbose
```

#### ステップ4: NFSサービスの起動

```bash
# サービスの起動と有効化
# Debian/Ubuntu
sudo systemctl enable --now nfs-kernel-server

# RHEL/CentOS
sudo systemctl enable --now nfs-server

# サービスの状態確認
sudo systemctl status nfs-server       # RHEL/CentOS
sudo systemctl status nfs-kernel-server  # Debian/Ubuntu
```

## トラブルシューティング

### 診断フロー

1. サービス状態の確認
   ```bash
   sudo systemctl status nfs-server rpcbind
   sudo rpcinfo -p
   ```

2. ファイアウォールの確認
   ```bash
   sudo ss -tlnp | grep -E '(2049|111)'
   sudo iptables -L -n | grep -E '(2049|111)'
   ```

### よくある問題と対処方法

- **問題**: NFSサービスが起動しない
  - **対処**: `sudo journalctl -u nfs-server -f`（RHEL/CentOS）または`sudo journalctl -u nfs-kernel-server -f`（Debian/Ubuntu）でログを確認してください

- **問題**: クライアントから接続できない
  - **対処**: ファイアウォール設定とネットワーク到達性を確認してください

## アンインストール（手動）

NFSサーバーのパッケージを削除する手順：

```bash
# 1. NFSサービスを停止
# Debian/Ubuntu
sudo systemctl stop nfs-kernel-server
sudo systemctl disable nfs-kernel-server

# RHEL/CentOS
sudo systemctl stop nfs-server
sudo systemctl disable nfs-server

# 2. NFSパッケージを削除
# Debian/Ubuntu
sudo apt-get remove --purge nfs-kernel-server

# RHEL/CentOS
sudo yum remove nfs-utils

# 3. ファイアウォールルールを削除
sudo firewall-cmd --permanent --remove-service=nfs
sudo firewall-cmd --permanent --remove-service=rpc-bind
sudo firewall-cmd --permanent --remove-service=mountd
sudo firewall-cmd --reload
```

## 注意事項

- NFSv4を使用する場合は、擬似ファイルシステムのルートを設定する必要があります
- エクスポート設定は別ロールで管理するため、このロールの適用後に別途設定が必要です
