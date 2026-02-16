# keepalived

VRRP（Virtual Router Redundancy Protocol）による高可用性を実現

## 概要

### このドキュメントの目的

このロールは、Keepalivedを使用してVRRPによる高可用性を実現します。ジャンプホストなどの重要なサービスで仮想IPアドレスのフェイルオーバーを提供し、Ansible自動設定と手動設定の両方の方法に対応しています。

### 実現される機能

- 仮想IPアドレスによる自動フェイルオーバー
- サービス監視によるヘルスチェック
- 複数のVRRPインスタンスのサポート
- カスタムチェックスクリプトによる柔軟な監視
- 優先度ベースのマスター選出

## 要件と前提条件

### 共通要件

- Debian/RedHat系ディストリビューション
- ネットワークインターフェース設定済み
- VRRPプロトコル（112）の通信が許可されていること
- rootまたはsudo権限

### Ansible固有の要件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要
- 制御ノードから対象ホストへのSSH接続

### 手動設定の要件

- rootまたはsudo権限
- テキストエディタの基本操作
- ネットワーク設定の基本知識

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                         | デフォルト値                                | 説明                                                 |
| ------------------------------ | ------------------------------------------- | ---------------------------------------------------- |
| `keepalived_base_dir`          | `/etc/keepalived`                           | Keepalivedのベースディレクトリ                       |
| `keepalived_config_file`       | `{{ keepalived_base_dir }}/keepalived.conf` | メイン設定ファイル                                   |
| `keepalived_config_dir`        | `{{ keepalived_base_dir }}/conf.d`          | 設定ディレクトリ                                     |
| `keepalived_check_scripts_dir` | `{{ keepalived_base_dir }}/scripts`         | チェックスクリプトディレクトリ                       |
| `keepalived_check_script_user` | `keepalived_script`                         | チェックスクリプトのグローバルデフォルト実行ユーザー |
| `keepalived_global_defs`       | {}                                          | グローバル設定                                       |
| `keepalived_vrrp_instances`    | []                                          | VRRPインスタンス設定のリスト                         |
| `keepalived_check_scripts`     | []                                          | チェックスクリプト設定のリスト                       |

**VRRPインスタンスパラメータ:**

- `name`: インスタンス名（必須）
- `interface`: インターフェース名（必須）
- `state`: MASTER/BACKUP（デフォルト: MASTER）
- `virtual_router_id`: 仮想ルーターID（必須、1-255）
- `priority`: 優先度（必須、0-255）
- `virtual_ipaddresses`: 仮想IPアドレスリスト（必須）
- `auth_type`/`auth_pass`: 認証設定（オプション）
- `track_scripts`: トラッキングするスクリプト名のリスト（オプション）

#### 依存関係

なし

#### タグとハンドラー

**ハンドラー:**

- `restart keepalived`: Keepalivedサービスを再起動

**タグ:**
このroleでは特定のタグは使用していません。

#### 使用例

基本設定：

```yaml
- hosts: jump_hosts
  become: true
  roles:
    - keepalived
```

ホスト個別設定（host_vars）：

```yaml
# host-01（MASTER）
keepalived_vrrp_instances:
  - name: "VI_1"
    interface: "eth0"
    state: "MASTER"
    virtual_router_id: 51
    priority: 100
    virtual_ipaddresses:
      - "192.168.1.100/24"
    track_scripts:
      - "check_ssh"

# host-02（BACKUP）
keepalived_vrrp_instances:
  - name: "VI_1"
    interface: "eth0"
    state: "BACKUP"
    virtual_router_id: 51
    priority: 90
    virtual_ipaddresses:
      - "192.168.1.100/24"
    track_scripts:
      - "check_ssh"
```

チェックスクリプトを含む設定：

```yaml
keepalived_check_scripts:
  - name: "check_ssh.sh"
    template: "check_systemd_service.sh.j2"
    vrrp_name: "check_ssh"
    service_name: "ssh.service"
    interval: 2
    weight: -10
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# チェックスクリプト用ユーザーの作成（システムユーザー）
sudo useradd -r -s /usr/sbin/nologin -d /nonexistent -M -c "Keepalived health check script user" keepalived_script
```

#### ステップ2: インストール

##### Debian/Ubuntu

```bash
# パッケージリストの更新
sudo apt-get update

# keepalivedのインストール
sudo apt-get install -y keepalived
```

##### RHEL/CentOS/Fedora

```bash
# keepalivedのインストール
sudo dnf install -y keepalived
```

#### ステップ3: 設定

##### ディレクトリ構造の作成

```bash
# 設定ディレクトリの作成
sudo mkdir -p /etc/keepalived/conf.d
sudo chmod 755 /etc/keepalived
sudo chmod 755 /etc/keepalived/conf.d

# スクリプトディレクトリの作成
sudo mkdir -p /etc/keepalived/scripts
sudo chmod 755 /etc/keepalived/scripts
```

##### チェックスクリプトの作成

```bash
# systemdサービス監視スクリプトの作成（例：SSH監視）
sudo tee /etc/keepalived/scripts/check_ssh.sh << 'EOF' > /dev/null
#!/bin/bash
# Check if systemd service is active
if systemctl is-active --quiet ssh.service; then
    exit 0
else
    exit 1
fi
EOF

# スクリプトに実行権限を付与
sudo chmod 755 /etc/keepalived/scripts/check_ssh.sh
sudo chown root:root /etc/keepalived/scripts/check_ssh.sh
```

##### メイン設定ファイルの作成

```bash
# メイン設定ファイル（conf.dディレクトリをインクルード）
sudo tee /etc/keepalived/keepalived.conf << 'EOF' > /dev/null
# Main configuration file for keepalived
# Include all configuration files from conf.d directory
include /etc/keepalived/conf.d/*.conf
EOF

sudo chmod 644 /etc/keepalived/keepalived.conf
sudo chown root:root /etc/keepalived/keepalived.conf
```

##### グローバル設定の作成

```bash
# グローバル定義
sudo tee /etc/keepalived/conf.d/00-global_defs.conf << 'EOF' > /dev/null
global_defs {
    # 通知メール無効化（メール設定なし）
    enable_script_security
    script_user keepalived_script
}
EOF

sudo chmod 644 /etc/keepalived/conf.d/00-global_defs.conf
sudo chown root:root /etc/keepalived/conf.d/00-global_defs.conf
```

##### VRRPスクリプトの定義

```bash
# チェックスクリプトの定義
sudo tee /etc/keepalived/conf.d/10-vrrp_scripts.conf << 'EOF' > /dev/null
vrrp_script check_ssh {
    script "/etc/keepalived/scripts/check_ssh.sh"
    interval 2      # チェック間隔（秒）
    weight -10      # 失敗時の優先度減少値
    fall 2          # 失敗判定回数
    rise 2          # 復旧判定回数
    user keepalived_script
}
EOF

sudo chmod 644 /etc/keepalived/conf.d/10-vrrp_scripts.conf
sudo chown root:root /etc/keepalived/conf.d/10-vrrp_scripts.conf
```

##### VRRPインスタンスの設定

**MASTERノードの場合:**

```bash
# VRRPインスタンス設定（MASTER）
sudo tee /etc/keepalived/conf.d/20-vrrp_instances.conf << 'EOF' > /dev/null
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1

    # 認証設定（オプション）
    authentication {
        auth_type PASS
        auth_pass 1234
    }

    # 仮想IPアドレス
    virtual_ipaddress {
        10.120.20.51/24
    }

    # トラッキングスクリプト
    track_script {
        check_ssh
    }
}
EOF

sudo chmod 600 /etc/keepalived/conf.d/20-vrrp_instances.conf
sudo chown root:root /etc/keepalived/conf.d/20-vrrp_instances.conf
```

**BACKUPノードの場合:**

```bash
# VRRPインスタンス設定（BACKUP）
sudo tee /etc/keepalived/conf.d/20-vrrp_instances.conf << 'EOF' > /dev/null
vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 90
    advert_int 1

    # 認証設定（オプション）
    authentication {
        auth_type PASS
        auth_pass 1234
    }

    # 仮想IPアドレス
    virtual_ipaddress {
        10.120.20.51/24
    }

    # トラッキングスクリプト
    track_script {
        check_ssh
    }
}
EOF

sudo chmod 600 /etc/keepalived/conf.d/20-vrrp_instances.conf
sudo chown root:root /etc/keepalived/conf.d/20-vrrp_instances.conf
```

#### ステップ4: 起動と有効化

```bash
# systemdデーモンのリロード
sudo systemctl daemon-reload

# keepalivedサービスの有効化
sudo systemctl enable keepalived

# keepalivedサービスの起動
sudo systemctl start keepalived
```

## 運用管理

### 基本操作

```bash
# サービスステータスの確認
sudo systemctl status keepalived

# サービスの再起動
sudo systemctl restart keepalived

# サービスの停止
sudo systemctl stop keepalived

# サービスの開始
sudo systemctl start keepalived

# 設定の検証
sudo keepalived -t
```

### ログとモニタリング

```bash
# ログの確認（リアルタイム）
sudo journalctl -u keepalived -f

# 仮想IPアドレスの確認（MASTERで実行）
ip addr show dev eth0 | grep -E "inet .* secondary"

# VRRPステータスの確認
sudo journalctl -u keepalived | grep -E "(Entering|Leaving) (MASTER|BACKUP) STATE"

# 最近のログ（100行）
sudo journalctl -u keepalived -n 100 --no-pager
```

### トラブルシューティング

#### 診断フロー

1. **サービスが起動しない**

   ```bash
   # 設定の検証
   sudo keepalived -t

   # 詳細なエラーログ
   sudo journalctl -u keepalived -n 200 --no-pager
   ```

2. **仮想IPが割り当てられない**

   ```bash
   # インターフェースの確認
   ip link show

   # VRRPパケットの確認（tcpdump必要）
   sudo tcpdump -i eth0 -n vrrp
   ```

3. **フェイルオーバーが機能しない**
   ```bash
   # チェックスクリプトの手動実行
   sudo -u keepalived_script /etc/keepalived/scripts/check_ssh.sh
   echo $?  # 0なら成功、それ以外は失敗
   ```

#### よくある問題と対処

1. **認証エラー**
   - パスワードは8文字以内である必要があります
   - 全ノードで同じパスワードを使用

2. **virtual_router_idの競合**
   - 同一ネットワーク内で一意である必要があります（1-255）

3. **ファイアウォール**
   ```bash
   # VRRPプロトコル（112）を許可
   sudo iptables -I INPUT -p vrrp -j ACCEPT
   ```

### メンテナンス

#### バックアップ

```bash
# 設定ファイルのバックアップ
sudo tar -czf keepalived-backup-$(date +%Y%m%d).tar.gz /etc/keepalived
```

#### フェイルオーバーテスト

```bash
# MASTERノードでサービスを停止
sudo systemctl stop keepalived

# BACKUPノードで仮想IPを確認
ip addr show dev eth0 | grep -E "inet .* secondary"

# MASTERノードでサービスを再開
sudo systemctl start keepalived
```

#### アップデート

```bash
# パッケージの更新（Debian/Ubuntu）
sudo apt-get update
sudo apt-get upgrade keepalived

# パッケージの更新（RHEL/CentOS）
sudo dnf update keepalived
```

## アンインストール（手動）

以下の手順でKeepalived設定を完全に削除します。

```bash
# 1. サービスの停止と無効化
sudo systemctl stop keepalived
sudo systemctl disable keepalived

# 2. パッケージの削除（Debian/Ubuntu）
sudo apt-get remove --purge keepalived
# または（RHEL/CentOS）
sudo dnf remove keepalived

# 3. 設定ファイルとスクリプトの削除
sudo rm -rf /etc/keepalived

# 4. チェックスクリプトユーザーの削除
# 警告: このユーザーが他のサービスで使用されていないことを確認
sudo userdel keepalived_script

# 5. 残存する仮想IPアドレスの手動削除（必要な場合）
# 例: sudo ip addr del 10.120.20.51/24 dev eth0
```

## 参考

- [Keepalived Documentation](https://www.keepalived.org/doc/)
- [VRRP Protocol RFC](https://tools.ietf.org/html/rfc5798)
