#!/bin/bash
set -eux

function UBUNTU_FINALIZE () {
    if [ -e "${DISK2}" ]; then
        local EFI_PARTS="${EFI1_PART} ${EFI2_PART}"
    else
        local EFI_PARTS="${EFI1_PART}"
    fi
    chroot "${MOUNT_POINT}" /bin/bash -eux -- << EOS
update-grub
debconf-set-selections <<< "grub-common grub-efi/install_devices multiselect ${EFI_PARTS}"
dpkg-reconfigure --frontend noninteractive shim-signed
EOS
}

function DEBIAN_FINALIZE () {
    chroot "${MOUNT_POINT}" /bin/bash -eux -- << EOS
update-grub
dpkg-reconfigure --frontend noninteractive shim-signed
EOS
    if [ ! -e "${DISK2}" ]; then
        return 0
    fi
    # EFI system partitionを冗長化する
    find "${MOUNT_POINT}/boot/efi2" -mindepth 1 -maxdepth 1 -exec rm -dr "{}" +
    find "${MOUNT_POINT}/boot/efi" -mindepth 1 -maxdepth 1 -exec cp --recursive --force -p "{}" "${MOUNT_POINT}/boot/efi2" \;
    if ! hash efibootmgr 2>/dev/null; then
      DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y efibootmgr
    fi
    efibootmgr --create --disk "${DISK2}" --label debian --loader '\EFI\debian\shimx64.efi'

    # EFI system partitionの冗長化を自動化する
    chroot "${MOUNT_POINT}" /bin/bash -eux -- << EOS
DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y rsync
EOS
    tee "${MOUNT_POINT}/etc/grub.d/90_copy_to_boot_efi2" << EOF > /dev/null
#!/bin/sh
set -eu

if mountpoint --quiet --nofollow /boot/efi && mountpoint --quiet --nofollow /boot/efi2 ; then
    rsync --times --recursive --delete /boot/efi/ /boot/efi2/
fi
exit 0
EOF
    chmod a+x "${MOUNT_POINT}/etc/grub.d/90_copy_to_boot_efi2"
}

# 本番と同じ形でマウント
mount "${ROOTFS1_PART}" -o "subvol=${DEFAULT_SUBVOLUME_NAME},${BTRFS_OPTIONS}" "${MOUNT_POINT}"
mount "${ROOTFS1_PART}" -o "subvol=${VAR_LOG_SUBVOLUME_NAME},${BTRFS_OPTIONS}" "${MOUNT_POINT}/var/log"
mount "${EFI1_PART}" "${MOUNT_POINT}/boot/efi"
if [ -e "${DISK2}" ]; then
    mkdir -p "${MOUNT_POINT}/boot/efi2"
    mount "${EFI2_PART}" "${MOUNT_POINT}/boot/efi2"
fi
mount -t proc /proc "${MOUNT_POINT}/proc"
mount -t sysfs /sys "${MOUNT_POINT}/sys"
mount -o bind /dev "${MOUNT_POINT}/dev"
#mount -o bind /dev/pts "${MOUNT_POINT}/dev/pts"
mount -o bind /sys/firmware/efi/efivars "${MOUNT_POINT}/sys/firmware/efi/efivars"

# GRUB・ESPを更新
OS_ID="$(grep -oP '(?<=^ID=).+(?=$)' /etc/os-release)" &&
if [ "ubuntu" = "${OS_ID}" ]; then
    UBUNTU_FINALIZE
else
    DEBIAN_FINALIZE
fi
