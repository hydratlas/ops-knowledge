# debootstrapでインストール
DebinaまたはUbuntuをdebootstrapでカスタムインストールするスクリプト。
- 最小限のパッケージだけインストール可能
- Btrfs RAID 1対応（オプションでExt4またはXFS）
- キーボード、ロケールおよびタイムゾーン設定実施
- ネットワークはsystemd-networkd（mDNS対応）

ただし、構築が大変であるため、デフォルトのインストーラーでインストールすることをおすすめする。

debootstrapでDebianをインストールすると、vmlinuzおよびinitrd.imgのシンボリックリンクが、/bootではなく/に作られる。

## ツールのセットアップ
### ダウンロード
```bash
DEBIAN_FRONTEND=noninteractive sudo apt-get install --no-install-recommends -y git &&
cd ~/ &&
if [ -d ./tips ]; then
  rm -drf ./tips
fi &&
git clone --depth=1 git@github.com:hydratlas/tips.git &&
cd tips/debian-and-ubuntu-tips/debootstrap
```

### ハッシュ化されたパスワードの生成
デフォルトでは「newuser」となっている。変更する場合は以下のようにハッシュ化されたパスワードの生成する。そして、設定ファイルに書き込む。
```bash
openssl passwd -6 "newuser"
```

### インストールするカーネルの選択
デフォルトではDebianの場合「linux-image-amd64」、ubuntuの場合「linux-generic」となっている。UbuntuではHWE（Hardware Enablement）カーネルを選ぶことができる。また、debian、Ubuntuともに、仮想マシンのゲストで動かすときに限ったハードウェアをサポートする、軽量なカーネルが用意されている。

まず、使えるカーネルイメージを一覧表示する。
```bash
apt-cache search --names-only ^linux-image- | grep -v -E "[0-9]+\.[0-9]+\.[0-9]+" | sort
```
これらの中から任意のカーネルイメージを選ぶ。Dabianの場合はそれを設定ファイルに書き込む。Debian 12の場合にはlinux-image-amd64、linux-image-cloud-amd64またはlinux-image-rt-amd64になる。

Ubuntuの場合は、選んだカーネルイメージの名前から「image」を抜いた名前がimageとheadersをセットにしたメタパッケージの名前になっていることを確認する。そのうえでそのメタパッケージの名前を設定ファイルに書き込む。
```bash
apt-cache depends linux-generic

apt-cache depends linux-generic-hwe-22.04

apt-cache depends linux-kvm
```

さらに、仮想マシンのゲストではfirmwareとmicrocodeは不要であり、設定ファイルから削除することができる。ただし、その場合、ディスプレーは既定ではなくSPICE (qxl)またはVirtIO-GPUを選ばないと画面が表示されない（Proxmox VEのとき）。

### 設定の変更
```bash
nano install-config.sh
```

## インストール
### インストールするストレージの特定
```bash
lsblk -f -e 7
```

### インストール
「lsblk」によって、インストール先のsdXを確認し、次のコマンドの1個目および2個目の引数に指定する。
```bash
sudo bash -eux install1.sh <config-path> <hostname> <sdX> <sdX>
sudo bash -eux install2.sh <config-path> <hostname> <sdX> <sdX>
```

## トラブルシューティング
### インストールされたパッケージの確認
```bash
sudo arch-chroot /mnt dpkg --get-selections | grep -v deinstall | awk '{print$1}'
```
- less: 入れないと、nmcliコマンドの色を正しく表示できない
- libpam-systemd: 入れないと、SSH切断時にクライアント側がフリーズする

### パッケージの検索
```bash
apt-cache search --names-only linux-image
```

### パッケージの依存関係の確認
```bash
sudo arch-chroot /mnt apt-cache depends <name>
sudo arch-chroot /mnt apt-cache rdepends <name>
```

### debconfの確認
```bash
cat /mnt/var/cache/debconf/config.dat
```

### EFIシステムパーティションの確認
```bash
ls -la /mnt/boot/efi/EFI
ls -la /mnt/boot/efi2/EFI
```
efi2/EFIはdebianの場合は空である。

### NVRAMに保存されたブートエントリーの確認
```bash
sudo efibootmgr -v
```

### NVRAMに保存されたブートエントリーを削除
```bash
sudo efibootmgr --bootnum 1234 --delete-bootnum
```

### debootstrap実行直後に戻す（Btrfsの場合のみ）
```bash
sudo umount -R /mnt

sudo mount -o subvolid=5 /dev/<sdXY> /mnt &&
sudo btrfs subvolume set-default /mnt &&
sudo btrfs subvolume delete /mnt/@ &&
sudo btrfs subvolume snapshot /mnt/@snapshots/after-installation /mnt/@ &&
sudo btrfs subvolume set-default /mnt/@ &&
sudo umount /mnt

sudo bash -eux install-mount.sh sdX sdX
```

## 後処理
### debootstrap実行直後のスナップショットを削除（Btrfsの場合のみ）
```bash
sudo btrfs subvolume delete /mnt/.snapshots/after-installation
```

### アンマウント
再起動するなら飛ばしてよい。
```bash
cd ~/ &&
sudo umount -R /mnt
```

### 再起動
```bash
sudo poweroff
```

### 再起動後に再度マウント
```bash
cd tips/debian-and-ubuntu-tips/debootstrap &&
sudo bash -eux install-mount.sh <config-path> <sdX> <sdX>
```

## その他、起動後の追加設定（オプション）
### console-setup.serviceがエラーになっているときの対処
確認。
```bash
systemctl status console-setup.service
```

再起動。
```bash
sudo systemctl restart console-setup.service
```

### パッケージのアップデート通知（Ubuntu）
SSHログイン時のメッセージ(MOTD)でパッケージのアップデート通知を表示する。MOTDの仕組み上、システム全体のロケールでメッセージが生成されるようである。これをインストールすると依存関係でubuntu-advantage-toolsもインストールされる。ubuntu-advantage-toolsはUbuntu Proを導入する際には必要であるが、導入しない際には広告としての側面が目障りである。
```bash
sudo apt-get install --no-install-recommends -y update-notifier-common
```

### 各種ツールのインストール
```bash
sudo apt-get install --no-install-recommends -y \
  bzip2 curl gdisk git make rsync wget \
  htop psmisc time
```
- htop: htop
- psmisc: killall
- time: time

```bash
sudo apt-get install --no-install-recommends -y \
  lshw lsof mc moreutils
```
- lshw: lshw
- lsof: lsof
- mc: Midnight Commander (file manager)
- moreutils: Unix tools

### NetworkManager関係（Debian）
#### NetworkManagerに切り替える
```bash
sudo apt-get install --no-install-recommends -y network-manager &&
sudo nmcli connection modify "Wired connection 1" connection.autoconnect "yes" &&
ls -alF /etc/NetworkManager/system-connections && # confirmation
echo -e "[main]\ndns=systemd-resolved" | sudo tee /etc/NetworkManager/conf.d/dns.conf &&
sudo systemctl disable systemd-networkd.service &&
sudo systemctl disable systemd-networkd-wait-online.service &&
sudo systemctl enable --now NetworkManager.service
```

#### NetworkManagerでmDNSを使う
```bash
nmcli connection show
nmcli connection show "Wired connection 1"
sudo nmcli connection modify "Wired connection 1" connection.mdns 2
sudo nmcli connection up "Wired connection 1"
```

### 2つ目のEFIシステムパーティションにブートローダー（rEFInd）をインストール（Debian）（未検証）
KVM上でなぜかブートせず、動作を検証できていない。
```bash
EFI_PATH="/boot/efi2" &&
DISTRIBUTOR="$(lsb_release -i -s 2> /dev/null || echo Debian)" &&
ROOT_UUID="$(findmnt --target / --output UUID --noheadings)" &&
sudo apt-get install --no-install-recommends -y wget unzip efibootmgr &&
wget -O "refind.zip" https://sourceforge.net/projects/refind/files/latest/download &&
unzip "refind.zip" -d refind &&
cd refind/refind-bin-*/refind &&
sudo mkdir -p "${EFI_PATH}/EFI/BOOT/drivers_x64" &&
sudo cp refind_x64.efi "${EFI_PATH}/EFI/BOOT/bootx64.efi" &&
sudo cp drivers_x64/btrfs_x64.efi "${EFI_PATH}/EFI/BOOT/drivers_x64/btrfs_x64.efi" &&
sudo tee "${EFI_PATH}/EFI/BOOT/refind.conf" <<- EOS > /dev/null &&
timeout 2
use_nvram false
textonly
scanfor internal,external,optical,manual
menuentry "${DISTRIBUTOR}" {
  volume  "${DISTRIBUTOR}"
  loader  "/@/vmlinuz-linux"
  initrd  "/@/initrd.img"
  options "root=UUID=${ROOT_UUID} ro rootflags=subvol=@"
  submenuentry "rootflags=degraded" {
    options "root=UUID=${ROOT_UUID} ro rootflags=subvol=@,degraded"
  }
}
EOS
cat "${EFI_PATH}/EFI/BOOT/refind.conf" && # confirmation
ESP_DEV="$(findmnt --target "${EFI_PATH}" --output SOURCE --noheadings)" &&
ESP_DISK="${ESP_DEV:0:-1}" &&
ESP_PART="${ESP_DEV: -1}" && # A space is required before the minus sign.
sudo efibootmgr -q --create --disk "${ESP_DISK}" --part "${ESP_PART}" \
  --loader /EFI/BOOT/bootx64.efi --label "${DISTRIBUTOR} (rEFInd Boot Manager)" --unicode &&
sudo efibootmgr -v
```
