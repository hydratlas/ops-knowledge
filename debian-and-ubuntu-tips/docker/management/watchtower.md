# Watchtower
Dockerのイメージを自動的にアップデートする。公式Github：[containrrr/watchtower: A process for automating Docker container base image updates.](https://github.com/containrrr/watchtower)

## rootユーザーで実行する場合（sudoを含む）
### インストール・自動再起動の有効化・実行
- 前提
  - DockerまたはPodmanのインストール
  - ソケットの有効化（Podmanの場合のみ）（Dockerはデフォルトで有効）
```sh
sudo docker run \
  --detach \
  --name watchtower \
  --restart always \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  docker.io/containrrr/watchtower
```

### 停止・自動再起動の無効化・削除
```sh
sudo docker stop watchtower &&
if ! type podman >/dev/null 2>&1; then
  sudo docker update --restart=no watchtower
fi &&
sudo docker rm watchtower
```

## 非rootユーザーで実行する場合（Rootful）
### インストール・自動再起動の有効化・実行
- 前提
  - Dockerのインストール（Podmanは非rootユーザーかつRootfulで実行できない）
```sh
docker run \
  --detach \
  --name watchtower \
  --restart always \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  docker.io/containrrr/watchtower
```

### 停止・自動再起動の無効化・削除
```sh
docker stop watchtower &&
if ! type podman >/dev/null 2>&1; then
  docker update --restart=no watchtower
fi &&
docker rm watchtower
```

## 非rootユーザーで実行する場合（Rootless）
### インストール・自動再起動の有効化・実行
- 前提
  - DockerまたはPodmanのインストール
  - ソケットの有効化（ユーザーごとの設定）（Podmanの場合のみ）（Dockerはデフォルトで有効）
  - linger（居残り）の有効化（ユーザーごとの設定）
```sh
docker run \
  --detach \
  --name watchtower \
  --restart always \
  --volume ${XDG_RUNTIME_DIR}/docker.sock:/var/run/docker.sock \
  docker.io/containrrr/watchtower
```

### 停止・削除
```sh
docker stop watchtower &&
if ! type podman >/dev/null 2>&1; then
  docker update --restart=no watchtower
fi &&
docker rm watchtower
```
