# Node Exporter
## node-exporter-textfile-collector-scriptsのインストール
公式サイトは[node-exporter-textfile-collector-scripts/ipmitool at master · prometheus-community/node-exporter-textfile-collector-scripts](https://github.com/prometheus-community/node-exporter-textfile-collector-scripts)。

### 必要なパッケージのインストール
```bash
# Debian系の場合
sudo apt-get install -y moreutils python3-apt python3-prometheus-client ipmitool jq nvme-cli smartmontools rsync

# RHEL系の場合
sudo dnf install -y epel-release moreutils
```

### 本体のインストールおよびサービスの設定
```bash
cd "$HOME" &&
mkdir -p prometheus-node-exporter-collectors &&
wget -O - https://github.com/prometheus-community/node-exporter-textfile-collector-scripts/archive/refs/heads/master.tar.gz | tar xvfz - -C prometheus-node-exporter-collectors --strip-components 1 &&
rm -dr prometheus-node-exporter-collectors/mock &&
rm -dr prometheus-node-exporter-collectors/.circleci &&
rm -dr prometheus-node-exporter-collectors/.github &&
rm prometheus-node-exporter-collectors/CODE_OF_CONDUCT.md &&
rm prometheus-node-exporter-collectors/LICENSE &&
rm prometheus-node-exporter-collectors/MAINTAINERS.md &&
rm prometheus-node-exporter-collectors/README.md &&
rm prometheus-node-exporter-collectors/SECURITY.md &&
rm prometheus-node-exporter-collectors/.flake8 &&
mkdir -p prometheus-node-exporter-collectors/tmp &&
mkdir -p prometheus-node-exporter-collectors/prom &&
sudo mkdir -p /opt/prometheus-node-exporter-collectors &&
sudo rsync -rpt prometheus-node-exporter-collectors/ /opt/prometheus-node-exporter-collectors/ &&
rm -dr prometheus-node-exporter-collectors &&
sudo tee /opt/prometheus-node-exporter-collectors/collectors <<'EOF' >/dev/null &&
#!/bin/bash
TMPDIR=/opt/prometheus-node-exporter-collectors/tmp
COLLECTORSDIR=/opt/prometheus-node-exporter-collectors
PROMDIR=/opt/prometheus-node-exporter-collectors/prom
"$COLLECTORSDIR/btrfs_stats.py"                      | sponge "$PROMDIR/btrfs_stats.prom"
/usr/bin/ipmitool sensor | "$COLLECTORSDIR/ipmitool" | sponge "$PROMDIR/ipmitool_sensor.prom"
"$COLLECTORSDIR/mellanox_hca_temp"                   | sponge "$PROMDIR/mellanox_hca_temp.prom"
"$COLLECTORSDIR/node_os_info.sh"                     | sponge "$PROMDIR/node_os_info.prom"
"$COLLECTORSDIR/nvme_metrics.sh"                     | sponge "$PROMDIR/nvme_metrics.prom"
"$COLLECTORSDIR/smartmon.sh"                         | sponge "$PROMDIR/smartmon.prom"
"$COLLECTORSDIR/storcli.py"                          | sponge "$PROMDIR/storcli.prom"
EOF
sudo chmod a+x /opt/prometheus-node-exporter-collectors/collectors &&
sudo tee /etc/systemd/system/prometheus-node-exporter-collectors.service <<'EOF' >/dev/null &&
[Unit]
Description=prometheus-node-exporter-collectors

[Service]
Type=oneshot
ExecStart=/opt/prometheus-node-exporter-collectors/collectors
EOF
sudo systemctl daemon-reload &&
sudo systemctl start prometheus-node-exporter-collectors.service
```

### 確認
```bash
sudo systemctl status prometheus-node-exporter-collectors.service
```

## Node Exporterのインストール
公式サイトは[prometheus/node_exporter: Exporter for machine metrics](https://github.com/prometheus/node_exporter)。

### 必要なパッケージのインストール
```bash
sudo apt-get install -y jq
```

### インストール
```bash
OS="$(uname -s)" &&
OS="${OS,,}" &&
ARCH="$(dpkg --print-architecture)" &&
if [ "${ARCH}" = "i386" ]; then
  ARCH="386"
fi &&
LATEST_RELEASE="$(wget -q -O - "https://api.github.com/repos/prometheus/node_exporter/releases/latest")" &&
FILTER=".assets[] | select(.name | startswith(\"node_exporter-\") and endswith(\".${OS}-${ARCH}.tar.gz\")) | .browser_download_url" &&
DOWNLOAD_URL="$(echo "${LATEST_RELEASE}" | jq -r "${FILTER}")" &&
if [ -z "${DOWNLOAD_URL}" ]; then
  echo "Could not find download URL." 1>&2 &&
  exit 1
fi &&
mkdir -p "${HOME}/node_exporter" &&
wget -O - "${DOWNLOAD_URL}" | tar xfz - -C "${HOME}/node_exporter" --strip-components 1 &&
sudo install -m 0775 -D -t /usr/local/bin "${HOME}/node_exporter/node_exporter" &&
rm -dr "${HOME}/node_exporter"
```
アップデートの際はこれと同様のことを行った上で、`sudo systemctl restart node_exporter.service`を実行する。

### 設定・起動・常時起動化
```bash
sudo tee "/etc/systemd/system/node_exporter.service" <<'EOF' >/dev/null &&
[Unit]
Description=Prometheus Node Exporter
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter --collector.textfile.directory=/opt/prometheus-node-exporter-collectors/prom
SyslogIdentifier=node_exporter
Restart=always
RestartSec=1
StartLimitInterval=0
NoNewPrivileges=yes
ProtectSystem=strict
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=yes
DynamicUser=true

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload &&
sudo systemctl enable --now node_exporter.service
```
`DynamicUser=true`を指定することによって、明示的にroot以外のユーザーを作成せずにすんでいる。

### 確認
```bash
sudo systemctl status --no-pager --full node_exporter.service

node_exporter --version

wget -q -O - http://localhost:9100/metrics
```

### 自動アップデートスクリプト
```bash
#!/bin/bash
BINARY_NAME="node_exporter"
INSTALL_DIR="/usr/local/bin"
TEMP_DIR="/tmp"

OS="$(uname -s)"
OS="${OS,,}"
ARCH="$(dpkg --print-architecture)"
if [ "${ARCH}" = "i386" ]; then
  ARCH="386"
fi
LATEST_RELEASE="$(wget -q -O - "https://api.github.com/repos/prometheus/node_exporter/releases/latest")"
FILTER=".assets[] | select(.name | startswith(\"node_exporter-\") and endswith(\".${OS}-${ARCH}.tar.gz\")) | .browser_download_url"
DOWNLOAD_URL="$(echo "${LATEST_RELEASE}" | jq -r "${FILTER}")"
if [ -z "$DOWNLOAD_URL" ]; then
  echo "Could not find download URL." 1>&2
  exit 1
fi
DOWNLOAD_FILEBASENAME="${DOWNLOAD_URL##*/}"
DOWNLOAD_FILEBASENAME="${DOWNLOAD_FILEBASENAME%.tar.gz}"
wget -O - "${DOWNLOAD_URL}" | tar xzf - -O "${DOWNLOAD_FILEBASENAME}/node_exporter" > "${TEMP_DIR}/${BINARY_NAME}"

if [ -e "${INSTALL_DIR}/${BINARY_NAME}" ]; then
  CURRENT_MD5="$(md5sum "${INSTALL_DIR}/${BINARY_NAME}")"
  CURRENT_MD5="${CURRENT_MD5:0:32}"
  NEW_MD5="$(md5sum "${TEMP_DIR}/${BINARY_NAME}")"
  NEW_MD5="${NEW_MD5:0:32}"
  if [ "${CURRENT_MD5}" = "${NEW_MD5}" ]; then
    exit 0
  fi
  systemctl stop node_exporter.service
fi
install -m 0775 -D -t "${INSTALL_DIR}" "${TEMP_DIR}/${BINARY_NAME}"
systemctl enable --now node_exporter.service
rm "${TEMP_DIR}/${BINARY_NAME}"
```
