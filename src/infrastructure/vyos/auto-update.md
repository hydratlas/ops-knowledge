# VyOSの自動アップデートの設定

## REST API用のキーのセットアップ

```bash
REST_KEY="$(uuidgen)" &&
KEY_NAME="main" &&
/bin/vbash << EOS &&
source /opt/vyatta/etc/functions/script-template
configure
set service https api rest
set service https listen-address 127.0.0.1
set service https api keys id ${KEY_NAME} key ${REST_KEY}
show service https api keys
commit && save && exit
EOS
curl -k --location --request POST 'https://localhost/retrieve' \
    --form data='{"op": "showConfig", "path": []}' \
    --form key="${REST_KEY}"
```

## アップデーター一式の設定

```bash
SCRIPT_FILENAME="vyos-updater.sh" &&
SETUP_SCRIPT_FILENAME="setup-vyos-updater.sh" &&
ENV_FILENAME="vyos-updater.env" &&
SERVICE_FILENAME="vyos-updater.service" &&
TIMER_FILENAME="vyos-updater.timer" &&
sudo tee "/config/scripts/${SCRIPT_FILENAME}" << 'EOS' > /dev/null &&
#!/bin/bash
set -euo pipefail

if [ -z "${REST_KEY:-}" ]; then
    echo "ERROR: REST_KEY is not set" >&2
    exit 1
fi

NEW_IMAGE_URL=$(wget -q -O - "https://api.github.com/repos/vyos/vyos-rolling-nightly-builds/releases/latest" | grep browser_download_url | head -n 1 | cut -d\" -f4)
if [ -z "${NEW_IMAGE_URL}" ]; then
    exit 0
fi
echo "Download URL: ${NEW_IMAGE_URL}"
DATA='{"op": "add", "url": "'"${NEW_IMAGE_URL}"'"}'
curl --silent -k --location --request POST 'https://localhost/image' --form data="${DATA}" --form key="${REST_KEY}" > /dev/null || exit 0
echo "Download Completed"

IMAGE_JSON="$(/usr/libexec/vyos/op_mode/image_info.py show_images_summary --raw)"
DEFAULT_IMAGE="$(echo "${IMAGE_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['image_default'])")"
RUNNING_IMAGE="$(echo "${IMAGE_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['image_running'])")"
ALL_IMAGES="$(echo "${IMAGE_JSON}" | python3 -c "import sys,json; [print(i) for i in json.load(sys.stdin)['images_available']]")"

while IFS= read -r IMAGE_NAME; do
    if [ -n "${IMAGE_NAME}" ] && [ "${IMAGE_NAME}" != "${DEFAULT_IMAGE}" ] && [ "${IMAGE_NAME}" != "${RUNNING_IMAGE}" ]; then
        DATA='{"op": "delete", "name": "'"${IMAGE_NAME}"'"}'
        curl --silent -k --location --request POST 'https://localhost/image' --form data="${DATA}" --form key="${REST_KEY}" > /dev/null
        echo "Delete: ${IMAGE_NAME}"
    fi
done <<< "${ALL_IMAGES}"

/sbin/reboot
EOS
sudo chmod 755 "/config/scripts/${SCRIPT_FILENAME}" &&
sudo tee "/config/scripts/${SETUP_SCRIPT_FILENAME}" << EOS > /dev/null &&
#!/bin/bash
set -e
cp /config/scripts/${SERVICE_FILENAME} /etc/systemd/system/${SERVICE_FILENAME}
cp /config/scripts/${TIMER_FILENAME} /etc/systemd/system/${TIMER_FILENAME}
systemctl enable ${TIMER_FILENAME}
EOS
sudo chmod 755 "/config/scripts/${SETUP_SCRIPT_FILENAME}" &&
sudo tee "/config/scripts/${ENV_FILENAME}" << EOS > /dev/null &&
REST_KEY="${REST_KEY}"
EOS
sudo chmod 600 "/config/scripts/${ENV_FILENAME}" &&
sudo tee "/config/scripts/${SERVICE_FILENAME}" << EOS > /dev/null &&
[Unit]
Description=Update VyOS to the latest rolling release

[Service]
Type=oneshot
EnvironmentFile=/config/scripts/${ENV_FILENAME}
ExecStart=/bin/bash /config/scripts/${SCRIPT_FILENAME}
StandardOutput=journal
StandardError=journal
EOS
sudo tee "/config/scripts/${TIMER_FILENAME}" << EOS > /dev/null &&
[Unit]
Description=Run VyOS update monthly

[Timer]
OnCalendar=monthly
RandomizedDelaySec=28d
Persistent=true

[Install]
WantedBy=timers.target
EOS
sudo tee -a "/config/scripts/vyos-postconfig-bootup.script" <<< "/config/scripts/${SETUP_SCRIPT_FILENAME}" > /dev/null
```

## systemdユニットの反映

```bash
sudo /config/scripts/setup-vyos-updater.sh && sudo systemctl daemon-reload && sudo systemctl start vyos-updater.timer
```

## 確認

```bash
systemctl status --no-pager --full vyos-updater.timer &&
systemctl status --no-pager --full vyos-updater.service &&
show system image
```

## すぐに実行

```bash
sudo systemctl start vyos-updater.service
```

## ログの確認

```bash
journalctl --no-pager --full -u vyos-updater.service
```
