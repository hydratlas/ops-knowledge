#!/bin/bash
set -eux

function GET_VMLINUZ_PATH () {
    local BASE_PATH="${1}"
    if [ -e "${BASE_PATH}/boot/vmlinuz" ]; then
        echo "/boot/vmlinuz"
    elif [ -e "${BASE_PATH}/vmlinuz" ]; then
        echo "/vmlinuz"
    else
        echo "Error: vmlinuz not found." 1>&2
        return 1
    fi
}
function GET_INITRD_PATH () {
    local BASE_PATH="${1}"
    if [ -e "${BASE_PATH}/boot/initrd.img" ]; then
        echo "/boot/initrd.img"
    elif [ -e "${BASE_PATH}/initrd.img" ]; then
        echo "/initrd.img"
    else
        echo "Error: initrd.img not found." 1>&2
        return 1
    fi
}
function CREATE_DEGRADED_BOOT () {
    local BASE_PATH="${1}"
    local VMLINUZ="$(GET_VMLINUZ_PATH "${BASE_PATH}")"
    local INITRD="$(GET_INITRD_PATH "${BASE_PATH}")"

    tee "${BASE_PATH}/etc/grub.d/19_linux_rootflags_degraded" << EOF > /dev/null
#!/bin/sh
. "\$pkgdatadir/grub-mkconfig_lib"
TITLE="\$(echo "\${GRUB_DISTRIBUTOR} (rootflags=degraded)" | grub_quote)"
ROOTSUBVOL="\`make_system_path_relative_to_its_root /\`"
ROOTSUBVOL="\${ROOTSUBVOL#/}"
cat << EOS
menuentry '\$TITLE' {
  search --no-floppy --fs-uuid --set=root ${ROOTFS_UUID}
  linux /\${ROOTSUBVOL}${VMLINUZ} root=UUID=${ROOTFS_UUID} ro rootflags=subvol=\${ROOTSUBVOL},degraded \${GRUB_CMDLINE_LINUX} \${GRUB_CMDLINE_LINUX_DEFAULT}
  initrd /\${ROOTSUBVOL}${INITRD}
}
EOS
EOF
    chmod a+x "${BASE_PATH}/etc/grub.d/19_linux_rootflags_degraded"
}
function CREATE_SNAPSHOT_BOOT () {
    local BASE_PATH="${1}"
    local SNAPSHOT_NAME="${2}"
    local VMLINUZ="$(GET_VMLINUZ_PATH "${SNAPSHOT_NAME}")"
    local INITRD="$(GET_INITRD_PATH "${SNAPSHOT_NAME}")"

    local OLD_DISTRIBUTION="$(grep -oP '(?<=^PRETTY_NAME=").+(?="$)' "${SNAPSHOT_NAME}/etc/os-release")"

    tee "${BASE_PATH}/etc/grub.d/18_old_linux" << EOF > /dev/null
#!/bin/sh
. "\$pkgdatadir/grub-mkconfig_lib"
TITLE="\$(echo "${OLD_DISTRIBUTION} (snapshot: ${OLD_SNAPSHOT_NAME})" | grub_quote)"
cat << EOS
menuentry '\$TITLE' {
search --no-floppy --fs-uuid --set=root ${ROOTFS_UUID}
linux /${SNAPSHOT_NAME}${VMLINUZ} root=UUID=${ROOTFS_UUID} ro rootflags=subvol=${SNAPSHOT_NAME} \${GRUB_CMDLINE_LINUX} \${GRUB_CMDLINE_LINUX_DEFAULT}
initrd /${SNAPSHOT_NAME}${INITRD}
}
EOS
EOF
    chmod a+x "${BASE_PATH}/etc/grub.d/18_old_linux"
}
