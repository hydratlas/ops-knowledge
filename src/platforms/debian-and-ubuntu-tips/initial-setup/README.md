# 初期設定
## キーボード配列を日本語にする（管理者）
```bash
sudo perl -pi -e "s/^XKBMODEL=.+\$/XKBMODEL=\"pc105\"/g;s/^XKBLAYOUT=.+\$/XKBLAYOUT=\"jp\"/g" "/etc/default/keyboard" &&
sudo dpkg-reconfigure --frontend noninteractive keyboard-configuration
```

## ロケールをシステム全体ではC.UTF-8にした上で、ユーザー個別ではja_JP.UTF-8に設定可能にする（管理者）
```bash
sudo perl -pi -e "s/^#? *C.UTF-8/C.UTF-8/g;s/^#? *ja_JP.UTF-8/ja_JP.UTF-8/g" "/etc/locale.gen" &&
sudo locale-gen &&
sudo localectl set-locale LANG=C.UTF-8 &&
sudo dpkg-reconfigure --frontend noninteractive locales
```

### 補足
「localectl set-locale」に代えて、/etc/default/localeに書き込んでもよい（おそらくlocalectlはこの処理のラッパーとなっている）。
```bash
sudo tee "/etc/default/locale" <<< "LANG=C.UTF-8" > /dev/null

cat "/etc/default/locale" # confirmation
```

## ロケールをログインしているユーザー個別でja_JP.UTF-8に設定する（各ユーザー）
```bash
tee -a "~/.bashrc" << "export LANG=ja_JP.UTF-8" > /dev/null &&
source ~/.bashrc
```

## タイムゾーンをAsia/Tokyoにする（管理者）
```bash
sudo timedatectl set-timezone Asia/Tokyo &&
sudo dpkg-reconfigure --frontend noninteractive tzdata

timedatectl status # confirmation
```

### 補足
設定の場所は3つある。
```bash
sudo tee "/etc/timezone" <<< "Asia/Tokyo" > /dev/null
cat "/etc/timezone" # confirmation

sudo ln -sf "/usr/share/zoneinfo/Asia/Tokyo" "/etc/localtime"
readlink "/etc/localtime" # confirmation

sudo debconf-set-selections <<< "tzdata tzdata/Areas select Asia" &&
sudo debconf-set-selections <<< "tzdata tzdata/Zones/Asia select Tokyo"
```
このうち、「dpkg-reconfigure tzdata」の実行時に参照されているのは「/etc/localtime」だけである。そして、「timedatectl set-timezone」は「/etc/localtime」を書き換える。その上で「dpkg-reconfigure tzdata」を実行すれば、「/etc/timezone」を書き換えてくれる。

## 管理者ユーザーを追加（管理者）
```bash
sudo useradd -u <uid> -U -G adm,cdrom,sudo,dip,plugdev,lpadmin,sambashare,root \
  -p "$(openssl passwd -6 "<password>")" -s /bin/bash -m <username>
```
`-u <uid>`オプションは省略可能で、省略すると適当な番号が割り振られる。また、lpadminおよびsambashareグループは存在せず、そのためにエラーが出る場合があり、その場合は削除して再実行する。

## ユーザー・グループを削除（管理者）
```bash
sudo userdel -r <username> # rオプションでホームディレクトリも削除

sudo groupdel <username>
```

## sudoをパスワードなしで使えるようにする（管理者）
この設定にはリスクがある。
```bash
sudo tee "/etc/sudoers.d/90-adm" <<< "%sudo ALL=(ALL) NOPASSWD: ALL" > /dev/null
```

## DebianでBOOTX64.EFIを作成する（管理者）
UbuntuではEFIシステムパーティションに`EFI/BOOT/BOOTX64.EFI`が作成されるが、Debianでは作成されない。`grub2/force_efi_extra_removable`を`true`にして作成されるようにする。作成しておくと、マザーボードがブートに失敗する可能性が減るが、デュアルブートの場合にはほかのOSの`EFI/BOOT/BOOTX64.EFI`を上書きしてしまうリスクがある。
```bash
sudo debconf-set-selections <<< "grub-efi-amd64 grub2/force_efi_extra_removable boolean true" &&
sudo dpkg-reconfigure --frontend noninteractive shim-signed &&
ls -la /boot/efi/EFI/BOOT
```
設定の確認は`debconf-get-selections | grep grub`でできる。Ubuntuの場合はデフォルトで`grub-efi-amd64 grub2/no_efi_extra_removable boolean false`となっている。`true`と`false`の意味が逆になっていることに注意。

## GRUBの待ち時間をなくす（管理者）
/bootがlvmまたはbtrfsであり、なおかつUEFIブートの場合、GRUBのタイムアウトが30秒になる。それを0秒にする設定。
```bash
sudo tee "/etc/default/grub.d/50-timeout-recordfail.cfg" <<< "GRUB_RECORDFAIL_TIMEOUT=0" > /dev/null &&
sudo update-grub
```

## Nanoをインストールする（管理者）
```bash
sudo apt-get install --no-install-recommends -y nano
```

## GAカーネルからHWEカーネルへの切り替え
### GAカーネルのインストール
```bash
sudo apt-get update &&
sudo apt-get install -y linux-generic
```

### HWEカーネルの削除
```bash
sudo apt-get purge -y linux-hwe-* linux-generic-hwe-* linux-headers-generic-hwe-* linux-image-generic-hwe-*
```

### 一時的にGRUBメニューの表示時間を3秒にする
```bash
sudo tee "/etc/default/grub.d/99-timeout.cfg" << EOS
GRUB_TIMEOUT=3
GRUB_RECORDFAIL_TIMEOUT=3
EOS
```

### GRUBの更新
```bash
sudo update-grub
```
再起動時にAdvanced options for Ubuntuから古いカーネルを選んで起動する。

### インストールされているカーネルの確認
```bash
dpkg --list | grep "^ii  linux"
```

### 具体的なHWEカーネルの削除
```bash
sudo apt-get purge -y linux-*-6.11.0-17-*
```

### GRUBメニューの表示時間を元に戻す
```bash
sudo rm /etc/default/grub.d/99-timeout.cfg
```

### GRUBの更新
```bash
sudo update-grub
```
