# Flask + uWSGI + nginxのセットアップ
Ubuntu 24.04を前提とする。頻出する`my_project`は仮の値。
- 参考：
  - [UbuntuにAnaconda+Flask環境を作成する #Python - Qiita](https://qiita.com/katsujitakeda/items/b8e0cdc04611e3645f76#nginx%E3%81%AE%E8%A8%AD%E5%AE%9A)
  - [How To Serve Flask Applications with uWSGI and Nginx on Ubuntu 22.04 | DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-serve-flask-applications-with-uwsgi-and-nginx-on-ubuntu-22-04#step-6-configuring-nginx-to-proxy-requests)

## Miniforgeのインストール
```sh
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
```sh
PROJECT_NAME="my_project" &&
conda create -n "$PROJECT_NAME" -y &&
conda activate "$PROJECT_NAME" &&
conda install python flask uwsgi -y &&
conda deactivate
```

## Flaskのデータの作成・動作テスト
```sh
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
```sh
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
```sh
PROJECT_NAME="my_project" &&
conda deactivate &&
conda remove -n $PROJECT_NAME --all -y
```

## nginxのインストール・構成
`/etc/nginx/sites-available/<project name>.conf`で設定している`server_name`の`example.com`は仮の値であることに注意。
```sh
PROJECT_NAME="my_project" &&
sudo apt-get install -y --no-install-recommends nginx &&
sudo systemctl enable --now nginx.service &&
tee "$HOME/$PROJECT_NAME/uwsgi.ini" <<- EOS > /dev/null &&
[uwsgi]
module = wsgi:app

master = true
processes = 5

socket = $PROJECT_NAME.sock
chmod-socket = 660
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
sudo chgrp www-data "$HOME" &&
chmod g+rx "$HOME" &&
sudo chgrp www-data "$HOME/$PROJECT_NAME/$PROJECT_NAME.sock" &&
sudo tee "/etc/nginx/sites-available/$PROJECT_NAME.conf" <<- EOS > /dev/null &&
server {
  listen 80;
  server_name example.com;
  location / {
    include uwsgi_params;
    uwsgi_pass unix:$HOME/$PROJECT_NAME/$PROJECT_NAME.sock;
  }
}
EOS
sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME.conf /etc/nginx/sites-enabled/$PROJECT_NAME.conf &&
sudo unlink /etc/nginx/sites-enabled/default &&
sudo systemctl daemon-reload &&
sudo systemctl enable --now $PROJECT_NAME &&
sudo systemctl restart nginx.service
```
http://your_server_ip/にアクセスする。nginxのエラーログは`/var/log/nginx/error.log`にある。