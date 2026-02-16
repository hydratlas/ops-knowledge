# create_home_dirs

ローカルホームディレクトリ作成ロール（Podman用）

## 概要

### このドキュメントの目的
このロールは、NFSマウントされたホームディレクトリ（`/nfs/home`）とは別に、ローカルのbtrfsファイルシステム上に`/home`ディレクトリを作成します。Ansible自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- ローカル `/home` ディレクトリの作成（権限: 755）
- 各ユーザーのローカルホームディレクトリの作成（権限: 700）
- Podmanストレージ用の適切な所有権設定
- NFSストレージとは独立したローカルコンテナストレージの確保

## 要件と前提条件

### 共通要件
- ローカルファイルシステム（btrfs推奨）
- NFSホームディレクトリが別パス（通常は`/nfs/home`）にマウントされていること
- root権限またはsudo権限
- UID/GIDは既存のLDAP/IDMユーザーと一致させる必要がある

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- bashシェル
- sudo権限を持つユーザー
- 基本的なLinuxコマンド（mkdir、chmod、chown）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `create_home_dirs.home_base` | ローカルホームディレクトリのベースパス | `/home` | いいえ |
| `cluster_user_list` | ユーザー情報のリスト | `[]` | はい |
| `cluster_user_list[].name` | ユーザー名 | - | はい |
| `cluster_user_list[].uid` | ユーザーID | - | はい |
| `cluster_user_list[].gid` | グループID | - | はい |

#### 依存関係
なし

#### タグとハンドラー
- タグ: なし
- ハンドラー: なし

#### 使用例

基本的な使用例：
```yaml
- hosts: computes
  become: true
  vars:
    create_home_dirs:
      home_base: /home
    cluster_user_list:
      - { name: alice, uid: 1001, gid: 1001 }
      - { name: bob, uid: 1002, gid: 1002 }
  roles:
    - infrastructure/create_home_dirs
```

カスタムベースパスを使用する例：
```yaml
- hosts: container_hosts
  become: true
  vars:
    create_home_dirs:
      home_base: /local/home
    cluster_user_list:
      - { name: container_user, uid: 2001, gid: 2001 }
  roles:
    - infrastructure/create_home_dirs
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# 作業前の確認
mount | grep -E "(^| )/home( |$)"
ls -la /home 2>/dev/null || echo "/home does not exist"
```

#### ステップ2: ホームディレクトリのベースを作成

```bash
# /homeディレクトリの作成（通常は既に存在）
sudo mkdir -p /home
sudo chmod 755 /home
sudo chown root:root /home
```

#### ステップ3: 各ユーザーのホームディレクトリを作成

個別作成の場合：
```bash
# ユーザー alice (UID: 1001, GID: 1001) の例
sudo mkdir -p /home/alice
sudo chown 1001:1001 /home/alice
sudo chmod 700 /home/alice

# ユーザー bob (UID: 1002, GID: 1002) の例
sudo mkdir -p /home/bob
sudo chown 1002:1002 /home/bob
sudo chmod 700 /home/bob
```

複数ユーザーを一括処理する場合：
```bash
# ユーザーリストを定義（名前:UID:GID形式）
cat > /tmp/cluster_user_list.txt << 'EOF'
alice:1001:1001
bob:1002:1002
carol:1003:1003
EOF

# 一括でホームディレクトリを作成
while IFS=: read -r username uid gid; do
    sudo mkdir -p "/home/${username}"
    sudo chown "${uid}:${gid}" "/home/${username}"
    sudo chmod 700 "/home/${username}"
    echo "Created home directory for ${username}"
done < /tmp/cluster_user_list.txt

# 一時ファイルを削除
rm /tmp/cluster_user_list.txt
```

#### ステップ4: 作成したディレクトリの確認

```bash
# ディレクトリ一覧と権限を確認
ls -la /home/

# 特定ユーザーのディレクトリ情報を確認
stat /home/alice
```

## 運用管理

### 基本操作

ユーザーの追加：
```bash
# 新規ユーザーのホームディレクトリ作成
sudo mkdir -p /home/newuser
sudo chown 1004:1004 /home/newuser
sudo chmod 700 /home/newuser
```

### ログとモニタリング

```bash
# ディスク使用量の確認
du -sh /home/*

# inode使用量の確認
df -i /home

# Podmanストレージの使用状況確認（ユーザーとして実行）
su - alice -c "podman system df"
```

### トラブルシューティング

#### 診断フロー

1. ディレクトリの存在確認
   ```bash
   ls -la /home/username
   ```

2. 権限確認
   ```bash
   stat /home/username
   namei -l /home/username
   ```

3. ファイルシステムの確認
   ```bash
   df -h /home
   mount | grep "/home"
   ```

#### よくある問題と対処方法

- **問題**: Podmanがストレージエラーを出す
  - **対処**: ホームディレクトリの権限を確認（700である必要）
  
- **問題**: ディレクトリが作成できない
  - **対処**: ディスク容量とinode容量を確認

### メンテナンス

定期的なクリーンアップ：
```bash
# 未使用のPodmanイメージを削除（各ユーザーで実行）
for user in alice bob carol; do
    su - $user -c "podman image prune -af"
done

# ディスク使用量の監視
du -sh /home/* | sort -rh | head -20
```

## アンインストール（手動）

```bash
# 警告: この操作は破壊的です。必要なデータをバックアップしてください。

# 特定ユーザーのローカルホームディレクトリを削除
sudo rm -rf /home/username

# すべてのローカルホームディレクトリを削除（危険）
# sudo rm -rf /home/*

# 注意: /homeディレクトリ自体は通常システムで使用されるため削除しません
```

**注意**: 
- このロールは主にPodmanのローカルストレージ用にホームディレクトリを作成します
- NFSマウントされたホームディレクトリ（通常は `/nfs/home`）とは別に管理されます
- 削除前に必ずPodmanコンテナとイメージをクリーンアップしてください