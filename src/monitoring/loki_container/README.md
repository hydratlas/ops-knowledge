# Grafana Loki

水平スケーラブルで高可用性のマルチテナントログ集約システム。ログデータの効率的な集約と保存を実現します。

## 概要

### このドキュメントの目的
このロールは、Grafana Lokiをrootlessコンテナとしてデプロイし、ログ集約サービスを提供します。Ansible roleによる自動設定と手動での設定手順の両方に対応しています。

### 実現される機能
- ログデータの集約と長期保存
- 効率的なログインデックスとクエリ機能
- Grafanaとの統合によるログ可視化
- 保持ポリシーによる自動ログ管理
- Rootlessコンテナによる安全な運用

## 要件と前提条件

### 共通要件
- OS: Ubuntu (focal, jammy), Debian (buster, bullseye), RHEL/CentOS (8, 9)
- Podmanがインストールされていること
- systemdによるユーザーサービス管理が可能であること
- ポート3100が利用可能であること

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
| `loki_user` | `monitoring` | Lokiを実行するユーザー名 |
| `loki_user_comment` | `Grafana Loki rootless user` | ユーザーのコメント |
| `loki_app_name` | `loki` | アプリケーション名（設定ディレクトリ名に使用） |
| `loki_container_image` | `docker.io/grafana/loki:latest` | 使用するコンテナイメージ |
| `loki_container_port` | `3100` | Lokiのリスニングポート |
| `loki_network_name` | `monitoring.network` | 使用するコンテナネットワーク |
| `loki_service_description` | `Grafana Loki Service` | サービスの説明 |
| `loki_service_restart` | `always` | コンテナの再起動ポリシー |
| `loki_service_restart_sec` | `5` | 再起動間隔（秒） |
| `loki_auth_enabled` | `false` | 認証の有効/無効 |
| `loki_analytics_reporting_enabled` | `false` | 分析レポートの有効/無効 |

#### 依存関係
- [podman_rootless_quadlet_base](../../../infrastructure/container/podman_rootless_quadlet_base/README.md)ロールを内部的に使用

#### タグとハンドラー
- ハンドラー:
  - `reload systemd user daemon`: systemdユーザーデーモンをリロード
  - `restart loki`: Lokiサービスを再起動

#### 使用例

基本的な使用例:
```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.loki
```

カスタム設定を含む例:
```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.loki
      vars:
        loki_user: "monitoring"
        loki_container_port: 3100
        loki_auth_enabled: false
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

システムユーザーを作成し、ルートレスコンテナ用のsubuid/subgidを割り当てます：

```bash
# ユーザーの作成（subuid/subgid付き）
USER_SHELL="/usr/sbin/nologin"  # 必要に応じて変更可能
sudo useradd --system --user-group --add-subids-for-system --shell "${USER_SHELL}" --comment "Grafana Loki rootless user" "monitoring"

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
sudo mkdir -p "${QUADLET_HOME}/.config/loki" &&
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
sudo -u "monitoring" mkdir -p /home/monitoring/.config/loki

# Loki設定ファイルの作成
sudo -u "monitoring" tee "/home/monitoring/.config/loki/loki.yaml" << EOF > /dev/null
auth_enabled: false

server:
  http_listen_port: 3100
  http_listen_address: 0.0.0.0

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 336h # 14 days
  retention_stream:
    - selector: '{appname="kernel"}'
      period: 13140h # 1.5 year
      priority: 1
    - selector: '{level="error"}'
      period: 1440h # 60 days
      priority: 0

analytics:
  reporting_enabled: false
EOF
```

#### ステップ5: Quadletコンテナの設定

```bash
# データディレクトリの作成
sudo -u "monitoring" mkdir -p "/home/monitoring/.local/share/loki"

# Quadletコンテナ定義ファイルの作成
sudo -u "monitoring" tee "/home/monitoring/.config/containers/systemd/loki.container" << EOF > /dev/null
[Unit]
Description=Grafana Loki Service

[Container]
Image=docker.io/grafana/loki:latest
ContainerName=loki
AutoUpdate=registry
LogDriver=journald
Network=monitoring.network
UserNS=keep-id
Exec='-config.file=/loki.yaml'
NoNewPrivileges=true
ReadOnly=true
PublishPort=3100:3100
Volume=/home/monitoring/.config/loki/loki.yaml:/loki.yaml:z
Volume=/home/monitoring/.local/share/loki:/loki:Z
Volume=/etc/localtime:/etc/localtime:ro

[Service]
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# パーミッションの設定
sudo chmod 644 /home/monitoring/.config/containers/systemd/loki.container
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
  systemctl --user start "loki.service"
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
  systemctl --user status "loki.service"

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "loki.service"

# サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user stop "loki.service"

# サービスの開始
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user start "loki.service"
```

ログ確認：

```bash
# サービスのログの確認（最新の100行）
sudo -u "monitoring" \
  journalctl --user -u "loki.service" --no-pager -n 100

# サービスのログの確認（リアルタイム表示）
sudo -u "monitoring" \
  journalctl --user -u "loki.service" -f
```

コンテナ確認：

```bash
# コンテナの状態確認
sudo -u "monitoring" podman ps

# すべてのコンテナを表示（停止中も含む）
sudo -u "monitoring" podman ps -a

# コンテナの詳細情報
sudo -u "monitoring" podman inspect loki

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
- `/home/monitoring/.config/loki/` - アプリケーション固有の設定
- `/home/monitoring/.config/containers/systemd/` - Quadletファイル配置場所
- `/home/monitoring/.local/share/containers/storage/` - コンテナストレージ


Loki固有の操作：

```bash
# Loki固有のサービス状態確認
wget -O - http://localhost:3100/ready

# プッシュエンドポイントの確認
wget --method=POST --header="Content-Type: application/json" --body-data='{}' http://localhost:3100/loki/api/v1/push
```

### トラブルシューティング

診断フロー:
1. サービスの状態確認
2. ログメッセージの確認
3. ネットワーク接続性の確認
4. ディスク容量の確認
5. 設定ファイルの構文確認

よくある問題と対処:
- **サービスが起動しない**: ポート競合の確認、設定ファイルの構文チェック
- **ログが保存されない**: ディスク容量とパーミッションの確認
- **クエリが失敗する**: インデックス破損の確認、保持期間の設定確認

```bash
# ポート使用状況の確認
ss -tlnp | grep 3100

# ディスク使用量の確認
df -h /home/monitoring/.local/share/loki

# 設定ファイルの構文確認
sudo -u monitoring podman run --rm -v /home/monitoring/.config/loki/loki.yaml:/loki.yaml:ro docker.io/grafana/loki:latest -config.file=/loki.yaml -verify-config
```

### メンテナンス

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

バックアップ：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 設定ファイルとQuadletファイルのバックアップ
sudo tar -czf "loki-backup-$(date +%Y%m%d).tar.gz" \
    "${QUADLET_HOME}/monitoring/.config/loki" \
    "${QUADLET_HOME}/monitoring/.config/containers/systemd"
```

手動更新：

```bash
# 手動でのイメージ更新
sudo -u "monitoring" podman pull docker.io/grafana/loki:latest

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "loki.service"
```

自動更新は`podman-auto-update.timer`により定期的に実行されます。


Loki固有のメンテナンス：

```bash
# データのバックアップ
sudo -u monitoring tar czf loki-backup-$(date +%Y%m%d).tar.gz -C /home/monitoring/.local/share loki
```

## アンインストール（手動）

以下の手順でLokiを完全に削除します。

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

```bash
# 0. ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 1. サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user stop "loki.service"

# 2. 自動更新タイマーの停止と無効化
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user disable --now podman-auto-update.timer

# 3. Quadletコンテナ定義ファイルの削除
sudo rm -f \
  "${QUADLET_HOME}/monitoring/.config/containers/systemd/loki.container"

# 4. systemdユーザーデーモンのリロード
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user daemon-reload

# 5. コンテナイメージの削除
sudo -u "monitoring" podman rmi "docker.io/grafana/loki:latest"

# 6. アプリケーション設定の削除
# 警告: この操作により、アプリケーション固有の設定がすべて削除されます
sudo rm -rf "${QUADLET_HOME}/monitoring/.config/loki"

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

- [Grafana Loki公式ドキュメント](https://grafana.com/docs/loki/latest/)
- [Loki設定リファレンス](https://grafana.com/docs/loki/latest/configuration/)
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
