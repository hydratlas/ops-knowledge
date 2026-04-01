# Portainer CEのインストール・実行

Portainer CEは、DockerやKubernetesなどのコンテナ環境を管理するためのWeb UIベースの管理ツールです。直感的なインターフェースを通じて、コンテナ、イメージ、ボリューム、ネットワークなどを簡単に管理でき、コマンドラインに不慣れなユーザーでもコンテナ運用が可能になります。
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
Image=docker.io/portainer/portainer-ce:latest
ContainerName=portainer
AutoUpdate=registry
LogDriver=journald
${SECURITYLABELDISABLE}

PublishPort=9443:9443
Volume=${SOCKET}:/var/run/docker.sock:Z
Volume=portainer_data:/data:Z

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
sudo tee /etc/containers/systemd/portainer.container <<< "${CONTAINER_FILE}" > /dev/null &&
sudo systemctl daemon-reload &&
sudo systemctl start portainer.service
```
一般的には`systemctl enable`で常時起動設定を有効化し（`systemctl disable`で無効化）、`systemctl start`で起動させる（`systemctl stop`で停止）。しかし、Quadletでは`systemctl enable`は使えない（[podman-systemd.unit — Podman documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)）。`.container`ファイルを作って`systemctl daemon-reload`を実行すると常時起動設定が有効になり、`.container`ファイルを削除して`systemctl daemon-reload`を実行すると常時起動設定が無効になる。

#### 非rootユーザーで実行する場合
```bash
mkdir -p "$HOME/.config/containers/systemd" &&
tee "$HOME/.config/containers/systemd/portainer.container" <<< "${CONTAINER_FILE}" > /dev/null &&
systemctl --user daemon-reload &&
systemctl --user start portainer.service
```

### 確認
#### rootユーザーで実行した場合（sudo）
```bash
sudo systemctl status portainer.service
```

#### 非rootユーザーで実行した場合
```bash
systemctl --user status portainer.service
```

### 停止・削除
#### rootユーザーで実行した場合（sudo）
```bash
sudo systemctl stop portainer.service &&
sudo rm /etc/containers/systemd/portainer.container &&
sudo systemctl daemon-reload
```

#### 非rootユーザーで実行した場合
```bash
systemctl --user stop portainer.service &&
rm "$HOME/.config/containers/systemd/portainer.container" &&
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
  -p 9443:9443 \
  --privileged \
  --name portainer \
  --restart always \
  --volume /var/run/docker.sock:/var/run/docker.sock:Z \
  --volume portainer_data:/data:Z \
  docker.io/portainer/portainer-ce:latest
```

#### 停止・自動再起動の無効化・削除
```bash
sudo docker stop portainer &&
if ! type podman >/dev/null 2>&1; then
  sudo docker update --restart=no portainer
fi &&
sudo docker rm portainer
```

### 非rootユーザーで実行する場合（Rootful）
#### インストール・自動再起動の有効化・実行
- 前提
  - Dockerのインストール（Podmanは非rootユーザーかつRootfulで実行できない）
```bash
docker run \
  --detach \
  -p 9443:9443 \
  --privileged \
  --name portainer \
  --restart always \
  --volume /var/run/docker.sock:/var/run/docker.sock:Z \
  --volume portainer_data:/data:Z \
  docker.io/portainer/portainer-ce:latest
```

#### 停止・自動再起動の無効化・削除
```bash
docker stop portainer &&
if ! type podman >/dev/null 2>&1; then
  docker update --restart=no portainer
fi &&
docker rm portainer
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
  -p 9443:9443 \
  --name portainer \
  --restart always \
  --security-opt label=disable \
  --volume ${XDG_RUNTIME_DIR}/docker.sock:/var/run/docker.sock:Z \
  --volume portainer_data:/data:Z \
  docker.io/portainer/portainer-ce:latest
```

#### 停止・削除
```bash
docker stop portainer &&
if ! type podman >/dev/null 2>&1; then
  docker update --restart=no portainer
fi &&
docker rm portainer
```
