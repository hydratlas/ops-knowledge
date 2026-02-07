# VictoriaMetrics

高性能で費用対効果の高い時系列データベース。Prometheusと互換性があり、長期保存に最適化されています。

## 概要

### このドキュメントの目的
このロールは、VictoriaMetrics（シングルノード版）をrootlessコンテナとしてデプロイする機能を提供します。Ansible roleによる自動設定と手動での設定手順の両方に対応しています。

### 実現される機能
- Prometheusと互換性のある時系列データベースの提供
- メトリクスデータの長期保存
- 高速なクエリ処理とデータ圧縮
- Rootlessコンテナによる安全な運用
- Podman Quadletによる自動起動と管理

## 要件と前提条件

### 共通要件
- OS: Ubuntu (focal, jammy), Debian (buster, bullseye), RHEL/CentOS (8, 9)
- Podmanがインストールされていること
- systemdによるユーザーサービス管理が可能であること
- ポート8428が利用可能であること

### Ansible固有の要件
- Ansible 2.9以上
- 制御ノードからターゲットホストへのSSH接続が可能であること

### 手動設定の要件
- sudo権限を持つユーザーアカウント
- Podman 3.0以上がインストールされていること

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | デフォルト値 | 説明 |
|--------|--------------|------|
| `victoria_metrics_user` | `monitoring` | VictoriaMetricsを実行するユーザー名 |
| `victoria_metrics_user_comment` | `VictoriaMetrics rootless user` | ユーザーのコメント |
| `victoria_metrics_app_name` | `victoria-metrics` | アプリケーション名（設定ディレクトリ名に使用） |
| `victoria_metrics_container_image` | `docker.io/victoriametrics/victoria-metrics:latest` | 使用するコンテナイメージ |
| `victoria_metrics_container_port` | `8428` | VictoriaMetricsのリスニングポート |
| `victoria_metrics_network_name` | `monitoring.network` | 使用するコンテナネットワーク |
| `victoria_metrics_service_description` | `VictoriaMetrics Service` | サービスの説明 |
| `victoria_metrics_service_restart` | `always` | コンテナの再起動ポリシー |
| `victoria_metrics_service_restart_sec` | `5` | 再起動間隔（秒） |
| `victoria_metrics_scrape_configs` | デフォルト設定あり | Prometheusスクレイプ設定 |

#### 依存関係
- [podman_rootless_quadlet_base](../../../infrastructure/container/podman_rootless_quadlet_base/README.md)ロールを内部的に使用

#### タグとハンドラー
- ハンドラー:
  - `reload systemd user daemon`: systemdユーザーデーモンをリロード
  - `restart victoria_metrics`: VictoriaMetricsサービスを再起動

#### 使用例

基本的な使用例:
```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.victoria_metrics
```

カスタムスクレイプ設定を含む例:
```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.victoria_metrics
      vars:
        victoria_metrics_user: "monitoring"
        victoria_metrics_scrape_configs:
          - job_name: node
            static_configs:
              - targets:
                - "192.168.0.10:9100:server1"
                - "192.168.0.11:9100:server2"
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

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

システムユーザーを作成し、ルートレスコンテナ用のsubuid/subgidを割り当てます：

```bash
# ユーザーの作成（subuid/subgid付き）
USER_SHELL="/usr/sbin/nologin"  # 必要に応じて変更可能
sudo useradd --system --user-group --add-subids-for-system --shell "${USER_SHELL}" --comment "VictoriaMetrics rootless user" "monitoring"

# systemd-journalグループへの追加
sudo usermod -aG systemd-journal "monitoring"
```

ユーザーがログインしていなくてもサービスを実行できるようにsystemd lingeringを有効化します：

```bash
# lingeringを有効化
sudo loginctl enable-linger "monitoring"
```

Quadletとコンテナストレージ用のディレクトリを作成します：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 必要なディレクトリを作成
sudo mkdir -p "${QUADLET_HOME}/.config/victoria-metrics" &&
sudo mkdir -p "${QUADLET_HOME}/.config/containers/systemd" &&
sudo mkdir -p "${QUADLET_HOME}/.local/share/containers/storage"

# 所有権の設定
sudo chown -R "monitoring:monitoring" "${QUADLET_HOME}"

# パーミッションの設定
sudo chmod -R 755 "${QUADLET_HOME}"
```

#### ステップ2: Podmanのインストール

Podmanのインストールは各ディストリビューションのパッケージマネージャーを使用してください。

#### ステップ3: ネットワーク設定

Ansible実行時は`container/podman_rootless_quadlet_network`ロールが自動的にネットワークファイルを作成する。手動で作成する場合は以下の手順に従う。

```bash
# ネットワークファイルの作成
if [ ! -f "/home/monitoring/.config/containers/systemd/monitoring.network" ]; then
sudo -u "monitoring" tee "/home/monitoring/.config/containers/systemd/monitoring.network" << EOF > /dev/null
[Unit]
Description=Monitoring Container Network

[Network]
Label=app=monitoring
EOF
fi
```

#### ステップ4: 設定ファイルの作成

```bash
# 設定ディレクトリの作成
sudo -u monitoring mkdir -p /home/monitoring/.config/prometheus

# Prometheus互換設定ファイルの作成
sudo -u monitoring tee /home/monitoring/.config/prometheus/prometheus.yml << 'EOF' > /dev/null
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
EOF
```

#### ステップ5: Quadletコンテナの設定

```bash
# データディレクトリの作成
sudo -u monitoring mkdir -p /home/monitoring/.local/share/victoria-metrics-data

# Quadletコンテナ定義ファイルの作成
sudo -u monitoring tee /home/monitoring/.config/containers/systemd/victoria-metrics.container << 'EOF' > /dev/null
[Unit]
Description=VictoriaMetrics Service

[Container]
Image=docker.io/victoriametrics/victoria-metrics:latest
ContainerName=victoria-metrics
Network=monitoring.network
AutoUpdate=registry
LogDriver=journald
UserNS=keep-id
NoNewPrivileges=true
ReadOnly=true
PublishPort=8428:8428
Volume=/home/monitoring/.config/prometheus/prometheus.yml:/etc/prometheus.yml:z
Volume=/home/monitoring/.local/share/victoria-metrics-data:/victoria-metrics-data:Z
Volume=/etc/localtime:/etc/localtime:ro
Exec='-promscrape.config=/etc/prometheus.yml'

[Service]
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# パーミッションの設定
sudo chmod 644 /home/monitoring/.config/containers/systemd/victoria-metrics.container
```

#### ステップ6: サービスの起動と有効化

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

Quadletから生成されたサービスファイルを認識させるため、systemdユーザーデーモンをリロードしてから、サービスを起動します：

```bash
# systemdユーザーデーモンのリロード
sudo -u monitoring \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user daemon-reload

# サービスの起動
sudo -u monitoring \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user start "victoria-metrics.service"
```

podman-auto-update.timerの起動と有効化によって、コンテナイメージの自動更新を有効にします：

```bash
# タイマーの起動と有効化
sudo -u monitoring \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user enable --now podman-auto-update.timer
```


## 運用管理

### 基本操作

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

サービス操作：

```bash
# サービスの状態確認
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user status "victoria-metrics.service"

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "victoria-metrics.service"

# サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user stop "victoria-metrics.service"

# サービスの開始
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user start "victoria-metrics.service"
```

ログ確認：

```bash
# サービスのログの確認（最新の100行）
sudo -u "monitoring" \
  journalctl --user -u "victoria-metrics.service" --no-pager -n 100

# サービスのログの確認（リアルタイム表示）
sudo -u "monitoring" \
  journalctl --user -u "victoria-metrics.service" -f
```

コンテナ確認：

```bash
# コンテナの状態確認
sudo -u "monitoring" podman ps

# すべてのコンテナを表示（停止中も含む）
sudo -u "monitoring" podman ps -a

# コンテナの詳細情報
sudo -u "monitoring" podman inspect victoria-metrics

# コンテナイメージの一覧
sudo -u "monitoring" podman images

# 古いコンテナイメージのクリーンアップ
sudo -u "monitoring" podman image prune -f
```

設定・環境確認：

```bash
# subuid/subgidの確認
grep "monitoring" /etc/subuid /etc/subgid

# lingeringの確認
loginctl show-user "monitoring" --property=Linger

# ユーザー情報の確認
id "monitoring"
```

Quadletファイル管理：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# ファイルの存在確認
ls -la "${QUADLET_HOME}/monitoring/.config/containers/systemd/"

# 構文確認
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  /usr/libexec/podman/quadlet --dryrun --user

# Systemdのリロード
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user daemon-reload
```

自動更新：

```bash
# 自動更新タイマーの状態確認
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user status podman-auto-update.timer

# 自動更新のログ確認
sudo -u "monitoring" \
  journalctl --user -u podman-auto-update.service
```

作成されるディレクトリ：
- `/home/monitoring/` - ユーザーのホームディレクトリ
- `/home/monitoring/.config/` - 設定ディレクトリ
- `/home/monitoring/.config/victoria-metrics/` - アプリケーション固有の設定
- `/home/monitoring/.config/containers/systemd/` - Quadletファイル配置場所
- `/home/monitoring/.local/share/containers/storage/` - コンテナストレージ


VictoriaMetrics固有の操作：

```bash
# VictoriaMetrics固有のメトリクスエンドポイント確認
curl http://localhost:8428/metrics
```

### トラブルシューティング

診断フロー:
1. サービスの状態確認
2. ログメッセージの確認
3. ネットワーク接続性の確認
4. ディスク容量の確認

よくある問題と対処:
- **サービスが起動しない**: ポート競合の確認、設定ファイルの構文チェック
- **データが保存されない**: ディスク容量とパーミッションの確認
- **メトリクスが収集されない**: スクレイプ設定とターゲットの到達性確認

```bash
# ポート使用状況の確認
ss -tlnp | grep 8428

# 設定ファイルの構文確認
sudo -u monitoring podman run --rm -v /home/monitoring/.config/prometheus/prometheus.yml:/etc/prometheus.yml:ro docker.io/victoriametrics/victoria-metrics:latest -promscrape.config=/etc/prometheus.yml -promscrape.config.dryRun

# ディスク使用量の確認
df -h /home/monitoring/.local/share/victoria-metrics-data
```

### メンテナンス

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

バックアップ：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 設定ファイルとQuadletファイルのバックアップ
sudo tar -czf "victoria-metrics-backup-$(date +%Y%m%d).tar.gz" \
    "${QUADLET_HOME}/monitoring/.config/victoria-metrics" \
    "${QUADLET_HOME}/monitoring/.config/containers/systemd"
```

手動更新：

```bash
# 手動でのイメージ更新
sudo -u "monitoring" podman pull docker.io/victoriametrics/victoria-metrics:latest

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "victoria-metrics.service"
```

自動更新は`podman-auto-update.timer`により定期的に実行されます。


VictoriaMetrics固有のメンテナンス：

```bash
# データのバックアップ
sudo -u monitoring tar czf victoria-metrics-backup-$(date +%Y%m%d).tar.gz -C /home/monitoring/.local/share victoria-metrics-data

# 設定変更後の反映
sudo -u monitoring XDG_RUNTIME_DIR=/run/user/$(id -u monitoring) systemctl --user daemon-reload
sudo -u monitoring XDG_RUNTIME_DIR=/run/user/$(id -u monitoring) systemctl --user restart victoria-metrics.service
```

## アンインストール（手動）

以下の手順でVictoriaMetricsを完全に削除します。

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

```bash
# 0. ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 1. サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user stop "victoria-metrics.service"

# 2. 自動更新タイマーの停止と無効化
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user disable --now podman-auto-update.timer

# 3. Quadletコンテナ定義ファイルの削除
sudo rm -f \
  "${QUADLET_HOME}/monitoring/.config/containers/systemd/victoria-metrics.container"

# 4. systemdユーザーデーモンのリロード
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user daemon-reload

# 5. コンテナイメージの削除
sudo -u "monitoring" podman rmi "docker.io/victoriametrics/victoria-metrics:latest"

# 6. アプリケーション設定の削除
# 警告: この操作により、アプリケーション固有の設定がすべて削除されます
sudo rm -rf "${QUADLET_HOME}/monitoring/.config/victoria-metrics"

# 7. lingeringを無効化
sudo loginctl disable-linger "monitoring"

# 8. ユーザーの削除
# 警告: このユーザーのホームディレクトリとすべてのデータが削除されます
sudo userdel -r "monitoring"
```


```bash
# 9. ネットワークの削除（他のサービスで使用していない場合）
sudo -u monitoring podman network rm monitoring || true
sudo rm -f /home/monitoring/.config/containers/systemd/monitoring.network

# 10. Prometheus設定ファイルの削除
sudo rm -rf /home/monitoring/.config/prometheus
```

## 参考

- [VictoriaMetrics公式ドキュメント](https://docs.victoriametrics.com/)
- [VictoriaMetrics GitHubリポジトリ](https://github.com/VictoriaMetrics/VictoriaMetrics)
- [Prometheusでinstance名をホスト名にしたい - Qiita](https://qiita.com/fkshom/items/bafb2160e2c9ca8ded38)
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
