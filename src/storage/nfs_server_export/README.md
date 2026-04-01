# nfs_server_export

NFSエクスポートディレクトリ作成・エクスポート設定管理ロール

## 概要

### このドキュメントの目的
このロールは、NFSサーバーのエクスポートディレクトリの作成と`/etc/exports`ファイルの管理を行います。エクスポートディレクトリの存在確認・作成、`/etc/exports`のテンプレート生成を自動化します。NFSサーバーパッケージのインストールやサービスの有効化は含まれません（`nfs_server_install`ロールで管理）。Ansible自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- エクスポートディレクトリの作成と権限設定（既存のディレクトリはスキップ）
- `/etc/exports`ファイルの自動生成と管理
- エクスポート設定の動的リロード
- 明示的なクライアントリスト、Ansibleインベントリのホストグループに基づく動的クライアント定義、グループごとの個別オプション設定、追加クライアントの指定に対応

## 要件と前提条件

### 共通要件
- Linux OS（Debian/Ubuntu/RHEL/CentOS/AlmaLinux）
- root権限またはsudo権限
- NFSサーバーパッケージがインストール済みであること（`nfs_server_install`ロールを事前に適用）
- エクスポート用のディレクトリまたはファイルシステム

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- bashシェル
- sudo権限を持つユーザー
- テキストエディタ（nano、vim等）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `nfs_exports` | NFSエクスポート設定のリスト | なし | はい |
| `nfs_exports[].path` | エクスポートするディレクトリパス | なし | はい |
| `nfs_exports[].mode` | ディレクトリのパーミッション | `'0755'` | いいえ |
| `nfs_exports[].options` | デフォルトのエクスポートオプション（`client_groups`等で使用） | なし | いいえ |
| `nfs_exports[].clients` | 明示的なクライアント設定のリスト | なし | いいえ |
| `nfs_exports[].clients[].host` | クライアントホスト/ネットワーク | なし | はい |
| `nfs_exports[].clients[].options` | エクスポートオプション（未指定時は`nfs_exports[].options`を使用） | なし | いいえ |
| `nfs_exports[].clients[].comment` | オプションのコメント | なし | いいえ |
| `nfs_exports[].client_groups` | Ansibleインベントリのグループ名リスト（グループ内ホストを動的にクライアントとして追加） | なし | いいえ |
| `nfs_exports[].client_groups_with_options` | グループごとに異なるオプションを指定するリスト | なし | いいえ |
| `nfs_exports[].client_groups_with_options[].group` | Ansibleインベントリのグループ名 | なし | はい |
| `nfs_exports[].client_groups_with_options[].options` | そのグループに適用するエクスポートオプション | なし | はい |
| `nfs_exports[].extra_clients` | 追加クライアント設定のリスト（グループに属さないホスト用） | なし | いいえ |
| `nfs_exports[].extra_clients[].host` | クライアントホスト/ネットワーク | なし | はい |
| `nfs_exports[].extra_clients[].options` | エクスポートオプション（未指定時は`nfs_exports[].options`を使用） | なし | いいえ |
| `nfs_exports[].extra_clients[].comment` | オプションのコメント | なし | いいえ |

#### 依存関係
- `storage/nfs_server_install`: NFSサーバーパッケージのインストールとサービスの有効化を行うロール。本ロールの適用前に実行する必要があります。

#### タグとハンドラー
- タグ: なし
- ハンドラー:
  - `Restart NFS service`: NFSサービスの再起動
  - `Reload NFS export configuration`: エクスポート設定のリロード（`exportfs -rv`）

#### 使用例

基本的な使用例（明示的なクライアントリスト）：
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
    - storage/nfs_server_install
    - storage/nfs_server_export
```

Ansibleインベントリグループを使用した動的クライアント定義：
```yaml
- hosts: nfs_servers
  become: true
  vars:
    nfs_exports:
      - path: /export/home
        mode: '0755'
        options: "rw,sync,no_subtree_check,no_root_squash"
        client_groups:
          - slurm_nodes
          - login_nodes
  roles:
    - storage/nfs_server_install
    - storage/nfs_server_export
```

グループごとに異なるオプションを適用する例：
```yaml
- hosts: nfs_servers
  become: true
  vars:
    nfs_exports:
      - path: /export/home
        mode: '0755'
        client_groups_with_options:
          - group: slurm_nodes
            options: "rw,sync,no_subtree_check,no_root_squash"
          - group: login_nodes
            options: "rw,sync,no_subtree_check,root_squash"
        extra_clients:
          - host: "monitoring.example.com"
            options: "ro,sync,no_subtree_check"
            comment: "Monitoring server - read only"
  roles:
    - storage/nfs_server_install
    - storage/nfs_server_export
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
    - storage/nfs_server_install
    - storage/nfs_server_export
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

NFSサーバーパッケージがインストール済みであることを確認してください。未インストールの場合は`nfs_server_install`ロールのREADMEを参照してください。

```bash
# NFSサービスの状態確認
sudo systemctl status nfs-server       # RHEL/CentOS
sudo systemctl status nfs-kernel-server  # Debian/Ubuntu

# 現在のエクスポート状況確認
showmount -e localhost

# ディスク容量の確認
df -h
```

#### ステップ2: エクスポートディレクトリの作成

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

#### ステップ3: /etc/exportsファイルの設定

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

#### ステップ4: エクスポートの適用

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

### エクスポート管理

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

### トラブルシューティング

#### 診断フロー

1. エクスポート設定の検証
   ```bash
   sudo exportfs -v
   sudo showmount -e localhost
   ```

2. NFSサービスの状態確認
   ```bash
   sudo systemctl status nfs-server rpcbind
   sudo rpcinfo -p
   ```

3. エクスポートの再読み込み
   ```bash
   sudo exportfs -ra && echo "Export configuration is valid"
   ```

#### よくある問題と対処方法

- **問題**: "exportfs: Failed to stat /export/data: No such file or directory"
  - **対処**: エクスポートディレクトリが存在することを確認してください

- **問題**: "Permission denied"エラー
  - **対処**: エクスポートオプションとディレクトリ権限を確認してください

- **問題**: `/etc/exports`の変更が反映されない
  - **対処**: `sudo exportfs -ra`を実行してエクスポート設定を再読み込みしてください

- **問題**: Ansibleインベントリグループのホストがエクスポートに含まれない
  - **対処**: 対象ホストの`ansible_host`変数が定義されていることを確認してください。`client_groups`による動的クライアント定義では、`ansible_host`が未定義のホストはスキップされます

## アンインストール（手動）

エクスポート設定を削除する手順（NFSサーバー自体は残します）：

```bash
# 1. すべてのエクスポートを解除
sudo exportfs -ua

# 2. エクスポート設定を削除
sudo mv /etc/exports /etc/exports.removed
sudo touch /etc/exports

# 3. エクスポート設定を再読み込み（空の状態を適用）
sudo exportfs -ra

# 4. エクスポートディレクトリを削除（注意：データも削除される）
sudo rm -rf /export
```

## 注意事項

- `no_root_squash`オプションはセキュリティリスクがあるため、信頼できるホストのみに使用してください
- エクスポートパスは絶対パスで指定する必要があります
- NFSv4を使用する場合は、擬似ファイルシステムのルートを設定する必要があります
- パフォーマンスを重視する場合は`async`オプションを検討しますが、データ整合性のリスクがあります
- 定期的にエクスポート設定とアクセスログを監査してください
- ZFSマウントポイントなど既存のディレクトリはディレクトリ作成をスキップするため、事前にマウントポイントを準備しておくこと
- `client_groups`を使用する場合、対象ホストに`ansible_host`変数が定義されている必要があります
- 本ロールは`/etc/exports`ファイルを完全に上書きするため、手動で追加した設定は`nfs_exports`変数に含めてください
