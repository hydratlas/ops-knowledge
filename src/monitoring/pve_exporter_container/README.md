# Prometheus PVE Exporter

Proxmox VE クラスターのメトリクスを収集し、Prometheus形式で公開するエクスポーター。

## 概要

### このドキュメントの目的

このロールは、Prometheus PVE ExporterをrootlessコンテナとしてデプロイするAnsible roleを提供する。Proxmox VE（仮想環境）の監視に使用し、VM/コンテナの状態、リソース使用量などのメトリクスを収集する。

### 実現される機能

- Proxmox VEクラスターからのメトリクス収集
- VM/CTのCPU、メモリ、ディスク、ネットワーク使用量の監視
- ノードレベルのリソース監視
- Rootlessコンテナによる安全な運用
- Podman Quadletによる自動起動と管理

## 要件と前提条件

### 共通要件

- OS: Ubuntu (noble), Debian (trixie)
- Podmanがインストールされていること
- systemdによるユーザーサービス管理が可能であること
- ポート9221が利用可能であること
- Proxmox VE APIへのネットワーク接続が可能であること

### Proxmox VE側の要件

- APIトークンを持つユーザー（PVEAuditorロール推奨）
- APIトークンの作成手順:
  1. Datacenter > Permissions > Users でユーザー作成（User name: `prometheus`、Realm: `Proxmox VE authentication server`）
  2. Datacenter > Permissions > API Tokens でトークン作成（User: `prometheus@pve`、Token ID: `exporter`、Privilege Separation: off）
  3. Datacenter > Permissions の Add > User Permission でロールを割り当て（Path: `/`、User: `prometheus@pve`、Role: `PVEAuditor`）
- Ansible変数
  - `pve_exporter_pve_user`: ユーザー名（`prometheus@pve`）
  - `pve_exporter_pve_token_name`: トークンID（`exporter`）
  - `pve_exporter_pve_token_value`: トークンシークレット

### Ansible固有の要件

- Ansible 2.15以上
- 制御ノードからターゲットホストへのSSH接続が可能であること

### 手動設定の要件

- sudo権限を持つユーザーアカウント
- Podman 4.0以上がインストールされていること

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                             | デフォルト値                                       | 説明                                      |
| ---------------------------------- | -------------------------------------------------- | ----------------------------------------- |
| `pve_exporter_user`                | `monitoring`                                       | PVE Exporterを実行するユーザー名          |
| `pve_exporter_app_name`            | `pve-exporter`                                     | アプリケーション名                        |
| `pve_exporter_container_image`     | `docker.io/prompve/prometheus-pve-exporter:latest` | 使用するコンテナイメージ                  |
| `pve_exporter_container_port`      | `9221`                                             | エクスポーターのリスニングポート          |
| `pve_exporter_service_restart`     | `always`                                           | コンテナの再起動ポリシー                  |
| `pve_exporter_service_restart_sec` | `5`                                                | 再起動間隔（秒）                          |
| `pve_exporter_pve_targets`         | `{}`                                               | PVEターゲットごとの設定（必須、下記参照） |
| `pve_exporter_pve_verify_ssl`      | `false`                                            | SSL証明書の検証                           |
| `pve_exporter_collector_config`    | `true`                                             | configコレクターの有効化                  |

`pve_exporter_pve_targets` の各ターゲットには以下のフィールドが必須:

| フィールド    | 説明                   |
| ------------- | ---------------------- |
| `user`        | Proxmox VE APIユーザー |
| `token_name`  | APIトークン名          |
| `token_value` | APIトークン値          |

#### 依存関係

- [podman_rootless_quadlet_base](../../../infrastructure/container/podman_rootless_quadlet_base/README.md)ロールを内部的に使用

#### タグとハンドラー

- ハンドラー:
  - `reload systemd user daemon`: systemdユーザーデーモンをリロード
  - `restart pve_exporter`: PVE Exporterサービスを再起動

#### 使用例

基本的な使用例:

```yaml
- hosts: monitoring_servers
  roles:
    - role: services.monitoring.pve_exporter
      vars:
        pve_exporter_pve_targets:
          ve-01:
            user: "prometheus@pve"
            token_name: "exporter"
            token_value: "{{ vault_pve_token_ve01 }}"
```

複数のPVEターゲットを監視する例:

```yaml
pve_exporter_pve_targets:
  ve-01: # モジュール名（スクレイプ設定のparams.moduleで指定）
    user: "prometheus@pve"
    token_name: "exporter"
    token_value: "{{ vault_pve_token_ve01 }}"
  ve-02:
    user: "prometheus@pve"
    token_name: "exporter"
    token_value: "{{ vault_pve_token_ve02 }}"
```

Prometheusのスクレイプ設定で各ターゲットに対応するモジュールを指定する:

```yaml
static_configs:
  - targets:
      - 192.168.1.10 # ve-01
    labels:
      pve_module: ve-01
  - targets:
      - 192.168.1.11 # ve-02
    labels:
      pve_module: ve-02
relabel_configs:
  - source_labels: [pve_module]
    target_label: __param_module
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

システムユーザーを作成し、ルートレスコンテナ用のsubuid/subgidを割り当てます：

```bash
# ユーザーの作成（subuid/subgid付き）
USER_SHELL="/usr/sbin/nologin"  # 必要に応じて変更可能
sudo useradd --system --user-group --add-subids-for-system --shell "${USER_SHELL}" --comment "PVE Exporter rootless user" "monitoring"

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
sudo mkdir -p "${QUADLET_HOME}/.config/pve-exporter" &&
sudo mkdir -p "${QUADLET_HOME}/.config/containers/systemd" &&
sudo mkdir -p "${QUADLET_HOME}/.local/share/containers/storage"

# 所有権の設定
sudo chown -R "monitoring:monitoring" "${QUADLET_HOME}"

# パーミッションの設定
sudo chmod -R 755 "${QUADLET_HOME}"
```

#### ステップ2: Podmanのインストール

Podmanのインストールは各ディストリビューションのパッケージマネージャーを使用する。

#### ステップ3: 設定ファイルの作成

```bash
# 設定ディレクトリの作成
sudo -u monitoring mkdir -p /home/monitoring/.config/prometheus

# PVE接続設定ファイルの作成
sudo -u monitoring tee /home/monitoring/.config/prometheus/pve.yml << 'EOF' > /dev/null
default:
  user: prometheus@pve
  token_name: "exporter"
  token_value: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  verify_ssl: false
EOF

# 設定ファイルのパーミッション設定（トークンを含むため）
sudo chmod 600 /home/monitoring/.config/prometheus/pve.yml
```

#### ステップ4: Quadletコンテナの設定

```bash
# Quadletコンテナ定義ファイルの作成
sudo -u monitoring tee /home/monitoring/.config/containers/systemd/pve-exporter.container << 'EOF' > /dev/null
[Unit]
Description=Prometheus PVE Exporter Service

[Container]
Image=docker.io/prompve/prometheus-pve-exporter:latest
ContainerName=pve-exporter
AutoUpdate=registry
LogDriver=journald
UserNS=keep-id
NoNewPrivileges=true
ReadOnly=true
PublishPort=9221:9221
Volume=/home/monitoring/.config/prometheus/pve.yml:/etc/prometheus/pve.yml:ro,z
Volume=/etc/localtime:/etc/localtime:ro

[Service]
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# パーミッションの設定
sudo chmod 644 /home/monitoring/.config/containers/systemd/pve-exporter.container
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
  systemctl --user start "pve-exporter.service"
```

podman-auto-update.timerの起動と有効化によって、コンテナイメージの自動更新を有効にします：

```bash
# タイマーの起動と有効化
sudo -u monitoring \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user enable --now podman-auto-update.timer
```


## 運用管理

### Prometheusスクレイプ設定

VictoriaMetricsまたはPrometheusで使用するスクレイプ設定例:

```yaml
scrape_configs:
  - job_name: "pve"
    static_configs:
      - targets:
          - 192.168.1.10 # Proxmox VE node 1
          - 192.168.1.11 # Proxmox VE node 2
    metrics_path: /pve
    params:
      module: [default]
      cluster: ["1"]
      node: ["1"]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9221 # PVE exporter address
```

### 基本操作

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

サービス操作：

```bash
# サービスの状態確認
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user status "pve-exporter.service"

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "pve-exporter.service"

# サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user stop "pve-exporter.service"

# サービスの開始
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user start "pve-exporter.service"
```

ログ確認：

```bash
# サービスのログの確認（最新の100行）
sudo -u "monitoring" \
  journalctl --user -u "pve-exporter.service" --no-pager -n 100

# サービスのログの確認（リアルタイム表示）
sudo -u "monitoring" \
  journalctl --user -u "pve-exporter.service" -f
```

コンテナ確認：

```bash
# コンテナの状態確認
sudo -u "monitoring" podman ps

# すべてのコンテナを表示（停止中も含む）
sudo -u "monitoring" podman ps -a

# コンテナの詳細情報
sudo -u "monitoring" podman inspect pve-exporter

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
- `/home/monitoring/.config/pve-exporter/` - アプリケーション固有の設定
- `/home/monitoring/.config/containers/systemd/` - Quadletファイル配置場所
- `/home/monitoring/.local/share/containers/storage/` - コンテナストレージ


PVE Exporter固有の操作:

```bash
# メトリクスエンドポイントの確認
curl "http://localhost:9221/pve?target=192.168.1.10&module=default"

# エクスポーター自体のメトリクス確認
curl http://localhost:9221/metrics
```

### トラブルシューティング

診断フロー:

1. サービスの状態確認
2. ログメッセージの確認
3. Proxmox VE APIへの接続性確認
4. 認証情報の確認

よくある問題と対処:

- **サービスが起動しない**: 設定ファイルの構文とパーミッションを確認
- **認証エラー**: APIトークンの有効性とユーザー権限を確認
- **SSL証明書エラー**: `verify_ssl: false`を設定するか、証明書をインポート
- **メトリクスが取得できない**: Proxmox VEノードへのネットワーク接続を確認

```bash
# Proxmox VE APIへの接続テスト
curl -k "https://192.168.1.10:8006/api2/json/version"

# 設定ファイルの確認
sudo -u monitoring cat /home/monitoring/.config/prometheus/pve.yml
```

### メンテナンス

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

バックアップ：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 設定ファイルとQuadletファイルのバックアップ
sudo tar -czf "pve-exporter-backup-$(date +%Y%m%d).tar.gz" \
    "${QUADLET_HOME}/monitoring/.config/pve-exporter" \
    "${QUADLET_HOME}/monitoring/.config/containers/systemd"
```

手動更新：

```bash
# 手動でのイメージ更新
sudo -u "monitoring" podman pull docker.io/prompve/prometheus-pve-exporter:latest

# サービスの再起動
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u monitoring)" \
  systemctl --user restart "pve-exporter.service"
```

自動更新は`podman-auto-update.timer`により定期的に実行されます。


## アンインストール（手動）

以下の手順でPVE Exporterを完全に削除する。

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

```bash
# 0. ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "monitoring" | cut -d: -f6)"

# 1. サービスの停止
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user stop "pve-exporter.service"

# 2. 自動更新タイマーの停止と無効化
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user disable --now podman-auto-update.timer

# 3. Quadletコンテナ定義ファイルの削除
sudo rm -f \
  "${QUADLET_HOME}/monitoring/.config/containers/systemd/pve-exporter.container"

# 4. systemdユーザーデーモンのリロード
sudo -u "monitoring" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "monitoring")" \
  systemctl --user daemon-reload

# 5. コンテナイメージの削除
sudo -u "monitoring" podman rmi "docker.io/prompve/prometheus-pve-exporter:latest"

# 6. アプリケーション設定の削除
# 警告: この操作により、アプリケーション固有の設定がすべて削除されます
sudo rm -rf "${QUADLET_HOME}/monitoring/.config/pve-exporter"

# 7. lingeringを無効化
sudo loginctl disable-linger "monitoring"

# 8. ユーザーの削除
# 警告: このユーザーのホームディレクトリとすべてのデータが削除されます
sudo userdel -r "monitoring"
```


```bash
# 9. Prometheus設定ファイルの削除
sudo rm -rf /home/monitoring/.config/prometheus
```

## 参考

- [prometheus-pve-exporter GitHub](https://github.com/prometheus-pve/prometheus-pve-exporter)
- [Docker Hub - prompve/prometheus-pve-exporter](https://hub.docker.com/r/prompve/prometheus-pve-exporter)
- [Proxmox VE API Documentation](https://pve.proxmox.com/wiki/Proxmox_VE_API)
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
