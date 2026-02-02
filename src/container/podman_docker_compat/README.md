# podman_docker

podman-docker互換性パッケージのインストールと設定を行うロール

## 概要

### このドキュメントの目的
このロールは、既存のDockerコマンドをPodmanで実行できるようにする互換性環境を構築します。Ansible自動設定と手動設定の両方の方法に対応しており、Dockerからの移行をスムーズに行うための環境を提供します。

### 実現される機能
- Dockerコマンドのpodmanへのエイリアス設定
- podman-docker互換性パッケージのインストール
- Docker Hubをデフォルトレジストリとして設定
- Docker関連ツールとの互換性の提供
- 既存のDockerスクリプトの継続利用支援

## 要件と前提条件

### 共通要件
- Podmanが事前にインストールされていること
- サポートされるOS：
  - RHEL/CentOS/AlmaLinux/Rocky Linux 8以降
  - Fedora 33以降
  - Debian 11以降
  - Ubuntu 20.04以降
- `/etc/containers/`ディレクトリへの書き込み権限

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
- 必須: `infrastructure.container.podman`（Podmanのインストール）

#### タグとハンドラー
このroleでは特定のタグやハンドラーは使用していません。

#### 使用例

基本的な使用例：
```yaml
- hosts: container_hosts
  become: true
  roles:
    - infrastructure.container.podman
    - infrastructure.container.podman_docker
```

完全なコンテナ環境構築の例：
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

Podmanのインストール状態を確認します：
```bash
# Podmanの確認
podman --version

# 既存のDockerインストールの確認
which docker || echo "Docker not found (expected)"

# registries.confの存在確認
ls -la /etc/containers/registries.conf
```

#### ステップ2: インストール

**Debian/Ubuntu系の場合：**
```bash
# パッケージリストの更新
sudo apt-get update

# podman-dockerのインストール（推奨パッケージを除外）
sudo apt-get install -y --no-install-recommends podman-docker

# インストールの確認
dpkg -l | grep podman-docker
```

**RHEL/CentOS/AlmaLinux/Rocky Linux系の場合：**
```bash
# podman-dockerのインストール
sudo dnf install -y podman-docker

# インストールの確認
rpm -qa | grep podman-docker
```

**Fedora系の場合：**
```bash
# podman-dockerのインストール
sudo dnf install -y podman-docker

# 追加ツールのインストール（オプション）
sudo dnf install -y podman-compose
```

#### ステップ3: 設定

コンテナレジストリとマーカーファイルの設定を行います：

```bash
# registries.confの設定
# 既存の設定をバックアップ
[ -f /etc/containers/registries.conf ] && \
  sudo cp /etc/containers/registries.conf /etc/containers/registries.conf.bak

# registries.confファイルが存在しない場合は作成
sudo touch /etc/containers/registries.conf

# unqualified-search-registriesの設定を追加または更新
sudo sed -i '/^#*\s*unqualified-search-registries/d' /etc/containers/registries.conf
echo 'unqualified-search-registries = ["docker.io"]' | sudo tee -a /etc/containers/registries.conf

# ファイルの権限を設定
sudo chmod 644 /etc/containers/registries.conf
sudo chown root:root /etc/containers/registries.conf

# nodockerマーカーファイルの作成
sudo touch /etc/containers/nodocker
sudo chmod 644 /etc/containers/nodocker
sudo chown root:root /etc/containers/nodocker
```

#### ステップ4: 起動と有効化

インストールと設定の確認を行います：

```bash
# dockerコマンドの確認
which docker
ls -la /usr/bin/docker

# バージョンの確認
docker --version

# レジストリ設定の確認
grep unqualified-search-registries /etc/containers/registries.conf

# 動作テスト
docker run --rm hello-world
```

## 運用管理

### 基本操作

```bash
# Docker互換コマンドの使用
docker ps
docker images
docker pull nginx
docker run -d --name test-nginx nginx
docker logs test-nginx
docker stop test-nginx
docker rm test-nginx

# Podmanネイティブコマンドとの比較
podman ps
docker ps  # 同じ結果

# aliasの確認
alias | grep docker
```

### ログとモニタリング

```bash
# コンテナログの確認（Docker風）
docker logs <container_name>

# システムイベントの監視
docker events

# システム情報の表示
docker info

# 使用状況の確認
docker system df
```

### トラブルシューティング

#### 診断フロー
1. dockerコマンドの存在確認
2. シンボリックリンクの確認
3. レジストリ設定の確認
4. Podman本体の動作確認

#### よくある問題と対処

**問題**: dockerコマンドが見つからない
```bash
# パッケージの再インストール
sudo apt-get install --reinstall podman-docker  # Debian/Ubuntu
sudo dnf reinstall podman-docker                 # RHEL/CentOS

# 手動でシンボリックリンクを作成
sudo ln -sf /usr/bin/podman /usr/bin/docker
```

**問題**: イメージ名の解決エラー
```bash
# レジストリ設定の確認
cat /etc/containers/registries.conf

# 完全修飾名でのテスト
docker pull docker.io/alpine:latest

# 設定の再適用
echo 'unqualified-search-registries = ["docker.io"]' | \
  sudo tee /etc/containers/registries.conf
```

**問題**: Docker Composeが動作しない
```bash
# podman-composeのインストール
sudo apt-get install -y podman-compose  # Debian/Ubuntu
sudo dnf install -y podman-compose      # RHEL/CentOS

# docker-composeエイリアスの作成
sudo ln -sf /usr/bin/podman-compose /usr/bin/docker-compose
```

### メンテナンス

```bash
# 設定ファイルのバックアップ
sudo tar -czf podman-docker-config-backup.tar.gz \
  /etc/containers/registries.conf \
  /etc/containers/nodocker

# Docker互換性の検証スクリプト
cat > /tmp/check_docker_compat.sh << 'EOF'
#!/bin/bash
echo "=== Docker Compatibility Check ==="
echo "Docker command: $(which docker)"
echo "Docker version: $(docker --version)"
echo ""
echo "Testing basic commands:"
docker pull alpine:latest && echo "✓ Pull: OK" || echo "✗ Pull: Failed"
docker run --rm alpine echo "test" && echo "✓ Run: OK" || echo "✗ Run: Failed"
docker ps && echo "✓ List: OK" || echo "✗ List: Failed"
echo ""
echo "Registry configuration:"
grep unqualified-search-registries /etc/containers/registries.conf
EOF

chmod +x /tmp/check_docker_compat.sh
/tmp/check_docker_compat.sh

# 古いイメージのクリーンアップ（Docker風）
docker image prune -a
docker system prune -a
```

## アンインストール（手動）

以下の手順でpodman-docker互換性環境を削除します：

**Debian/Ubuntu系：**
```bash
# 1. パッケージの削除
sudo apt-get remove --purge -y podman-docker

# 2. 設定ファイルのクリーンアップ
# registries.confから該当行を削除
sudo sed -i '/^unqualified-search-registries.*docker\.io/d' /etc/containers/registries.conf

# 3. マーカーファイルの削除
sudo rm -f /etc/containers/nodocker

# 4. 手動で作成したシンボリックリンクの削除（存在する場合）
[ -L /usr/bin/docker ] && sudo rm -f /usr/bin/docker
[ -L /usr/bin/docker-compose ] && sudo rm -f /usr/bin/docker-compose

# 5. 設定ファイルのバックアップを復元（必要な場合）
[ -f /etc/containers/registries.conf.bak ] && \
  sudo mv /etc/containers/registries.conf.bak /etc/containers/registries.conf
```

**RHEL/CentOS/Fedora系：**
```bash
# 1. パッケージの削除
sudo dnf remove -y podman-docker

# 2. 設定ファイルのクリーンアップ
sudo sed -i '/^unqualified-search-registries.*docker\.io/d' /etc/containers/registries.conf

# 3. マーカーファイルの削除
sudo rm -f /etc/containers/nodocker

# 4. 手動で作成したシンボリックリンクの削除（存在する場合）
[ -L /usr/bin/docker ] && sudo rm -f /usr/bin/docker
[ -L /usr/bin/docker-compose ] && sudo rm -f /usr/bin/docker-compose

# 5. 依存関係のクリーンアップ（オプション）
sudo dnf autoremove -y
```

注意事項:
- podman-dockerパッケージは、`docker`コマンドを`podman`へのシンボリックリンクとして提供します
- 完全なDocker互換性はありませんが、多くの基本的なDockerコマンドが動作します
- Docker Composeを使用する場合は、別途podman-composeのインストールが必要です
- systemdサービスファイルなど、Dockerに依存する設定は手動で調整が必要な場合があります
- Dockerデーモンに依存する機能（docker.sockなど）は利用できません