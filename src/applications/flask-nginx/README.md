# Flask & uWSGI & nginxのセットアップ

FlaskアプリケーションをuWSGIとNginxを使用して本番環境で実行するための構成手順です。この構成により、Pythonで作成されたWebアプリケーションを安定的かつ高性能に運用できます。

Ubuntu 24.04を前提とする。頻出する`my_project`は仮の値。
- 参考：
  - [UbuntuにAnaconda+Flask環境を作成する #Python - Qiita](https://qiita.com/katsujitakeda/items/b8e0cdc04611e3645f76#nginx%E3%81%AE%E8%A8%AD%E5%AE%9A)
  - [How To Serve Flask Applications with uWSGI and Nginx on Ubuntu 22.04 | DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-serve-flask-applications-with-uwsgi-and-nginx-on-ubuntu-22-04#step-6-configuring-nginx-to-proxy-requests)

## Miniforgeのインストール
```bash
sudo apt-get install -y --no-install-recommends wget ca-certificates &&
wget --quiet -O Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" &&
bash Miniforge3.sh -b -p "${HOME}/conda" &&
rm Miniforge3.sh &&
"$HOME/conda/bin/conda" init &&
. "$HOME/.bashrc" &&
conda -V
```
- [conda-forge/miniforge: A conda-forge distribution.](https://github.com/conda-forge/miniforge)

## 仮想環境の作成とFlaskおよびuWSGIのインストール
```bash
PROJECT_NAME="my_project" &&
conda create -n "$PROJECT_NAME" -y &&
conda activate "$PROJECT_NAME" &&
conda install python flask uwsgi -y &&
conda deactivate
```

## Flaskのデータの作成・動作テスト
```bash
PROJECT_NAME="my_project" &&
mkdir "$HOME/$PROJECT_NAME" &&
tee "$HOME/$PROJECT_NAME/app_route.py" <<- 'EOS' > /dev/null &&
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

if __name__ == "__main__":
    app.run(host='0.0.0.0')
EOS
conda activate "$PROJECT_NAME" &&
python "$HOME/$PROJECT_NAME/app_route.py"
```

http://your_server_ip:5000/にアクセスする。アクセスできたらCtrl + Cで終了する。

## uWSGIのデータの作成・動作テスト
```bash
PROJECT_NAME="my_project" &&
tee "$HOME/$PROJECT_NAME/wsgi.py" <<- EOS > /dev/null &&
from app_route import app

if __name__ == "__main__":
    app.run()
EOS
conda activate "$PROJECT_NAME" &&
cd "$HOME/$PROJECT_NAME" &&
uwsgi --socket 0.0.0.0:5000 --protocol=http -w wsgi:app
```
http://your_server_ip:5000/にアクセスする。アクセスできたらCtrl + Cで終了する。

## 【元に戻す】仮想環境の削除
```bash
PROJECT_NAME="my_project" &&
conda deactivate &&
conda remove -n $PROJECT_NAME --all -y
```

## uWSGIのサービス化
```bash
PROJECT_NAME="my_project" &&
tee "$HOME/$PROJECT_NAME/uwsgi.ini" <<- EOS > /dev/null &&
[uwsgi]
module = wsgi:app

master = true
processes = 5

socket = $PROJECT_NAME.sock
uid = www-data
gid = www-data
chmod-socket = 666
vacuum = true

die-on-term = true
EOS
sudo tee "/etc/systemd/system/$PROJECT_NAME.service" <<- EOS > /dev/null &&
[Unit]
Description=uWSGI instance to serve $PROJECT_NAME
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$HOME/$PROJECT_NAME
Environment="PATH=$HOME/conda/envs/$PROJECT_NAME/bin"
ExecStart=$HOME/conda/envs/$PROJECT_NAME/bin/uwsgi --ini uwsgi.ini

[Install]
WantedBy=multi-user.target
EOS
chmod a+rx "$HOME" &&
sudo systemctl daemon-reload &&
sudo systemctl enable --now "$PROJECT_NAME.service" &&
sudo chgrp www-data "$HOME/$PROJECT_NAME/$PROJECT_NAME.sock"
```
本当はchmod-socket = 660が望ましいが、.sockファイルのGIDがwww-dataにならないため、妥協している。nginxをDockerで起動させた場合はバインドしているため666でよいと思われる。

## nginxのインストール・構成
### 直接インストールする場合
```bash
PROJECT_NAME="my_project" &&
sudo apt-get install -y --no-install-recommends nginx &&
sudo systemctl enable --now nginx.service &&
sudo tee "/etc/nginx/sites-available/$PROJECT_NAME.conf" <<- EOS > /dev/null &&
server {
  listen 80;
  server_name _;
  location / {
    include uwsgi_params;
    uwsgi_pass unix:$HOME/$PROJECT_NAME/$PROJECT_NAME.sock;
  }
}
EOS
sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME.conf /etc/nginx/sites-enabled/$PROJECT_NAME.conf &&
sudo unlink /etc/nginx/sites-enabled/default &&
sudo systemctl restart nginx.service
```
http://your_server_ip/にアクセスする（5000番ポートではない）。nginxのエラーログは`/var/log/nginx/error.log`にある。

### Dockerでインストールする場合
#### 前提
Podmanをインストールしておく。Rootless Dockerでもおそらく動く。

#### 【オプション】デフォルトの設定ファイルの取得
次の設定ファイルを見直す際に、デフォルトがほしい場合は実行。
```bash
docker run --rm --entrypoint=cat nginx:1.26 /etc/nginx/nginx.conf > ./nginx.conf
```

#### 設定ファイルの作成
```bash
PROJECT_NAME="my_project" &&
cd "$HOME/$PROJECT_NAME" &&
tee "$HOME/$PROJECT_NAME/nginx.conf" << EOS > /dev/null &&
user  root;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    gzip  on;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;

        location / {
            include uwsgi_params;
            uwsgi_pass unix:/var/app/app.sock;
        }

        error_page 404 /404.html;
        location = /404.html {}

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {}
    }
}
EOS
touch "$HOME/$PROJECT_NAME/nginx-error.log" &&
sudo chgrp www-data "$HOME/$PROJECT_NAME/nginx-error.log"
```
- 参考：
  - [Unix Domain SocketによるuWSGIとNginxの通信 #Python - Qiita](https://qiita.com/wf-yamaday/items/735be1da1022e096d6c6)

#### Dockerの起動
```bash
docker run \
  --name "$PROJECT_NAME-nginx" \
  -p 8080:80 \
  -v "$HOME/$PROJECT_NAME/$PROJECT_NAME.sock:/var/app/app.sock:ro" \
  -v "$HOME/$PROJECT_NAME/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$HOME/$PROJECT_NAME/nginx-error.log:/var/log/nginx/error.log:rw" \
  --detach \
  nginx:1.26
```

#### 【デバッグ】コンテナに入る
```bash
docker container exec -it "$PROJECT_NAME-nginx" bash
```

#### 【元に戻す】Dockerの停止・削除
```bash
docker stop "$PROJECT_NAME-nginx" &&
docker rm "$PROJECT_NAME-nginx"
```