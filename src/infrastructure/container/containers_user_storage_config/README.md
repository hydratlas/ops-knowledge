# containers_user_storage_config

Podmanストレージ設定ロール（NFS環境用）

## 概要

### このドキュメントの目的
このロールは、NFSホームディレクトリ環境でPodmanを使用する際のストレージ設定を自動化します。Ansible自動設定と手動設定の両方の方法に対応しており、NFSの性能問題を回避しながらPodmanコンテナを効率的に運用できる環境を構築します。

### 実現される機能
- NFSホームディレクトリ（`/nfs/home`）への設定ファイル配置
- 実際のコンテナストレージ（graphroot）はローカルディスク（`/home`）を使用
- 高速なBtrfsストレージドライバの設定
- 複数ユーザーへの一括設定対応
- 適切なパーミッション設定による安全な運用

## 要件と前提条件

### 共通要件
- NFSのホームディレクトリが`/nfs/home`にマウントされていること
- ローカルの`/home`ディレクトリが存在すること（btrfsファイルシステム）
- Podmanがインストールされていること
- 対象ユーザーアカウントが事前に作成されていること

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要
- 制御ノードから対象ホストへのSSH接続

### 手動設定の要件
- rootまたはsudo権限
- 基本的なLinuxコマンドの知識

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | デフォルト値 | 説明 |
|--------|--------------|------|
| `containers_user_storage_config.home_base` | `/nfs/home` | NFSホームディレクトリのベースパス |
| `containers_user_storage_config.graphroot_home_base` | `/home` | ローカルストレージのベースパス |
| `cluster_user_list` | `[]` | ユーザー情報のリスト |
| `cluster_user_list[].name` | - | ユーザー名（必須） |

#### 依存関係
なし

#### タグとハンドラー
このroleでは特定のタグやハンドラーは使用していません。

#### 使用例

基本的な使用例：
```yaml
- hosts: nfs_home_servers
  become: true
  vars:
    cluster_user_list:
      - { name: alice, uid: 1001, gid: 1001 }
      - { name: bob, uid: 1002, gid: 1002 }
  roles:
    - infrastructure.container.containers_user_storage_config
```

カスタムパスを使用する例：
```yaml
- hosts: nfs_home_servers
  become: true
  vars:
    containers_user_storage_config:
      home_base: /nfs/home
      graphroot_home_base: /home
    cluster_user_list:
      - { name: alice, uid: 1001, gid: 1001 }
      - { name: bob, uid: 1002, gid: 1002 }
  roles:
    - infrastructure.container.containers_user_storage_config
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

作業を開始する前に、環境変数を設定します：

```bash
# ユーザー名を設定
USERNAME="alice"

# パスの設定（必要に応じて変更）
NFS_HOME_BASE="/nfs/home"
LOCAL_HOME_BASE="/home"
```

#### ステップ2: 設定ディレクトリの作成

各ユーザーごとに設定ディレクトリを作成します：

```bash
# .configディレクトリの作成
sudo mkdir -p ${NFS_HOME_BASE}/${USERNAME}/.config/containers

# 所有権の設定
sudo chown -R ${USERNAME}:${USERNAME} ${NFS_HOME_BASE}/${USERNAME}/.config
```

#### ステップ3: 設定

Podmanのストレージ設定ファイルを作成します：

```bash
# storage.confファイルの作成
sudo tee ${NFS_HOME_BASE}/${USERNAME}/.config/containers/storage.conf << EOF
[storage]
driver = "btrfs"
graphroot = "${LOCAL_HOME_BASE}/${USERNAME}/.local/share/containers/storage"
EOF

# ファイルの所有権と権限を設定
sudo chown ${USERNAME}:${USERNAME} ${NFS_HOME_BASE}/${USERNAME}/.config/containers/storage.conf
sudo chmod 644 ${NFS_HOME_BASE}/${USERNAME}/.config/containers/storage.conf
```

#### ステップ4: 起動と有効化

実際のコンテナストレージが配置されるローカルディレクトリを準備します：

```bash
# ローカルストレージディレクトリの作成（ユーザー自身で実行）
sudo -u ${USERNAME} mkdir -p ${LOCAL_HOME_BASE}/${USERNAME}/.local/share/containers/storage

# 設定の確認
cat ${NFS_HOME_BASE}/${USERNAME}/.config/containers/storage.conf

# 期待される出力：
# [storage]
# driver = "btrfs"
# graphroot = "/home/alice/.local/share/containers/storage"
```

## 運用管理

### 基本操作

```bash
# 設定ファイルの確認
cat /nfs/home/${USERNAME}/.config/containers/storage.conf

# ストレージの使用状況確認
du -sh /home/${USERNAME}/.local/share/containers/storage

# Podmanの設定確認（ユーザーとして実行）
sudo -u ${USERNAME} podman info | grep -A 5 "graphRoot"
```

### ログとモニタリング

```bash
# Podmanのストレージ情報を確認
sudo -u ${USERNAME} podman system df

# ストレージの詳細情報
sudo -u ${USERNAME} podman info --format json | jq '.store'
```

### トラブルシューティング

#### 診断フロー
1. storage.confファイルの存在と内容を確認
2. ローカルストレージディレクトリの存在と権限を確認
3. btrfsファイルシステムの確認
4. Podman infoでストレージ設定を確認

#### よくある問題と対処

**問題**: コンテナイメージのpullが遅い
```bash
# NFSではなくローカルストレージが使用されているか確認
sudo -u ${USERNAME} podman info | grep graphRoot
# 出力が/home/${USERNAME}/...であることを確認
```

**問題**: Permission deniedエラー
```bash
# 権限の修正
sudo chown -R ${USERNAME}:${USERNAME} ${NFS_HOME_BASE}/${USERNAME}/.config/containers
sudo chown -R ${USERNAME}:${USERNAME} ${LOCAL_HOME_BASE}/${USERNAME}/.local/share/containers
```

**問題**: btrfsドライバーエラー
```bash
# ファイルシステムの確認
mount | grep "/home"
# btrfsであることを確認、異なる場合はstorage.confのdriverを変更
```

### メンテナンス

```bash
# 不要なイメージの削除
sudo -u ${USERNAME} podman image prune -a

# ストレージのクリーンアップ
sudo -u ${USERNAME} podman system prune -a

# ストレージの完全リセット（注意：すべてのコンテナデータが削除されます）
sudo -u ${USERNAME} podman system reset
```

## アンインストール（手動）

以下の手順でPodmanストレージ設定を削除します：

```bash
# 1. 実行中のコンテナを停止
sudo -u ${USERNAME} podman stop -a

# 2. すべてのコンテナを削除
sudo -u ${USERNAME} podman rm -a

# 3. すべてのイメージを削除
sudo -u ${USERNAME} podman rmi -a

# 4. ストレージ設定ファイルの削除
sudo rm -f ${NFS_HOME_BASE}/${USERNAME}/.config/containers/storage.conf

# 5. ローカルストレージディレクトリの削除
# 警告: この操作により、すべてのコンテナデータが削除されます
sudo rm -rf ${LOCAL_HOME_BASE}/${USERNAME}/.local/share/containers

# 6. 空のディレクトリの削除（オプション）
sudo rmdir ${NFS_HOME_BASE}/${USERNAME}/.config/containers 2>/dev/null || true
sudo rmdir ${NFS_HOME_BASE}/${USERNAME}/.config 2>/dev/null || true
```

注意: 複数ユーザーの設定を削除する場合は、各ユーザーに対して上記の手順を繰り返します。