# DebianまたはUbuntuをBtrfs (RAID 1)でセットアップ

UbuntuをBtrfsファイルシステムでインストールする手順です。スナップショット機能やサブボリューム管理など、Btrfsの先進的な機能を活用したシステム構築を実現します。

手順および補助スクリプトです。

## 前提
UEFIブートの必要があります。

## インストールできるOSのISOイメージ
- Ubuntu 24.04
- Ubuntu Server 24.04
- Debian 12
  - 注意：インストーラーはbusyboxで実行されていると思われるため、`parted.sh`および`install.sh`のスクリプトを実行するときには、Debian Live 12のライブ起動から実行する必要がある
- Debian Live 12 GNOME
- Debian Live 12 Standard
  - 注意：インストーラーはbusyboxで実行されていると思われるため、`parted.sh`および`install.sh`のスクリプトを実行するときには、ライブ起動から実行する必要がある

## 使い方
### インストール前
```bash
sudo apt-get install -y git
git clone --depth=1 https://github.com/hydratlas/tips
cd tips/debian-and-ubuntu-tips/install-ubuntu-with-btrfs

lsblk -fe7

sudo ./parted.sh sdX
sudo ./parted.sh sdX
```

### インストール後
```bash
sudo ./install.sh sdX sdX
```

## 詳細な手順
- [Ubuntu 24.04](desktop.md)
- [Ubuntu Server 24.04](server.md)

## 解説
### 新規インストール時
`parted.sh`はインストールの前段階で使用します。1台のストレージデバイスをFAT、SwapおよびBtrfs用の3つにパーティションを切り分け、FATおよびSwapはフォーマットします。デフォルトではFATのサイズは約512MiB、Swapのサイズは4GiB、Btrfsのサイズは残りすべてです。

`parted.sh`のコマンド例は次のとおりです。以下、sdaおよびsdbは例であって、マシンによって異なります。`lsblk -fe7`コマンドでマシンに接続されたストレージを確認することができます。
```bash
sudo ./parted.sh sda
sudo ./parted.sh sdb
```
またオプションとして`sudo ./parted.sh sda 1024MiB 8GiB`というように、FATとSwapのサイズをデフォルトから変更することができます。

`parted.sh`によって作るパーティションの構成と、各パーティションのファイルシステムは次のとおりです。
- 1台目のストレージデバイス
  - /dev/sda1 (FAT | Formatting with parted.sh)
  - /dev/sda2 (Swap | Formatting with parted.sh)
  - /dev/sda3 (Btrfs | Formatting in the installer)
- 2台目のストレージデバイス
  - /dev/sdb1 (FAT | Formatting with parted.sh)
  - /dev/sdb2 (Swap | Formatting with parted.sh)
  - /dev/sdb3 (Btrfs | Configure RAID 1 with install.sh)

OSのインストーラーを使って、`sda3`にBtrfsでOSをインストールします。インストールが完了すると、ルートファイルシステムは次のようになります（Ubuntuの場合）。
- /dev/sda3 (Btrfs single)
  - /target (Mount point after reboot: /)

`install.sh`はインストールの後段階で使用します。OSがインストールされたBtrfsをRAID 1化およびサブボリューム化します。また、加えて、起動時にRAID 1を構成するストレージが1台故障していたときでも、起動できるメニューエントリーをGRUBに追加します。これはカーネルパラメータに`rootflags=degraded`を付加したものです。

`install.sh`のコマンド例は次のとおりです。sda3からsdb3にRAID 1化します。なお、引数を1つだけ指定すると、RAID 1化は行いません。
```bash
sudo ./install.sh sda sdb
```

`install.sh`の処理が完了すると、ルートファイルシステムは次のようになります。
- /dev/sda3 (Btrfs RAID 1) | /dev/sdb3 (Btrfs RAID 1)
  - /mnt/@ (Mount point after reboot: /)
  - /mnt/@root (Mount point after reboot: /root)
  - /mnt/@home (Mount point after reboot: /home)
  - /mnt/@var_log (Mount point after reboot: /var/log)
  - /mnt/@snapshots (Mount point after reboot: /.snapshots)

スクリプトが設定する、`/etc/fstab`におけるBtrfsのマウントオプションはSSD向けに最適化されています(`noatime`)。ただし、`ssd`および`discard=async`マウントオプションはほとんどの場合で自動的に設定されるため、スクリプトによって明示的に指定しません。`ssd`マウントオプションは`cat /sys/block/XXX/queue/rotational`が0であれば自動的に設定されます。`install.sh`の処理後に`/etc/fstab`を手動で編集することによってカスタマイズすることができます。

### 上書きインストール時
`parted.sh`および`install.sh`を使用してインストールした後に、上書きインストールが必要になった際、`update.sh`を使うと既存のOSをサブボリュームに退避できます。

`parted.sh`によって作るパーティションの構成と、各パーティションのファイルシステムは次のとおりです。
- 1台目のストレージデバイス（既存の物）
  - /dev/sda1 (FAT)
  - /dev/sda2 (Swap)
  - /dev/sda3 (Btrfs)
- 2台目のストレージデバイス（既存の物）
  - /dev/sdb1 (FAT)
  - /dev/sdb2 (Swap)
  - /dev/sdb3 (Btrfs)
- 3台目のストレージデバイスまたはUSBメモリ（一時的に使う物）
  - /dev/sdc1 (FAT | Formatting with parted.sh)
  - /dev/sdc2 (Swap | Formatting with parted.sh)
  - /dev/sdc3 (Btrfs | Formatting in the installer)

まずOSのインストーラーを使って、`sdc3`にBtrfsでOSをインストールします。次に新規インストール時と同様に`install.sh`を実行します。

`update.sh`はOSがインストールされた新しいBtrfsを、既存のBtrfsに差し込みます。`/etc/fstab`は既存のものをそのまま使うため、たとえば`/home`を別のストレージデバイスで動かしていたとしても、問題なく使用を継続できます。

`update.sh`のコマンド例は次のとおりです。新しくインストールした`sdc3`から、既存のRAID 1構成の`sda3`および`sdb3`にデータを差し込みます。なお、RAID 1ではない場合、引数を2つだけ指定します。
```bash
sudo ./update.sh sdc3 sda sdb
```

`update.sh`の処理が完了すると、ルートファイルシステムは次のようになります。処理が完了したら`sdc`は不要になります。
- /dev/sda3 (Btrfs RAID 1) | /dev/sdb3 (Btrfs RAID 1)
  - /mnt/@ (Mount point after reboot: / | New OS)
  - /mnt/@root (Mount point after reboot: /root | Existing data)
  - /mnt/@home (Mount point after reboot: /home | Existing data)
  - /mnt/@var_log (Mount point after reboot: /var/log | Existing data)
  - /mnt/@snapshots (Mount point after reboot: /.snapshots | Existing snapshots)
  - /mnt/@snapshots/20000101T000000+0000 (Existing OS)

既存のOS(`@snapshots/20000101T000000+0000`)はGRUBのメニューエントリーから起動可能です。`update.sh`によってメニューエントリーが追加されています。

既存のOSの起動中にカーネルのアップデートが行われると（セキュリティーアップデートは自動的に行われます）、メニューエントリーが既存のOSのものになり、新しいOS(`@`)のメニューエントリーが破壊される可能性があります。