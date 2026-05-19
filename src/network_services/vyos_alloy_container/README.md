# VyOS上のGrafana Alloyコンテナの設定

## 概要

VyOSのコンテナ機能を使用してGrafana Alloyを実行し、VyOSのsyslogをLokiへ転送する。Alloyコンテナはホストネットワークモードで動作し、UDPポート5514でsyslogを受信する。WAL（Write-Ahead Log）により、Lokiの一時的な障害時にもログを保持する。

## このロールが行うこと

- `/config/alloy/`ディレクトリーとWAL用データディレクトリーの作成
- Alloy設定ファイル（`config.alloy`）のデプロイ

コンテナの定義とsyslog転送の設定は`vyos_base_config`変数で管理する。

## 手動での設定手順

### ディレクトリの作成

```bash
sudo mkdir -p /config/alloy/data
```

### 設定ファイルの作成

`/config/alloy/config.alloy`を作成する。内容はテンプレート（`templates/config.alloy.j2`）を参照のこと。

### コンテナとsyslogの設定

```
configure
set container name alloy image 'docker.io/grafana/alloy:latest'
set container name alloy allow-host-networks
set container name alloy memory 256
set container name alloy restart on-failure
set container name alloy volume config source /config/alloy/config.alloy
set container name alloy volume config destination /etc/alloy/config.alloy
set container name alloy volume data source /config/alloy/data
set container name alloy volume data destination /var/lib/alloy/data
set system syslog host 127.0.0.1 port 5514
set system syslog host 127.0.0.1 protocol udp
set system syslog host 127.0.0.1 facility all level info
commit
save
```

### 動作確認

```bash
show container
sudo podman logs alloy
```
