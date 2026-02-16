#!/bin/bash -eu
source "${1}"
DISK1="${2:-}"
DISK2="${3:-}"
source ./install-common.sh
diskname-to-diskpath "${DISK1}" "${DISK2}"
diskpath-to-partitionpath "${DISK1_PATH}" "${DISK2_PATH}"

mount-installfs
