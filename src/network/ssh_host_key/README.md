# ssh_host_key

カスタムSSHホストキーを注入するロール

## 概要

### このドキュメントの目的

このロールはカスタムSSHホストキーの注入を行う。`ssh_hardening`ロールから分離された独立ロールであり、単体でもdependencyとしても使用可能である。

### 実現される機能

- カスタムEd25519ホストキー（秘密鍵・公開鍵）の配置
- sshdへのカスタムホストキー設定の適用

## 要件と前提条件

### 共通要件

- OpenSSHサーバーがインストールされていること
- root権限またはsudo権限を持つユーザーでの実行

### Ansible固有の要件

- Ansible 2.9以降
- プレイブックレベルで `become: true` の指定が必要

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `sshd.host_ed25519_key` | カスタムEd25519ホスト秘密鍵（Vault暗号化推奨） | なし | はい |
| `sshd.host_ed25519_key_pub` | カスタムEd25519ホスト公開鍵 | なし | はい |

#### 依存関係

なし

#### ハンドラー

- `Reload SSH`: SSH設定変更後にSSHサービスをリロード

#### 使用例

**単体での使用:**
```yaml
- hosts: all
  become: true
  vars:
    sshd:
      host_ed25519_key: "{{ vault_ssh_host_ed25519_key }}"
      host_ed25519_key_pub: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
  roles:
    - ssh_host_key
```

**ssh_hardeningとの併用（推奨）:**
```yaml
- hosts: all
  become: true
  vars:
    sshd:
      host_ed25519_key: "{{ vault_ssh_host_ed25519_key }}"
      host_ed25519_key_pub: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
  roles:
    - ssh_hardening  # ssh_host_keyがdependencyとして自動的に適用される
```

### 方法2: 手動での設定手順

#### ステップ1: ホストキーの準備

```bash
# カスタムホストキーを生成（新規作成の場合）
ssh-keygen -t ed25519 -f custom_ssh_host_ed25519_key -N '' -C ''
```

#### ステップ2: sshd_config.dディレクトリの作成

```bash
sudo mkdir -p /etc/ssh/sshd_config.d
sudo chmod 755 /etc/ssh/sshd_config.d

# sshd_config.dのインクルード設定を確認
grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config || \
  echo "Include /etc/ssh/sshd_config.d/*.conf" | sudo tee -a /etc/ssh/sshd_config
```

#### ステップ3: ホストキーの配置

```bash
# カスタムホストキー設定ファイルを作成
sudo tee /etc/ssh/sshd_config.d/80-ssh-hostkey.conf > /dev/null << 'EOF'
HostKey /etc/ssh/custom_ssh_host_ed25519_key
EOF

# 権限を設定
sudo chmod 644 /etc/ssh/sshd_config.d/80-ssh-hostkey.conf
sudo chown root:root /etc/ssh/sshd_config.d/80-ssh-hostkey.conf

# カスタム秘密鍵を配置
sudo cp custom_ssh_host_ed25519_key /etc/ssh/custom_ssh_host_ed25519_key
sudo chmod 600 /etc/ssh/custom_ssh_host_ed25519_key
sudo chown root:root /etc/ssh/custom_ssh_host_ed25519_key

# カスタム公開鍵を配置
sudo cp custom_ssh_host_ed25519_key.pub /etc/ssh/custom_ssh_host_ed25519_key.pub
sudo chmod 644 /etc/ssh/custom_ssh_host_ed25519_key.pub
sudo chown root:root /etc/ssh/custom_ssh_host_ed25519_key.pub
```

#### ステップ4: 適用

```bash
# SSH設定のテスト
sudo sshd -t

# エラーがなければSSHサービスをリロード
sudo systemctl reload ssh    # Debian/Ubuntu
sudo systemctl reload sshd   # RHEL/CentOS/AlmaLinux
sudo rc-service sshd reload  # Alpine Linux
```

## 運用管理

### 基本操作

```bash
# 現在使用されているホストキーを確認
sudo sshd -T | grep hostkey

# ホストキーのフィンガープリントを表示
ssh-keygen -lf /etc/ssh/custom_ssh_host_ed25519_key.pub
```

### トラブルシューティング

**カスタムホストキーが使用されない場合:**
```bash
# ホストキーファイルの権限を確認
ls -la /etc/ssh/custom_ssh_host_*

# SSHデーモンのログを確認
sudo journalctl -u ssh -n 100       # Debian/Ubuntu (systemd)
sudo journalctl -u sshd -n 100      # RHEL/CentOS/AlmaLinux (systemd)
sudo tail -n 100 /var/log/messages  # Alpine Linux (OpenRC)
```

## アンインストール（手動）

```bash
# カスタムホストキー設定ファイルの削除
sudo rm -f /etc/ssh/sshd_config.d/80-ssh-hostkey.conf

# カスタムホストキーの削除
sudo rm -f /etc/ssh/custom_ssh_host_ed25519_key
sudo rm -f /etc/ssh/custom_ssh_host_ed25519_key.pub

# SSHサービスの再起動
sudo systemctl restart ssh    # Debian/Ubuntu
sudo systemctl restart sshd   # RHEL/CentOS/AlmaLinux
sudo rc-service sshd restart  # Alpine Linux
```
