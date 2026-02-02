# alloy

Grafana Alloyをインストール・設定し、ログやメトリクスの収集・転送を自動化するロール

## 概要

### このドキュメントの目的
このロールは、Grafana Alloyの自動インストールと設定機能を提供します。Alloyは、観測可能性データ（ログ、メトリクス、トレース）の収集と転送を行うエージェントで、systemd journalのログをLokiに転送する設定を含みます。Ansibleによる自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- Grafana Alloyのインストールと設定
- systemd journalログのLokiへの転送
- ログのラベリングとリレーベリング
- サービスの自動起動と監視
- マルチプラットフォーム対応（Debian/Ubuntu/RHEL系）

## 要件と前提条件

### 共通要件
- **OS**: Ubuntu (focal, jammy), Debian (buster, bullseye, bookworm), RHEL/CentOS/Rocky/AlmaLinux (8, 9)
- **権限**: root権限またはsudo権限
- **ネットワーク**: Lokiサーバーへの接続（デフォルト: 3100番ポート）
- **ディスク**: ログバッファ用の十分な空き容量

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: ansible.builtin
- **実行権限**: become: true必須
- **パッケージマネージャ**: apt/dnf/yum

### 手動設定の要件
- インターネット接続（リポジトリアクセス用）
- GPGキーのインポート権限
- systemdサービス管理権限

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|--------------|------|
| `alloy_loki_hostname` | Lokiサーバーのホスト名 | `localhost` | いいえ |
| `alloy_service_enabled` | サービス自動起動の有効化 | `true` | いいえ |
| `alloy_service_state` | サービスの状態 | `started` | いいえ |
| `alloy_config_file` | 設定ファイルパス | `/etc/alloy/config.alloy` | いいえ |
| `alloy_user` | Alloyサービスユーザー | `alloy` | いいえ |
| `alloy_systemd_journal_group` | systemd-journalグループ名 | `systemd-journal` | いいえ |

#### 依存関係
他のロールへの依存関係はありません。

#### タグとハンドラー
| 種類 | 名前 | 説明 |
|------|------|------|
| ハンドラー | reload alloy | Alloyサービスをリロード |
| ハンドラー | restart alloy | Alloyサービスを再起動 |

#### 使用例

基本的な使用例：
```yaml
---
- name: Configure Grafana Alloy
  hosts: monitoring_agents
  become: yes
  roles:
    - alloy
```

Lokiサーバーを指定した例：
```yaml
---
- name: Configure Alloy with remote Loki
  hosts: all
  become: yes
  vars:
    alloy_loki_hostname: loki.example.com
  roles:
    - alloy
```

複数環境での使用例：
```yaml
---
- name: Configure Alloy for multiple environments
  hosts: all
  become: yes
  vars:
    loki_servers:
      production: loki-prod.example.com
      staging: loki-stage.example.com
      development: loki-dev.example.com
    alloy_loki_hostname: "{{ loki_servers[env_type] }}"
  roles:
    - alloy
```

カスタム設定を含む例：
```yaml
---
- name: Configure Alloy with custom settings
  hosts: monitoring_agents
  become: yes
  vars:
    alloy_loki_hostname: loki.monitoring.svc.cluster.local
    alloy_service_enabled: true
    alloy_service_state: started
  pre_tasks:
    - name: Ensure monitoring directory exists
      ansible.builtin.file:
        path: /var/log/alloy
        state: directory
        owner: alloy
        group: alloy
        mode: '0755'
  roles:
    - alloy
  post_tasks:
    - name: Verify Alloy is running
      ansible.builtin.systemd:
        name: alloy.service
      register: alloy_status
      failed_when: alloy_status.status.ActiveState != "active"
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

1. システムの更新：
```bash
# Debian/Ubuntu
sudo apt-get update

# RHEL/CentOS/Rocky/AlmaLinux
sudo dnf update
```

2. 必要なパッケージのインストール：
```bash
# Debian/Ubuntu
sudo apt-get install -y gpg wget curl

# RHEL系
sudo dnf install -y gnupg2 wget curl
```

#### ステップ2: リポジトリの設定

**Debian/Ubuntu系の場合：**
```bash
# GPGキーのインポート
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# リポジトリの追加
sudo tee "/etc/apt/sources.list.d/grafana.sources" > /dev/null << 'EOF'
Types: deb
URIs: https://apt.grafana.com
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/grafana.gpg
EOF

# パッケージリストの更新
sudo apt-get update
```

**RHEL系の場合：**
```bash
# GPGキーのインポート
curl -sS -L https://rpm.grafana.com/gpg.key | sudo rpm --import -

# リポジトリの追加
sudo tee /etc/yum.repos.d/grafana.repo > /dev/null << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# リポジトリキャッシュの更新
sudo dnf makecache
```

#### ステップ3: インストールと設定

Alloyのインストール：
```bash
# Lokiホスト名の設定（適宜変更）
LOKI_HOSTNAME="localhost"

# Debian/Ubuntu
sudo apt-get install -y alloy

# RHEL系
sudo dnf install -y alloy
```

設定ファイルの作成：
```bash
# 設定ディレクトリの確認
sudo mkdir -p /etc/alloy

# 設定ファイルの作成
sudo tee "/etc/alloy/config.alloy" > /dev/null << EOF
// Journalログのリレーベル設定
loki.relabel "journal" {
  forward_to = []

  rule {
    source_labels = ["__journal__systemd_unit"]
    target_label  = "unit"
  }
  
  rule {
    source_labels = ["__journal__hostname"]
    target_label  = "hostname"
  }
  
  rule {
    source_labels = ["__journal_priority"]
    target_label  = "priority"
  }
}

// Journalログソースの設定
loki.source.journal "read"  {
  forward_to    = [loki.write.endpoint.receiver]
  relabel_rules = loki.relabel.journal.rules
  labels        = {component = "loki.source.journal"}
}

// Lokiへの書き込み設定
loki.write "endpoint" {
  endpoint {
    url = "http://${LOKI_HOSTNAME}:3100/loki/api/v1/push"
    
    // 認証が必要な場合は以下を追加
    // basic_auth {
    //   username = "your-username"
    //   password = "your-password"
    // }
  }
}
EOF
```

#### ステップ4: 起動と有効化

ユーザー権限の設定：
```bash
# alloyユーザーをsystemd-journalグループに追加
sudo usermod -aG systemd-journal alloy

# 権限の確認
id alloy
```

サービスの起動：
```bash
# サービスのリロード（設定変更後）
sudo systemctl daemon-reload

# サービスの有効化と起動
sudo systemctl enable --now alloy.service

# サービス状態の確認
sudo systemctl status alloy.service
```

## 運用管理

### 基本操作

サービス管理コマンド：
```bash
# サービスの状態確認
sudo systemctl status alloy.service

# サービスの起動/停止/再起動
sudo systemctl start alloy.service
sudo systemctl stop alloy.service
sudo systemctl restart alloy.service

# 設定のリロード（サービス再起動不要）
sudo systemctl reload alloy.service

# サービスの有効化/無効化
sudo systemctl enable alloy.service
sudo systemctl disable alloy.service
```

### ログとモニタリング

ログファイルと確認方法：
```bash
# Alloyサービスログの確認
sudo journalctl -u alloy.service -f

# 最新100行のログ表示
sudo journalctl -u alloy.service --no-pager -n 100

# 特定期間のログ表示
sudo journalctl -u alloy.service --since "2024-01-01" --until "2024-01-02"

# エラーログのみ表示
sudo journalctl -u alloy.service -p err

# Alloy自体のデバッグ実行
sudo alloy run /etc/alloy/config.alloy --log.level=debug
```

監視すべき項目：
- Alloyサービスの稼働状態
- Lokiサーバーへの接続状態
- ログ転送のレート
- エラーメッセージの発生頻度
- システムリソース使用率（CPU、メモリ）

監視スクリプト例：
```bash
#!/bin/bash
# /usr/local/bin/check-alloy-status.sh

echo "=== Alloy Service Status ==="
echo "Date: $(date)"
echo

# サービス状態
echo "--- Service Status ---"
systemctl is-active alloy.service || echo "WARNING: Alloy is not running"

# プロセス情報
echo -e "\n--- Process Info ---"
ps aux | grep -E "[a]lloy run" || echo "No Alloy process found"

# ポート確認（Alloy APIポート）
echo -e "\n--- Listening Ports ---"
ss -tlnp | grep alloy || echo "No ports found"

# 最近のエラー
echo -e "\n--- Recent Errors ---"
journalctl -u alloy.service -p err --since "1 hour ago" --no-pager | tail -20

# Loki接続テスト
echo -e "\n--- Loki Connection Test ---"
LOKI_HOST=$(grep -oP 'url\s*=\s*"http://\K[^:]+' /etc/alloy/config.alloy)
nc -zv $LOKI_HOST 3100 2>&1 || echo "Cannot connect to Loki"
```

### トラブルシューティング

#### 問題1: Alloyサービスが起動しない
**原因**: 設定ファイルのエラーまたは権限問題
**対処方法**:
```bash
# 設定ファイルの検証
sudo alloy fmt /etc/alloy/config.alloy

# 手動実行でエラー確認
sudo -u alloy alloy run /etc/alloy/config.alloy --log.level=debug

# 権限の確認
ls -la /etc/alloy/
sudo chown -R root:root /etc/alloy/
sudo chmod 644 /etc/alloy/config.alloy
```

#### 問題2: ログがLokiに送信されない
**原因**: ネットワーク接続またはLoki設定の問題
**対処方法**:
```bash
# Loki接続テスト
curl -v http://localhost:3100/ready

# Journal読み取り権限の確認
groups alloy | grep -q systemd-journal || sudo usermod -aG systemd-journal alloy

# サービス再起動
sudo systemctl restart alloy.service

# ファイアウォール確認
sudo firewall-cmd --list-all  # または sudo ufw status
```

#### 問題3: 高いリソース使用率
**原因**: ログ量が多すぎるか、設定が最適化されていない
**対処方法**:
```bash
# リソース使用状況確認
top -p $(pgrep alloy)

# ログフィルタリング設定の追加
# /etc/alloy/config.alloyに以下を追加：
# rule {
#   source_labels = ["__journal_priority"]
#   regex = "[0-5]"  # 重要度6以上のみ転送
#   action = "keep"
# }
```

診断フロー：
1. サービス状態の確認
2. 設定ファイルの検証
3. ネットワーク接続の確認
4. ログファイルのエラー確認
5. 手動実行でのデバッグ

### メンテナンス

#### 設定のバックアップとリストア
```bash
#!/bin/bash
# /usr/local/bin/backup-alloy-config.sh

BACKUP_DIR="/var/backups/alloy"
mkdir -p $BACKUP_DIR

# 設定のバックアップ
cp /etc/alloy/config.alloy $BACKUP_DIR/config.alloy.$(date +%Y%m%d-%H%M%S)

# 古いバックアップの削除（30日以上）
find $BACKUP_DIR -name "config.alloy.*" -mtime +30 -delete
```

#### ログローテーション設定
```bash
# Alloy自体のログローテーション設定
sudo tee /etc/logrotate.d/alloy > /dev/null << 'EOF'
/var/log/alloy/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 alloy alloy
    postrotate
        systemctl reload alloy.service > /dev/null 2>&1 || true
    endscript
}
EOF
```

#### パフォーマンス監視
```bash
#!/bin/bash
# /usr/local/bin/monitor-alloy-performance.sh

# CPU/メモリ使用率の記録
echo "=== Alloy Performance Metrics ==="
echo "Timestamp: $(date +%Y-%m-%d\ %H:%M:%S)"

# プロセス情報
ps aux | grep "[a]lloy run" | awk '{print "CPU:", $3"%, MEM:", $4"%, VSZ:", $5"KB, RSS:", $6"KB"}'

# 転送統計（Alloy APIから取得可能な場合）
# curl -s http://localhost:12345/metrics | grep -E "loki_source_journal"
```

## アンインストール（手動）

Alloyを完全に削除する手順：

1. サービスの停止と無効化：
```bash
# サービスの停止
sudo systemctl stop alloy.service

# サービスの無効化
sudo systemctl disable alloy.service
```

2. パッケージの削除：
```bash
# Debian/Ubuntu
sudo apt-get purge -y alloy
sudo apt-get autoremove -y

# RHEL系
sudo dnf remove -y alloy
```

3. 設定ファイルとデータの削除：
```bash
# 設定ファイル
sudo rm -rf /etc/alloy/

# ログファイル（存在する場合）
sudo rm -rf /var/log/alloy/

# キャッシュデータ（存在する場合）
sudo rm -rf /var/lib/alloy/
```

4. ユーザーとグループの削除（必要に応じて）：
```bash
# ユーザーの削除
sudo userdel alloy

# systemd-journalグループからの削除は不要（ユーザー削除で自動的に削除される）
```

5. リポジトリの削除（オプション）：
```bash
# Debian/Ubuntu
sudo rm -f /etc/apt/sources.list.d/grafana.sources
sudo rm -f /etc/apt/keyrings/grafana.gpg

# RHEL系
sudo rm -f /etc/yum.repos.d/grafana.repo
```

6. 削除の確認：
```bash
# パッケージ確認
dpkg -l | grep alloy  # Debian/Ubuntu
rpm -qa | grep alloy  # RHEL系

# ファイル確認
find /etc /var -name "*alloy*" 2>/dev/null
```