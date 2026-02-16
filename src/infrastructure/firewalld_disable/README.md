# firewalld_disable

ファイアウォール（ufwおよびfirewalld）無効化ロール

## 概要

### このドキュメントの目的
このロールは、システムで動作している可能性のあるファイアウォール（ufwまたはfirewalld）を無効化します。Ansible自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- ufwファイアウォールの無効化（Debian/Ubuntu系）
- firewalldファイアウォールの無効化（RHEL/CentOS系）
- ファイアウォールサービスの自動起動無効化
- k3sなどのコンテナオーケストレーションツールの通信要件を満たす環境の構築

## 要件と前提条件

### 共通要件
- Linux OS（Debian/Ubuntu/RHEL/CentOS/AlmaLinux）
- root権限またはsudo権限
- 対象システムへのSSHアクセス

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- bashシェル
- sudo権限を持つユーザー
- systemctl（systemd環境）またはservice（SysV init環境）コマンド

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はありません。

#### 依存関係
なし

#### タグとハンドラー
- タグ: なし
- ハンドラー: なし

#### 使用例

基本的な使用例：
```yaml
- hosts: k3s_servers
  become: true
  roles:
    - infrastructure/firewalld_disable
```

複数ロールと組み合わせる例：
```yaml
- hosts: container_hosts
  become: true
  roles:
    - infrastructure/firewalld_disable
    - infrastructure/update_packages
    - services/k3s_install
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# 現在のファイアウォール状態を確認
# ufwの確認（Debian/Ubuntu）
which ufw && sudo ufw status

# firewalldの確認（RHEL/CentOS/AlmaLinux）
sudo systemctl status firewalld

# iptablesの確認（共通）
sudo iptables -L -n -v
```

#### ステップ2: ufwの無効化（Debian/Ubuntu系）

```bash
# ufwが存在する場合の処理
if which ufw >/dev/null 2>&1; then
    # ufwの状態を確認
    sudo ufw status
    
    # ufwを無効化
    sudo ufw disable
    
    # ufwサービスの自動起動を無効化
    sudo systemctl disable ufw
    
    # 確認
    sudo ufw status
    sudo systemctl is-enabled ufw
fi
```

#### ステップ3: firewalldの無効化（RHEL/CentOS系）

```bash
# firewalldサービスが存在する場合の処理
if systemctl list-unit-files | grep -q firewalld.service; then
    # firewalldを停止
    sudo systemctl stop firewalld
    
    # firewalldの自動起動を無効化
    sudo systemctl disable firewalld
    
    # マスクして確実に起動しないようにする（オプション）
    sudo systemctl mask firewalld
    
    # 確認
    sudo systemctl status firewalld
    sudo systemctl is-enabled firewalld
fi
```

#### ステップ4: iptablesルールのクリア（オプション）

```bash
# 既存のiptablesルールをすべてクリア
# 警告: これにより既存のファイアウォールルールがすべて削除されます

# ルールをクリア
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X

# デフォルトポリシーをACCEPTに設定
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# IPv6用（必要な場合）
sudo ip6tables -F
sudo ip6tables -X
sudo ip6tables -P INPUT ACCEPT
sudo ip6tables -P FORWARD ACCEPT
sudo ip6tables -P OUTPUT ACCEPT

# 現在のルールを確認
sudo iptables -L -n -v
```

## 運用管理

### 基本操作

ファイアウォールの状態確認：
```bash
# ufwの状態確認
sudo ufw status verbose

# firewalldの状態確認
sudo systemctl status firewalld
sudo firewall-cmd --state

# iptablesのルール確認
sudo iptables -L -n -v --line-numbers
```

### ログとモニタリング

```bash
# ufwのログ確認
sudo journalctl -u ufw -f

# firewalldのログ確認
sudo journalctl -u firewalld -f

# ドロップされたパケットの確認（iptables）
sudo dmesg | grep -i drop
```

### トラブルシューティング

#### 診断フロー

1. ファイアウォールサービスの状態確認
   ```bash
   systemctl list-units --type=service | grep -E '(firewall|ufw)'
   ```

2. 実際のパケットフィルタリング確認
   ```bash
   sudo iptables -L -n -v
   sudo iptables -t nat -L -n -v
   ```

3. ネットワーク接続性テスト
   ```bash
   # 特定ポートへの接続テスト
   nc -zv hostname port
   ```

#### よくある問題と対処方法

- **問題**: ファイアウォールを無効化してもポートがブロックされる
  - **対処**: iptablesルールが残っている可能性があるため、手動でクリア
  
- **問題**: 再起動後にファイアウォールが有効になる
  - **対処**: サービスの自動起動が無効化されているか確認

### メンテナンス

ファイアウォールの一時的な有効化（メンテナンス時）：
```bash
# ufwの一時有効化
sudo ufw enable

# firewalldの一時有効化
sudo systemctl start firewalld

# メンテナンス後に再度無効化
sudo ufw disable
sudo systemctl stop firewalld
```

## アンインストール（手動）

ファイアウォールを再度有効化する手順：

```bash
# ufwの再有効化（Debian/Ubuntu）
sudo systemctl enable ufw
sudo ufw enable

# firewalldの再有効化（RHEL/CentOS/AlmaLinux）
sudo systemctl unmask firewalld  # マスクした場合
sudo systemctl enable firewalld
sudo systemctl start firewalld

# デフォルトルールの設定例
# ufwの場合
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh

# firewalldの場合
sudo firewall-cmd --set-default-zone=public
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

## セキュリティ上の注意事項

**警告**: ファイアウォールを無効化すると、システムが外部からの攻撃に対して脆弱になります。

- このロールは開発環境や信頼できる内部ネットワークでの使用を想定しています
- 本番環境では、必要なポートのみを開放する適切なファイアウォール設定を推奨します
- k3sなどのコンテナオーケストレーションツールを使用する際は、必要なポートを明示的に開放することを推奨します
- ネットワークセグメンテーションやVLANなど、他のセキュリティ対策と組み合わせて使用してください