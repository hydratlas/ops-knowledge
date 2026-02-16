#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "${SCRIPT_DIR}/install-config-base.sh"

# Base
DISTRIBUTION="debian"
SUITE="bookworm"
COMPONENTS=(main contrib non-free non-free-firmware)
VARIANT="minbase"

# Packages
MIRROR1="http://ftp.jp.debian.org/debian"
KEYRING_FILENAME="debian-archive-keyring.gpg"
KEYS=( \
  'https://ftp-master.debian.org/keys/release-10.asc' \
  'https://ftp-master.debian.org/keys/archive-key-10.asc' \
  'https://ftp-master.debian.org/keys/archive-key-10-security.asc' \
  'https://ftp-master.debian.org/keys/release-11.asc' \
  'https://ftp-master.debian.org/keys/archive-key-11.asc' \
  'https://ftp-master.debian.org/keys/archive-key-11-security.asc' \
  'https://ftp-master.debian.org/keys/release-12.asc' \
  'https://ftp-master.debian.org/keys/archive-key-12.asc' \
  'https://ftp-master.debian.org/keys/archive-key-12-security.asc' \
  )
# ftp-master.debian.org Archive Signing Keys
# https://ftp-master.debian.org/keys.html

# Base and Image
INSTALLATION_PACKAGES_FOR_BASE+=()
INSTALLATION_PACKAGES_FOR_IMAGE=(linux-image-amd64)

# Firmware
INSTALLATION_PACKAGES_FOR_FIRMWARE+=(firmware-linux fwupd-amd64-signed)

# systemd-timesyncd
FallbackNTP="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"

# GRUB
INSTALLATION_PACKAGES_FOR_GRUB+=(grub-efi-amd64 grub-efi-amd64-signed shim-signed)
