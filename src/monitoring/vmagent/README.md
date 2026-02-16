# vmagent

VictoriaMetricsのvmagentをシングルバイナリーとしてインストール・管理するロールである。

## 概要

vmagentはPrometheus互換のメトリクス収集エージェントであり、スクレイプしたメトリクスを`remote_write`プロトコルでVictoriaMetricsやPrometheus互換のTSDBに転送する。本ロールはGitHub Releasesからバイナリーをダウンロードし、systemd（Debian/RHEL）またはOpenRC（Alpine）でサービスとして管理する。

## 必須変数

| 変数名 | 説明 |
|---|---|
| `vmagent_remote_write_urls` | リモートライト先のURLリスト（1つ以上必須） |

## 主要な変数

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `vmagent_version` | `v1.112.0` | vmagentのバージョン |
| `vmagent_http_listen_addr` | `:8429` | HTTPリッスンアドレス |
| `vmagent_scrape_configs` | nodeジョブのみ | Prometheusスクレイプ設定 |
| `vmagent_remote_write_max_disk_usage_per_url` | `1GB` | リモートライト先がダウンした際のディスクバッファ上限（URL単位） |
| `vmagent_extra_flags` | `[]` | 追加のCLIフラグ |

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
