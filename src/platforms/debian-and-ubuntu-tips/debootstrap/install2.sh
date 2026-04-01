#!/bin/bash -eu
source "${1}"
readonly HOSTNAME="${2}"
source ./install-common.sh
diskname-to-diskpath "${3}" "${4:-}"
diskpath-to-partitionpath "${DISK1_PATH}" "${DISK2_PATH}"
get-filesystem-UUIDs

function install2 () {
	# Temporarily set language
	LANG_BAK="${LANG}"
	export LANG="${INSTALLATION_LANG}"

	# Configure locale
	PERL_SCRIPT=$(cat <<- EOS
	s/^#? *${INSTALLATION_LANG}/${INSTALLATION_LANG}/g;
	s/^#? *${USER_LANG}/${USER_LANG}/g;
	EOS
	)
	perl -pi -e "${PERL_SCRIPT}" "${MOUNT_POINT}/etc/locale.gen"
	tee "${MOUNT_POINT}/etc/default/locale" <<< "LANG=${INSTALLATION_LANG}" > /dev/null
	cat "${MOUNT_POINT}/etc/default/locale" # confirmation

	# Configure time zone
	ln -sf "/usr/share/zoneinfo/${TIMEZONE}" "${MOUNT_POINT}/etc/localtime"
	readlink "/etc/localtime" # confirmation

	# Configure keyboard
	PERL_SCRIPT=$(cat <<- EOS
	s/^XKBMODEL=.+\$/XKBMODEL=\"${XKBMODEL}\"/g;
	s/^XKBLAYOUT=.+\$/XKBLAYOUT=\"${XKBLAYOUT}\"/g;
	s/^XKBVARIANT=.+\$/XKBVARIANT=\"${XKBVARIANT}\"/g;
	EOS
	)
	perl -pi -e "${PERL_SCRIPT}" "${MOUNT_POINT}/etc/default/keyboard"
	cat "${MOUNT_POINT}/etc/default/keyboard" # confirmation

	# dpkg-reconfigure
	arch-chroot "${MOUNT_POINT}" /bin/bash -eux -- <<- EOS
	locale-gen &&
	dpkg-reconfigure --frontend noninteractive locales
	dpkg-reconfigure --frontend noninteractive tzdata
	dpkg-reconfigure --frontend noninteractive keyboard-configuration
	EOS

	# Set hostname
	tee "${MOUNT_POINT}/etc/hostname" <<< "${HOSTNAME}" > /dev/null
	cat "${MOUNT_POINT}/etc/hostname" # confirmation
	tee "${MOUNT_POINT}/etc/hosts" <<- EOS > /dev/null
	127.0.0.1 localhost
	127.0.1.1 ${HOSTNAME}
	::1     ip6-localhost ip6-loopback
	fe00::0 ip6-localnet
	ff00::0 ip6-mcastprefix
	ff02::1 ip6-allnodes
	ff02::2 ip6-allrouters
	EOS
	cat "${MOUNT_POINT}/etc/hosts" # confirmation

	# Create user
	arch-chroot "${MOUNT_POINT}" /bin/bash -eux -- <<- EOS
	passwd -l root
	useradd --password '${USER_PASSWORD}' --user-group --groups sudo --shell /bin/bash \
		--create-home --home-dir "${USER_HOME_DIR}" "${USER_NAME}"
	EOS
	if [ -n "${USER_PUBKEYURL}" ]; then
		mkdir -p "${MOUNT_POINT}${USER_HOME_DIR}/.ssh"
		wget -O "${MOUNT_POINT}${USER_HOME_DIR}/.ssh/authorized_keys" "${USER_PUBKEYURL}"
		chmod u=rw,go= "${MOUNT_POINT}${USER_HOME_DIR}/.ssh/authorized_keys"
		cat "${MOUNT_POINT}${USER_HOME_DIR}/.ssh/authorized_keys" # confirmation
	fi
	arch-chroot "${MOUNT_POINT}" chown -R "${USER_NAME}:${USER_NAME}" "${USER_HOME_DIR}"
	tee -a "${MOUNT_POINT}${USER_HOME_DIR}/.bashrc" <<< "export LANG=${USER_LANG}" > /dev/null
	if "${USER_NO_SUDO_PASSWORD}"; then
		tee "${MOUNT_POINT}/etc/sudoers.d/90-adm" <<< "%sudo ALL=(ALL) NOPASSWD: ALL" > /dev/null
	fi

	# Other installations
	setup-systemd-timesyncd
	if "${IS_SSH_SERVER_INSTALLATION}"; then
		setup-ssh-server
	fi
	if "${IS_SYSTEMD_NETWORKD_INSTALLATION}"; then
		setup-systemd-networkd
	fi
	if "${IS_NETWORK_MANAGER_INSTALLATION}"; then
		setup-network-manager
	fi
	if "${IS_NETPLAN_INSTALLATION}"; then
		setup-netplan
	fi
	if "${IS_GRUB_INSTALLATION}"; then
		setup-grub
	fi

	export LANG="${LANG_BAK}"
}

function setup-systemd-timesyncd () {
	if ${IS_SYSTEMD_TIMESYNCD_ENABLED}; then
		arch-chroot "${MOUNT_POINT}" systemctl enable systemd-timesyncd.service
	else
		arch-chroot "${MOUNT_POINT}" systemctl disable systemd-timesyncd.service
	fi
	tee "${MOUNT_POINT}/etc/systemd/timesyncd.conf" <<- EOS > /dev/null
	[Time]
	NTP=${NTP}
	FallbackNTP=${FallbackNTP}
	EOS
}

# SSH server
function setup-ssh-server () {
	tee "${MOUNT_POINT}/etc/ssh/ssh_config.d/20-local.conf" <<- EOS > /dev/null
	PasswordAuthentication no
	PermitRootLogin no
	EOS
	cat "${MOUNT_POINT}/etc/ssh/ssh_config.d/20-local.conf" # confirmation
}

# systemd-networkd
function setup-systemd-networkd () {
	if ${MDNS}; then
		setup-mdns
	fi

	setup-systemd-networkd-core

	# Configuration
	tee "${MOUNT_POINT}/etc/systemd/network/10-dhcp-all.network" <<- EOS > /dev/null
	[Match]
	Name=en*

	[Network]
	DHCP=yes
	EOS
	cat "${MOUNT_POINT}/etc/systemd/network/10-dhcp-all.network" # confirmation

	if [ "off" != "${WOL}" ]; then
		tee "${MOUNT_POINT}/etc/systemd/network/10-wol-all.link" <<- EOS > /dev/null
		[Match]
		OriginalName=*

		[Link]
		WakeOnLan=${WOL}
		EOS
		cat "${MOUNT_POINT}/etc/systemd/network/10-wol-all.link" # confirmation
	fi

	arch-chroot "${MOUNT_POINT}" systemctl enable systemd-networkd.service
}
function setup-systemd-networkd-core () {
	# If one interface can be connected, it will start without waiting.
	mkdir -p "${MOUNT_POINT}/etc/systemd/system/systemd-networkd-wait-online.service.d"
	tee "${MOUNT_POINT}/etc/systemd/system/systemd-networkd-wait-online.service.d/wait-for-only-one-interface.conf" <<- EOS > /dev/null
	[Service]
	ExecStart=
	ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any
	EOS
	cat "${MOUNT_POINT}/etc/systemd/system/systemd-networkd-wait-online.service.d/wait-for-only-one-interface.conf" # confirmation
}

# NetworkManager
function setup-network-manager () {
	if ${MDNS}; then
		setup-mdns
	fi

	setup-network-manager-core

	if [ "off" != "${WOL}" ]; then
		tee "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-wol.conf" <<- EOS > /dev/null
		[connection]
		802-3-ethernet.wake-on-lan=${WOL}
		EOS
		cat "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-wol.conf" # confirmation
	fi

	tee "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-dns.conf" <<- EOS > /dev/null
	[main]
	dns=systemd-resolved
	EOS
	cat "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-dns.conf" # confirmation

	arch-chroot "${MOUNT_POINT}" systemctl enable NetworkManager.service
}
function setup-network-manager-core () {
	if [ ! -f "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf" ]; then
		tee "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf" <<- EOS > /dev/null
		[connection]
		wifi.powersave=3
		EOS
		cat "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf" # confirmation
	fi
}

# Netplan
function setup-netplan () {
	if ${MDNS}; then
		setup-mdns
	fi

	if [ -f "${MOUNT_POINT}/usr/bin/nmcli" ]; then
		setup-network-manager-core

		tee "${MOUNT_POINT}/etc/netplan/01-network-manager-all.yaml" <<- EOS > /dev/null
		network:
		  version: 2
		  renderer: NetworkManager
		EOS
		cat "${MOUNT_POINT}/etc/netplan/01-network-manager-all.yaml"  # confirmation
		chmod u=rw,go= "${MOUNT_POINT}/etc/netplan/01-network-manager-all.yaml"
	else
		setup-systemd-networkd-core
	fi

	local IS_WOL=false
	if [ "off" != "${WOL}" ]; then
		IS_WOL=true
	fi
	tee "${MOUNT_POINT}/etc/netplan/60-custom.yaml" <<- EOS > /dev/null
	network:
	  ethernets:
	    eth0:
	      match:
	        name: en*
	      dhcp4: true
	      dhcp6: true
	      wakeonlan: ${IS_WOL}
	EOS
	chmod u=rw,go= "${MOUNT_POINT}/etc/netplan/60-custom.yaml"

	arch-chroot "${MOUNT_POINT}" /bin/bash -eux -- <<- EOS
	systemctl enable NetworkManager.service
	netplan generate
	EOS
}

function setup-mdns () {
	if [ -d "${MOUNT_POINT}/etc/systemd/network" ]; then
		tee "${MOUNT_POINT}/etc/systemd/network/10-mdns-all.network" <<- EOS > /dev/null
		[Match]
		Name=en*

		[Network]
		MulticastDNS=yes
		EOS
		cat "${MOUNT_POINT}/etc/systemd/network/10-mdns-all.network" # confirmation
	fi

	if [ -f "${MOUNT_POINT}/etc/systemd/resolved.conf" ]; then
		if ${MDNS}; then
			local -r MDNS_STR="yes"
		else
			local -r MDNS_STR="no"
		fi
		perl -pi -e "s/^#?MulticastDNS=.*\$/MulticastDNS=${MDNS_STR}/g" "${MOUNT_POINT}/etc/systemd/resolved.conf"
	fi

	if [ -d "${MOUNT_POINT}/etc/NetworkManager/conf.d" ]; then
		tee "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-mdns.conf" <<- EOS > /dev/null
		[connection]
		connection.mdns=2
		EOS
		cat "${MOUNT_POINT}/etc/NetworkManager/conf.d/default-mdns.conf" # confirmation
	fi
}

# GRUB
function setup-grub () {
	if [ "ubuntu" = "${DISTRIBUTION}" ]; then
		setup-grub-on-ubuntu
	elif [ "debian" = "${DISTRIBUTION}" ]; then
		setup-grub-on-debian
	fi
	efibootmgr -v
}
function setup-grub-on-ubuntu () {
	adding-entries-to-grub "/@/boot/vmlinuz" "/@/boot/initrd.img"

	if [ -e "${DISK2_PATH}" ]; then
		local -r ESPs="${DISK1_EFI}, ${DISK2_EFI}"
	else
		local -r ESPs="${DISK1_EFI}"
	fi
	
	arch-chroot "${MOUNT_POINT}" /bin/bash -eux -- <<- EOS
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --no-nvram
	update-grub
	debconf-set-selections <<< "grub-common grub-efi/install_devices multiselect ${ESPs}"
	dpkg-reconfigure --frontend noninteractive shim-signed
	update-grub
	EOS
}
function setup-grub-on-debian () {
	adding-entries-to-grub "/@/boot/vmlinuz" "/@/boot/initrd.img" # /etc/kernel-img.conf link_in_boot = yes

	if [ -e "${DISK2_PATH}" ]; then
		create-second-esp-entry
	fi

	arch-chroot "${MOUNT_POINT}" /bin/bash -eux -- <<- EOS
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --no-nvram
	update-grub
	debconf-set-selections <<< "grub-efi-amd64 grub2/force_efi_extra_removable boolean true"
	dpkg-reconfigure --frontend noninteractive grub-efi-amd64
	update-grub
	EOS
}
function adding-entries-to-grub () {
	local -r LINUX_PATH="${1}"
	local -r INITRD_PATH="${2}"
	local -r PERL_SCRIPT=$(cat <<- EOS
	s/^#?GRUB_CMDLINE_LINUX_DEFAULT=.*\$/GRUB_CMDLINE_LINUX_DEFAULT=\"${GRUB_CMDLINE_LINUX_DEFAULT}\"/g;
	s/^#?GRUB_TIMEOUT=.*\$/GRUB_TIMEOUT=${GRUB_TIMEOUT}/g;
	s/^#?GRUB_DISABLE_OS_PROBER=.*\$/GRUB_DISABLE_OS_PROBER=${GRUB_DISABLE_OS_PROBER}/g;
	EOS
	)
	perl -pi -e "${PERL_SCRIPT}" "${MOUNT_POINT}/etc/default/grub"
	tee -a "${MOUNT_POINT}/etc/default/grub" <<< "GRUB_RECORDFAIL_TIMEOUT=${GRUB_TIMEOUT}" > /dev/null
	if [ "btrfs" = "${ROOT_FILESYSTEM}" ]; then
		mkdir -p "${MOUNT_POINT}/etc/grub.d"
		tee "${MOUNT_POINT}/etc/grub.d/19_linux_rootflags_degraded" <<- EOF > /dev/null
		#!/bin/sh
		. "\$pkgdatadir/grub-mkconfig_lib"
		TITLE="\$(echo "\${GRUB_DISTRIBUTOR} (rootflags=degraded)" | grub_quote)"
		cat << EOS
		menuentry '\$TITLE' {
			search --no-floppy --fs-uuid --set=root ${ROOTFS_UUID}
			linux ${LINUX_PATH} root=UUID=${ROOTFS_UUID} ro rootflags=subvol=@,degraded \${GRUB_CMDLINE_LINUX} \${GRUB_CMDLINE_LINUX_DEFAULT}
			initrd ${INITRD_PATH}
		}
		EOS
		EOF
		chmod a+x "${MOUNT_POINT}/etc/grub.d/19_linux_rootflags_degraded"

		cat "${MOUNT_POINT}/etc/grub.d/19_linux_rootflags_degraded" # confirmation
	fi
}
function create-second-esp-entry () {
	local -r DISTRIBUTOR="$(arch-chroot "${MOUNT_POINT}" lsb_release -i -s 2> /dev/null || echo Debian)"
	local -r ENTRY_LABEL="${DISTRIBUTOR} (Second EFI system partition)"
	local -r DISK2_EFI_PART="${DISK2_EFI: -1}" && # A space is required before the minus sign.
	local -r PATTERN="^Boot([0-9A-F]+)\* (.+)$" &&
	while read LINE; do
		if [[ ${LINE} =~ $PATTERN ]]; then
			if [[ "${ENTRY_LABEL}" == "${BASH_REMATCH[2]}" ]]; then
				efibootmgr -b "${BASH_REMATCH[1]}" -B
			fi
		fi
	done <<< efibootmgr

	arch-chroot "${MOUNT_POINT}" /bin/bash -eux -- <<- EOS
	grub-install --target=x86_64-efi --efi-directory=/boot/efi2 --removable --no-nvram
	efibootmgr --quiet --create-only --disk "${DISK2_PATH}" --part "${DISK2_EFI_PART}" \
		--loader /EFI/BOOT/bootx64.efi --label "${ENTRY_LABEL}" --unicode 
	EOS
}

install2
