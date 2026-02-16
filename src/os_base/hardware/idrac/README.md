# iDRAC

Dell iDRAC（Integrated Dell Remote Access Controller）の設定と管理方法です。リモートからのサーバー管理、監視、トラブルシューティングを可能にします。

## リバースプロキシを設定する
ポート5900を使用する仮想コンソールがうまく動かないという問題がある。
```bash
ip_address="0.0.0.0" &&
container_user="nginx" &&
if hash apt-get 2>/dev/null; then
  sudo apt-get install -y podman
elif hash dnf 2>/dev/null; then
  sudo dnf install -y podman
fi &&
if ! id "${container_user}" &>/dev/null; then
    sudo useradd --system --user-group --add-subids-for-system \
      --shell /usr/sbin/nologin --create-home "${container_user}"
fi &&
sudo usermod -aG systemd-journal "${container_user}" &&
user_home="$(grep "^${container_user}:" /etc/passwd | cut -d: -f6)" &&
sudo loginctl enable-linger "${container_user}" &&
sudo -u "${container_user}" mkdir -p "${user_home}/.config/containers/systemd" &&

sudo -u "${container_user}" openssl req -x509 -nodes -days 7300 -newkey rsa:2048 \
  -keyout "${user_home}/.config/containers/nginx.key" \
  -out "${user_home}/.config/containers/nginx.crt" \
  -subj "/CN=localhost" &&
sudo -u "${container_user}" chmod 644 "${user_home}/.config/containers/nginx.crt" &&
sudo -u "${container_user}" chmod 600 "${user_home}/.config/containers/nginx.key" &&
sudo install \
  -m 644 -o "${container_user}" -g "${container_user}" \
  /dev/stdin \
  "${user_home}/.config/containers/nginx.conf" << EOS > /dev/null &&
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    server {
        listen 10443 ssl;
        listen [::]:10443 ssl;

        ssl_certificate /etc/nginx/ssl/nginx.crt;
        ssl_certificate_key /etc/nginx/ssl/nginx.key;
    
        server_name _;
    
        location / {
            proxy_pass https://$ip_address; # リクエストを転送

            proxy_set_header Host $ip_address; # 転送先サーバーに送るHostヘッダーを固定
            proxy_set_header Referer "https://$ip_address/"; # 転送先サーバーに送るReferer ヘッダーを固定

            proxy_set_header X-Forwarded-Proto \$scheme; # クライアントの接続プロトコル (http/https) を転送
            proxy_set_header X-Real-IP \$remote_addr; # クライアントの実際のIPアドレスを転送
            proxy_set_header X-Forwarded-Port \$proxy_port; # クライアントが接続したポート番号を転送
            proxy_set_header X-Forwarded-Host \$host; # クライアントがリクエストしたホスト名を転送
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; # クライアントのIPアドレスを転送（多段プロキシ対応）

            proxy_http_version 1.1; # バックエンドとの通信にHTTP/1.1を使用（WebSocketなどの維持接続に必要）
            proxy_set_header Upgrade \$http_upgrade; # WebSocketなどのプロトコルアップグレードを転送
            proxy_set_header Connection "Upgrade"; # プロトコルアップグレードが必要な接続を維持

            proxy_redirect https://$ip_address/ https://\$host:\$server_port/; # レスポンス内のリダイレクトURLを書き換え

            proxy_ssl_verify off; # バックエンドへのSSL証明書検証を無効化
        }
    }
}
EOS
sudo install \
  -m 644 -o "${container_user}" -g "${container_user}" \
  /dev/stdin \
  "${user_home}/.config/containers/systemd/nginx.container" << EOS > /dev/null &&
[Container]
Image=docker.io/nginx:latest
ContainerName=nginx
AutoUpdate=registry
LogDriver=journald
PublishPort=10443:10443
Volume=%h/.config/containers/nginx.conf:/etc/nginx/nginx.conf:ro,z
Volume=%h/.config/containers/nginx.crt:/etc/nginx/ssl/nginx.crt:ro,z
Volume=%h/.config/containers/nginx.key:/etc/nginx/ssl/nginx.key:ro,z

[Service]
Restart=on-failure

[Install]
WantedBy=default.target
EOS
sleep 1s &&
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user daemon-reexec &&
sleep 1s &&
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user daemon-reload &&
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user start nginx.service &&
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user status --no-pager --full nginx.service
```
- 参考：[anyone reverse proxy idrac? : r/homelab](https://www.reddit.com/r/homelab/comments/a0963b/anyone_reverse_proxy_idrac/)

## 自動更新の有効化
```bash
container_user="nginx" &&
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user enable --now podman-auto-update.timer
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user status --no-pager --full podman-auto-update.timer
```

## 【デバッグ】ログの確認
```bash
container_user="nginx" &&
sudo -u "${container_user}" journalctl --user --no-pager --lines=100 --unit=nginx.service
```

## 【デバッグ】再起動
```bash
container_user="nginx" &&
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user restart nginx.service
```

## 【元に戻す】停止・削除
```bash
container_user="nginx" &&
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user stop nginx.service &&
user_home="$(grep "^${container_user}:" /etc/passwd | cut -d: -f6)" &&
sudo rm "${user_home}/.config/containers/systemd/nginx.container" &&
sudo -u "${container_user}" env XDG_RUNTIME_DIR=/run/user/$(id -u "${container_user}") \
  systemctl --user daemon-reload &&
sudo rm "${user_home}/.config/containers/nginx.conf" &&
sudo rm "${user_home}/.config/containers/nginx.crt" &&
sudo rm "${user_home}/.config/containers/nginx.key"
```
