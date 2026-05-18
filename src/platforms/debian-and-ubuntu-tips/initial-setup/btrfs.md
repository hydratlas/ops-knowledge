# Btrfs関係（すべて管理者）
## 状況確認
```bash
btrfs filesystem usage /
```

## RAID 1の修復
```bash
sudo btrfs balance start -mconvert=raid1,soft -dconvert=raid1,soft --bg /
```

## スクラブ・バランスのタイマーの設定・確認
[btrfs_maintenance ロールの「手動手順」](../../../storage/btrfs_maintenance/README.md#手動手順)を参照。

## Snapperのインストールと設定・確認
[snapper ロールの「共通事項」](../../../storage/snapper/README.md#共通事項)を参照。`@snapshots` 構成・単一サブボリューム構成のいずれでも、「手動」または Ansible ロールによる設定をそのまま適用できる。

## grub-btrfsのインストールと設定
スナップショットから起動できるようにする。なんらかの理由で起動ができなくなったとき、助かる可能性が上がる。
```bash
sudo apt-get install --no-install-recommends -y gawk inotify-tools git make bzip2 &&
cd ~/ &&
git clone --depth=1 https://github.com/Antynea/grub-btrfs.git &&
cd grub-btrfs && # git checkout xxxxxxx
sudo make install &&
sudo update-grub &&
cd ../ &&
rm -drf grub-btrfs &&
sudo systemctl enable --now grub-btrfsd.service
```
最新版で不具合がある場合は、git checkout xxxxxxxを挿入する。

確認。
```bash
sudo systemctl status grub-btrfsd.service
```

## btrfs-compsizeのインストールと使用
Btrfsの圧縮機能でどの程度ファイルが圧縮されたのかを表示する。

インストール。
```bash
sudo apt-get install --no-install-recommends -y btrfs-compsize
```

表示。
```bash
sudo compsize -x /
```
