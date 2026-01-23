# Kanidm Serverのセットアップ
## 前提
Podmanをインストール、step-cli（クライアント）をインストールしてサーバー証明書を取得しておく必要がある。

## ユーザー・ディレクトリー・鍵の準備
```bash
SERVER_DATA_DIR="/opt/kanidm" &&
SERVER_USER="kanidm" &&
if ! id "${SERVER_USER}" &>/dev/null; then
    sudo useradd --system --create-home --user-group "${SERVER_USER}"
fi &&
sudo install -o root -g "${SERVER_USER}" -m 770 -d "${SERVER_DATA_DIR}" &&
sudo mkdir -p "/usr/local/etc/step-cli.d" &&
sudo install -m 755 -o "root" -g "root" /dev/stdin "/usr/local/etc/step-cli.d/kanidm" << EOS > /dev/null
#!/bin/bash
install -m 644 -o "root" -g "${SERVER_USER}" "\$1" "${SERVER_DATA_DIR}/server.crt"
install -m 640 -o "root" -g "${SERVER_USER}" "\$2" "${SERVER_DATA_DIR}/server.key"
EOS
sudo bash /usr/local/bin/step-cli-renew
```

## インストール・テスト
```bash
SERVER_FQDN="idm-01.int.home.arpa" &&
sudo install -m 640 -o "root" -g "${SERVER_USER}" /dev/stdin "${SERVER_DATA_DIR}/server.toml" << EOS > /dev/null &&
bindaddress = "[::]:8443"
db_path = "/data/kanidm.db"
db_fs_type = "zfs"
tls_chain = "/data/server.crt"
tls_key = "/data/server.key"
domain = "${SERVER_FQDN}"
origin = "https://${SERVER_FQDN}/"

[online_backup]
path = "/data/backups/"
schedule = "00 22 * * *"
EOS
sudo podman run --user "$(id -u "${SERVER_USER}"):$(id -g "${SERVER_USER}")" --rm -it -v "${SERVER_DATA_DIR}:/data" docker.io/kanidm/server:latest /sbin/kanidmd configtest
```

## サービス化
```bash
sudo tee "/etc/containers/systemd/kanidm-server.container" << EOS > /dev/null &&
[Container]
Image=docker.io/kanidm/server:latest
ContainerName=kanidm-server
AutoUpdate=registry
LogDriver=journald

PublishPort=8443:8443
Volume=${SERVER_DATA_DIR}:/data:Z
Volume=/etc/localtime:/etc/localtime:ro
User=$(id -u "${SERVER_USER}")
Group=$(id -g "${SERVER_USER}")

[Service]
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOS
sudo systemctl daemon-reload &&
sudo systemctl start kanidm-server.service &&
sudo systemctl status --no-pager --full kanidm-server.service
```
- [Installing the Server - Kanidm Administration](https://kanidm.github.io/kanidm/stable/installing_the_server.html)

## 確認
```bash
sudo systemctl status --no-pager --full kanidm-server.service
systemctl cat --no-pager --full kanidm-server.service
sudo journalctl --no-pager --lines=30 -xeu kanidm-server.service
```

## サーバー証明書の確認
```bash
openssl x509 -noout -text -in "${SERVER_DIR}/${SERVER_FILENAME}.crt"
```

## 管理者アカウントの初期化
```bash
sudo podman exec -i -t kanidm-server kanidmd recover-account admin
sudo podman exec -i -t kanidm-server kanidmd recover-account idm_admin
```
ランダムなパスワードが生成されるので控えておく。

## 【デバッグ用】再起動
```bash
sudo systemctl restart kanidm-server.service
```

## 【デバッグ用】停止・削除
```bash
sudo systemctl stop kanidm-server.service &&
sudo rm /etc/containers/systemd/kanidm-server.container &&
sudo systemctl daemon-reload &&
sudo rm -dr /opt/kanidm
```
