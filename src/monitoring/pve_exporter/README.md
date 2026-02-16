# Prometheus PVE Exporter（pip版）

Proxmox VE クラスターのメトリクスを収集し、Prometheus形式で公開するエクスポーター。pipでvenv内にインストールし、systemdサービスとして動作する。

## 概要

### このドキュメントの目的

このロールは、Prometheus PVE ExporterをpipでインストールしsystemdサービスとしてデプロイするAnsible roleを提供する。コンテナ版（`pve_exporter_container`）とは異なり、Podmanが不要でシンプルな構成となる。

### 実現される機能

- Proxmox VEクラスターからのメトリクス収集
- VM/CTのCPU、メモリ、ディスク、ネットワーク使用量の監視
- ノードレベルのリソース監視
- Python venvによる隔離されたインストール
- systemdサービスによる自動起動と管理

## 要件と前提条件

### 共通要件

- OS: Ubuntu (noble), Debian (trixie), Alpine Linux
- Python 3.9以上
- ポート9221が利用可能であること
- Proxmox VE APIへのネットワーク接続が可能であること

### Proxmox VE側の要件

- APIトークンを持つユーザー（PVEAuditorロール推奨）
- APIトークンの作成手順:
  1. Datacenter > Permissions > Users でユーザー作成（User name: `prometheus`、Realm: `Proxmox VE authentication server`）
  2. Datacenter > Permissions > API Tokens でトークン作成（User: `prometheus@pve`、Token ID: `exporter`、Privilege Separation: off）
  3. Datacenter > Permissions の Add > User Permission でロールを割り当て（Path: `/`、User: `prometheus@pve`、Role: `PVEAuditor`）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                             | デフォルト値                  | 説明                                      |
| ---------------------------------- | ----------------------------- | ----------------------------------------- |
| `pve_exporter_user`                | `monitoring`                  | PVE Exporterを実行するユーザー名          |
| `pve_exporter_group`               | `monitoring`                  | PVE Exporterを実行するグループ名          |
| `pve_exporter_pip_package`         | `prometheus-pve-exporter`     | インストールするpipパッケージ名           |
| `pve_exporter_venv_dir`            | `/opt/pve-exporter`           | Python venvのインストール先               |
| `pve_exporter_port`                | `9221`                        | エクスポーターのリスニングポート          |
| `pve_exporter_service_restart`     | `always`                      | サービスの再起動ポリシー                  |
| `pve_exporter_service_restart_sec` | `5`                           | 再起動間隔（秒）                          |
| `pve_exporter_config_dir`          | `/etc/pve-exporter`           | 設定ファイルのディレクトリ                |
| `pve_exporter_config_file`         | `/etc/pve-exporter/pve.yml`   | PVE接続設定ファイルのパス                 |
| `pve_exporter_pve_targets`         | `{}`                          | PVEターゲットごとの設定（必須、下記参照） |
| `pve_exporter_pve_verify_ssl`      | `false`                       | SSL証明書の検証                           |
| `pve_exporter_collector_config`    | `true`                        | configコレクターの有効化                  |

`pve_exporter_pve_targets` の各ターゲットには以下のフィールドが必須:

| フィールド    | 説明                   |
| ------------- | ---------------------- |
| `user`        | Proxmox VE APIユーザー |
| `token_name`  | APIトークン名          |
| `token_value` | APIトークン値          |

#### タグとハンドラー

- ハンドラー:
  - `reload systemd daemon`: systemdデーモンをリロード（Debian/Ubuntu）
  - `restart pve_exporter`: PVE Exporterサービスを再起動（OS自動判定でsystemd/OpenRCを使い分け）

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

### 方法2: 手動での設定手順

#### ステップ1: ユーザーとディレクトリの作成

```bash
sudo groupadd --system monitoring
sudo useradd --system --gid monitoring --shell /usr/sbin/nologin --no-create-home monitoring
```

#### ステップ2: venvの作成とインストール

```bash
sudo python3 -m venv /opt/pve-exporter
sudo /opt/pve-exporter/bin/pip install prometheus-pve-exporter
```

#### ステップ3: 設定ファイルの作成

```bash
sudo mkdir -p /etc/pve-exporter
sudo tee /etc/pve-exporter/pve.yml << 'EOF' > /dev/null
default:
  user: prometheus@pve
  token_name: "exporter"
  token_value: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  verify_ssl: false
EOF
sudo chown root:monitoring /etc/pve-exporter/pve.yml
sudo chmod 640 /etc/pve-exporter/pve.yml
```

#### ステップ4: systemdサービスの作成

```bash
sudo tee /etc/systemd/system/pve-exporter.service << 'EOF' > /dev/null
[Unit]
Description=Prometheus PVE Exporter Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=monitoring
Group=monitoring
ExecStart=/opt/pve-exporter/bin/pve_exporter --config.file /etc/pve-exporter/pve.yml --web.listen-address :9221
Restart=always
RestartSec=5
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/etc/pve-exporter

[Install]
WantedBy=multi-user.target
EOF
```

#### ステップ5: サービスの起動

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pve-exporter.service
sudo systemctl status pve-exporter.service
```

## 運用管理

### 基本操作

```bash
# サービスの状態確認
sudo systemctl status pve-exporter.service

# ログの確認
sudo journalctl -u pve-exporter.service -f

# サービスの再起動
sudo systemctl restart pve-exporter.service

# メトリクスエンドポイントの確認
curl "http://localhost:9221/pve?target=192.168.1.10&module=default"

# エクスポーター自体のメトリクス確認
curl http://localhost:9221/metrics
```

### パッケージの更新

```bash
sudo /opt/pve-exporter/bin/pip install --upgrade prometheus-pve-exporter
sudo systemctl restart pve-exporter.service
```

### トラブルシューティング

- **サービスが起動しない**: 設定ファイルの構文とパーミッション、venvのパスを確認
- **認証エラー**: APIトークンの有効性とユーザー権限を確認
- **SSL証明書エラー**: `verify_ssl: false`を設定するか、証明書をインポート
- **メトリクスが取得できない**: Proxmox VEノードへのネットワーク接続を確認

## アンインストール（手動）

```bash
sudo systemctl disable --now pve-exporter.service
sudo rm /etc/systemd/system/pve-exporter.service
sudo systemctl daemon-reload
sudo rm -rf /opt/pve-exporter
sudo rm -rf /etc/pve-exporter
sudo userdel monitoring
sudo groupdel monitoring
```

## コンテナ版との比較

| 項目               | pip版（このロール）            | コンテナ版                     |
| ------------------ | ------------------------------ | ------------------------------ |
| 依存関係           | Python 3.9+                    | Podman                         |
| インストール先     | `/opt/pve-exporter` (venv)     | rootlessコンテナ               |
| サービス管理       | systemd / OpenRC（Alpine）     | user systemd                   |
| 更新方法           | pip upgrade                    | コンテナイメージ自動更新       |
| セキュリティ       | systemd hardening              | コンテナ隔離 + systemd         |

## 参考

- [prometheus-pve-exporter GitHub](https://github.com/prometheus-pve/prometheus-pve-exporter)
- [PyPI - prometheus-pve-exporter](https://pypi.org/project/prometheus-pve-exporter/)
- [PVE Exporter venv install guide](https://github.com/prometheus-pve/prometheus-pve-exporter/wiki/PVE-Exporter-on-Proxmox-VE-Node-in-a-venv)
- [Proxmox VE API Documentation](https://pve.proxmox.com/wiki/Proxmox_VE_API)
