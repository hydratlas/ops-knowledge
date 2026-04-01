#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "${SCRIPT_DIR}/install-config-base.sh"

# Base
DISTRIBUTION="ubuntu"
SUITE="mantic"
COMPONENTS=(main restricted universe multiverse)
VARIANT="minbase"

# Packages
MIRROR1="http://ftp.udx.icscoe.jp/Linux/ubuntu"
KEYRING_FILENAME="ubuntu-archive-keyring.gpg"
KEYS=( \
  'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x790bc7277767219c42c86f933b4fe6acc0b21f32' \
    # Ubuntu Archive Automatic Signing Key (2012)
  'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf6ecb3762474eda9d21b7022871920d1991bc93c' \
    # Ubuntu Archive Automatic Signing Key (2018)
  )
# SecurityTeam/FAQ - Ubuntu Wiki
# https://wiki.ubuntu.com/SecurityTeam/FAQ

# Base and Image
INSTALLATION_PACKAGES_FOR_BASE+=(landscape-common)
INSTALLATION_PACKAGES_FOR_IMAGE=(linux-generic)

# Firmware
INSTALLATION_PACKAGES_FOR_FIRMWARE+=(linux-firmware fwupd-signed)

# GNOME
INSTALLATION_PACKAGES_FOR_GNOME+=(policykit-desktop-privileges)

# systemd-timesyncd
FallbackNTP="ntp.ubuntu.com"

# Netplan
INSTALLATION_PACKAGES_FOR_NETPLAN=(network-manager netplan.io systemd-resolved)

# GRUB
INSTALLATION_PACKAGES_FOR_GRUB+=(shim-signed)
