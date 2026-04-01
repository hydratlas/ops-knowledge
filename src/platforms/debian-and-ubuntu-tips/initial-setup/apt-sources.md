# aptのソースを設定する（すべて管理者）
aptのソースを日本で速いミラーサーバー群に切り替える。

## Ubuntu
### Deb822-style Format
新しいDeb822-style Formatに対応している場合（基本的にはこちらでよい）。
```bash
sudo tee "/etc/apt/sources.list.d/ubuntu.sources" <<- EOS > /dev/null &&
Types: deb
URIs: mirror+file:/etc/apt/ubuntu-mirrors.txt
Suites: $(lsb_release --short --codename) $(lsb_release --short --codename)-updates $(lsb_release --short --codename)-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: $(lsb_release --short --codename)-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOS
cat "/etc/apt/sources.list.d/ubuntu.sources" && # confirmation
sudo tee "/etc/apt/ubuntu-mirrors.txt" <<- EOS > /dev/null &&
http://ftp.udx.icscoe.jp/Linux/ubuntu	priority:1
https://linux.yz.yamagata-u.ac.jp/ubuntu	priority:2
http://jp.archive.ubuntu.com/ubuntu
EOS
cat "/etc/apt/ubuntu-mirrors.txt" && # confirmation
if [ -f "/etc/apt/sources.list" ]; then
  sudo rm -f "/etc/apt/sources.list"
fi &&
sudo apt-get update
```

### One-Line-Style Format
新しいDeb822-style Formatに対応していない場合。
```bash
sudo tee "/etc/apt/sources.list" <<- EOS > /dev/null &&
deb mirror+file:/etc/apt/mirrors.txt $(lsb_release --short --codename) main restricted universe multiverse
deb mirror+file:/etc/apt/mirrors.txt $(lsb_release --short --codename)-updates main restricted universe multiverse
deb mirror+file:/etc/apt/mirrors.txt $(lsb_release --short --codename)-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $(lsb_release --short --codename)-security main restricted universe multiverse
EOS
cat "/etc/apt/sources.list" && # confirmation
sudo tee "/etc/apt/mirrors.txt" <<- EOS > /dev/null &&
http://ftp.udx.icscoe.jp/Linux/ubuntu	priority:1
https://linux.yz.yamagata-u.ac.jp/ubuntu	priority:2
http://jp.archive.ubuntu.com/ubuntu
EOS
cat "/etc/apt/mirrors.txt" && # confirmation
if [ -f "/etc/apt/sources.list.d/ubuntu.sources" ]; then
  sudo rm -f "/etc/apt/sources.list.d/ubuntu.sources"
fi &&
sudo apt-get update
```

## Debian
### Deb822-style Format
新しいDeb822-style Formatに対応している場合（基本的にはこちらでよい）。
```bash
sudo tee "/etc/apt/sources.list.d/debian.sources" <<- EOS > /dev/null &&
Types: deb
URIs: mirror+file:/etc/apt/debian-mirrors.txt
Suites: $(lsb_release --short --codename) $(lsb_release --short --codename)-updates $(lsb_release --short --codename)-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: $(lsb_release --short --codename)-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOS
cat "/etc/apt/sources.list.d/debian.sources" && # confirmation
sudo tee "/etc/apt/debian-mirrors.txt" <<- EOS > /dev/null &&
http://ftp.jp.debian.org/debian	priority:1
https://debian-mirror.sakura.ne.jp/debian	priority:2
http://cdn.debian.or.jp/debian
EOS
cat "/etc/apt/debian-mirrors.txt" && # confirmation
if [ -f "/etc/apt/sources.list" ]; then
  sudo rm -f "/etc/apt/sources.list"
fi &&
sudo apt-get update
```

### One-Line-Style Format
新しいDeb822-style Formatに対応していない場合。
```bash
sudo tee "/etc/apt/sources.list" <<- EOS > /dev/null &&
deb mirror+file:/etc/apt/mirrors.txt $(lsb_release --short --codename) main contrib non-free non-free-firmware
deb mirror+file:/etc/apt/mirrors.txt $(lsb_release --short --codename)-updates main contrib non-free non-free-firmware
deb mirror+file:/etc/apt/mirrors.txt $(lsb_release --short --codename)-backports main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $(lsb_release --short --codename)-security main contrib non-free non-free-firmware
EOS
cat "/etc/apt/sources.list" && # confirmation
sudo tee "/etc/apt/mirrors.txt" <<- EOS > /dev/null &&
http://ftp.jp.debian.org/debian	priority:1
https://debian-mirror.sakura.ne.jp/debian	priority:2
http://cdn.debian.or.jp/debian
EOS
cat "/etc/apt/mirrors.txt" && # confirmation
if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then
  sudo rm -f "/etc/apt/sources.list.d/debian.sources"
fi &&
sudo apt-get update
```
