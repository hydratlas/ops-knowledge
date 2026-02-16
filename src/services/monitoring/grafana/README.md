# Grafana

メトリクスとログの可視化プラットフォーム

## 概要

### このドキュメントの目的
このロールは、Grafanaをrootlessコンテナとしてデプロイし、PrometheusとLokiのデータソースを自動設定します。Ansible自動設定と手動設定の両方の方法に対応しています。

### 実現される機能
- Grafanaの可視化プラットフォームの構築
- Rootless Podman Quadletによる安全なコンテナ実行
- PrometheusとLokiデータソースの自動設定
- 匿名アクセスでのViewer権限付与
- コンテナイメージの自動更新

## 要件と前提条件

### 共通要件
- 対応OS: Ubuntu (focal, jammy), Debian (buster, bullseye), RHEL/CentOS (8, 9)
- Podmanがインストールされていること
- systemdがインストールされていること
- ネットワーク接続（コンテナイメージの取得用）

### Ansible固有の要件
- Ansible 2.9以上
- 制御ノードから対象ホストへのSSH接続
- 対象ホストでのsudo権限

### 手動設定の要件
- rootまたはsudo権限
- 基本的なLinuxコマンドの知識

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | デフォルト値 | 説明 |
|--------|--------------|------|
| `grafana_user` | `monitoring` | Grafanaを実行するユーザー名 |
| `grafana_user_comment` | `Grafana rootless user` | ユーザーのコメント |
| `grafana_app_name` | `grafana` | アプリケーション名（設定ディレクトリ名に使用） |
| `grafana_container_image` | `docker.io/grafana/grafana-oss:latest` | 使用するコンテナイメージ |
| `grafana_container_port` | `3000` | Grafanaのリスニングポート |
| `grafana_network_name` | `monitoring.network` | 使用するコンテナネットワーク |
| `grafana_service_description` | `Grafana Service` | サービスの説明 |
| `grafana_service_restart` | `always` | コンテナの再起動ポリシー |
| `grafana_service_restart_sec` | `5` | 再起動間隔（秒） |
| `grafana_admin_user` | `admin` | 管理者ユーザー名 |
| `grafana_admin_password` | 自動生成 | 管理者パスワード（24文字のランダム文字列） |
| `grafana_allow_sign_up` | `false` | ユーザー登録を許可するか |
| `grafana_allow_org_create` | `false` | 組織の作成を許可するか |
| `grafana_anonymous_enabled` | `true` | 匿名アクセスを有効にするか |
| `grafana_anonymous_org_role` | `Viewer` | 匿名ユーザーのロール |

#### 依存関係
- [podman_rootless_quadlet_base](../../../infrastructure/container/podman_rootless_quadlet_base/README.md)ロールを内部的に使用

#### タグとハンドラー

**ハンドラー:**
- `reload systemd user daemon`: systemdユーザーデーモンをリロード
- `restart grafana`: Grafanaサービスを再起動

**タグ:**
このroleでは特定のタグは使用していません。

#### 使用例

基本的な使用例：
```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.grafana
      vars:
        grafana_user: "monitoring"
        grafana_container_port: 3000
```

カスタムポートとイメージを使用する例：
```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.grafana
      vars:
        grafana_user: "monitoring"
        grafana_container_port: 3001
        grafana_container_image: "docker.io/grafana/grafana-oss:10.2.0"
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

システムユーザーを作成し、ルートレスコンテナ用のsubuid/subgidを割り当てます：

```bash
# ユーザーの作成（subuid/subgid付き）
USER_SHELL="/usr/sbin/nologin"  # 必要に応じて変更可能
sudo useradd --system --user-group --add-subids-for-system --shell "${USER_SHELL}" --comment "Grafana rootless user" "monitoring"

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
sudo mkdir -p "${QUADLET_HOME}/.config/grafana" &&
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

##### 環境変数ファイルの作成

```bash
# 管理者パスワードの生成
password="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)"

# 環境変数ファイルの作成
sudo -u monitoring tee /home/monitoring/.config/grafana/grafana.env << EOF > /dev/null
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=${password}
GF_USERS_ALLOW_SIGN_UP=false
GF_USERS_ALLOW_ORG_CREATE=false
GF_AUTH_ANONYMOUS_ENABLED=true
GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer
EOF

# パーミッションの設定
sudo chmod 600 /home/monitoring/.config/grafana/grafana.env
sudo chown monitoring:monitoring /home/monitoring/.config/grafana/grafana.env

# パスワードの表示
echo "Grafana admin password: ${password}"
```

##### データソース設定ファイルの作成

```bash
# データソースディレクトリの作成
sudo -u monitoring mkdir -p /home/monitoring/.config/grafana/provisioning/datasources

# Prometheusデータソース
sudo -u monitoring tee /home/monitoring/.config/grafana/provisioning/datasources/prometheus.yaml << EOF > /dev/null
apiVersion: 1
datasources:
  - name: prometheus
    type: prometheus
    access: proxy
    url: http://victoria-metrics:8428/
    isDefault: true
EOF

# Lokiデータソース
sudo -u monitoring tee /home/monitoring/.config/grafana/provisioning/datasources/loki.yaml << EOF > /dev/null
apiVersion: 1
datasources:
  - name: loki
    type: loki
    access: proxy
    url: http://loki:3100/
EOF
```

#### ステップ5: Quadletコンテナの設定

```bash
# データディレクトリの作成
sudo -u monitoring mkdir -p /home/monitoring/.local/share/grafana

# Quadletコンテナ定義ファイルの作成
sudo -u monitoring tee /home/monitoring/.config/containers/systemd/grafana.container << 'EOF' > /dev/null
[Unit]
Description=Grafana Service
Wants=victoria-metrics.service
Wants=loki.service
After=victoria-metrics.service
After=loki.service

[Container]
Image=docker.io/grafana/grafana-oss:latest
ContainerName=grafana
Network=monitoring.network
EnvironmentFile=/home/monitoring/.config/grafana/grafana.env
AutoUpdate=registry
LogDriver=journald
UserNS=keep-id
NoNewPrivileges=true
ReadOnly=true
PublishPort=3000:3000
Volume=/home/monitoring/.local/share/grafana:/var/lib/grafana:Z
Volume=/home/monitoring/.config/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:z
Volume=/etc/localtime:/etc/localtime:ro

[Service]
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# パーミッションの設定
sudo chmod 644 /home/monitoring/.config/containers/systemd/grafana.container
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
  systemctl --user start "grafana.service"
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
  systemctl --user status "grafana.service"

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "grafana.service"

# サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user stop "grafana.service"

# サービスの開始
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user start "grafana.service"
```

ログ確認：

```bash
# サービスのログの確認（最新の100行）
sudo -u "monitoring" \
  journalctl --user -u "grafana.service" --no-pager -n 100

# サービスのログの確認（リアルタイム表示）
sudo -u "monitoring" \
  journalctl --user -u "grafana.service" -f
```

コンテナ確認：

```bash
# コンテナの状態確認
sudo -u "monitoring" podman ps

# すべてのコンテナを表示（停止中も含む）
sudo -u "monitoring" podman ps -a

# コンテナの詳細情報
sudo -u "monitoring" podman inspect grafana

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
- `/home/monitoring/.config/grafana/` - アプリケーション固有の設定
- `/home/monitoring/.config/containers/systemd/` - Quadletファイル配置場所
- `/home/monitoring/.local/share/containers/storage/` - コンテナストレージ


### トラブルシューティング

#### サービスが起動しない場合

```bash
# ポートの競合確認
sudo ss -tlnp | grep :3000
```

#### 初期設定

1. `http://example.com:3000`にアクセス（`example.com`はインストールしたマシンのホスト名またはIPアドレス）
2. Ansible実行時に表示される管理者ユーザー名とパスワードでログイン
3. 左ペインの「Dashboards」画面で、右上の`New`ボタンから`Import`を選択
   - IDとして`1860`を入力して、`Load`を押す。データソースはPrometheusを使用する
     - [Node Exporter Full | Grafana Labs](https://grafana.com/ja/grafana/dashboards/1860-node-exporter-full/)
   - IDとして`14055`を入力して、`Load`を押す。データソースはPrometheusおよびLokiを使用する
     - [Loki stack monitoring (Promtail, Loki) | Grafana Labs](https://grafana.com/grafana/dashboards/14055-loki-stack-monitoring-promtail-loki/)

### メンテナンス

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

バックアップ：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 設定ファイルとQuadletファイルのバックアップ
sudo tar -czf "grafana-backup-$(date +%Y%m%d).tar.gz" \
    "${QUADLET_HOME}/monitoring/.config/grafana" \
    "${QUADLET_HOME}/monitoring/.config/containers/systemd"
```

手動更新：

```bash
# 手動でのイメージ更新
sudo -u "monitoring" podman pull docker.io/grafana/grafana-oss:latest

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "grafana.service"
```

自動更新は`podman-auto-update.timer`により定期的に実行されます。


Grafana固有のメンテナンス：

```bash
# データディレクトリのバックアップ
sudo tar -czf grafana-backup-$(date +%Y%m%d).tar.gz \
    /home/monitoring/.local/share/grafana \
    /home/monitoring/.config/grafana
```

## アンインストール（手動）

以下の手順でGrafanaを完全に削除します。

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

```bash
# 0. ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 1. サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user stop "grafana.service"

# 2. 自動更新タイマーの停止と無効化
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user disable --now podman-auto-update.timer

# 3. Quadletコンテナ定義ファイルの削除
sudo rm -f \
  "${QUADLET_HOME}/monitoring/.config/containers/systemd/grafana.container"

# 4. systemdユーザーデーモンのリロード
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user daemon-reload

# 5. コンテナイメージの削除
sudo -u "monitoring" podman rmi "docker.io/grafana/grafana-oss:latest"

# 6. アプリケーション設定の削除
# 警告: この操作により、アプリケーション固有の設定がすべて削除されます
sudo rm -rf "${QUADLET_HOME}/monitoring/.config/grafana"

# 7. lingeringを無効化
sudo loginctl disable-linger "monitoring"

# 8. ユーザーの削除
# 警告: このユーザーのホームディレクトリとすべてのデータが削除されます
sudo userdel -r "monitoring"
```


```bash
# 9. ネットワークファイルの削除（他のサービスが使用していない場合）
sudo rm -f /home/monitoring/.config/containers/systemd/monitoring.network
```

## 参考

- [Run Grafana Docker image | Grafana documentation](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/)
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
