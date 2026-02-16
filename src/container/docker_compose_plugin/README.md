# docker_compose_plugin

Docker Compose Plugin インストールロール

## 概要

### このドキュメントの目的
このロールは、Debian系ディストリビューションにDockerリポジトリから`docker-compose-plugin`をインストールする。Dockerリポジトリの追加（GPGキー・ソースリスト）とパッケージインストールを自動化する。

### 実現される機能
- Dockerリポジトリの追加（GPGキー取得・ソースリスト設定）
- `docker-compose-plugin`のインストール

## 要件と前提条件

### 共通要件
- サポートされるOS：
  - Debian 11以降
  - Ubuntu 20.04以降
- インターネット接続（Dockerリポジトリへのアクセス用）
- RHEL系ディストリビューションには対応していない

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- rootまたはsudo権限

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はない。

#### 依存関係
なし

#### タグとハンドラー
このロールでは特定のタグやハンドラーは使用していない。

#### 使用例

```yaml
- hosts: container_hosts
  become: true
  roles:
    - infrastructure.container.podman
    - infrastructure.container.docker_compose_plugin
```

### 方法2: 手動での設定手順

#### ステップ1: Dockerリポジトリの追加

```bash
DISTRIBUTION_ID="$(grep -oP '(?<=^ID=).+(?=$)' /etc/os-release)" &&
DISTRIBUTION_NAME="" &&
if [ "${DISTRIBUTION_ID}" = "ubuntu" ]; then
  DISTRIBUTION_NAME="ubuntu"
elif [ "${DISTRIBUTION_ID}" = "debian" ]; then
  DISTRIBUTION_NAME="debian"
else
  echo "Error: Could not confirm that the OS is Ubuntu or Debian."
fi &&
sudo apt-get install -U -y ca-certificates &&
wget -4 -O - "https://download.docker.com/linux/${DISTRIBUTION_NAME}/gpg" | \
  sudo tee /etc/apt/keyrings/docker.asc > /dev/null &&
sudo tee "/etc/apt/sources.list.d/docker.sources" > /dev/null << EOF
Types: deb
URIs: https://download.docker.com/linux/${DISTRIBUTION_NAME}
Suites: $(grep -oP '(?<=^VERSION_CODENAME=).+(?=$)' /etc/os-release)
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
Architectures: $(dpkg --print-architecture)
EOF
```

#### ステップ2: docker-compose-pluginのインストール

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends docker-compose-plugin
```

#### ステップ3: インストールの確認

```bash
docker compose version
```

## アンインストール（手動）

```bash
# docker-compose-pluginを削除
sudo apt-get remove --purge -y docker-compose-plugin

# Dockerリポジトリを削除
sudo rm -f /etc/apt/sources.list.d/docker.sources
sudo rm -f /etc/apt/keyrings/docker.asc
```
