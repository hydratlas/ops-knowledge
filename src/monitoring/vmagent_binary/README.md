# vmagent

VictoriaMetricsのvmagentをシングルバイナリーとしてインストール・管理するロールである。

## 概要

vmagentはPrometheus互換のメトリクス収集エージェントであり、スクレイプしたメトリクスを`remote_write`プロトコルでVictoriaMetricsやPrometheus互換のTSDBに転送する。本ロールはGitHub Releasesからバイナリーをダウンロードし、systemd（Debian/RHEL）またはOpenRC（Alpine）でサービスとして管理する。

## 必須変数

| 変数名                      | 説明                                       |
| --------------------------- | ------------------------------------------ |
| `vmagent_remote_write_urls` | リモートライト先のURLリスト（1つ以上必須） |

## 主要な変数

| 変数名                                        | デフォルト値   | 説明                                                            |
| --------------------------------------------- | -------------- | --------------------------------------------------------------- |
| `vmagent_version`                             | `v1.136.9`     | vmagentのバージョン                                             |
| `vmagent_http_listen_addr`                    | `:8429`        | HTTPリッスンアドレス                                            |
| `vmagent_scrape_configs`                      | nodeジョブのみ | Prometheusスクレイプ設定                                        |
| `vmagent_remote_write_max_disk_usage_per_url` | `1GB`          | リモートライト先がダウンした際のディスクバッファ上限（URL単位） |
| `vmagent_extra_flags`                         | `[]`           | 追加のCLIフラグ                                                 |

## 使用例

### 方法1: Ansible

`host_vars`または`group_vars`で以下のように設定する。

```yaml
vmagent_remote_write_urls:
  - "http://victoria-metrics.int.home.arpa:8428/api/v1/write"

vmagent_scrape_configs:
  - job_name: node
    static_configs:
      - targets:
          - "10.120.10.1:9100"
          - "10.120.10.2:9100"
```

### 方法2: 手動

1. GitHub Releasesからvmutilsアーカイブをダウンロードし、`vmagent-prod`バイナリーを`/opt/vmagent/`に配置する
2. `/etc/vmagent/prometheus.yml`にスクレイプ設定を記述する
3. systemdサービスファイルを作成し、`-promscrape.config`と`-remoteWrite.url`を指定して起動する

**Alpine Linux の場合（OpenRC）:**

`supervise-daemon` を `supervisor` に指定することで、プロセスが異常終了しても自動的に再起動（respawn）される。`command_background="yes"`（start-stop-daemon による単発起動）は監視・自動再起動を持たないため使用しない。

```bash
# init スクリプトを作成（<...> は環境に合わせて置換する）
cat << 'EOF' | doas tee /etc/init.d/vmagent
#!/sbin/openrc-run

name="vmagent"
description="VictoriaMetrics vmagent"

command="/usr/local/bin/vmagent-prod"
command_args="-httpListenAddr=:8429 -promscrape.config=/etc/vmagent/prometheus.yml -remoteWrite.tmpDataPath=/var/lib/vmagent/remote-write-tmp -remoteWrite.maxDiskUsagePerURL=1GB -promscrape.cluster.name=<HOSTNAME> -remoteWrite.url=<REMOTE_WRITE_URL>"
command_user="monitoring:monitoring"
supervisor="supervise-daemon"
pidfile="/run/${RC_SVCNAME}.pid"

respawn_delay=5
respawn_max=0
respawn_period=1800

output_log="/var/log/vmagent/vmagent.log"
error_log="/var/log/vmagent/vmagent.log"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner monitoring:monitoring --mode 0755 /var/log/vmagent
}
EOF
doas chmod 755 /etc/init.d/vmagent

# サービスを起動
doas rc-update add vmagent default
doas rc-service vmagent start
```
