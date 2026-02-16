#!/bin/vbash
source /opt/vyatta/etc/functions/script-template
set -euo pipefail

NEW_IMAGE_URL=$(curl -Ls "https://api.github.com/repos/vyos/vyos-rolling-nightly-builds/releases/latest" | grep browser_download_url | head -n 1 | cut -d\" -f4)
if [ -z "${NEW_IMAGE_URL}" ]; then
    exit 0
fi
echo "Download URL: ${NEW_IMAGE_URL}"
printf '%s\n' "" "Yes" "Yes" "Yes" | /opt/vyatta/bin/vyatta-op-cmd-wrapper add system image "${NEW_IMAGE_URL}" || exit 0
echo "Download Completed"

IMAGE_JSON="$(/usr/libexec/vyos/op_mode/image_info.py show_images_summary --raw)"
DEFAULT_IMAGE="$(echo "${IMAGE_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['image_default'])")"
RUNNING_IMAGE="$(echo "${IMAGE_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['image_running'])")"
ALL_IMAGES="$(echo "${IMAGE_JSON}" | python3 -c "import sys,json; [print(i) for i in json.load(sys.stdin)['images_available']]")"

while IFS= read -r IMAGE_NAME; do
    if [ -n "${IMAGE_NAME}" ] && [ "${IMAGE_NAME}" != "${DEFAULT_IMAGE}" ] && [ "${IMAGE_NAME}" != "${RUNNING_IMAGE}" ]; then
        printf '%s\n' "Yes" | /opt/vyatta/bin/vyatta-op-cmd-wrapper delete system image "${IMAGE_NAME}"
        echo "Delete: ${IMAGE_NAME}"
    fi
done <<< "${ALL_IMAGES}"

/sbin/reboot
