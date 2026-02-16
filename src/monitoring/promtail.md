# Promtail
Promtailは（要説明追加）。このドキュメントでは、手動での設定手順を説明します。

## リポジトリーの設定
### Debian系
```bash
sudo apt-get install -U -y gpg &&
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null &&
sudo tee "/etc/apt/sources.list.d/grafana.sources" > /dev/null << EOF
Types: deb
URIs: https://apt.grafana.com
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/grafana.gpg
EOF
```

## インストール
`loki_hostname`の値は適宜書き換えること。`localhost`は、localhostにLokiがあるという設定である。
```bash
loki_hostname="localhost" &&
sudo apt-get install -U -y promtail &&
sudo tee "/etc/promtail/config.yml" > /dev/null << EOF &&
server:
  http_listen_port: 0
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${loki_hostname}:3100/loki/api/v1/push

scrape_configs:
  - job_name: systemd-journal
    journal:
      path: /var/log/journal
      labels:
        job: systemd-journal
        host: ${HOSTNAME}
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
EOF
sudo usermod -aG systemd-journal promtail &&
sudo systemctl restart promtail.service
```
- [Welcome to Grafana Labs's package repository](https://apt.grafana.com/)

## 確認
```bash
sudo systemctl status --no-pager --full promtail.service
journalctl --no-pager --lines=20 --unit=promtail
```

## テスト実行
```bash
sudo -u promtail promtail -config.file /etc/promtail/config.yml -dry-run
```

## 【デバッグ用】再起動
```bash
sudo systemctl restart promtail.service
```

## 【デバッグ用】停止・削除
```bash
sudo systemctl disable --now promtail.service &&
sudo apt-get purge -y promtail &&
sudo rm /tmp/positions.yaml
```
