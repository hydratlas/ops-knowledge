# ifupdown_config

Debian系ネットワークインターフェース設定ロール

## 概要

### このドキュメントの目的
このロールは、Debian系Linuxディストリビューションのネットワークインターフェースをifupdownツールを使用して設定します。Ansible自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- `/etc/network/interfaces`ファイルの管理
- 静的IPアドレス、DHCP、ブリッジ、VLAN等の設定
- ネットワークインターフェースの永続的な設定
- 再起動後も保持されるネットワーク構成

## 要件と前提条件

### 共通要件
- Debian/Ubuntu系Linux OS
- root権限またはsudo権限
- ifupdownパッケージがインストール済み

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- bashシェル
- sudo権限を持つユーザー
- テキストエディタ（nano、vim等）
- 基本的なネットワーク知識

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `ifupdown_config` | `/etc/network/interfaces`に書き込む設定内容 | なし | はい |

#### 依存関係
なし

#### タグとハンドラー
- タグ: なし
- ハンドラー: なし（ネットワーク再起動は手動で必要）

#### 使用例

静的IPアドレスの設定例：
```yaml
- hosts: servers
  become: true
  vars:
    ifupdown_config: |
      # This file describes the network interfaces available on your system
      # and how to activate them. For more information, see interfaces(5).
      
      source /etc/network/interfaces.d/*
      
      # The loopback network interface
      auto lo
      iface lo inet loopback
      
      # The primary network interface
      auto eth0
      iface eth0 inet static
        address 192.168.1.100
        netmask 255.255.255.0
        gateway 192.168.1.1
        dns-nameservers 8.8.8.8 8.8.4.4
  roles:
    - infrastructure/ifupdown_config
```

DHCP設定の例：
```yaml
- hosts: workstations
  become: true
  vars:
    ifupdown_config: |
      source /etc/network/interfaces.d/*
      
      auto lo
      iface lo inet loopback
      
      auto eth0
      iface eth0 inet dhcp
  roles:
    - infrastructure/ifupdown_config
```

ブリッジ設定の例：
```yaml
- hosts: kvm_hosts
  become: true
  vars:
    ifupdown_config: |
      source /etc/network/interfaces.d/*
      
      auto lo
      iface lo inet loopback
      
      auto eth0
      iface eth0 inet manual
      
      auto br0
      iface br0 inet static
        address 192.168.1.10
        netmask 255.255.255.0
        gateway 192.168.1.1
        bridge_ports eth0
        bridge_stp off
        bridge_fd 0
        bridge_maxwait 0
  roles:
    - infrastructure/ifupdown_config
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# 現在のネットワーク設定を確認
ip addr show
ip route show
cat /etc/network/interfaces

# 設定ファイルのバックアップ
sudo cp /etc/network/interfaces /etc/network/interfaces.backup

# ifupdownがインストールされているか確認
dpkg -l | grep ifupdown
# インストールされていない場合
sudo apt-get update && sudo apt-get install -y ifupdown
```

#### ステップ2: インターフェース設定の編集

静的IPアドレスの設定：
```bash
# エディタで設定ファイルを開く
sudo nano /etc/network/interfaces

# 以下の内容を記述
cat << 'EOF' | sudo tee /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
  address 192.168.1.100
  netmask 255.255.255.0
  gateway 192.168.1.1
  dns-nameservers 8.8.8.8 8.8.4.4
EOF
```

#### ステップ3: ネットワークインターフェースの再起動

```bash
# 方法1: インターフェースを個別に再起動
sudo ifdown eth0 && sudo ifup eth0

# 方法2: ネットワークサービスを再起動
sudo systemctl restart networking

# 方法3: すべてのインターフェースをリロード（推奨）
sudo ifreload -a

# 設定が適用されたか確認
ip addr show eth0
ip route show
```

#### ステップ4: 設定の検証

```bash
# IPアドレスが正しく設定されているか確認
ip addr show

# デフォルトゲートウェイの確認
ip route show default

# DNS設定の確認
cat /etc/resolv.conf

# 接続性テスト
ping -c 4 8.8.8.8
ping -c 4 google.com
```

## 運用管理

### 基本操作

インターフェースの状態確認：
```bash
# すべてのインターフェースの状態
ip link show

# 特定インターフェースの詳細
ip addr show eth0

# インターフェースの統計情報
ip -s link show eth0
```

インターフェースの有効化/無効化：
```bash
# インターフェースを無効化
sudo ifdown eth0

# インターフェースを有効化
sudo ifup eth0

# 設定をリロード（ifupdown2の場合）
sudo ifreload -a
```

### ログとモニタリング

```bash
# ネットワーク関連のログ
sudo journalctl -u networking
sudo journalctl -xe | grep -i network

# インターフェースの変更履歴
sudo journalctl -f | grep -E "(eth0|br0|link)"

# エラーとドロップの監視
watch -n 1 'ip -s link show eth0'
```

### トラブルシューティング

#### 診断フロー

1. インターフェースの物理的状態確認
   ```bash
   ip link show
   ethtool eth0  # 物理層の詳細
   ```

2. 設定ファイルの構文確認
   ```bash
   sudo ifup --no-act eth0
   ```

3. ネットワーク到達性確認
   ```bash
   ping -c 4 192.168.1.1  # ゲートウェイ
   ping -c 4 8.8.8.8      # 外部
   ```

#### よくある問題と対処方法

- **問題**: インターフェースが起動しない
  - **対処**: 設定ファイルの構文エラーを確認、`sudo ifup -v eth0`で詳細ログ確認

- **問題**: IPアドレスが設定されない
  - **対処**: DHCPサーバーの応答確認、静的設定の場合は重複IPをチェック

- **問題**: ネットワークに接続できない
  - **対処**: ゲートウェイ設定、ルーティング、ファイアウォールを確認

### メンテナンス

設定のテスト：
```bash
# 設定を一時的にテスト
sudo ifup --force --no-act eth0

# 設定の検証
sudo ifquery --check eth0
```

パフォーマンス監視：
```bash
# インターフェースの統計
sar -n DEV 1 10

# 帯域幅使用量
iftop -i eth0
```

## アンインストール（手動）

デフォルト設定に戻す手順：

```bash
# バックアップから復元
sudo cp /etc/network/interfaces.backup /etc/network/interfaces

# または最小構成に戻す
cat << 'EOF' | sudo tee /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# DHCPを使用する設定に戻す
auto eth0
iface eth0 inet dhcp
EOF

# ネットワークを再起動
sudo systemctl restart networking

# 確認
ip addr show
```

## 注意事項

- ネットワーク設定の変更はSSH接続に影響する可能性があります
- リモート接続時は、設定変更前に代替アクセス方法を確保してください
- 設定ファイルの構文エラーはネットワーク接続を完全に失う原因となります
- NetworkManagerが有効な場合は、ifupdownと競合する可能性があるため無効化を推奨
- 設定変更後は必ず`ifreload -a`ではなく個別にインターフェースを再起動することを推奨（接続が切れるリスクを最小化）