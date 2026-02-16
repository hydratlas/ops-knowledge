# create_containers_storage_dir

ローカルコンテナストレージディレクトリ作成ロール

## 概要

### このドキュメントの目的
このロールは、Podmanのルートレスコンテナ用ストレージディレクトリ構造を自動的に作成します。Ansible自動設定と手動設定の両方の方法に対応しており、NFS環境でのパフォーマンス問題を回避するためのローカルストレージ構造を提供します。

### 実現される機能
- ローカルbtrfsファイルシステム上（`/home`）へのストレージディレクトリ作成
- Podmanルートレスコンテナに必要な標準ディレクトリ構造の構築
- 適切な所有権（UID/GID）とパーミッション（755）の設定
- 複数ユーザーへの一括適用
- NFS環境でのコンテナパフォーマンスの最適化

## 要件と前提条件

### 共通要件
- ローカルの`/home`ディレクトリが存在すること（推奨: btrfsファイルシステム）
- 対象ユーザーアカウントが事前に作成されていること
- 各ユーザーのUID/GIDが定義されていること

### Ansible固有の要件
- Ansible 2.9以上
- `create_home_dirs`ロールが事前に実行されていること（推奨）
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
| `create_containers_storage_dir.home_base` | `/home` | ローカルホームディレクトリのベースパス |
| `shared_home_users` | `[]` | ユーザー情報のリスト |
| `shared_home_users[].name` | - | ユーザー名（必須） |
| `shared_home_users[].uid` | - | ユーザーID（必須） |
| `shared_home_users[].gid` | - | グループID（必須） |

#### 依存関係
- 推奨: `infrastructure.create_home_dirs`（ユーザーホームディレクトリの事前作成）

#### タグとハンドラー
このroleでは特定のタグやハンドラーは使用していません。

#### 使用例

基本的な使用例：
```yaml
- hosts: container_hosts
  become: true
  vars:
    shared_home_users:
      - { name: alice, uid: 1001, gid: 1001 }
      - { name: bob, uid: 1002, gid: 1002 }
  roles:
    - infrastructure.container.create_containers_storage_dir
```

カスタムパスを使用する例：
```yaml
- hosts: container_hosts
  become: true
  vars:
    create_containers_storage_dir:
      home_base: /home
    shared_home_users:
      - { name: alice, uid: 1001, gid: 1001 }
      - { name: bob, uid: 1002, gid: 1002 }
      - { name: charlie, uid: 1003, gid: 1003 }
  roles:
    - infrastructure.container.create_containers_storage_dir
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

作業を開始する前に、必要な情報を収集し環境変数を設定します：

```bash
# ユーザー情報の確認
id alice
# 出力例: uid=1001(alice) gid=1001(alice) groups=1001(alice)

# 環境変数の設定
USERNAME="alice"
USER_UID="1001"
USER_GID="1001"
HOME_BASE="/home"
```

#### ステップ2: ディレクトリ構造の作成

Podmanルートレスコンテナ用のディレクトリ構造を作成します：

```bash
# 必要なディレクトリを一度に作成
sudo mkdir -p ${HOME_BASE}/${USERNAME}/.local/share/containers/storage

# または、段階的に作成
sudo mkdir -p ${HOME_BASE}/${USERNAME}/.local
sudo mkdir -p ${HOME_BASE}/${USERNAME}/.local/share
sudo mkdir -p ${HOME_BASE}/${USERNAME}/.local/share/containers
sudo mkdir -p ${HOME_BASE}/${USERNAME}/.local/share/containers/storage
```

#### ステップ3: 設定

所有権とパーミッションを設定します：

```bash
# 所有権を再帰的に設定
sudo chown -R ${USER_UID}:${USER_GID} ${HOME_BASE}/${USERNAME}/.local

# パーミッションを設定（ディレクトリのみ755）
find ${HOME_BASE}/${USERNAME}/.local -type d -exec chmod 755 {} \;
```

#### ステップ4: 起動と有効化

ディレクトリ構造が正しく作成されたことを確認します：

```bash
# ディレクトリ構造の確認
tree -pugd ${HOME_BASE}/${USERNAME}/.local

# 期待される出力：
# /home/alice/.local [drwxr-xr-x 1001 1001]
# └── share [drwxr-xr-x 1001 1001]
#     └── containers [drwxr-xr-x 1001 1001]
#         └── storage [drwxr-xr-x 1001 1001]

# Podmanでの動作確認（ユーザーとして実行）
sudo -u ${USERNAME} podman info | grep -E "graphRoot|runRoot"
```

## 運用管理

### 基本操作

```bash
# ストレージディレクトリの使用状況確認
du -sh ${HOME_BASE}/${USERNAME}/.local/share/containers/storage

# ディレクトリの権限確認
ls -la ${HOME_BASE}/${USERNAME}/.local/share/containers/

# 複数ユーザーのストレージ使用量一覧
for user in alice bob charlie; do
    echo -n "$user: "
    du -sh ${HOME_BASE}/$user/.local/share/containers/storage 2>/dev/null || echo "Not found"
done
```

### ログとモニタリング

```bash
# Podmanストレージの使用状況（ユーザーごと）
sudo -u ${USERNAME} podman system df

# ストレージの詳細情報
sudo -u ${USERNAME} podman info --format json | jq '.store.graphRoot'

# iノード使用状況の確認
df -i ${HOME_BASE}
```

### トラブルシューティング

#### 診断フロー
1. ディレクトリの存在確認
2. 所有権とパーミッションの確認
3. ファイルシステムの容量確認
4. SELinuxコンテキストの確認（該当する場合）

#### よくある問題と対処

**問題**: Permission deniedエラー
```bash
# 所有権の修正
sudo chown -R ${USER_UID}:${USER_GID} ${HOME_BASE}/${USERNAME}/.local

# SELinuxコンテキストの修正（RHEL/CentOS）
sudo restorecon -Rv ${HOME_BASE}/${USERNAME}/.local
```

**問題**: ディスク容量不足
```bash
# 容量確認
df -h ${HOME_BASE}

# 不要なイメージの削除
sudo -u ${USERNAME} podman image prune -a
```

**問題**: ディレクトリが作成されない
```bash
# 親ディレクトリの確認
ls -la ${HOME_BASE}/${USERNAME}

# 手動作成とデバッグ
sudo mkdir -pv ${HOME_BASE}/${USERNAME}/.local/share/containers/storage
```

### メンテナンス

```bash
# 定期的なクリーンアップ（ユーザーごと）
sudo -u ${USERNAME} podman system prune -a

# ストレージの完全リセット
# 警告: すべてのコンテナデータが削除されます
sudo -u ${USERNAME} podman system reset

# ディレクトリサイズの監視スクリプト
cat > /tmp/check_container_storage.sh << 'EOF'
#!/bin/bash
THRESHOLD=80  # 使用率の閾値（%）
HOME_BASE="/home"

for userdir in ${HOME_BASE}/*/; do
    if [ -d "${userdir}.local/share/containers/storage" ]; then
        user=$(basename "$userdir")
        usage=$(df --output=pcent "${userdir}" | tail -n 1 | tr -d ' %')
        if [ "$usage" -gt "$THRESHOLD" ]; then
            echo "Warning: User $user storage usage is ${usage}%"
        fi
    fi
done
EOF
chmod +x /tmp/check_container_storage.sh
```

## アンインストール（手動）

以下の手順でコンテナストレージディレクトリを削除します：

```bash
# 1. 環境変数の設定
USERNAME="alice"
HOME_BASE="/home"

# 2. 実行中のコンテナを停止（ユーザーとして実行）
sudo -u ${USERNAME} podman stop -a

# 3. すべてのコンテナを削除
sudo -u ${USERNAME} podman rm -a

# 4. すべてのイメージを削除
sudo -u ${USERNAME} podman rmi -a

# 5. ストレージディレクトリの削除
# 警告: この操作により、すべてのコンテナデータが削除されます
sudo rm -rf ${HOME_BASE}/${USERNAME}/.local/share/containers

# 6. 空のディレクトリの削除（オプション）
# .localディレクトリに他のアプリケーションのデータがない場合のみ
sudo rmdir ${HOME_BASE}/${USERNAME}/.local/share 2>/dev/null || true
sudo rmdir ${HOME_BASE}/${USERNAME}/.local 2>/dev/null || true

# 7. 複数ユーザーの一括削除スクリプト
for user in alice bob charlie; do
    echo "Cleaning up user: $user"
    sudo -u $user podman system reset -f 2>/dev/null || true
    sudo rm -rf ${HOME_BASE}/$user/.local/share/containers
done
```

注意: 
- `.local`ディレクトリには他のアプリケーションのデータが含まれる可能性があるため、削除時は注意が必要です
- 複数ユーザーの設定を削除する場合は、各ユーザーに対して上記の手順を繰り返します