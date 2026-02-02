#!/bin/bash
set -eux

if ! hash btrfs 2>/dev/null; then
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y btrfs-progs
fi
if ! grep -Eq "^btrfs " /proc/modules; then
  modprobe btrfs
fi

export MOUNT_POINT="/mnt"

# ディスク
export DISK1="/dev/${1}"
if [ ! -e "${DISK1}" ]; then
  echo "Error: disk 1 not found." 1>&2
  exit 1
fi

if [ -n "${2:-}" ]; then
  export DISK2="/dev/${2}"
else
  export DISK2=""
fi

# Btrfsオプション
export BTRFS_OPTIONS="noatime,compress=zstd:1,degraded"
export DEFAULT_SUBVOLUME_NAME="@"
export HOME_SUBVOLUME_NAME="@home"
export ROOT_SUBVOLUME_NAME="@root"
export VAR_LOG_SUBVOLUME_NAME="@var_log"
export SNAPSHOTS_SUBVOLUME_NAME="@snapshots"

# パーティション
if [ -e "${DISK1}p1" ]; then
  export EFI1_PART="${DISK1}p1"
elif [ -e "${DISK1}1" ]; then
  export EFI1_PART="${DISK1}1"
else
  echo "Error: First partition on disk 1 not found." 1>&2
  exit 1
fi

if [ -e "${DISK1}p2" ]; then
  export SWAP1_PART="${DISK1}p2"
elif [ -e "${DISK1}2" ]; then
  export SWAP1_PART="${DISK1}2"
else
  echo "Error: Second partition on disk 1 not found." 1>&2
  exit 1
fi

if [ -e "${DISK1}p3" ]; then
  export ROOTFS1_PART="${DISK1}p3"
elif [ -e "${DISK1}3" ]; then
  export ROOTFS1_PART="${DISK1}3"
else
  echo "Error: Third partition on disk 1 not found." 1>&2
  exit 1
fi

if [ -e "${DISK2}" ]; then
  if [ -e "${DISK2}p1" ]; then
    export EFI2_PART="${DISK2}p1"
  elif [ -e "${DISK2}1" ]; then
    export EFI2_PART="${DISK2}1"
  else
    echo "Error: First partition on disk 2 not found." 1>&2
    exit 1
  fi

  if [ -e "${DISK2}p2" ]; then
    export SWAP2_PART="${DISK2}p2"
  elif [ -e "${DISK2}2" ]; then
    export SWAP2_PART="${DISK2}2"
  else
    echo "Error: Second partition on disk 2 not found." 1>&2
    exit 1
  fi

  if [ -e "${DISK2}p3" ]; then
    export ROOTFS2_PART="${DISK2}p3"
  elif [ -e "${DISK2}3" ]; then
    export ROOTFS2_PART="${DISK2}3"
  else
    echo "Error: Third partition on disk 2 not found." 1>&2
    exit 1
  fi
fi

# UUIDを取得
export EFI1_UUID="$(lsblk -dno UUID ${EFI1_PART})"
export SWAP1_UUID="$(lsblk -dno UUID ${SWAP1_PART})"
export ROOTFS_UUID="$(lsblk -dno UUID ${ROOTFS1_PART})"
if [ -e "${DISK2}" ]; then
  export EFI2_UUID="$(lsblk -dno UUID ${EFI2_PART})"
  export SWAP2_UUID="$(lsblk -dno UUID ${SWAP2_PART})"
fi

# インストール先を取得
CALAMARES_ROOT="$(find /tmp -maxdepth 1 -type d -iname "calamares-root-*" -print -quit)"
if [ -n "${CALAMARES_ROOT}" ]; then
  export TARGET="${CALAMARES_ROOT}"
else
  if [ -e "/target" ] && mountpoint --quiet --nofollow /target; then
    export TARGET="/target"
  else
    export TARGET=""
  fi
fi
