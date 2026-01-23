# FreeIPAサーバーをPodmanコンテナとしてインストール
うまく動かない。

## 事前設定
```bash
ds_password="$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'"'"'()*+,-./:;<=>?@[]\^_`{|}~' | head -c 12)" &&
admin_password="$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'"'"'()*+,-./:;<=>?@[]\^_`{|}~' | head -c 12)" &&
base_domain="home.arpa" &&
user_name="freeipa-server" &&
echo "Directory Manager user password: ${ds_password}" &&
echo "IPA admin user password: ${admin_password}" &&
if hash apt-get 2>/dev/null; then
  sudo apt-get install -y podman
elif hash dnf 2>/dev/null; then
  sudo dnf install -y podman
fi &&
if hash wget 2>/dev/null; then
  eval "$(wget -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/freeipa")"
elif hash curl 2>/dev/null; then
  eval "$(curl "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/freeipa")"
fi &&
chosen_domain &&
chosen_nameserver &&
chosen_ip_address &&
if ! id "${user_name}" &>/dev/null; then
  sudo useradd --system --no-create-home --user-group \
    --shell /usr/usr/sbin/nologin "${user_name}"
fi
```

## コンテナを起動
コンテナは`--detach`オプションによりバックグラウンドで起動させており、そのログを別途`podman logs`コマンドで表示させている。初期設定が完了したら「FreeIPA server configured.」と表示される。それを確認したら「Ctrl + C」キーでログの表示を終了させる。

### マスター（Aパターン／動作実績あり）
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run \
  --detach \
  --name freeipa-server \
  --hostname "${domain}" \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --volume "/var/local/lib/ipa-data:/data:Z" \
  --env IPA_SERVER_IP="${ip_address}" \
  --publish 80:80 \
  --publish 443:443 \
  --publish 389:389 \
  --publish 636:636 \
  --publish 88:88/tcp --publish 88:88/udp \
  --publish 464:464/tcp --publish 464:464/udp \
  docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
  --unattended \
  --ds-password="${ds_password}" \
  --admin-password="${admin_password}" \
  --domain="${base_domain,,}" \
  --realm="${base_domain^^}" \
  --no-ntp &&
sudo podman logs --follow freeipa-server
```

### マスター（Bパターン／動作実績あり）
Aパターン＋--rm＋--read-only＋--log-driver
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run --detach --rm \
  --name freeipa-server \
  --hostname "${domain}" \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --volume "/var/local/lib/ipa-data:/data:Z" \
  --read-only \
  --log-driver journald \
  --env IPA_SERVER_IP="${ip_address}" \
  --publish 80:80 \
  --publish 443:443 \
  --publish 389:389 \
  --publish 636:636 \
  --publish 88:88/tcp --publish 88:88/udp \
  --publish 464:464/tcp --publish 464:464/udp \
  docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
  --unattended \
  --ds-password="${ds_password}" \
  --admin-password="${admin_password}" \
  --domain="${base_domain,,}" \
  --realm="${base_domain^^}" \
  --no-ntp &&
sudo podman logs --follow freeipa-server
```

### マスター（Cパターン／動かない）
Bパターンー--read-only＋--setup-dns＋--forwarder
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run --detach --rm \
  --name freeipa-server \
  --hostname "${domain}" \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --volume "/var/local/lib/ipa-data:/data:Z" \
  --log-driver journald \
  --env IPA_SERVER_IP="${ip_address}" \
  --publish 80:80 \
  --publish 443:443 \
  --publish 389:389 \
  --publish 636:636 \
  --publish 88:88/tcp --publish 88:88/udp \
  --publish 464:464/tcp --publish 464:464/udp \
  docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
  --unattended \
  --ds-password="${ds_password}" \
  --admin-password="${admin_password}" \
  --domain="${base_domain,,}" \
  --realm="${base_domain^^}" \
  --no-ntp \
  --setup-dns --forwarder="${nameserver}" &&
sudo podman logs --follow freeipa-server
```

### マスター（Z-Aパターン／動作実績あり）
外から持ってきたもの
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run -d --name freeipa-server --log-driver journald \
    -h ${domain} \
    --read-only \
    --dns=127.0.0.1 \
    -v /var/local/lib/ipa-data:/data:Z \
    -e IPA_SERVER_IP=${ip_address} \
    -p 636:636 -p 80:80 -p 123:123 -p 389:389 -p 443:443 -p 88:88 -p 464:464 -p 53:53 -p 53:53/udp \
    docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
    -a ${admin_password} -p ${admin_password} \
    --setup-dns --no-forwarders \
    -r ${base_domain^^} \
    --no-ntp \
    -U &&
sudo podman logs --follow freeipa-server
```

### マスター（Z-Bパターン／動作実績あり）
Z-Aパターンと内容同等でオプション名を変えたもの
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run --detach \
    --name freeipa-server \
    --hostname "${domain}" \
    --dns=127.0.0.1 \
    --read-only \
    --volume "/var/local/lib/ipa-data:/data:Z" \
    --log-driver journald \
    --env IPA_SERVER_IP=${ip_address} \
    -p 636:636 -p 80:80 -p 123:123 -p 389:389 -p 443:443 -p 88:88 -p 464:464 -p 53:53 -p 53:53/udp \
    docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
    --unattended \
    --ds-password="${ds_password}" \
    --admin-password="${admin_password}" \
    --realm="${base_domain^^}" \
    --no-ntp \
    --setup-dns --no-forwarders &&
sudo podman logs --follow freeipa-server
```

### マスター（Z-Cパターン／動作実績あり）
Z-Bパターンー-p 123:123＋--rm
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run --detach --rm \
    --name freeipa-server \
    --hostname "${domain}" \
    --dns=127.0.0.1 \
    --read-only \
    --volume "/var/local/lib/ipa-data:/data:Z" \
    --log-driver journald \
    --env IPA_SERVER_IP=${ip_address} \
    --publish 80:80 --publish 443:443 \
    --publish 389:389 --publish 636:636 \
    --publish 88:88/tcp --publish 88:88/udp --publish 464:464/tcp --publish 464:464/udp \
    --publish 53:53/tcp --publish 53:53/udp \
    docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
    --unattended \
    --ds-password="${ds_password}" \
    --admin-password="${admin_password}" \
    --realm="${base_domain^^}" \
    --no-ntp \
    --setup-dns --no-forwarders &&
sudo podman logs --follow freeipa-server
```

### マスター（Z-Dパターン／動かない）
Z-Cパターン＋--domain

Unable to resolve "idm-01.int.home.arpa". Is --dns=127.0.0.1 set for the container?
→`--dns=127.0.0.1`を`--dns=${nameserver}`に差し替えても`mode of '/tmp/var' changed from 1755 (rwxr-xr-t) to 0755 (rwxr-xr-x)`で止まる
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run --detach --rm \
    --name freeipa-server \
    --hostname "${domain}" \
    --dns=127.0.0.1 \
    --read-only \
    --volume "/var/local/lib/ipa-data:/data:Z" \
    --log-driver journald \
    --env IPA_SERVER_IP=${ip_address} \
    --publish 80:80 --publish 443:443 \
    --publish 389:389 --publish 636:636 \
    --publish 88:88/tcp --publish 88:88/udp --publish 464:464/tcp --publish 464:464/udp \
    --publish 53:53/tcp --publish 53:53/udp \
    docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
    --unattended \
    --ds-password="${ds_password}" \
    --admin-password="${admin_password}" \
    --domain="${base_domain,,}" \
    --realm="${base_domain^^}" \
    --no-ntp \
    --setup-dns --no-forwarders &&
sudo podman logs --follow freeipa-server
```

### マスター（Dパターン）
Cパターンー--forwarder＋--dns＋--no-forwarders
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run --detach --rm \
  --name freeipa-server \
  --hostname "${domain}" \
  --dns=127.0.0.1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --volume "/var/local/lib/ipa-data:/data:Z" \
  --log-driver journald \
  --env IPA_SERVER_IP="${ip_address}" \
  -p 636:636 -p 80:80 -p 123:123 -p 389:389 -p 443:443 -p 88:88 -p 464:464 -p 53:53 -p 53:53/udp \
  docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
  --unattended \
  --ds-password="${ds_password}" \
  --admin-password="${admin_password}" \
  --domain="${base_domain,,}" \
  --realm="${base_domain^^}" \
  --no-ntp \
  --setup-dns --no-forwarders &&
sudo podman logs --follow freeipa-server
```

### マスター（目標）
```bash
sudo install -o "root" -g "${user_name}" -m 775 -d "/var/local/lib/ipa-data" &&
sudo podman run --detach --rm \
  --name=freeipa-server \
  --hostname="${domain}" \
  --dns=127.0.0.1 \
  --sysctl=net.ipv6.conf.all.disable_ipv6=0 \
  --volume="/var/local/lib/ipa-data:/data:Z" \
  --read-only \
  --log-driver journald \
  --env IPA_SERVER_IP="${ip_address}" \
  docker.io/freeipa/freeipa-server:almalinux-9 ipa-server-install \
  --unattended \
  --ds-password="${ds_password}" \
  --admin-password="${admin_password}" \
  --domain="${base_domain,,}" \
  --realm="${base_domain^^}" \
  --no-ntp \
  --setup-dns --forwarder="${nameserver}" &&
sudo podman logs --follow freeipa-server
```

## コンテナをいったん停止・削除
```bash
sudo podman stop freeipa-server;
sudo podman rm freeipa-server
```

## 【元に戻す】ディレクトリーを削除
```bash
sudo rm -drf /var/local/lib/ipa-data
```

## サービス化（A／動作実績あり）
```bash
sudo tee "/etc/containers/systemd/freeipa-server.container" << EOS > /dev/null &&
[Unit]
Description=FreeIPA Server Container
Wants=network-online.target
After=network-online.target

[Container]
Image=docker.io/freeipa/freeipa-server:almalinux-9
ContainerName=freeipa-server
Network=freeipa.network
Sysctl=net.ipv6.conf.all.disable_ipv6=0
Volume=/var/local/lib/ipa-data:/data:Z
PublishPort=80:80
PublishPort=443:443
PublishPort=389:389
PublishPort=636:636
PublishPort=88:88/tcp
PublishPort=88:88/udp
PublishPort=464:464/tcp
PublishPort=464:464/udp

[Service]
Restart=on-failure
Environment=IPA_SERVER_IP=${ip_address}

[Install]
WantedBy=multi-user.target
EOS
sudo systemctl daemon-reload &&
sudo systemctl start freeipa-server.service &&
sudo systemctl status --no-pager --full freeipa-server.service
```

## サービス化（B）
Aから53番ポートの開放を追加
```bash
sudo tee "/etc/containers/systemd/freeipa-server.container" << EOS > /dev/null &&
[Unit]
Description=FreeIPA Server Container
Wants=network-online.target
After=network-online.target

[Container]
Image=docker.io/freeipa/freeipa-server:almalinux-9
ContainerName=freeipa-server
Network=freeipa.network
Sysctl=net.ipv6.conf.all.disable_ipv6=0
Volume=/var/local/lib/ipa-data:/data:Z
PublishPort=80:80
PublishPort=443:443
PublishPort=389:389
PublishPort=636:636
PublishPort=88:88/tcp
PublishPort=88:88/udp
PublishPort=464:464/tcp
PublishPort=464:464/udp
PublishPort=53:53/tcp
PublishPort=53:53/udp

[Service]
Restart=on-failure
Environment=IPA_SERVER_IP=${ip_address}

[Install]
WantedBy=multi-user.target
EOS
sudo systemctl daemon-reload &&
sudo systemctl start freeipa-server.service &&
sudo systemctl status --no-pager --full freeipa-server.service
```

## サービス化（--read-only＋--log-driver＋AutoUpdate／動作実績あり）
`ReadOnly=true`はだめで、`[22058.891494] podman1: port 1(veth0) entered blocking state`や`[22058.891727] podman1: port 1(veth0) entered disabled state`を繰り返す。
```bash
sudo tee "/etc/containers/systemd/freeipa-server.container" << EOS > /dev/null &&
[Unit]
Description=FreeIPA Server Container
Wants=network-online.target
After=network-online.target

[Container]
Image=docker.io/freeipa/freeipa-server:almalinux-9
ContainerName=freeipa-server
Network=freeipa.network
Sysctl=net.ipv6.conf.all.disable_ipv6=0
Volume=/var/local/lib/ipa-data:/data:Z
AutoUpdate=registry
LogDriver=journald

PublishPort=80:80
PublishPort=443:443
PublishPort=389:389
PublishPort=636:636
PublishPort=88:88/tcp
PublishPort=88:88/udp
PublishPort=464:464/tcp
PublishPort=464:464/udp

[Service]
Restart=on-failure
Environment=IPA_SERVER_IP=${ip_address}

[Install]
WantedBy=multi-user.target
EOS
sudo systemctl daemon-reload &&
sudo systemctl start freeipa-server.service &&
sudo systemctl status --no-pager --full freeipa-server.service
```

## サービス化（目標）
```bash
sudo tee "/etc/containers/systemd/freeipa-server.container" << EOS > /dev/null &&
[Unit]
Description=FreeIPA Server Container
Wants=network-online.target
After=network-online.target

[Container]
Image=docker.io/freeipa/freeipa-server:almalinux-9
ContainerName=freeipa-server
HostName=${domain}
DNS=127.0.0.1
#Network=freeipa.network
Sysctl=net.ipv6.conf.all.disable_ipv6=0
ReadOnly=true
Volume=/var/local/lib/ipa-data:/data:Z
PublishPort=80:80
PublishPort=443:443
PublishPort=389:389
PublishPort=636:636
PublishPort=88:88/tcp
PublishPort=88:88/udp
PublishPort=464:464/tcp
PublishPort=464:464/udp

[Service]
Restart=on-failure
Environment=IPA_SERVER_IP=${ip_address}
Environment=FORWARDER=${nameservers}

[Install]
WantedBy=multi-user.target
EOS
sudo systemctl daemon-reload &&
sudo systemctl start freeipa-server.service &&
sudo systemctl status --no-pager --full freeipa-server.service &&
sudo podman exec -it freeipa-server cat /etc/resolv.conf
```

## 【デバッグ】podmanコマンドの確認
```bash
systemctl cat --no-pager --full freeipa-server.service | grep ExecStart=
```

## 【デバッグ】ログの表示
```bash
journalctl --no-pager --lines=20 --unit=freeipa-server.service
```

## 【元に戻す】サービスの停止・削除
```bash
sudo systemctl stop freeipa-server.service;
sudo rm /etc/containers/systemd/freeipa-server.container;
sudo systemctl daemon-reload
```

### レプリカ
```bash
sudo podman run \
  --detach \
  --name=freeipa-server \
  --hostname="${domain}" \
  --dns="${nameserver}"
  --sysctl=net.ipv6.conf.all.disable_ipv6=0 \
  --volume="/var/local/lib/ipa-data:/data:Z" \
  --env IPA_SERVER_IP=${ip_address} \
  --env DNS=${nameserver} \
  --publish 80:80 \
  --publish 443:443 \
  --publish 389:389 \
  --publish 636:636 \
  --publish 88:88/tcp --publish 88:88/udp \
  --publish 464:464/tcp --publish 464:464/udp \
  docker.io/freeipa/freeipa-server:almalinux-9 ipa-replica-install \
  --unattended \
  --setup-dns \
  --forwarder=${ip_address} \
  --no-ntp &&
sudo podman logs --follow freeipa-server
```

## ネットワークの作成
```bash
sudo mkdir -p /etc/containers/systemd &&
sudo tee /etc/containers/systemd/freeipa.network << EOS > /dev/null
[Unit]
Description=FreeIPA Container Network

[Network]
Label=app=freeipa
EOS
```
