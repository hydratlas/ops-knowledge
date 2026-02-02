#!/bin/bash
set -eux

# ディスク
DISK1="/dev/${1}"
if [ -n "${2:-}" ]; then
  DISK2="/dev/${2}"
else
  DISK2=""
fi

# Btrfsオプション
BTRFS_OPTIONS="noatime,compress=zstd:1,degraded"

# パーティション
if [ -e "${DISK1}p1" ]; then
  EFI1_PART="${DISK1}p1"
else
  EFI1_PART="${DISK1}1"
fi

if [ -e "${DISK1}p2" ]; then
  SWAP1_PART="${DISK1}p2"
else
  SWAP1_PART="${DISK1}2"
fi

if [ -e "${DISK1}p3" ]; then
  ROOTFS1_PART="${DISK1}p3"
else
  ROOTFS1_PART="${DISK1}3"
fi

if [ -e "${DISK2}p1" ]; then
  EFI2_PART="${DISK2}p1"
else
  EFI2_PART="${DISK2}1"
fi

if [ -e "${DISK2}p2" ]; then
  SWAP2_PART="${DISK2}p2"
else
  SWAP2_PART="${DISK2}2"
fi

if [ -e "${DISK2}p3" ]; then
  ROOTFS2_PART="${DISK2}p3"
else
  ROOTFS2_PART="${DISK2}3"
fi

# UUIDを取得
EFI1_UUID="$(lsblk -dno UUID ${EFI1_PART})"
SWAP1_UUID="$(lsblk -dno UUID ${SWAP1_PART})"
ROOTFS_UUID="$(lsblk -dno UUID ${ROOTFS1_PART})"
if [ -e "${DISK2}" ]; then
  EFI2_UUID="$(lsblk -dno UUID ${EFI2_PART})"
  SWAP2_UUID="$(lsblk -dno UUID ${SWAP2_PART})"
fi

# アンマウント
umount -R /target

# マウント
MOUNT_POINT="/mnt"
mount "/dev/disk/by-uuid/${ROOTFS_UUID}" -o "${BTRFS_OPTIONS}" "${MOUNT_POINT}"
cd "${MOUNT_POINT}"

# 圧縮
btrfs filesystem defragment -r -czstd .

# @サブボリュームを作成
btrfs subvolume snapshot . @

# @配下のサブボリュームを作成
btrfs subvolume create @home
btrfs subvolume create @root
btrfs subvolume create @var_log
btrfs subvolume create @snapshots

# @サブボリュームから@配下のサブボリュームにファイルをコピー
cp -RT --reflink=always home/ @home/
cp -RT --reflink=always root/ @root/
cp -RT --reflink=always var/log/ @var_log/

# ルートボリュームからファイルを削除
find . -mindepth 1 -maxdepth 1 \( -type d -or -type l \) -not -iname "@*" -exec rm -dr "{}" +

# @サブボリュームから@配下のサブボリュームと重複するファイルを削除
find @/home -mindepth 1 -maxdepth 1 -exec rm -dr "{}" +
find @/root -mindepth 1 -maxdepth 1 -exec rm -dr "{}" +
find @/var/log -mindepth 1 -maxdepth 1 -exec rm -dr "{}" +

# RAID1化
if [ -e "${DISK2}" ]; then
  btrfs device add -f "${ROOTFS2_PART}" .
  btrfs balance start -mconvert=raid1 -dconvert=raid1 .
fi
#btrfs balance start -mconvert=raid1,soft -dconvert=raid1,soft --bg / # 1台で運用した後に修復する場合

# @サブボリュームをデフォルト（GRUBがブートしようとする）に変更
btrfs subvolume set-default @

# fstabを作成
FSTAB_ARRAY=()
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} / btrfs defaults,subvol=@,${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /home btrfs defaults,subvol=@home,${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /root btrfs defaults,subvol=@root,${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /var/log btrfs defaults,subvol=@var_log,${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /.snapshots btrfs defaults,subvol=@snapshots,${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${EFI1_UUID} /boot/efi vfat defaults,nofail,x-systemd.device-timeout=5 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${SWAP1_UUID} none swap sw,nofail,x-systemd.device-timeout=5 0 0")
if [ -e "${DISK2}" ]; then
  FSTAB_ARRAY+=("/dev/disk/by-uuid/${EFI2_UUID} /boot/efi2 vfat defaults,nofail,x-systemd.device-timeout=5 0 0")
  FSTAB_ARRAY+=("/dev/disk/by-uuid/${SWAP2_UUID} none swap sw,nofail,x-systemd.device-timeout=5 0 0")
fi
printf -v FSTAB_STR "%s\n" "${FSTAB_ARRAY[@]}"
tee @/etc/fstab <<< "${FSTAB_STR}" > /dev/null

# GRUB設定の変更
tee @/etc/grub.d/19_linux_rootflags_degraded << EOF > /dev/null
#!/bin/sh
. "\$pkgdatadir/grub-mkconfig_lib"
TITLE="\$(echo "\${GRUB_DISTRIBUTOR} (rootflags=degraded)" | grub_quote)"
cat << EOS
menuentry '\$TITLE' {
  search --no-floppy --fs-uuid --set=root ${ROOTFS_UUID}
  linux /@/boot/vmlinuz root=UUID=${ROOTFS_UUID} ro rootflags=subvol=@,degraded \${GRUB_CMDLINE_LINUX} \${GRUB_CMDLINE_LINUX_DEFAULT}
  initrd /@/boot/initrd.img
}
EOS
EOF

chmod a+x @/etc/grub.d/19_linux_rootflags_degraded

# いったんアンマウント
cd /
umount -l "${MOUNT_POINT}"

# マウント
mount "${ROOTFS1_PART}" -o "subvol=@,${BTRFS_OPTIONS}" "${MOUNT_POINT}"
mount "${ROOTFS1_PART}" -o "subvol=@var_log,${BTRFS_OPTIONS}" "${MOUNT_POINT}/var/log"
mount "${EFI1_PART}" "${MOUNT_POINT}/boot/efi"
if [ -e "${DISK2}" ]; then
  mkdir "${MOUNT_POINT}/boot/efi2"
  mount "${EFI2_PART}" "${MOUNT_POINT}/boot/efi2"
fi

# GRUB・ESPを更新
if [ -e "${DISK2}" ]; then
  EFI_PARTS="${EFI1_PART} ${EFI2_PART}"
else
  EFI_PARTS="${EFI1_PART}"
fi
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y arch-install-scripts
arch-chroot "${MOUNT_POINT}" /bin/bash -eux -- << EOS
update-grub
debconf-set-selections <<< "grub-common grub-efi/install_devices multiselect ${EFI_PARTS}"
dpkg-reconfigure --frontend noninteractive shim-signed
EOS
