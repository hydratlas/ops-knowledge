# vyos

VyOSルーターの設定を管理し、ネットワーク設定の自動化と一元管理を実現するロール

## 概要

### このドキュメントの目的
このロールは、VyOSルーターの設定管理機能を提供します。ベース設定、DHCPマッピング設定、カスタム設定を組み合わせて、VyOSの設定を自動的に適用します。Ansibleによる自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- VyOSルーターの設定自動化
- ベース設定とカスタム設定の分離管理
- DHCP固定IPマッピングの管理
- 設定の一元化と標準化
- 設定変更の追跡と管理

## 要件と前提条件

### 共通要件
- **OS**: VyOS 1.3.x, 1.4.x（Sagitta）
- **権限**: VyOSの設定権限を持つユーザー
- **ネットワーク**: SSH接続可能な環境
- **リソース**: 特別な要件なし

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: vyos.vyos
- **接続タイプ**: network_cli
- **Python**: paramiko または netmiko

### 手動設定の要件
- SSHクライアント
- VyOSへのSSHアクセス
- テキストエディタ（設定ファイル作成用）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|--------------|------|
| `vyos_base_config` | ベース設定コマンドのリスト | `[]` | はい |
| `vyos_dhcp_mapping_config` | DHCP固定IPマッピング設定のリスト | `[]` | いいえ |
| `vyos_custom_config` | カスタム設定コマンドのリスト | `[]` | いいえ |

#### 依存関係
他のロールへの依存関係はありません。

#### タグとハンドラー
このロールにはタグやハンドラーは定義されていません。

#### 使用例

基本的な使用例：
```yaml
---
- name: Configure VyOS routers
  hosts: vyos_routers
  gather_facts: no
  connection: network_cli
  vars:
    ansible_network_os: vyos.vyos.vyos
    vyos_base_config:
      - set interfaces ethernet eth0 address dhcp
      - set interfaces ethernet eth1 address '192.168.1.1/24'
      - set service ssh port 22
      - set service ssh disable-host-validation
    vyos_custom_config:
      - set system host-name 'router01'
      - set system time-zone 'Asia/Tokyo'
  roles:
    - vyos
```

DHCP固定IPマッピングを含む例：
```yaml
---
- name: Configure VyOS with DHCP mappings
  hosts: vyos_routers
  gather_facts: no
  connection: network_cli
  vars:
    ansible_network_os: vyos.vyos.vyos
    vyos_base_config:
      - set interfaces ethernet eth1 address '192.168.1.1/24'
      - set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 range 0 start '192.168.1.100'
      - set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 range 0 stop '192.168.1.200'
      - set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 default-router '192.168.1.1'
      - set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 name-server '8.8.8.8'
    vyos_dhcp_mapping_config:
      - set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping server1 ip-address '192.168.1.10'
      - set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping server1 mac-address '00:11:22:33:44:55'
      - set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping server2 ip-address '192.168.1.11'
      - set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping server2 mac-address '00:11:22:33:44:56'
    vyos_custom_config:
      - set system host-name 'router01'
      - set firewall name OUTSIDE-IN default-action 'drop'
      - set firewall name OUTSIDE-IN rule 10 action 'accept'
      - set firewall name OUTSIDE-IN rule 10 state established 'enable'
  roles:
    - vyos
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

1. VyOSルーターにSSH接続：
```bash
ssh vyos@router-ip
```

2. 現在の設定をバックアップ：
```bash
show configuration commands > /config/backup-$(date +%Y%m%d-%H%M%S).txt
```

3. 設定モードに入る：
```bash
configure
```

#### ステップ2: ベース設定の適用

基本的なネットワーク設定：
```bash
# インターフェース設定
set interfaces ethernet eth0 address dhcp
set interfaces ethernet eth1 address '192.168.1.1/24'
set interfaces ethernet eth1 description 'LAN'

# SSH設定
set service ssh port 22
set service ssh disable-host-validation
set service ssh listen-address '192.168.1.1'

# DNS設定
set system name-server '8.8.8.8'
set system name-server '8.8.4.4'

# NTP設定
set system ntp server '0.pool.ntp.org'
set system ntp server '1.pool.ntp.org'
set system ntp server '2.pool.ntp.org'
```

#### ステップ3: DHCPサーバー設定

DHCPサーバーとDHCP固定IPマッピング：
```bash
# DHCPサーバー基本設定
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 range 0 start '192.168.1.100'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 range 0 stop '192.168.1.200'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 default-router '192.168.1.1'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 name-server '8.8.8.8'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 name-server '8.8.4.4'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 domain-name 'local.lan'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 lease '86400'

# DHCP固定IPマッピング
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping server1 ip-address '192.168.1.10'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping server1 mac-address '00:11:22:33:44:55'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping server1 description 'Web Server'

set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping printer1 ip-address '192.168.1.20'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping printer1 mac-address 'aa:bb:cc:dd:ee:ff'
set service dhcp-server shared-network-name LAN subnet 192.168.1.0/24 static-mapping printer1 description 'Office Printer'
```

#### ステップ4: カスタム設定と起動

システム設定とファイアウォール：
```bash
# システム設定
set system host-name 'router01'
set system time-zone 'Asia/Tokyo'
set system domain-name 'example.local'

# ファイアウォール設定
set firewall name OUTSIDE-IN default-action 'drop'
set firewall name OUTSIDE-IN rule 10 action 'accept'
set firewall name OUTSIDE-IN rule 10 state established 'enable'
set firewall name OUTSIDE-IN rule 10 state related 'enable'
set firewall name OUTSIDE-IN rule 10 description 'Allow established/related'

set firewall name OUTSIDE-IN rule 20 action 'accept'
set firewall name OUTSIDE-IN rule 20 protocol 'icmp'
set firewall name OUTSIDE-IN rule 20 icmp type-name 'echo-request'
set firewall name OUTSIDE-IN rule 20 description 'Allow ICMP echo'

# インターフェースにファイアウォールを適用
set interfaces ethernet eth0 firewall in name 'OUTSIDE-IN'

# 設定を適用して保存
commit
save
exit
```

## 運用管理

### 基本操作

設定の確認と管理：
```bash
# 実行中の設定を表示
show configuration

# 設定コマンド形式で表示
show configuration commands

# 特定セクションの設定を表示
show configuration commands | grep dhcp-server
show configuration commands | grep firewall

# インターフェース状態確認
show interfaces
show interfaces ethernet eth0
show interfaces ethernet eth1 brief
```

### ログとモニタリング

関連ログとモニタリング：
```bash
# システムログ
show log
show log tail 50
monitor log

# DHCPリース情報
show dhcp server leases
show dhcp server statistics

# ファイアウォールログ
show log firewall name OUTSIDE-IN

# トラフィック統計
show interfaces counters
monitor interfaces ethernet eth0
```

監視すべき項目：
- インターフェースのリンク状態
- DHCPリース使用率
- ファイアウォールのドロップ率
- CPU/メモリ使用率
- 設定変更履歴

### トラブルシューティング

#### 問題1: 設定がcommitできない
**原因**: 設定に構文エラーまたは矛盾がある
**対処方法**:
```bash
# エラー内容を確認
show | compare

# 問題のある設定を削除
delete <問題のある設定パス>

# または変更を破棄
exit discard
```

#### 問題2: DHCPクライアントがIPアドレスを取得できない
**原因**: DHCPサーバー設定またはインターフェース設定の問題
**対処方法**:
```bash
# DHCPサーバー状態確認
show dhcp server status
show dhcp server leases

# インターフェース確認
show interfaces ethernet eth1

# DHCPログ確認
show log dhcp
monitor log dhcp
```

#### 問題3: 外部からの接続ができない
**原因**: ファイアウォール設定またはNAT設定の問題
**対処方法**:
```bash
# ファイアウォールログ確認
show log firewall

# ファイアウォール統計
show firewall statistics

# NAT設定確認（必要な場合）
show nat source rules
```

診断フロー：
1. 設定の構文確認（compare）
2. インターフェース状態確認
3. ルーティングテーブル確認
4. ファイアウォールログ確認
5. パケットキャプチャ（必要に応じて）

### メンテナンス

#### 設定のバックアップとリストア
```bash
#!/bin/bash
# /config/scripts/backup-config.sh

# バックアップディレクトリ
BACKUP_DIR="/config/backups"
mkdir -p $BACKUP_DIR

# 日付付きバックアップ
DATE=$(date +%Y%m%d-%H%M%S)
show configuration commands > $BACKUP_DIR/config-$DATE.txt

# 古いバックアップの削除（30日以上）
find $BACKUP_DIR -name "config-*.txt" -mtime +30 -delete

echo "Configuration backed up to $BACKUP_DIR/config-$DATE.txt"
```

#### 設定の一括適用スクリプト
```bash
#!/bin/vbash
# /config/scripts/apply-config.sh

source /opt/vyatta/etc/functions/script-template

# 設定ファイルのパス
CONFIG_FILE=$1

if [ -z "$CONFIG_FILE" ]; then
    echo "Usage: $0 <config-file>"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
fi

# 設定モードに入る
configure

# 設定を読み込む
load $CONFIG_FILE

# 変更を確認
show | compare

# ユーザー確認
echo "Apply these changes? (yes/no)"
read answer

if [ "$answer" = "yes" ]; then
    commit
    save
    echo "Configuration applied and saved"
else
    exit discard
    echo "Changes discarded"
fi

exit
```

#### 定期的な設定監査
```bash
#!/bin/bash
# /config/scripts/audit-config.sh

# 基準設定ファイル
BASELINE="/config/baseline-config.txt"
CURRENT="/tmp/current-config.txt"

# 現在の設定を取得
show configuration commands > $CURRENT

# 差分を確認
diff -u $BASELINE $CURRENT > /tmp/config-diff.txt

if [ -s /tmp/config-diff.txt ]; then
    echo "Configuration drift detected:"
    cat /tmp/config-diff.txt
    # アラート送信などの処理
fi
```

## アンインストール（手動）

VyOS設定を初期状態に戻す手順：

1. 設定のバックアップ：
```bash
# 現在の設定を保存
show configuration commands > /config/final-backup.txt
```

2. 設定の初期化：
```bash
# 設定モードに入る
configure

# すべての設定を削除（注意：これにより接続が切れる可能性があります）
# 特定の設定のみ削除する場合は、個別にdeleteコマンドを使用

# DHCPサーバー設定の削除
delete service dhcp-server

# ファイアウォール設定の削除
delete firewall

# カスタムインターフェース設定の削除
delete interfaces ethernet eth1 address

# 最小限の設定を残す
set interfaces ethernet eth0 address dhcp
set service ssh port 22

commit
save
exit
```

3. システムの再起動（必要に応じて）：
```bash
reboot
```

4. 工場出荷時設定へのリセット（最終手段）：
```bash
# 警告：すべての設定が失われます
add system image
# プロンプトに従って新しいイメージをインストール
# その後、古い設定を削除
```