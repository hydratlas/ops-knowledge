# VictoriaLogs

VictoriaMetricsプロジェクトが提供する高性能なログ管理ソリューション。Loki互換のプッシュAPIを備え、CLIフラグのみで設定が完結するシンプルな構成が特徴である。

## 概要

### このドキュメントの目的

このロールは、VictoriaLogsをrootlessコンテナとしてデプロイし、ログ集約サービスを提供する。Ansible roleによる自動設定と手動での設定手順の両方に対応している。

### 実現される機能

- ログデータの集約と保存
- Loki互換のプッシュAPI（`/insert/loki/api/v1/push`）
- LogsQLによるクエリ機能
- 保持期間による自動ログ管理
- Rootlessコンテナによる安全な運用
- Podman Quadletによる自動起動と管理

## 要件と前提条件

### 共通要件

- OS: Ubuntu, Debian, RHEL
- Podmanがインストールされていること
- systemdによるユーザーサービス管理が可能であること
- ポート9428が利用可能であること

### Ansible固有の要件

- Ansible 2.9以上
- 制御ノードからターゲットホストへのSSH接続が可能であること

### 手動設定の要件

- sudo権限を持つユーザーアカウント
- Podman 3.0以上がインストールされていること

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                             | デフォルト値                                     | 説明                                           |
| ---------------------------------- | ------------------------------------------------ | ---------------------------------------------- |
| `victorialogs_user`                | `monitoring`                                     | VictoriaLogsを実行するユーザー名               |
| `victorialogs_user_comment`        | `VictoriaLogs rootless user`                     | ユーザーのコメント                             |
| `victorialogs_app_name`            | `victoria-logs`                                  | アプリケーション名（設定ディレクトリ名に使用） |
| `victorialogs_container_image`     | `docker.io/victoriametrics/victoria-logs:latest` | 使用するコンテナイメージ                       |
| `victorialogs_container_port`      | `9428`                                           | VictoriaLogsのリスニングポート                 |
| `victorialogs_network_name`        | `monitoring.network`                             | 使用するコンテナネットワーク                   |
| `victorialogs_service_description` | `VictoriaLogs Service`                           | サービスの説明                                 |
| `victorialogs_service_restart`     | `always`                                         | コンテナの再起動ポリシー                       |
| `victorialogs_service_restart_sec` | `5`                                              | 再起動間隔（秒）                               |
| `victorialogs_retention_period`    | `7d`                                             | ログの保持期間                                 |

#### 依存関係

- [podman_rootless_quadlet_base](../../../infrastructure/container/podman_rootless_quadlet_base/README.md)ロールを内部的に使用

#### タグとハンドラー

- ハンドラー:
  - `reload systemd user daemon`: systemdユーザーデーモンをリロード
  - `restart victoria_logs`: VictoriaLogsサービスを再起動

#### 使用例

基本的な使用例:

```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.victorialogs
```

カスタム保持期間を含む例:

```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.victorialogs
      vars:
        victorialogs_retention_period: "30d"
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

システムユーザーを作成し、ルートレスコンテナ用のsubuid/subgidを割り当てます：

```bash
# ユーザーの作成（subuid/subgid付き）
USER_SHELL="/usr/sbin/nologin"  # 必要に応じて変更可能
sudo useradd --system --user-group --add-subids-for-system --shell "${USER_SHELL}" --comment "VictoriaLogs rootless user" "monitoring"

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
sudo mkdir -p "${QUADLET_HOME}/.config/victoria-logs" &&
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

#### ステップ4: Quadletコンテナの設定

VictoriaLogsは設定ファイルが不要であり、すべてのオプションをCLIフラグで指定する。

```bash
# データディレクトリの作成
sudo -u monitoring mkdir -p /home/monitoring/.local/share/victoria-logs-data

# Quadletコンテナ定義ファイルの作成
sudo -u monitoring tee /home/monitoring/.config/containers/systemd/victoria-logs.container << 'EOF' > /dev/null
[Unit]
Description=VictoriaLogs Service

[Container]
Image=docker.io/victoriametrics/victoria-logs:latest
ContainerName=victoria-logs
Network=monitoring.network
AutoUpdate=registry
LogDriver=journald
UserNS=keep-id
NoNewPrivileges=true
ReadOnly=true
PublishPort=9428:9428
Volume=/home/monitoring/.local/share/victoria-logs-data:/victoria-logs-data:Z
Volume=/etc/localtime:/etc/localtime:ro
Exec='-retentionPeriod=7d'

[Service]
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# パーミッションの設定
sudo chmod 644 /home/monitoring/.config/containers/systemd/victoria-logs.container
```

#### ステップ5: サービスの起動と有効化

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
  systemctl --user start "victoria-logs.service"
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
  systemctl --user status "victoria-logs.service"

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "victoria-logs.service"

# サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user stop "victoria-logs.service"

# サービスの開始
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user start "victoria-logs.service"
```

ログ確認：

```bash
# サービスのログの確認（最新の100行）
sudo -u "monitoring" \
  journalctl --user -u "victoria-logs.service" --no-pager -n 100

# サービスのログの確認（リアルタイム表示）
sudo -u "monitoring" \
  journalctl --user -u "victoria-logs.service" -f
```

コンテナ確認：

```bash
# コンテナの状態確認
sudo -u "monitoring" podman ps

# すべてのコンテナを表示（停止中も含む）
sudo -u "monitoring" podman ps -a

# コンテナの詳細情報
sudo -u "monitoring" podman inspect victoria-logs

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
- `/home/monitoring/.config/victoria-logs/` - アプリケーション固有の設定
- `/home/monitoring/.config/containers/systemd/` - Quadletファイル配置場所
- `/home/monitoring/.local/share/containers/storage/` - コンテナストレージ


VictoriaLogs固有の操作：

```bash
# ヘルスチェック
curl http://localhost:9428/health

# Loki互換プッシュエンドポイントの確認
curl -X POST http://localhost:9428/insert/loki/api/v1/push -H 'Content-Type: application/json' -d '{}'

# ログクエリの実行
curl 'http://localhost:9428/select/logsql/query?query=*&limit=10'
```

### トラブルシューティング

診断フロー:

1. サービスの状態確認
2. ログメッセージの確認
3. ネットワーク接続性の確認
4. ディスク容量の確認

よくある問題と対処:

- **サービスが起動しない**: ポート競合の確認
- **ログが保存されない**: ディスク容量とパーミッションの確認
- **クエリが失敗する**: クエリ構文の確認

```bash
# ポート使用状況の確認
ss -tlnp | grep 9428

# ディスク使用量の確認
df -h /home/monitoring/.local/share/victoria-logs-data
```

### メンテナンス

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

バックアップ：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 設定ファイルとQuadletファイルのバックアップ
sudo tar -czf "victoria-logs-backup-$(date +%Y%m%d).tar.gz" \
    "${QUADLET_HOME}/monitoring/.config/victoria-logs" \
    "${QUADLET_HOME}/monitoring/.config/containers/systemd"
```

手動更新：

```bash
# 手動でのイメージ更新
sudo -u "monitoring" podman pull docker.io/victoriametrics/victoria-logs:latest

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "victoria-logs.service"
```

自動更新は`podman-auto-update.timer`により定期的に実行されます。


VictoriaLogs固有のメンテナンス：

```bash
# データのバックアップ
sudo -u monitoring tar czf victoria-logs-backup-$(date +%Y%m%d).tar.gz -C /home/monitoring/.local/share victoria-logs-data
```

## アンインストール（手動）

以下の手順でVictoriaLogsを完全に削除する。

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

```bash
# 0. ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 1. サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user stop "victoria-logs.service"

# 2. 自動更新タイマーの停止と無効化
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user disable --now podman-auto-update.timer

# 3. Quadletコンテナ定義ファイルの削除
sudo rm -f \
  "${QUADLET_HOME}/monitoring/.config/containers/systemd/victoria-logs.container"

# 4. systemdユーザーデーモンのリロード
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user daemon-reload

# 5. コンテナイメージの削除
sudo -u "monitoring" podman rmi "docker.io/victoriametrics/victoria-logs:latest"

# 6. アプリケーション設定の削除
# 警告: この操作により、アプリケーション固有の設定がすべて削除されます
sudo rm -rf "${QUADLET_HOME}/monitoring/.config/victoria-logs"

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
```

## 参考

- [VictoriaLogs公式ドキュメント](https://docs.victoriametrics.com/victorialogs/)
- [VictoriaMetrics GitHubリポジトリ](https://github.com/VictoriaMetrics/VictoriaMetrics)
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
