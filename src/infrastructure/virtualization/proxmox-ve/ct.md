
# CT作成（UbuntuまたはDebian）
## 一般
Proxmox VEのストレージ（local）画面で、CTテンプレートの「テンプレート」ボタンからダウンロードする。さらに多くのバージョンのテンプレートが[http://download.proxmox.com/images/system/](http://download.proxmox.com/images/system/)にあり、ここで任意のtar.xzやtar.zstで終わるURLをコピーした上で、「URLからダウンロード」ボタンからダウンロードできる。

Debianの場合、IPv6は「静的」を選ばないとコンソール画面が表示されない（静的を選べば、IPアドレス、ゲートウェイは空でよい）。

## 初期設定（Ubuntu）
```bash
timedatectl set-timezone Asia/Tokyo &&
dpkg-reconfigure --frontend noninteractive tzdata &&
systemctl disable --now systemd-timesyncd.service &&
apt-get install --no-install-recommends -y lsb-release &&
tee "/etc/apt/sources.list.d/ubuntu.sources" <<- EOS > /dev/null &&
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
tee "/etc/apt/ubuntu-mirrors.txt" <<- EOS > /dev/null &&
http://ftp.udx.icscoe.jp/Linux/ubuntu	priority:1
https://linux.yz.yamagata-u.ac.jp/ubuntu	priority:2
http://jp.archive.ubuntu.com/ubuntu
EOS
cat "/etc/apt/ubuntu-mirrors.txt" && # confirmation
if [ -f "/etc/apt/sources.list" ]; then
  rm -f "/etc/apt/sources.list"
fi &&
apt-get update &&
apt-get dist-upgrade -y &&
apt-get install --no-install-recommends -y avahi-daemon libnss-mdns
```

## 初期設定（Debian 12）
```bash
timedatectl set-timezone Asia/Tokyo &&
dpkg-reconfigure --frontend noninteractive tzdata &&
systemctl disable --now systemd-timesyncd.service &&
apt-get install --no-install-recommends -y lsb-release &&
tee "/etc/apt/sources.list.d/debian.sources" <<- EOS > /dev/null &&
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
tee "/etc/apt/debian-mirrors.txt" <<- EOS > /dev/null &&
http://ftp.jp.debian.org/debian	priority:1
https://debian-mirror.sakura.ne.jp/debian	priority:2
http://cdn.debian.or.jp/debian
EOS
if [ -f "/etc/apt/sources.list" ]; then
  rm -f "/etc/apt/sources.list"
fi &&
apt-get update &&
apt-get dist-upgrade -y &&
apt-get install --no-install-recommends -y avahi-daemon libnss-mdns
```
