# ssh_hardening

SSHサーバーのセキュリティを強化するロール

## 概要

### このドキュメントの目的
このロールはSSHサーバーのセキュリティ強化設定を提供する。Ansibleによる自動設定と手動設定の両方の方法を説明する。

### 実現される機能
- パスワード認証の無効化による不正アクセスの防止
- 空パスワードの明示的な禁止
- rootユーザーの直接ログイン制限（デフォルト: 完全禁止）
- 暗号スイートの限定による通信の安全性確保
- セキュアなSSH設定の一元管理

## 要件と前提条件

### 共通要件
- OpenSSHサーバーがインストールされていること
- root権限またはsudo権限を持つユーザーでの実行
- 公開鍵認証が設定済みであること（パスワード認証無効化前に必須）

### Ansible固有の要件
- Ansible 2.9以降
- プレイブックレベルで `become: true` の指定が必要

### ロール変数

| 変数名 | デフォルト値 | 説明 |
|--------|-------------|------|
| `ssh_hardening_permit_root_login` | `"no"` | `PermitRootLogin`の値。rootログインが必要なホストでは`"prohibit-password"`を設定する |

### 手動設定の要件
- SSHクライアントからの接続が確立されていること
- 設定変更前に別のSSHセッションを開いておくこと（接続不能対策）

## 設定方法

### 方法1: Ansible Roleを使用

#### タグとハンドラー

**ハンドラー:**
- `Reload SSH`: SSH設定変更後にSSHサービスをリロード

#### 使用例

**基本的な使用例:**
```yaml
- hosts: all
  become: true
  roles:
    - ssh_hardening
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# 現在の設定をバックアップ
sudo cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# sshd_config.dディレクトリの作成（存在しない場合）
sudo mkdir -p /etc/ssh/sshd_config.d
sudo chmod 755 /etc/ssh/sshd_config.d

# sshd_config.dのインクルード設定を確認
grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config || \
  echo "Include /etc/ssh/sshd_config.d/*.conf" | sudo tee -a /etc/ssh/sshd_config
```

#### ステップ2: 設定

```bash
# セキュアSSH設定ファイルを作成
sudo tee /etc/ssh/sshd_config.d/00-ssh-hardening.conf > /dev/null << 'EOF'
PasswordAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
EOF

# 権限を設定
sudo chmod 644 /etc/ssh/sshd_config.d/00-ssh-hardening.conf
sudo chown root:root /etc/ssh/sshd_config.d/00-ssh-hardening.conf
```

#### ステップ3: 起動と有効化

```bash
# SSH設定のテスト
sudo sshd -t

# エラーがなければSSHサービスをリロード
# Debian/Ubuntu
sudo systemctl reload ssh

# RHEL/CentOS/AlmaLinux
sudo systemctl reload sshd
```

## 運用管理

### 基本操作

```bash
# SSHサービスの状態確認
sudo systemctl status ssh    # Debian/Ubuntu
sudo systemctl status sshd   # RHEL/CentOS/AlmaLinux

# 現在の設定を確認
sudo sshd -T | grep -E "(PasswordAuthentication|PermitRootLogin|HostKey)"

# SSHサービスの再起動（設定変更が反映されない場合）
sudo systemctl restart ssh   # Debian/Ubuntu
sudo systemctl restart sshd  # RHEL/CentOS/AlmaLinux
```

### ログとモニタリング

**ログファイルの場所:**
- `/var/log/auth.log` (Debian/Ubuntu)
- `/var/log/secure` (RHEL/CentOS/AlmaLinux)

**監視すべき項目:**
```bash
# 認証失敗の監視
sudo grep "Failed password" /var/log/auth.log
sudo grep "Failed publickey" /var/log/auth.log

# 不正なユーザーアクセス試行
sudo grep "Invalid user" /var/log/auth.log

# SSH接続の監視
sudo journalctl -u ssh --since "1 hour ago"
```

### トラブルシューティング

**診断フロー:**

1. **SSH接続できない場合**
   ```bash
   # クライアント側で詳細ログを表示
   ssh -vvv user@hostname

   # サーバー側でSSH設定を確認
   sudo sshd -T
   ```

2. **パスワード認証が無効にならない場合**
   ```bash
   # 設定ファイルの読み込み順序を確認
   ls -la /etc/ssh/sshd_config.d/

   # 競合する設定がないか確認
   sudo grep -r "PasswordAuthentication" /etc/ssh/
   ```

### メンテナンス

**定期的な確認事項:**
```bash
# SSH設定の定期確認（月次）
sudo sshd -t

# ホストキーのバックアップ（初回設定時）
sudo tar -czf /root/ssh-hostkeys-backup.tar.gz /etc/ssh/*host*key*

# 設定ファイルのバックアップ（変更前）
sudo cp -a /etc/ssh/sshd_config.d /etc/ssh/sshd_config.d.backup-$(date +%Y%m%d)
```

## アンインストール（手動）

```bash
# カスタムSSH設定ファイルの削除
sudo rm -f /etc/ssh/sshd_config.d/00-ssh-hardening.conf

# デフォルト設定に戻す
sudo sed -i 's/^PasswordAuthentication no/# PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin no/# PermitRootLogin yes/' /etc/ssh/sshd_config

# SSHサービスの再起動
sudo systemctl restart ssh   # Debian/Ubuntu
sudo systemctl restart sshd  # RHEL/CentOS/AlmaLinux

# 注意: この操作によりパスワード認証が再度有効になる
```
