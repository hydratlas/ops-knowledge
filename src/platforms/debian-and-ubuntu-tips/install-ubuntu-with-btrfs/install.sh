#!/bin/bash
set -eux

SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"

source "$SCRIPT_DIR/scripts/initialize.sh" "${1}" "${2:-}"
source "$SCRIPT_DIR/scripts/common.sh"

# インストーラーによるマウントをアンマウント
if [ -n "${TARGET}" ]; then
    if mountpoint --quiet --nofollow "${TARGET}"; then
        umount -R "${TARGET}"
    fi
fi

# btrfsの/からマウント
mount "/dev/disk/by-uuid/${ROOTFS_UUID}" -o "subvol=/,${BTRFS_OPTIONS}" "${MOUNT_POINT}"
cd "${MOUNT_POINT}"

# @サブボリュームがなければ対応
if [ ! -e "${DEFAULT_SUBVOLUME_NAME}" ]; then
    if [ -e "@rootfs" ]; then
        # @rootfsサブボリュームがあれば、@サブボリュームにリネーム
        btrfs subvolume snapshot "@rootfs" "${DEFAULT_SUBVOLUME_NAME}"
        btrfs subvolume delete "@rootfs"
    elif [ -e "@" ]; then
        # @サブボリュームがあれば、@サブボリュームにリネーム（DEFAULT_SUBVOLUME_NAMEが@ではない場合に有効）
        btrfs subvolume snapshot "@" "${DEFAULT_SUBVOLUME_NAME}"
        btrfs subvolume delete "@"
    elif [ -e "usr" ]; then
        # /に直接ディレクトリーがあれば、@サブボリュームに変換
        # サブボリューム作成
        btrfs subvolume snapshot . "${DEFAULT_SUBVOLUME_NAME}"
        # ルートボリュームからファイルを削除
        find . -mindepth 1 -maxdepth 1 \( -type d -or -type l \) -not -iname "${DEFAULT_SUBVOLUME_NAME}" \
          -exec sh -c 'mountpoint --quiet --nofollow "$1" || rm -dr "$1"' _ {} \;
    else
        # なにも見つからなければエラー
        echo "Error: Cannot find installed root(/)." 1>&2
        exit 1
    fi
fi

# @サブボリュームをデフォルト（GRUBがブートしようとする）に変更
btrfs subvolume set-default "${DEFAULT_SUBVOLUME_NAME}"

function CREATE_SUBVOLUME () {
    local DIR="${1}"
    local SUBVOLUME_NAME="${2}"
    if [ -e "${SUBVOLUME_NAME}" ]; then
        return 0
    fi
    # サブボリューム作成
    btrfs subvolume create "${SUBVOLUME_NAME}"
    # ディレクトリーを念のため作成
    mkdir -p "${DIR}"
    # ファイルコピー
    if ! hash rsync 2>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y rsync
    fi
    rsync -a "${DIR}/" "${SUBVOLUME_NAME}/"
    # ファイル削除
    find "${DIR}" -mindepth 1 -maxdepth 1 -exec rm -dr "{}" +
}

# @homeサブボリュームがなければ作成
CREATE_SUBVOLUME "${DEFAULT_SUBVOLUME_NAME}/home" "${HOME_SUBVOLUME_NAME}"

# @rootサブボリュームがなければ作成
CREATE_SUBVOLUME "${DEFAULT_SUBVOLUME_NAME}/root" "${ROOT_SUBVOLUME_NAME}"

# @var_logサブボリュームがなければ作成
CREATE_SUBVOLUME "${DEFAULT_SUBVOLUME_NAME}/var/log" "${VAR_LOG_SUBVOLUME_NAME}"

# @snapshotsサブボリュームがなければ
if [ ! -e "${SNAPSHOTS_SUBVOLUME_NAME}" ]; then
  # サブボリューム作成
  btrfs subvolume create "${SNAPSHOTS_SUBVOLUME_NAME}"
fi

# 圧縮
btrfs filesystem defragment -r -czstd .

# RAID1化
if [ -e "${DISK2}" ]; then
    btrfs device add -f "${ROOTFS2_PART}" .
    btrfs balance start -mconvert=raid1 -dconvert=raid1 .
fi

# fstabを作成
FSTAB_ARRAY=()
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} / btrfs defaults,subvol=${DEFAULT_SUBVOLUME_NAME},${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /home btrfs defaults,subvol=${HOME_SUBVOLUME_NAME},${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /root btrfs defaults,subvol=${ROOT_SUBVOLUME_NAME},${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /var/log btrfs defaults,subvol=${VAR_LOG_SUBVOLUME_NAME},${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /.snapshots btrfs defaults,subvol=${SNAPSHOTS_SUBVOLUME_NAME},${BTRFS_OPTIONS} 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${EFI1_UUID} /boot/efi vfat defaults,nofail,x-systemd.device-timeout=5 0 0")
FSTAB_ARRAY+=("/dev/disk/by-uuid/${SWAP1_UUID} none swap sw,nofail,x-systemd.device-timeout=5 0 0")
if [ -e "${DISK2}" ]; then
    FSTAB_ARRAY+=("/dev/disk/by-uuid/${EFI2_UUID} /boot/efi2 vfat defaults,nofail,x-systemd.device-timeout=5 0 0")
    FSTAB_ARRAY+=("/dev/disk/by-uuid/${SWAP2_UUID} none swap sw,nofail,x-systemd.device-timeout=5 0 0")
fi
printf -v FSTAB_STR "%s\n" "${FSTAB_ARRAY[@]}"
tee "${DEFAULT_SUBVOLUME_NAME}/etc/fstab" <<< "${FSTAB_STR}" > /dev/null

# 縮退起動をサポート
if [ -e "${DISK2}" ]; then
    CREATE_DEGRADED_BOOT "${DEFAULT_SUBVOLUME_NAME}"
fi

# btrfsの/からのマウントをアンマウント
cd /
umount -l "${MOUNT_POINT}"

"$SCRIPT_DIR/scripts/finalize.sh"
