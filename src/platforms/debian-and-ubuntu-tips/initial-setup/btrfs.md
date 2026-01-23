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
スクラブはデータの整合性をチェックする。バランスはデータの再配置を行う。ともに定期的に実行すべきもののため、Systemdのタイマーを設定する。
```bash
sudo apt-get install --no-install-recommends -y btrfsmaintenance &&
sudo mkdir -p /etc/systemd/system/btrfs-balance.timer.d &&
sudo mkdir -p /etc/systemd/system/btrfs-scrub.timer.d &&
sudo tee "/etc/systemd/system/btrfs-balance.timer.d/schedule.conf" << EOS > /dev/null &&
[Timer]
OnCalendar=fri
EOS
sudo tee "/etc/systemd/system/btrfs-scrub.timer.d/schedule.conf" << EOS > /dev/null &&
[Timer]
OnCalendar=sat
EOS
sudo systemctl daemon-reload &&
sudo systemctl enable --now btrfs-balance.timer &&
sudo systemctl enable --now btrfs-scrub.timer
```

確認。
```bash
sudo systemctl status btrfs-balance.timer
sudo systemctl status btrfs-scrub.timer
```

## Snapperのインストールと設定・確認
定期的にスナップショットを取得して、誤操作などからファイルを復旧できるようにする。この場合は`/.snapshots`ディレクトリーにスナップショットが保存される。`@snapshots`サブボリュームがすでにあることを前提にしている。
```bash
sudo apt-get install --no-install-recommends -y snapper &&
mountpoint --quiet --nofollow /boot/efi &&
sudo umount /.snapshots &&
sudo rm -d /.snapshots &&
sudo snapper -c root create-config / &&
sudo btrfs subvolume delete /.snapshots &&
sudo mkdir -p /.snapshots &&
sudo mount -a &&
sudo perl -pi -e 's/^TIMELINE_LIMIT_YEARLY=.+$/TIMELINE_LIMIT_YEARLY="0"/g;' /etc/snapper/configs/root &&
sudo systemctl enable --now snapper-timeline.timer &&
sudo systemctl enable --now snapper-cleanup.timer
```

/homeディレクトリーでもスナップショットを保存する場合の追加設定。この場合は`/home/.snapshots`にスナップショットが保存される。
```bash
sudo snapper -c home create-config /home &&
sudo perl -pi -e 's/^TIMELINE_LIMIT_YEARLY=.+$/TIMELINE_LIMIT_YEARLY="0"/g;' /etc/snapper/configs/home
```

確認。
```bash
sudo systemctl status snapper-timeline.timer
sudo systemctl status snapper-cleanup.timer

sudo btrfs subvolume list /
sudo snapper -c root list
```

スナップショットの削除に向けて、スナップショットの番号だけ表示する。
```bash
sudo snapper -c root --no-headers --csvout list --columns number
```

スナップショットの削除。この場合、#65と#70が削除される。
```bash
sudo snapper -c root delete 65 70
```

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
