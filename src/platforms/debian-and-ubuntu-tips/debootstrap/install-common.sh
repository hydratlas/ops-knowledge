#!/bin/bash -eu
function diskname-to-diskpath () {
	if [ -n "${1:-}" ]; then
		DISK1_PATH="/dev/${1}"
	else
		DISK1_PATH=""
	fi
	if [ -n "${2:-}" ]; then
		DISK2_PATH="/dev/${2}"
	else
		DISK2_PATH=""
	fi
}

function diskpath-to-partitionpath () {
	local -r DISK1="${1:-}"
	local -r DISK2="${2:-}"
	if [ -e "${DISK1}" ]; then
		local -r DISK1_INFO="$(get-partition-path "${DISK1}")"
		DISK1_EFI="$(cut -f 1 <<< "${DISK1_INFO}")"
		DISK1_SWAP="$(cut -f 2 <<< "${DISK1_INFO}")"
		DISK1_ROOTFS="$(cut -f 3 <<< "${DISK1_INFO}")"
	else
		DISK1_EFI=""
		DISK1_SWAP=""
		DISK1_ROOTFS=""
	fi
	if [ -e "${DISK2}" ]; then
		local -r DISK2_INFO="$(get-partition-path "${DISK2}")"
		DISK2_EFI="$(cut -f 1 <<< "${DISK2_INFO}")"
		DISK2_SWAP="$(cut -f 2 <<< "${DISK2_INFO}")"
		DISK2_ROOTFS="$(cut -f 3 <<< "${DISK2_INFO}")"
	else
		DISK2_EFI=""
		DISK2_SWAP=""
		DISK2_ROOTFS=""
	fi
}

function get-partition-path () {
	local EFI=""
	local SWAP=""
	local ROOTFS=""
	while read LINE; do
		set ${LINE}
		local PATH="${1:-}"
		local PARTTYPE="${2:-}"
		if [ "${PARTTYPE}" = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]; then
			EFI="${PATH}"
		elif [ "${PARTTYPE}" = "0657fd6d-a4ab-43c4-84e5-0933c84b4f4f" ]; then
			SWAP="${PATH}"
		elif [ "${PARTTYPE}" = "4f68bce3-e8cd-4db1-96e7-fbcaf984b709" ]; then
			ROOTFS="${PATH}"
		fi
	done <<< "$(lsblk --output PATH,PARTTYPE --noheadings "${1}")"
	echo -e "${EFI}\t${SWAP}\t${ROOTFS}"
}

# unused
function partitionpath-to-fstype () {
	lsblk --output FSTYPE --noheadings "${1}"
}

function get-fs-UUID () {
	local UUID="$(lsblk -dno UUID "${1}")"
	if [ -z "${UUID}" ]; then
		echo "Failed to get UUID of ${1}" 1>&2
		exit 1
	fi
	echo "${UUID}"
}

function get-filesystem-UUIDs () {
	EFI1_UUID="$(get-fs-UUID "${DISK1_EFI}")"
	SWAP1_UUID="$(get-fs-UUID "${DISK1_SWAP}")"
	if [ -e "${DISK2_PATH}" ]; then
		EFI2_UUID="$(get-fs-UUID "${DISK2_EFI}")"
		SWAP2_UUID="$(get-fs-UUID "${DISK2_SWAP}")"
	fi
	ROOTFS_UUID="$(get-fs-UUID "${DISK1_ROOTFS}")"
}

function mount-installfs () {
	if [ "btrfs" = "${ROOT_FILESYSTEM}" ]; then
		mount "${DISK1_ROOTFS}" -o "${BTRFS_OPTIONS},subvol=@" --mkdir "${MOUNT_POINT}"
		mount "${DISK1_ROOTFS}" -o "${BTRFS_OPTIONS},subvol=@home" --mkdir "${MOUNT_POINT}/home"
		mount "${DISK1_ROOTFS}" -o "${BTRFS_OPTIONS},subvol=@home2" --mkdir "${MOUNT_POINT}/home2"
		mount "${DISK1_ROOTFS}" -o "${BTRFS_OPTIONS},subvol=@root" --mkdir "${MOUNT_POINT}/root"
		mount "${DISK1_ROOTFS}" -o "${BTRFS_OPTIONS},subvol=@var_log" --mkdir "${MOUNT_POINT}/var/log"
		mount "${DISK1_ROOTFS}" -o "${BTRFS_OPTIONS},subvol=@snapshots" --mkdir "${MOUNT_POINT}/.snapshots"
	elif [ "ext4" = "${ROOT_FILESYSTEM}" ]; then
		mount "${DISK1_ROOTFS}" -o "${EXT4_OPTIONS}" --mkdir "${MOUNT_POINT}"
	elif [ "xfs" = "${ROOT_FILESYSTEM}" ]; then
		mount "${DISK1_ROOTFS}" -o "${XFS_OPTIONS}" --mkdir "${MOUNT_POINT}"
	fi

	if [ -e "${DISK1_PATH}" ]; then
		mount "${DISK1_EFI}" --mkdir "${MOUNT_POINT}/boot/efi"
	fi
	if [ -e "${DISK2_PATH}" ]; then
		mount "${DISK2_EFI}" --mkdir "${MOUNT_POINT}/boot/efi2"
	fi
}
