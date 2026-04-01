# podman

Podmanコンテナランタイムインストールロール

## 概要

### このドキュメントの目的
このロールは、Podmanコンテナランタイムのインストールを自動化します。Ansible自動設定と手動設定の両方の方法に対応しており、RHELベースとDebianベースの両方のディストリビューションで一貫したコンテナ環境を構築します。

### 実現される機能
- OSファミリーに応じた適切なパッケージマネージャーの自動選択
- Podmanコンテナランタイムのインストール
- Docker互換のコンテナ実行環境の提供
- ルートレスコンテナのサポート
- OCI準拠のコンテナ管理機能

## 要件と前提条件

### 共通要件
- サポートされるOS：
  - RHEL/CentOS/AlmaLinux/Rocky Linux 8以降
  - Fedora 33以降
  - Debian 11以降
  - Ubuntu 20.04以降
- インターネット接続（パッケージダウンロード用）

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
このロールには設定可能な変数はありません。OSファミリーに基づいて自動的にパッケージマネージャーを選択します。

#### 依存関係
なし

#### タグとハンドラー
このroleでは特定のタグやハンドラーは使用していません。

#### 使用例

基本的な使用例：
```yaml
- hosts: container_hosts
  become: true
  roles:
    - infrastructure.container.podman
```

複数のコンテナ関連ロールと組み合わせる例：
```yaml
- hosts: container_hosts
  become: true
  roles:
    - infrastructure.container.podman
    - infrastructure.container.podman_docker
    - infrastructure.container.podman_auto_update
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

OSの種類を確認します：
```bash
# OSの確認
cat /etc/os-release | grep -E "^(ID|VERSION_ID)="

# カーネルバージョンの確認（コンテナサポート確認用）
uname -r
```

#### ステップ2: インストール

##### Debian/Ubuntu系でのインストール
```bash
# パッケージリストを更新
sudo apt-get update

# Podmanをインストール（推奨パッケージは除外）
sudo apt-get install -y --no-install-recommends podman containers-storage uidmap slirp4netns passt aardvark-dns nftables
```

##### RHEL/CentOS/AlmaLinux/Rocky Linux系でのインストール
```bash
# Podmanをインストール
sudo dnf install -y podman podman-compose containers-storage
```

#### ステップ3: 設定

基本的な設定の確認と調整：
```bash
# レジストリの設定を確認
sudo cat /etc/containers/registries.conf

# 必要に応じてレジストリを追加
echo -e "[registries.search]\nregistries = ['docker.io', 'quay.io']" | \
  sudo tee -a /etc/containers/registries.conf

# ストレージ設定を確認
sudo cat /etc/containers/storage.conf
```

#### ステップ4: 起動と有効化

インストールの確認：
```bash
# Podmanのバージョンを確認
podman version

# システム情報を表示
podman info

# テストコンテナを実行
podman run docker.io/hello-world:latest

# ユーザー権限でのテスト（ルートレス）
podman run --rm docker.io/alpine:latest cat /etc/os-release
```

## 運用管理

### 基本操作

```bash
# 実行中のコンテナ一覧
podman ps

# すべてのコンテナ一覧（停止中も含む）
podman ps -a

# イメージ一覧
podman images

# システム情報
podman info

# ヘルプの表示
podman --help
podman run --help
```

### ログとモニタリング

```bash
# Podmanのシステムイベントを監視
podman events

# コンテナのログ確認
podman logs <container_name_or_id>

# リアルタイムでログを確認
podman logs -f <container_name_or_id>

# システムジャーナルでPodman関連ログを確認
journalctl -u podman
```

### トラブルシューティング

#### 診断フロー
1. Podmanのインストール状態確認
2. 設定ファイルの確認
3. ストレージとネットワークの状態確認
4. SELinuxやAppArmorの状態確認

#### よくある問題と対処

**問題**: コンテナイメージのpullができない
```bash
# DNS設定の確認
cat /etc/resolv.conf

# レジストリへの接続確認
podman pull docker.io/alpine:latest --log-level=debug

# プロキシ設定の確認
env | grep -i proxy
```

**問題**: ルートレスモードでのエラー
```bash
# subuidsとsubgidsの確認
grep $USER /etc/subuid /etc/subgid

# 必要に応じて追加
sudo usermod --add-subuids 100000-165535 $USER
sudo usermod --add-subgids 100000-165535 $USER
```

**問題**: ストレージ容量不足
```bash
# ストレージ使用状況の確認
podman system df

# 不要なデータの削除
podman system prune -a
```

### メンテナンス

```bash
# Podmanのアップデート（Debian/Ubuntu）
sudo apt-get update && sudo apt-get upgrade podman

# Podmanのアップデート（RHEL/CentOS）
sudo dnf update podman

# 不要なイメージとコンテナの削除
podman system prune -a --volumes

# キャッシュのクリア
podman system reset

# 設定のバックアップ
sudo tar -czf podman-config-backup.tar.gz /etc/containers/
```

## アンインストール（手動）

以下の手順でPodmanを完全に削除します：

**Debian/Ubuntu系：**
```bash
# 1. 実行中のコンテナをすべて停止
podman stop -a

# 2. すべてのコンテナを削除
podman rm -a

# 3. すべてのイメージを削除
podman rmi -a

# 4. Podmanのアンインストール
sudo apt-get remove --purge -y podman containers-storage uidmap slirp4netns passt aardvark-dns nftables

# 5. 設定ファイルの削除
sudo rm -rf /etc/containers
sudo rm -rf /var/lib/containers

# 6. ユーザーデータの削除（各ユーザーで実行）
rm -rf ~/.local/share/containers
rm -rf ~/.config/containers
```

**RHEL/CentOS/Fedora系：**
```bash
# 1. 実行中のコンテナをすべて停止
podman stop -a

# 2. すべてのコンテナを削除
podman rm -a

# 3. すべてのイメージを削除
podman rmi -a

# 4. Podmanのアンインストール
sudo dnf remove -y podman podman-compose

# 5. 設定ファイルの削除
sudo rm -rf /etc/containers
sudo rm -rf /var/lib/containers

# 6. ユーザーデータの削除（各ユーザーで実行）
rm -rf ~/.local/share/containers
rm -rf ~/.config/containers

# 7. 依存関係のクリーンアップ（オプション）
sudo dnf autoremove -y
```

注意: 
- アンインストール前に重要なコンテナやイメージのバックアップを取ることを推奨します
- 他のアプリケーションがcontainersディレクトリを使用している可能性があるため、削除時は注意が必要です