# lazydockerのインストール・実行

lazydockerは、Dockerの管理をターミナル上で直感的に行えるTUIツールです。コンテナ、イメージ、ボリューム、ネットワークの状態をリアルタイムで確認でき、キーボード操作だけで効率的に管理できます。

PodmanとDockerの両対応。また、Rootful DockerとRootless Dockerの両対応。

## インストール
Podmanの場合には、ソケットを有効化しておく必要がある。
```bash
wget -q -O- https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | env DIR=/usr/local/bin sudo -E bash -x
```
アップデートも同様の手順。

## 実行（root）
```bash
sudo lazydocker
```

## 実行（非root）
```bash
lazydocker
```