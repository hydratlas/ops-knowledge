# sssd_sudo_provider

FreeIPA/IdMのsudoルールをSSSD経由で集中管理するための設定ロール

## 概要

### このドキュメントの目的
このロールは、SSSDのsudoプロバイダー機能を設定します。FreeIPAサーバーで集中管理されたsudoルールを、SSSDを通じてクライアントシステムで利用できるようにします。Ansibleによる自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- FreeIPA/IdMサーバーからのsudoルール取得
- 集中管理されたsudoポリシーの適用
- ローカルsudoersファイルとの共存
- キャッシュによる高速なsudo認証
- オフライン時のsudo機能維持

## 要件と前提条件

### 共通要件
- **OS**: Linux（RHEL, CentOS, Ubuntu, Debian等）
- **権限**: root権限またはsudo権限
- **統合**: FreeIPAドメインへの参加済み
- **パッケージ**: sssd, sssd-sudo

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: ansible.builtin
- **実行権限**: become: true必須
- **変数**: ipaclient_domain（FreeIPAドメイン名）

### 手動設定の要件
- FreeIPAクライアントとして登録済み
- SSSDが動作中
- テキストエディタ（vi, nano等）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|--------------|------|
| `ipaclient_domain` | FreeIPAドメイン名 | - | はい |

#### 依存関係
- FreeIPAクライアント設定が完了していること
- SSSDが基本設定済みであること

#### タグとハンドラー
| 種類 | 名前 | 説明 |
|------|------|------|
| ハンドラー | Restart sssd | SSSDサービスを再起動 |

#### 使用例

基本的な使用例：
```yaml
---
- name: Configure SSSD sudo provider
  hosts: ipa_clients
  become: yes
  vars:
    ipaclient_domain: example.com
  roles:
    - sssd_sudo_provider
```

FreeIPAクライアント設定と組み合わせた例：
```yaml
---
- name: Complete FreeIPA client setup with sudo
  hosts: linux_servers
  become: yes
  vars:
    ipaclient_domain: corp.example.com
    ipaserver_hostname: ipa.corp.example.com
  roles:
    - freeipa_client
    - sssd_sudo_provider
    
  post_tasks:
    - name: Test sudo configuration
      ansible.builtin.command: sudo -l
      become_user: "{{ ansible_user }}"
      register: sudo_test
      changed_when: false
      
    - name: Display sudo rules
      ansible.builtin.debug:
        var: sudo_test.stdout_lines
```

複数環境での使用例：
```yaml
---
- name: Configure SSSD sudo for different environments
  hosts: all
  become: yes
  vars:
    domain_mapping:
      production: prod.example.com
      staging: stage.example.com
      development: dev.example.com
    ipaclient_domain: "{{ domain_mapping[env_type] }}"
  roles:
    - sssd_sudo_provider
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

1. FreeIPAドメイン参加状態の確認：
```bash
# ドメイン情報の確認
sudo ipa config-show

# 現在のユーザー情報
id $(whoami)

# SSSDサービス状態
sudo systemctl status sssd
```

2. 必要なパッケージのインストール：
```bash
# RHEL/CentOS/Fedora
sudo dnf install -y sssd sssd-tools sssd-sudo

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y sssd sssd-tools libsss-sudo
```

#### ステップ2: SSSD設定のバックアップ

既存設定のバックアップ：
```bash
# 設定ファイルのバックアップ
sudo cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.$(date +%Y%m%d-%H%M%S)

# 現在の設定確認
sudo sssctl config-check
```

#### ステップ3: 設定

SSSD設定ファイルの編集：
```bash
# SSSDサービスを停止
sudo systemctl stop sssd

# 設定ファイルを編集
sudo vi /etc/sssd/sssd.conf
```

以下の設定を追加または更新：
```ini
[sssd]
config_file_version = 2
services = nss, pam, sudo
domains = example.com

[domain/example.com]
# 既存の設定に以下を追加
sudo_provider = ipa
# オプション: sudoルールのキャッシュ設定
sudo_cache_timeout = 300
sudo_timed = true

# デバッグ用（必要に応じて）
# debug_level = 9
```

設定ファイルの権限設定：
```bash
# 権限を600に設定（必須）
sudo chmod 600 /etc/sssd/sssd.conf
sudo chown root:root /etc/sssd/sssd.conf

# SELinuxコンテキストの修正
if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
    sudo restorecon /etc/sssd/sssd.conf
fi
```

#### ステップ4: 起動と有効化

SSSDサービスの再起動：
```bash
# キャッシュのクリア
sudo rm -rf /var/lib/sss/db/*
sudo rm -rf /var/lib/sss/mc/*

# SSSDサービスの起動
sudo systemctl start sssd
sudo systemctl enable sssd

# サービス状態の確認
sudo systemctl status sssd
```

sudoルールの確認：
```bash
# 現在のユーザーのsudoルール確認
sudo -l

# 特定ユーザーのsudoルール確認
sudo -l -U username

# SSSDキャッシュの更新
sudo sss_cache -E
```

## 運用管理

### 基本操作

日常的な管理コマンド：
```bash
# sudoルールの一覧表示
sudo -l

# SSSDキャッシュの状態確認
sudo sssctl cache-expire -E

# 特定ユーザーのsudoルール確認
sudo -l -U username

# FreeIPAサーバー上のsudoルール確認
ipa sudorule-find
ipa sudorule-show rule_name
```

### ログとモニタリング

関連ログファイル：
- `/var/log/sssd/sssd_sudo.log` - sudo関連のSSSDログ
- `/var/log/sssd/sssd_<domain>.log` - ドメイン固有ログ
- `/var/log/secure` または `/var/log/auth.log` - sudo実行ログ
- `journalctl -u sssd` - SSSDサービスログ

監視すべき項目：
- SSSDサービスの稼働状態
- FreeIPAサーバーとの接続状態
- sudoルールのキャッシュ更新
- sudo実行の成功/失敗率
- キャッシュタイムアウトの適切性

監視スクリプト例：
```bash
#!/bin/bash
# /usr/local/bin/monitor-sssd-sudo.sh

echo "=== SSSD Sudo Provider Status ==="
echo "Date: $(date)"
echo

# SSSDサービス状態
echo "--- SSSD Service ---"
systemctl is-active sssd || echo "WARNING: SSSD is not running"

# sudo設定確認
echo -e "\n--- Sudo Configuration ---"
grep "sudo_provider" /etc/sssd/sssd.conf || echo "WARNING: sudo_provider not configured"

# キャッシュ統計
echo -e "\n--- Cache Statistics ---"
sudo sssctl cache-expire -E

# 最近のsudo実行
echo -e "\n--- Recent Sudo Activity ---"
sudo journalctl -u sssd --since "1 hour ago" | grep -i sudo | tail -10

# テストsudoルール
echo -e "\n--- Current User Sudo Rules ---"
sudo -l 2>&1 | head -20
```

### トラブルシューティング

#### 問題1: sudoルールが適用されない
**原因**: SSSDがFreeIPAからルールを取得できていない
**対処方法**:
```bash
# デバッグログを有効化
sudo sed -i '/\[domain/a debug_level = 9' /etc/sssd/sssd.conf
sudo systemctl restart sssd

# ログを確認
sudo tail -f /var/log/sssd/sssd_sudo.log

# キャッシュをクリアして再試行
sudo sss_cache -E
sudo -k  # sudoタイムスタンプをクリア
sudo -l
```

#### 問題2: sudo実行が遅い
**原因**: キャッシュ設定が不適切またはネットワーク遅延
**対処方法**:
```bash
# キャッシュタイムアウトを調整
sudo vi /etc/sssd/sssd.conf
# sudo_cache_timeout = 600  # 10分に増加

# オフラインキャッシュを有効化
# cache_credentials = true
# krb5_store_password_if_offline = true

sudo systemctl restart sssd
```

#### 問題3: 特定のsudoルールが機能しない
**原因**: FreeIPA側の設定問題またはルール競合
**対処方法**:
```bash
# FreeIPAサーバーでルールを確認
ipa sudorule-show rule_name --all

# ルールのテスト
ipa sudorule-test rule_name --user=username

# ローカルsudoersとの競合確認
sudo visudo -c
grep -v '^#' /etc/sudoers | grep -v '^$'
```

診断フロー：
1. SSSDサービスの動作確認
2. FreeIPAサーバーとの接続確認
3. sudoプロバイダー設定の確認
4. キャッシュの状態確認
5. ログファイルのエラー確認

### メンテナンス

#### sudoルールのキャッシュ管理
```bash
#!/bin/bash
# /usr/local/bin/sssd-sudo-cache-mgmt.sh

# キャッシュの統計情報
echo "=== SSSD Sudo Cache Management ==="
echo "Current cache status:"
sudo sssctl cache-expire -E

# 特定ユーザーのキャッシュ更新
refresh_user_sudo() {
    local user=$1
    echo "Refreshing sudo cache for user: $user"
    sudo sss_cache -u $user
    sudo -k -u $user  # Clear sudo timestamp
}

# 全ユーザーのキャッシュ更新
echo -e "\nRefreshing all user caches..."
for user in $(getent passwd | awk -F: '$3 >= 1000 {print $1}'); do
    refresh_user_sudo $user
done

# キャッシュサイズの確認
echo -e "\nCache sizes:"
du -sh /var/lib/sss/db/*
du -sh /var/lib/sss/mc/*
```

#### FreeIPAサーバーとの同期確認
```bash
#!/bin/bash
# /usr/local/bin/check-ipa-sudo-sync.sh

# FreeIPAサーバーのsudoルール数
echo "FreeIPA sudo rules:"
ipa sudorule-find --sizelimit=0 | grep "Number of entries"

# ローカルで認識されているルール
echo -e "\nLocal sudo rules for current user:"
sudo -l | grep -E "may run|NOPASSWD" | wc -l

# 同期状態の確認
echo -e "\nLast sync time:"
sudo sssctl domain-status $(hostname -d) | grep "Online status"
```

## アンインストール（手動）

SSSD sudoプロバイダー設定を削除する手順：

1. SSSD設定からsudoプロバイダーを削除：
```bash
# SSSDを停止
sudo systemctl stop sssd

# 設定ファイルを編集
sudo vi /etc/sssd/sssd.conf

# 以下の行を削除またはコメントアウト：
# sudo_provider = ipa
# また、servicesからsudoを削除：
# services = nss, pam
```

2. キャッシュのクリア：
```bash
sudo rm -rf /var/lib/sss/db/*
sudo rm -rf /var/lib/sss/mc/*
```

3. SSSDサービスの再起動：
```bash
sudo systemctl start sssd
```

4. ローカルsudoersファイルの設定（必要に応じて）：
```bash
# 必要なsudoルールをローカルに追加
sudo visudo

# 例：
# username ALL=(ALL) NOPASSWD: ALL
```

5. 設定の確認：
```bash
# sudoルールの確認
sudo -l

# SSSDサービスの状態
sudo systemctl status sssd

# sudoの動作確認
sudo echo "Sudo is working"
```