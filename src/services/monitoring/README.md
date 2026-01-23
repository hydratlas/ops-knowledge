# 監視
## 概要
Node Exporter + VictoriaMetrics (Single version) + Grafanaという構成で、サーバーのCPU使用率をはじめとしたシステムパフォーマンスを監視する。また、Promtail + Loki + Grafanaという構成で、サーバーのログを集約する。

- Node Exporter: 監視対象の各マシンにおいて、システムパフォーマンスを測定してHTTPで公開する
- VictoriaMetrics (Single version): Node Exporterから測定データをHTTPで収集して、集積する
- Promtail: 監視対象の各マシンにおいて、ログを収集してLokiへHTTPで送信する
- Loki: Promtailから送信されたログを集積する
- Grafana: VictoriaMetricsおよびLokiにHTTPでアクセスして、グラフ化などによって分かりやすく視覚化してユーザーに提示する

ここでは、監視対象の各マシンにはDockerが入らない可能性があるため、Node Exporterは手動でバイナリーをインストール、Promtailはaptでインストールする。VictoriaMetrics、LokiおよびGrafanaはDocker(Podman)でインストールする。

## クライアント
監視対象のそれぞれのマシンにインストールする。

## サーバー
1台のマシンにインストールする。Podman Quadletを使用しているため、Podman 4.6以上のインストールが必要で、Podman 4.6以上であることを満たすためにUbuntu LTSであれば24.04以上が必要である。

まず、ネットワークを作成し、次に各コンテナをインストールする。
```bash
sudo mkdir -p /etc/containers/systemd &&
sudo tee /etc/containers/systemd/monitoring.network << EOS > /dev/null
[Unit]
Description=Monitoring Container Network

[Network]
Label=app=monitoring
EOS
```

