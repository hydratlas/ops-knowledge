# Portainer Agentのインストール・実行

Portainer Agentは、リモートホストのコンテナ環境をPortainerのメインインスタンスから管理するためのエージェントプログラムです。これにより、複数のDockerホストを一元的に管理でき、分散環境でのコンテナ運用を効率化できます。
## Podman（Quadletでサービス化）の場合
### 環境別の準備
#### rootユーザーで実行する場合（sudoを含む）
- 前提
  - ソケットの有効化

以下のコマンドを実行。
```bash
SOCKET='/run/podman/podman.sock' &&
SECURITYLABELDISABLE=''
```

#### 非rootユーザーで実行する場合
- 前提
  - ソケットの有効化（ユーザーごとの設定）
  - linger（居残り）の有効化（ユーザーごとの設定）

以下のコマンドを実行。
```bash
SOCKET="${XDG_RUNTIME_DIR}/podman/podman.sock" &&
SECURITYLABELDISABLE='SecurityLabelDisable=true'
```

### 共通の準備
```bash
CONTAINER_FILE=$(cat << EOS
[Container]
Image=docker.io/portainer/agent:latest
ContainerName=portainer_agent
AutoUpdate=registry
LogDriver=journald
${SECURITYLABELDISABLE}

PublishPort=9001:9001
Volume=${SOCKET}:/var/run/docker.sock:Z
Volume=/var/lib/containers/storage/volumes:/var/lib/docker/volumes:Z
Volume=/:/host:Z

[Service]
Restart=on-success

[Install]
WantedBy=default.target
EOS
)
```

### インストール
#### rootユーザーで実行する場合（sudo）
```bash
sudo mkdir -p /etc/containers/systemd &&
sudo tee /etc/containers/systemd/portainer_agent.container <<< "${CONTAINER_FILE}" > /dev/null &&
sudo systemctl daemon-reload &&
sudo systemctl start portainer_agent.service
```

#### 非rootユーザーで実行する場合
```bash
mkdir -p "$HOME/.config/containers/systemd" &&
tee "$HOME/.config/containers/systemd/portainer_agent.container" <<< "${CONTAINER_FILE}" > /dev/null &&
systemctl --user daemon-reload &&
systemctl --user start portainer_agent.service
```

### 確認
#### rootユーザーで実行した場合（sudo）
```bash
sudo systemctl status portainer_agent.service
```

#### 非rootユーザーで実行した場合
```bash
systemctl --user status portainer_agent.service
```

### 停止・削除
#### rootユーザーで実行した場合（sudo）
```bash
sudo systemctl stop portainer_agent.service &&
sudo rm /etc/containers/systemd/portainer_agent.container &&
sudo systemctl daemon-reload
```

#### 非rootユーザーで実行した場合
```bash
systemctl --user stop portainer_agent.service &&
rm "$HOME/.config/containers/systemd/portainer_agent.container" &&
systemctl --user daemon-reload
```

## Docker・Podmanの場合
### rootユーザーで実行する場合（sudoを含む）
#### インストール・自動再起動の有効化・実行
- 前提
  - DockerまたはPodmanのインストール
  - ソケットの有効化（Podmanの場合のみ）（Dockerはデフォルトで有効）
```bash
sudo docker run \
  --detach \
  -p 9001:9001 \
  --name portainer_agent \
  --restart always \
  --volume /var/run/docker.sock:/var/run/docker.sock:Z \
  --volume /var/lib/docker/volumes:/var/lib/docker/volumes:Z
  --volume /:/host \
  docker.io/portainer/agent:latest
```

#### 停止・自動再起動の無効化・削除
```bash
sudo docker stop portainer_agent &&
if ! type podman >/dev/null 2>&1; then
  sudo docker update --restart=no portainer_agent
fi &&
sudo docker rm portainer_agent
```

### 非rootユーザーで実行する場合（Rootful）
#### インストール・自動再起動の有効化・実行
- 前提
  - Dockerのインストール（Podmanは非rootユーザーかつRootfulで実行できない）
```bash
docker run \
  --detach \
  -p 9001:9001 \
  --privileged \
  --name portainer_agent \
  --restart always \
  --volume /var/run/docker.sock:/var/run/docker.sock:Z \
  --volume /var/lib/docker/volumes:/var/lib/docker/volumes:Z
  --volume /:/host \
  docker.io/portainer/agent:latest
```

#### 停止・自動再起動の無効化・削除
```bash
docker stop portainer_agent &&
if ! type podman >/dev/null 2>&1; then
  docker update --restart=no portainer_agent
fi &&
docker rm portainer_agent
```

### 非rootユーザーで実行する場合（Rootless）
#### インストール・自動再起動の有効化・実行
- 前提
  - DockerまたはPodmanのインストール
  - ソケットの有効化（ユーザーごとの設定）（Podmanの場合のみ）（Dockerはデフォルトで有効）
  - linger（居残り）の有効化（ユーザーごとの設定）
```bash
docker run \
  --detach \
  -p 9001:9001 \
  --name portainer_agent \
  --restart always \
  --security-opt label=disable \
  --volume ${XDG_RUNTIME_DIR}/docker.sock:/var/run/docker.sock:Z \
  --volume /var/lib/docker/volumes:/var/lib/docker/volumes:Z
  --volume /:/host \
  docker.io/portainer/agent:latest
```

#### 停止・削除
```bash
docker stop portainer_agent &&
if ! type podman >/dev/null 2>&1; then
  docker update --restart=no portainer_agent
fi &&
docker rm portainer_agent
```
