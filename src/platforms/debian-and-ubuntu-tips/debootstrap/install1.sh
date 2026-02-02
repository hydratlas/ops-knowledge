#!/bin/bash -eu
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "${1}"
readonly HOSTNAME="${2}"
source ./install-common.sh
diskname-to-diskpath "${3}" "${4:-}"

function install1 () {
	if [ "mmdebstrap" = "${INSTALLER}" ]; then
		P="mmdebstrap"
	elif [ "debootstrap" = "${INSTALLER}" ]; then
		P="debootstrap"
	fi
	P="${P} gdisk util-linux wget efibootmgr arch-install-scripts"
	DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y ${P}

	# Partitioning
	function disk-partitioning () {
		wipefs --all "${1}"
		sgdisk \
			-Z \
			-n "0::${2}" -t 0:ef00 \
			-n "0::${3}" -t 0:8200 \
			-n "0::"     -t 0:8304 "${1}"
		mkfs.vfat -F 32 "${1}1"
		mkswap "${1}2"
	}

	for i in {1..2} ; do
		disk-partitioning "${DISK1_PATH}" "${EFI_END}" "${SWAP_END}"
		if [ -e "${DISK2_PATH}" ]; then
			disk-partitioning "${DISK2_PATH}" "${EFI_END}" "${SWAP_END}"
		fi
		sleep 1s
	done

	# Formatting
	if [ "btrfs" = "${ROOT_FILESYSTEM}" ]; then
		if [ -e "${DISK2_PATH}" ]; then
			mkfs.btrfs -f -d raid1 -m raid1 "${DISK1_PATH}3" "${DISK2_PATH}3"
		else
			mkfs.btrfs -f "${DISK1_PATH}3"
		fi
	elif [ "ext4" = "${ROOT_FILESYSTEM}" ]; then
		mkfs.ext4 -F "${DISK1_PATH}3"
	elif [ "xfs" = "${ROOT_FILESYSTEM}" ]; then
		mkfs.xfs -f "${DISK1_PATH}3"
	fi

	# Create Btrfs subvolumes
	if [ "btrfs" = "${ROOT_FILESYSTEM}" ]; then
		mount "${DISK1_ROOTFS}" -o "${BTRFS_OPTIONS}" --mkdir "${MOUNT_POINT}"
		btrfs subvolume create "${MOUNT_POINT}/@"
		btrfs subvolume create "${MOUNT_POINT}/@home"
		btrfs subvolume create "${MOUNT_POINT}/@home2"
		btrfs subvolume create "${MOUNT_POINT}/@root"
		btrfs subvolume create "${MOUNT_POINT}/@var_log"
		btrfs subvolume create "${MOUNT_POINT}/@snapshots"
		btrfs subvolume set-default "${MOUNT_POINT}/@"
		btrfs subvolume list "${MOUNT_POINT}" # confirmation
		umount "${MOUNT_POINT}"
	fi

	# Get Partition Path
	diskpath-to-partitionpath "${DISK1_PATH}" "${DISK2_PATH}"

	# Set UUIDs
	get-filesystem-UUIDs

	# Mount installation filesystem
	mount-installfs

	# Install distribution
	install-distribution

	# Create fstab
	create-fstab

	# Create kernel-img.conf
	tee "${MOUNT_POINT}/etc/kernel-img.conf" <<- EOS > /dev/null
	do_symlinks = yes
	do_bootloader = no
	do_initrd = yes
	link_in_boot = yes
	EOS

	# Get snapshot
	if [ "btrfs" = "${ROOT_FILESYSTEM}" ]; then
		btrfs subvolume snapshot -r "${MOUNT_POINT}" "${MOUNT_POINT}/.snapshots/after-installation"
	fi
}
function install-distribution () {
	local PACKAGES=()
	PACKAGES+=(${INSTALLATION_PACKAGES[@]})
	PACKAGES+=(${INSTALLATION_PACKAGES_FOR_BASE[@]})
	PACKAGES+=(${INSTALLATION_PACKAGES_FOR_IMAGE[@]})
	if "${IS_FIRMWARE_INSTALLATION}"; then
		PACKAGES+=(${INSTALLATION_PACKAGES_FOR_FIRMWARE[@]})
	fi
	if "${IS_QEMU_GUEST_INSTALLATION}"; then
		PACKAGES+=(${INSTALLATION_PACKAGES_FOR_QEMU_GUEST[@]})
	fi
	if "${IS_GNOME_INSTALLATION}"; then
		PACKAGES+=(${INSTALLATION_PACKAGES_FOR_GNOME[@]})
	fi
	if "${IS_SSH_SERVER_INSTALLATION}"; then
		PACKAGES+=(${INSTALLATION_PACKAGES_FOR_SSH_SERVER[@]})
	fi
	if "${IS_SYSTEMD_NETWORKD_INSTALLATION}"; then
		PACKAGES+=(${INSTALLATION_PACKAGES_FOR_SYSTEMD_NETWORKD[@]})
	fi
	if "${IS_NETWORK_MANAGER_INSTALLATION}"; then
		PACKAGES+=(${INSTALLATION_PACKAGES_FOR_NETWORK_MANAGER[@]})
	fi
	if "${IS_NETPLAN_INSTALLATION}"; then
		PACKAGES+=(${INSTALLATION_PACKAGES_FOR_NETPLAN[@]})
	fi
	if "${IS_GRUB_INSTALLATION}"; then
		PACKAGES+=(${INSTALLATION_PACKAGES_FOR_GRUB[@]})
	fi
	if [ "btrfs" = "${ROOT_FILESYSTEM}" ]; then
		PACKAGES+=(btrfs-progs)
	fi
	if [ "xfs" = "${ROOT_FILESYSTEM}" ]; then
		PACKAGES+=(xfsprogs)
	fi

	local KEY_FILE="${SCRIPT_DIR}/debootstrap-key.asc"
	local KEYRING_FILE="/usr/local/share/${KEYRING_FILENAME}"
	# Keyring
	if [ -f "${KEY_FILE}" ]; then
		rm "${KEY_FILE}"
	fi
	if [ -f "${KEYRING_FILE}" ]; then
		rm "${KEYRING_FILE}"
	fi
	for KEY in "${KEYS[@]}"; do
		wget -O "${KEY_FILE}" "${KEY}"
		gpg --no-default-keyring --keyring="${KEYRING_FILE}" --import "${KEY_FILE}"
		rm "${KEY_FILE}"
	done

	if [ "mmdebstrap" = "${INSTALLER}" ]; then
		mmdebstrap --skip=check/empty \
			--components="$(IFS=","; echo "${COMPONENTS[*]}")" --variant="${VARIANT}" --include="$(IFS=","; echo "${PACKAGES[*]}")" \
			"${SUITE}" "${MOUNT_POINT}" "deb [signed-by=${KEYRING_FILE}] ${MIRROR1} ${SUITE} $(IFS=" "; echo "${COMPONENTS[*]}")"
		tee "${MOUNT_POINT}/etc/apt/sources.list" <<< "deb ${MIRROR1} ${SUITE} $(IFS=" "; echo "${COMPONENTS[*]}")"
	elif [ "debootstrap" = "${INSTALLER}" ]; then
		mkdir -p "${CACHE_DIR}"
		if [ "standard" = "${VARIANT}" ]; then
			debootstrap --cache-dir="${CACHE_DIR}" --keyring="${KEYRING_FILE}" \
				--components="$(IFS=","; echo "${COMPONENTS[*]}")" --include="$(IFS=","; echo "${PACKAGES[*]}")" \
				"${SUITE}" "${MOUNT_POINT}" "${MIRROR1}"
		else
			debootstrap --cache-dir="${CACHE_DIR}" --keyring="${KEYRING_FILE}" --variant="${VARIANT}" \
				--components="$(IFS=","; echo "${COMPONENTS[*]}")" --include="$(IFS=","; echo "${PACKAGES[*]}")" \
				"${SUITE}" "${MOUNT_POINT}" "${MIRROR1}"
		fi
	fi
	rm "${KEYRING_FILE}"
}
function create-fstab () {
	local FSTAB_ARRAY=()
	if [ "btrfs" = "${ROOT_FILESYSTEM}" ]; then
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} / btrfs ${BTRFS_OPTIONS},subvol=@ 0 0")
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /home btrfs ${BTRFS_OPTIONS},subvol=@home 0 0")
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /home2 btrfs ${BTRFS_OPTIONS},subvol=@home2 0 0")
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /root btrfs ${BTRFS_OPTIONS},subvol=@root 0 0")
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /var/log btrfs ${BTRFS_OPTIONS},subvol=@var_log 0 0")
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} /.snapshots btrfs ${BTRFS_OPTIONS},subvol=@snapshots 0 0")
	elif [ "ext4" = "${ROOT_FILESYSTEM}" ]; then
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} / ext4 ${EXT4_OPTIONS} 0 0")
	elif [ "xfs" = "${ROOT_FILESYSTEM}" ]; then
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${ROOTFS_UUID} / xfs ${XFS_OPTIONS} 0 0")
	fi

	FSTAB_ARRAY+=("/dev/disk/by-uuid/${EFI1_UUID} /boot/efi vfat defaults,nofail,x-systemd.device-timeout=5 0 0")
	FSTAB_ARRAY+=("/dev/disk/by-uuid/${SWAP1_UUID} none swap sw,nofail,x-systemd.device-timeout=5 0 0")

	if [ -e "${DISK2_PATH}" ]; then
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${EFI2_UUID} /boot/efi2 vfat defaults,nofail,x-systemd.device-timeout=5 0 0")
		FSTAB_ARRAY+=("/dev/disk/by-uuid/${SWAP2_UUID} none swap sw,nofail,x-systemd.device-timeout=5 0 0")
	fi
	printf "%s\n" "${FSTAB_ARRAY[@]}" | tee "${MOUNT_POINT}/etc/fstab" > /dev/null
	cat "${MOUNT_POINT}/etc/fstab" # confirmation
}
install1
