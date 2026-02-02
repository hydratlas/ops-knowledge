# Podman tips

Podmanの運用で役立つTipsとトラブルシューティング方法をまとめたドキュメントです。よくある問題の解決方法や、効率的な使い方のヒントを記載しています。

## ZFSおよびLXC上の場合の追加設定
ファイルシステムがZFSであり、なおかつコンテナーのLXC上でPodmanを動かす場合、不具合があるため、対応が必要。`~/.config/containers/storage.conf`に個別設定がなければ、自動的に`/etc/containers/storage.conf`が使用される。
```bash
tee /usr/local/bin/overlayzfsmount << EOS > /dev/null &&
#!/bin/sh
exec /bin/mount -t overlay overlay "\$@"
EOS
chmod a+x /usr/local/bin/overlayzfsmount &&
tee /etc/containers/storage.conf << EOS > /dev/null
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options]
pull_options = {enable_partial_images = "false", use_hard_links = "false", ostree_repos=""}
mount_program = "/usr/local/bin/overlayzfsmount"

[storage.options.overlay]
mountopt = "nodev"
EOS
```

再起動して反映させる。
```bash
reboot
```
- [storage.conf mishandling with zfs storage driver · Issue #20324 · containers/podman](https://github.com/containers/podman/issues/20324)
- [Podman on LXC with ZFS backed volume and Overlay | Proxmox Support Forum](https://forum.proxmox.com/threads/podman-on-lxc-with-zfs-backed-volume-and-overlay.138722/)
- [[FIX] podman lxc is working on zfs with this fix · tteck/Proxmox · Discussion #3531](https://github.com/tteck/Proxmox/discussions/3531)

## Docker Composeのインストール
Docker Composeを使わない場合には必要ない。

### バイナリーをインストール・確認
```bash
sudo wget -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" &&
sudo chmod a+x /usr/local/bin/docker-compose &&
docker-compose --version
```
実際に使う前に、ソケットを有効化しておく必要がある。

### アンインストール
```bash
sudo rm /usr/local/bin/docker-compose
```

## Podmanのソケットを有効化（各ユーザー）
ソケットが必要なアプリケーションを使う場合に実行する。ソケットはユーザーごとに別個であるため、使うユーザー用のソケットをおのおの有効化する。

### rootユーザー用
#### 有効化
```bash
sudo systemctl enable --now podman.socket &&
if [ ! -e /var/run/docker.sock ]; then
  sudo ln -s /run/podman/podman.sock /var/run/docker.sock
fi
```

#### 無効化
```bash
sudo systemctl disable --now podman.socket &&
sudo rm /run/podman/podman.sock &&
sudo unlink /var/run/docker.sock
```

### 非rootユーザー用
#### 有効化
```bash
systemctl --user enable --now podman.socket &&
TARGET_FILE="$HOME/.bashrc" &&
START_MARKER="# BEGIN Podman BLOCK" &&
END_MARKER="# END Podman BLOCK" &&
CODE_BLOCK=$(cat << EOS
if [ -e "$XDG_RUNTIME_DIR/podman/podman.sock" ]; then
  export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
fi
EOS
) &&
if ! grep -q "$START_MARKER" "$TARGET_FILE"; then
  echo -e "$START_MARKER\n$CODE_BLOCK\n$END_MARKER" | tee -a "$TARGET_FILE" > /dev/null  
fi &&
. "$TARGET_FILE"
```

#### 無効化
```bash
systemctl --user disable --now podman.socket &&
rm "$XDG_RUNTIME_DIR/podman/podman.sock" &&
TARGET_FILE="$HOME/.bashrc" &&
START_MARKER="# BEGIN Podman BLOCK" &&
END_MARKER="# END Podman BLOCK" &&
if grep -q "$START_MARKER" "$TARGET_FILE"; then
  sed -i "/$START_MARKER/,/$END_MARKER/d" "$TARGET_FILE"
fi &&
export DOCKER_HOST=""
```

## Podman Quadlet周り
### オプションのドキュメント
`[Container]`に設定するオプションは[podman-systemd.unit — Podman documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)を参照。

### テストとエラーの表示
#### rootのサービス
```bash
sudo /usr/libexec/podman/quadlet -dryrun
```

#### 非rootのサービス
```bash
/usr/libexec/podman/quadlet -dryrun
```

## 実行中のコンテナを表示
### rootユーザーで実行中
```bash
sudo podman ps
```

### 現在のユーザーで実行中
```bash
podman ps
```
