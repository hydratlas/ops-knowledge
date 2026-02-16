# nfs_server

NFSサーバー設定・エクスポート管理ロール

## 概要

### このドキュメントの目的
このロールは、NFSサーバーのセットアップとディレクトリエクスポートの管理を行います。必要なパッケージのインストール、エクスポートディレクトリの作成、`/etc/exports`の設定を自動化します。Ansible自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- NFSサーバーパッケージの自動インストール
- エクスポートディレクトリの作成と権限設定
- `/etc/exports`ファイルの自動生成と管理
- NFSサービスの起動と有効化
- エクスポート設定の動的リロード

## 要件と前提条件

### 共通要件
- Linux OS（Debian/Ubuntu/RHEL/CentOS/AlmaLinux）
- root権限またはsudo権限
- エクスポート用のディレクトリまたはファイルシステム
- クライアントからのネットワークアクセス

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- bashシェル
- sudo権限を持つユーザー
- テキストエディタ（nano、vim等）
- ファイアウォール管理ツール（firewalld、ufw等）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `nfs_exports` | NFSエクスポート設定のリスト | なし | はい |
| `nfs_exports[].path` | エクスポートするディレクトリパス | なし | はい |
| `nfs_exports[].mode` | ディレクトリのパーミッション | `'0755'` | いいえ |
| `nfs_exports[].clients` | クライアント設定のリスト | なし | はい |
| `nfs_exports[].clients[].host` | クライアントホスト/ネットワーク | なし | はい |
| `nfs_exports[].clients[].options` | エクスポートオプション | なし | はい |
| `nfs_exports[].clients[].comment` | オプションのコメント | なし | いいえ |

#### 依存関係
なし

#### タグとハンドラー
- タグ: なし
- ハンドラー:
  - `Restart NFS service`: NFSサービスの再起動
  - `Reload NFS export configuration`: エクスポート設定のリロード

#### 使用例

基本的な使用例：
```yaml
- hosts: nfs_servers
  become: true
  vars:
    nfs_exports:
      - path: /export/data
        mode: '0755'
        clients:
          - host: "192.168.1.0/24"
            options: "rw,sync,no_subtree_check"
            comment: "Local network access"
  roles:
    - infrastructure/nfs_server
```

複数のエクスポート設定例：
```yaml
- hosts: storage_servers
  become: true
  vars:
    nfs_exports:
      # ホームディレクトリのエクスポート
      - path: /export/home
        mode: '0755'
        clients:
          - host: "192.168.1.0/24"
            options: "rw,sync,no_subtree_check,no_root_squash"
            comment: "Home directories for local network"
          - host: "10.0.0.0/8"
            options: "rw,sync,no_subtree_check,root_squash"
            comment: "Home directories for internal network"
      
      # 読み取り専用の共有アプリケーション
      - path: /export/apps
        mode: '0755'
        clients:
          - host: "*"
            options: "ro,sync,no_subtree_check"
            comment: "Read-only application share"
      
      # バックアップ用ストレージ
      - path: /export/backup
        mode: '0700'
        clients:
          - host: "backup-server.example.com"
            options: "rw,sync,no_subtree_check,no_root_squash"
            comment: "Backup server exclusive access"
  roles:
    - infrastructure/nfs_server
```

特定ホストへの詳細なアクセス制御例：
```yaml
- hosts: nfs_servers
  become: true
  vars:
    nfs_exports:
      - path: /export/secure
        mode: '0750'
        clients:
          - host: "web-01.example.com"
            options: "rw,sync,no_subtree_check,sec=sys"
          - host: "web-02.example.com"
            options: "rw,sync,no_subtree_check,sec=sys"
          - host: "db-server.example.com"
            options: "ro,sync,no_subtree_check"
            comment: "Database server - read only"
  roles:
    - infrastructure/nfs_server
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# 現在のエクスポート状況確認
showmount -e localhost

# ディスク容量の確認
df -h

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

#### ステップ3: エクスポートディレクトリの作成

```bash
# 単一のエクスポートディレクトリ
sudo mkdir -p /export/data
sudo chmod 755 /export/data

# 複数のエクスポートディレクトリ
for dir in /export/home /export/apps /export/backup; do
    sudo mkdir -p "$dir"
    sudo chmod 755 "$dir"
done

# 特定の権限設定
sudo chmod 700 /export/backup
sudo chown backup:backup /export/backup
```

#### ステップ4: /etc/exportsファイルの設定

```bash
# exportsファイルのバックアップ
sudo cp /etc/exports /etc/exports.backup

# 基本的なエクスポート設定
echo "/export/data 192.168.1.0/24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports

# 複数のエクスポート設定
cat << 'EOF' | sudo tee /etc/exports
# NFS Export Configuration
# Format: directory host(options)

# Home directories
/export/home 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
/export/home 10.0.0.0/8(rw,sync,no_subtree_check,root_squash)

# Read-only application share
/export/apps *(ro,sync,no_subtree_check)

# Backup storage - restricted access
/export/backup backup-server.example.com(rw,sync,no_subtree_check,no_root_squash)
EOF

# 設定の確認
sudo exportfs -v
```

#### ステップ5: ファイアウォールの設定

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

#### ステップ6: NFSサービスの起動とエクスポートの適用

```bash
# エクスポート設定を適用
sudo exportfs -ra

# エクスポートの確認
sudo exportfs -v
showmount -e localhost

# サービスの再起動（必要な場合）
# Debian/Ubuntu
sudo systemctl restart nfs-kernel-server

# RHEL/CentOS
sudo systemctl restart nfs-server
```

## 運用管理

### 基本操作

エクスポート状態の確認：
```bash
# 現在のエクスポート一覧
sudo exportfs -v

# クライアントから見えるエクスポート
showmount -e nfs-server

# アクティブな接続の確認
sudo showmount -a
```

エクスポートの動的管理：
```bash
# 新しいエクスポートを追加（一時的）
sudo exportfs -o rw,sync,no_subtree_check 192.168.1.100:/export/temp

# エクスポートを削除
sudo exportfs -u 192.168.1.100:/export/temp

# すべてのエクスポートを再読み込み
sudo exportfs -ra

# すべてのエクスポートを解除
sudo exportfs -ua
```

### ログとモニタリング

```bash
# NFSサーバーのログ
sudo journalctl -u nfs-server -f    # RHEL/CentOS
sudo journalctl -u nfs-kernel-server -f  # Debian/Ubuntu

# RPC関連のログ
sudo journalctl -u rpcbind -f

# カーネルのNFSメッセージ
sudo dmesg | grep -i nfs
```

パフォーマンス監視：
```bash
# NFSサーバー統計
nfsstat -s

# 接続しているクライアント
sudo netstat -an | grep 2049

# I/O統計
nfsiostat
```

### トラブルシューティング

#### 診断フロー

1. サービス状態の確認
   ```bash
   sudo systemctl status nfs-server rpcbind
   sudo rpcinfo -p
   ```

2. エクスポート設定の検証
   ```bash
   sudo exportfs -v
   sudo showmount -e localhost
   ```

3. ファイアウォールの確認
   ```bash
   sudo ss -tlnp | grep -E '(2049|111)'
   sudo iptables -L -n | grep -E '(2049|111)'
   ```

#### よくある問題と対処方法

- **問題**: "exportfs: Failed to stat /export/data: No such file or directory"
  - **対処**: エクスポートディレクトリが存在することを確認

- **問題**: クライアントから接続できない
  - **対処**: ファイアウォール設定とネットワーク到達性を確認

- **問題**: "Permission denied"エラー
  - **対処**: エクスポートオプションとディレクトリ権限を確認

### メンテナンス

エクスポート設定の最適化：
```bash
# キャッシュサイズの調整
echo 262144 | sudo tee /proc/sys/net/core/rmem_default
echo 262144 | sudo tee /proc/sys/net/core/wmem_default

# NFSスレッド数の調整
sudo sed -i 's/RPCNFSDCOUNT=.*/RPCNFSDCOUNT=16/' /etc/sysconfig/nfs
```

定期的なメンテナンス：
```bash
# 古いロックファイルのクリーンアップ
sudo systemctl restart nfs-lock

# エクスポート設定の検証
sudo exportfs -ra && echo "Export configuration is valid"
```

## アンインストール（手動）

NFSサーバーを削除する手順：

```bash
# 1. すべてのエクスポートを解除
sudo exportfs -ua

# 2. NFSサービスを停止
# Debian/Ubuntu
sudo systemctl stop nfs-kernel-server
sudo systemctl disable nfs-kernel-server

# RHEL/CentOS
sudo systemctl stop nfs-server
sudo systemctl disable nfs-server

# 3. エクスポート設定を削除
sudo mv /etc/exports /etc/exports.removed
sudo touch /etc/exports

# 4. NFSパッケージを削除（オプション）
# Debian/Ubuntu
sudo apt-get remove --purge nfs-kernel-server

# RHEL/CentOS
sudo yum remove nfs-utils

# 5. エクスポートディレクトリを削除（注意：データも削除される）
sudo rm -rf /export

# 6. ファイアウォールルールを削除
sudo firewall-cmd --permanent --remove-service=nfs
sudo firewall-cmd --permanent --remove-service=rpc-bind
sudo firewall-cmd --permanent --remove-service=mountd
sudo firewall-cmd --reload
```

## 注意事項

- `no_root_squash`オプションはセキュリティリスクがあるため、信頼できるホストのみに使用してください
- エクスポートパスは絶対パスで指定する必要があります
- NFSv4を使用する場合は、擬似ファイルシステムのルートを設定する必要があります
- パフォーマンスを重視する場合は`async`オプションを検討しますが、データ整合性のリスクがあります
- 定期的にエクスポート設定とアクセスログを監査してください