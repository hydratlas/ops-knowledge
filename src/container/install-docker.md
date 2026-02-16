# Dockerのインストール

Docker CEの標準的なインストール手順です。Ubuntu/Debian系およびRHEL系ディストリビューションでの公式リポジトリを使用したインストール方法を説明します。

## リポジトリーの設定
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

## DockerおよびDocker Composeのインストール
### パッケージをインストール
```bash
sudo apt-get install -U -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
- [Install Docker Engine on Ubuntu | Docker Docs](https://docs.docker.com/engine/install/ubuntu/)
- [Install Docker Engine on Debian | Docker Docs](https://docs.docker.com/engine/install/debian/)

### 確認
```bash
sudo systemctl status docker.service

sudo docker version
```

## root以外のユーザーにDockerの実行を許可（Rootful Docker）
### 許可する
#### 現在ログインしているユーザー用
```bash
if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi &&
sudo usermod -aG docker "$USER" &&
newgrp docker
```

#### 現在ログインしていない任意のユーザー用
```bash
if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi &&
sudo usermod -aG docker "<username>"
```

### 【元に戻す】許可を取り消す
#### 現在ログインしているユーザー用
```bash
sudo gpasswd -d "$USER" docker
```
再度ログインした後に反映される。

#### 現在ログインしていない任意のユーザー用
```bash
sudo gpasswd -d "<username>" docker
```
再度ログインした後に反映される。

## 実行
### Dockerコンテナをテスト実行
```bash
docker run docker.io/hello-world:latest
```

### Docker Composeをテスト実行
```bash
cd "$HOME" &&
tee docker-compose.yml << 'EOF' >/dev/null &&
services:
  hello:
    image: docker.io/hello-world:latest
EOF
if type docker-compose >/dev/null 2>&1; then
  docker-compose up
else
  docker compose up
fi
```

## 実行中のコンテナを表示
### rootユーザーで実行中
```bash
sudo docker ps
```

### 現在のユーザーで実行中
```bash
docker ps
```
