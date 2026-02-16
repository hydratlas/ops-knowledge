
# VictoriaMetrics (Single version)
## 設定
`/etc/prometheus/prometheus.yml`の中身の例。
```yaml
scrape_configs:
  - job_name: node
    static_configs:
      - targets:
        - 192.168.0.xxx:9100:label1
        - 192.168.0.xxx:9100:label2
    relabel_configs:
      - source_labels: [__address__]
        regex: '([^:]+):(\d+):([^:]+)'
        target_label: instance
        replacement: '${3}:${2}'
      - source_labels: [__address__]
        regex: '([^:]+):(\d+):([^:]+)'
        target_label: __address__
        replacement: '${1}:${2}'
```
参考：[Prometheusでinstance名をホスト名にしたい #prometheus - Qiita](https://qiita.com/fkshom/items/bafb2160e2c9ca8ded38)

## インストール
```bash
host_conf_file="/etc/prometheus/prometheus.yml" &&
container_conf_file="/etc/prometheus.yml" &&
host_dir="/var/lib/victoria-metrics-data" &&
container_dir="/victoria-metrics-data" &&
quadlet_file="/etc/containers/systemd/victoria-metrics.container" &&
sudo mkdir -p "$(dirname "${host_conf_file}")" &&
sudo touch "${host_conf_file}" &&
sudo mkdir -p "${host_dir}" &&
sudo mkdir -p "$(dirname "${quadlet_file}")" &&
sudo tee "${quadlet_file}" << EOS > /dev/null &&
[Container]
Image=docker.io/victoriametrics/victoria-metrics
ContainerName=victoria-metrics
Network=monitoring.network
AutoUpdate=registry
LogDriver=journald

PublishPort=8428:8428
Volume=${host_conf_file}:${container_conf_file}:z
Volume=${host_dir}:${container_dir}:Z
Volume=/etc/localtime:/etc/localtime:ro
User=0
Exec='-promscrape.config=${container_conf_file}'

[Service]
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOS
sudo systemctl daemon-reload &&
sudo systemctl start victoria-metrics.service
```
- 参考：
  - [VictoriaMetrics](https://docs.victoriametrics.com/)
  - [VictoriaMetrics/package/victoria-metrics.service at master · VictoriaMetrics/VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics/blob/master/package/victoria-metrics.service)

## 確認
```bash
sudo systemctl status --no-pager --full victoria-metrics.service
journalctl --no-pager --lines=20 --unit=victoria-metrics
```

## 【デバッグ用】再起動
```bash
sudo systemctl restart victoria-metrics.service
```

## 【デバッグ用】停止・削除
```bash
sudo systemctl stop victoria-metrics.service &&
sudo rm /etc/containers/systemd/victoria-metrics.container &&
sudo systemctl daemon-reload
```
