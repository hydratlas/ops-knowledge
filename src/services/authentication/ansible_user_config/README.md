# ansible_user_config

Ansible管理用ユーザーの設定を行い、セキュアな自動化環境を構築するロール

## 概要

### このドキュメントの目的
このロールは、Ansible管理用ユーザーの設定機能を提供します。SSHキー認証の設定、sudo権限の付与、セキュリティ強化のためのrootアクセス制限などを自動的に行います。Ansibleによる自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- Ansibleユーザーのセキュアな設定
- SSH公開鍵認証の設定
- パスワードなしsudo権限の付与
- rootユーザーのSSHアクセス無効化
- 古い設定ファイルのクリーンアップ

## 要件と前提条件

### 共通要件
- **OS**: Linux（Debian, Ubuntu, RHEL, CentOS等）
- **権限**: root権限またはsudo権限
- **ユーザー**: ansibleユーザーが存在すること
- **パッケージ**: sudo, openssh-server

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: ansible.builtin
- **実行権限**: become: true必須
- **制御ノード**: Python 3.6以上

### 手動設定の要件
- rootまたはsudo権限を持つアカウント
- SSH公開鍵の準備
- visudoコマンド（sudoers編集用）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|--------------|------|
| `ansible_user` | Ansible管理ユーザー名 | `ansible` | はい |
| `ansible_runner_user.ssh_authorized_keys` | SSH公開鍵のリスト | - | はい |
| `ansible_runner_user.password` | ユーザーパスワード（通常は'*'で無効化） | `*` | はい |

#### 依存関係
他のロールへの依存関係はありません。

#### タグとハンドラー
このロールにはタグやハンドラーは定義されていません。

#### 使用例

基本的な使用例：
```yaml
---
- name: Configure Ansible management user
  hosts: all
  become: yes
  vars:
    ansible_user: ansible
    ansible_runner_user:
      ssh_authorized_keys:
        - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHg... admin@example.com"
        - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJk... backup@example.com"
      password: '*'
  roles:
    - ansible_user_config
```

複数環境での使用例：
```yaml
---
- name: Configure Ansible users for different environments
  hosts: all
  become: yes
  vars:
    ansible_runner_user:
      ssh_authorized_keys: "{{ vault_ssh_keys[env_type] }}"
      password: '*'
  roles:
    - ansible_user_config
```

グループ変数を使用した例：
```yaml
# group_vars/production.yml
ansible_runner_user:
  ssh_authorized_keys:
    - "{{ lookup('file', 'files/ssh_keys/prod_admin.pub') }}"
    - "{{ lookup('file', 'files/ssh_keys/prod_backup.pub') }}"
  password: '*'

# playbook.yml
---
- name: Configure production servers
  hosts: production
  become: yes
  roles:
    - ansible_user_config
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

1. rootまたはsudo権限でログイン：
```bash
sudo -i
# または既存のsudo権限を持つユーザーで作業
```

2. ansibleユーザーの存在確認（存在しない場合は作成）：
```bash
# ユーザーの確認
id ansible

# ユーザーが存在しない場合は作成
useradd -m -s /bin/bash -c "Ansible Automation User" ansible

# ホームディレクトリの確認
ls -la /home/ansible/
```

#### ステップ2: SSH認証の設定

SSH公開鍵認証の設定：
```bash
# .sshディレクトリの作成
mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
chown ansible:ansible /home/ansible/.ssh

# authorized_keysファイルの作成
touch /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys
chown ansible:ansible /home/ansible/.ssh/authorized_keys

# SSH公開鍵の追加（単一の鍵）
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@example.com" >> /home/ansible/.ssh/authorized_keys

# 複数の鍵を追加
cat >> /home/ansible/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHg... primary-admin@example.com
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJk... backup-admin@example.com
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILm... automation@example.com
EOF

# SELinuxコンテキストの修正（RHEL/CentOS）
if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
    restorecon -R /home/ansible/.ssh
fi
```

#### ステップ3: sudo権限の設定

パスワードなしsudo権限の付与：
```bash
# sudoersファイルの作成
cat > /etc/sudoers.d/95-ansible-user << 'EOF'
ansible ALL=(ALL) NOPASSWD: ALL
EOF

# ファイル権限の設定
chmod 440 /etc/sudoers.d/95-ansible-user
chown root:root /etc/sudoers.d/95-ansible-user

# 構文検証
visudo -cf /etc/sudoers.d/95-ansible-user

# 古いsudoersファイルの削除
rm -f /etc/sudoers.d/ansible-runner-user
rm -f /etc/sudoers.d/ansible
rm -f /etc/sudoers.d/initial-user
```

#### ステップ4: ユーザー設定と起動

ユーザーアカウントの最終設定：
```bash
# シェルをbashに設定
usermod -s /bin/bash ansible

# パスワードを無効化（*に設定）
usermod -p '*' ansible

# または以下のコマンドでロック
passwd -l ansible

# 設定の確認
grep "^ansible:" /etc/passwd
grep "^ansible:" /etc/shadow

# rootユーザーのセキュリティ強化
# rootのSSH鍵を削除
rm -f /root/.ssh/authorized_keys

# rootパスワードを無効化
usermod -p '*' root
```

## 運用管理

### 基本操作

日常的な管理操作：
```bash
# ansibleユーザーでの接続テスト
ssh -i ~/.ssh/ansible_key ansible@target-host

# sudo権限の確認
ssh ansible@target-host "sudo whoami"

# 利用可能なsudo権限の一覧
ssh ansible@target-host "sudo -l"

# SSH鍵の一覧表示
sudo cat /home/ansible/.ssh/authorized_keys | grep -E "ssh-(rsa|ed25519|ecdsa)"
```

### ログとモニタリング

関連ログファイル：
- `/var/log/auth.log` - 認証ログ（Debian/Ubuntu）
- `/var/log/secure` - 認証ログ（RHEL/CentOS）
- `/var/log/sudo.log` - sudo実行ログ（設定による）
- `journalctl -u sshd` - SSHサービスログ

監視すべき項目：
- ansibleユーザーのログイン履歴
- sudo実行履歴
- 認証失敗の試行
- authorized_keysファイルの変更

監視コマンド例：
```bash
# 最近のansibleユーザーログイン
last ansible | head -20

# sudo使用履歴
grep "sudo.*ansible" /var/log/auth.log | tail -20

# SSH認証失敗
grep "Failed password\|Failed publickey" /var/log/auth.log | grep ansible

# ファイル変更監視
ls -la /home/ansible/.ssh/authorized_keys
md5sum /home/ansible/.ssh/authorized_keys
```

### トラブルシューティング

#### 問題1: SSH接続ができない
**原因**: SSH鍵の権限またはSELinuxコンテキストの問題
**対処方法**:
```bash
# 権限の確認と修正
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh

# SELinuxコンテキストの修正
restorecon -R /home/ansible/.ssh

# SSHデーモンの設定確認
sshd -T | grep -E "(PubkeyAuthentication|AuthorizedKeysFile|PermitRootLogin)"
```

#### 問題2: sudo権限が機能しない
**原因**: sudoersファイルの構文エラーまたは権限問題
**対処方法**:
```bash
# sudoers構文チェック
visudo -c

# ファイル権限確認
ls -la /etc/sudoers.d/95-ansible-user

# includeディレクティブ確認
grep "#includedir" /etc/sudoers

# デバッグモードでsudo実行
sudo -l -U ansible
```

#### 問題3: パスワード認証が要求される
**原因**: パスワードが正しく無効化されていない
**対処方法**:
```bash
# パスワード状態確認
passwd -S ansible

# パスワード無効化
usermod -p '*' ansible

# SSH設定確認
grep "PasswordAuthentication" /etc/ssh/sshd_config
```

診断フロー：
1. ユーザーアカウントの存在確認
2. SSH鍵ファイルの権限確認
3. sudoersファイルの構文確認
4. ログファイルのエラー確認
5. SELinuxやAppArmorの状態確認

### メンテナンス

#### SSH鍵のローテーション
```bash
#!/bin/bash
# /usr/local/bin/rotate-ansible-keys.sh

# バックアップ作成
cp /home/ansible/.ssh/authorized_keys /home/ansible/.ssh/authorized_keys.$(date +%Y%m%d)

# 新しい鍵を追加
echo "ssh-ed25519 AAAAC3... new-key@example.com" >> /home/ansible/.ssh/authorized_keys

# 古い鍵を削除（コメントを参照して特定）
sed -i '/old-key@example.com/d' /home/ansible/.ssh/authorized_keys

# 権限確認
chmod 600 /home/ansible/.ssh/authorized_keys
chown ansible:ansible /home/ansible/.ssh/authorized_keys
```

#### アクセス監査スクリプト
```bash
#!/bin/bash
# /usr/local/bin/audit-ansible-access.sh

echo "=== Ansible User Access Audit ==="
echo "Date: $(date)"
echo

echo "--- Recent Logins ---"
last ansible | head -10

echo
echo "--- Recent sudo Usage ---"
grep "sudo.*ansible" /var/log/auth.log | tail -10

echo
echo "--- Authorized Keys ---"
cat /home/ansible/.ssh/authorized_keys | while read line; do
    if [[ $line =~ ^ssh- ]]; then
        key_type=$(echo $line | awk '{print $1}')
        comment=$(echo $line | awk '{print $NF}')
        echo "$key_type ... $comment"
    fi
done

echo
echo "--- Failed Attempts ---"
grep "Failed.*ansible" /var/log/auth.log | tail -5
```

## アンインストール（手動）

Ansible管理ユーザー設定を削除する手順：

1. ansibleユーザーのsudo権限削除：
```bash
rm -f /etc/sudoers.d/95-ansible-user
```

2. SSH鍵の削除（必要に応じて）：
```bash
# すべての鍵を削除
> /home/ansible/.ssh/authorized_keys

# または特定の鍵のみ削除
sed -i '/specific-key-comment/d' /home/ansible/.ssh/authorized_keys
```

3. ansibleユーザーの無効化：
```bash
# アカウントをロック
usermod -L ansible

# シェルを無効化
usermod -s /sbin/nologin ansible
```

4. ansibleユーザーの完全削除（オプション）：
```bash
# ユーザーとホームディレクトリを削除
userdel -r ansible

# cronジョブがある場合は削除
rm -f /var/spool/cron/crontabs/ansible
```

5. rootアクセスの復元（必要に応じて）：
```bash
# rootパスワードの設定
passwd root

# rootのSSH鍵を復元（バックアップがある場合）
cp /path/to/backup/authorized_keys /root/.ssh/
```