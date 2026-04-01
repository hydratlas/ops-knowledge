# hostname

システムホスト名設定ロール

## 概要

### このドキュメントの目的
このロールは、Linuxシステムのホスト名を永続的に設定します。Ansible自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- システムホスト名の永続的な設定
- systemd環境ではhostnamectl、Alpine Linux（OpenRC）環境では/etc/hostnameを使用
- 再起動後も保持される設定
- RFC 1123準拠のホスト名検証

## 要件と前提条件

### 共通要件
- Linux OS（systemd搭載システム、またはAlpine Linux等のOpenRC環境）
- root権限またはsudo権限
- hostnamectlコマンド（systemd環境）またはhostnameコマンド（Alpine Linux等）が利用可能

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- シェル（bash、ash等）
- sudo権限を持つユーザー
- hostnamectl（systemd環境）またはhostnameコマンド（Alpine Linux等）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `hostname` | 設定するホスト名（英数字とハイフンのみ、最大63文字） | なし | はい |

#### 依存関係
なし

#### タグとハンドラー
- タグ: なし
- ハンドラー: なし

#### 使用例

基本的な使用例：
```yaml
- hosts: webservers
  become: true
  vars:
    hostname: web-01
  roles:
    - infrastructure/hostname
```

インベントリ変数を使用する例：
```yaml
# inventory/host_vars/web-01.yml
hostname: web-01

# playbook
- hosts: webservers
  become: true
  roles:
    - infrastructure/hostname
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# 現在のホスト名を確認
hostname
hostnamectl status

# /etc/hostsファイルを確認
cat /etc/hosts
```

#### ステップ2: ホスト名の設定

systemd環境（Debian/Ubuntu、RHEL/CentOS 7+等）：
```bash
# ホスト名を設定（例: web-01）
sudo hostnamectl set-hostname web-01

# 設定を確認
hostnamectl status
```

Alpine Linux（OpenRC環境）：
```bash
# ホスト名を設定（例: web-01）
echo "web-01" | sudo tee /etc/hostname

# 即時適用
sudo hostname -F /etc/hostname

# 設定を確認
hostname
```

従来の方法（systemd非対応環境）：
```bash
# 一時的にホスト名を変更
sudo hostname web-01

# 永続化のため設定ファイルを更新
echo "web-01" | sudo tee /etc/hostname

# Debian/Ubuntu系の場合
sudo sed -i "s/127.0.1.1.*/127.0.1.1\tweb-01/" /etc/hosts

# RHEL/CentOS系の場合（古いバージョン）
sudo sed -i "s/HOSTNAME=.*/HOSTNAME=web-01/" /etc/sysconfig/network
```

#### ステップ3: 設定の確認と適用

```bash
# 新しいホスト名を確認
hostname
hostname -f  # FQDN

# 必要に応じて再起動（推奨）
sudo reboot

# 再起動後に確認
hostname
hostnamectl status
```

## 運用管理

### 基本操作

ホスト名の確認（共通）：
```bash
# 短いホスト名
hostname

# FQDN（完全修飾ドメイン名）
hostname -f
```

systemd環境での詳細確認：
```bash
# 詳細情報
hostnamectl status

# すべてのホスト名形式を表示
hostnamectl status --static
hostnamectl status --transient
hostnamectl status --pretty
```

Alpine Linux（OpenRC環境）での確認：
```bash
# 設定ファイルの内容を確認
cat /etc/hostname

# ドメイン名を確認
hostname -d
```

### ログとモニタリング

systemd環境：
```bash
# ホスト名変更のログを確認
sudo journalctl -u systemd-hostnamed

# システムログで確認
sudo grep -i hostname /var/log/syslog  # Debian/Ubuntu
sudo grep -i hostname /var/log/messages # RHEL/CentOS

# 監査ログで確認（auditdが有効な場合）
sudo aureport -x --summary | grep hostname
```

Alpine Linux（OpenRC環境）：
```bash
# システムログで確認
sudo grep -i hostname /var/log/messages
```

### トラブルシューティング

#### 診断フロー

1. 現在の設定確認
   ```bash
   # systemd環境
   hostnamectl status

   # 共通
   cat /etc/hostname
   cat /etc/hosts
   ```

2. ネットワーク名前解決の確認
   ```bash
   hostname -f
   getent hosts $(hostname)
   ```

3. サービスへの影響確認
   ```bash
   # systemd環境
   systemctl status

   # Alpine Linux（OpenRC環境）
   rc-status
   ```

#### よくある問題と対処方法

- **問題**: ホスト名が変更されない
  - **対処**: hostnamectlの権限を確認し、sudo権限で実行
  
- **問題**: 再起動後に元のホスト名に戻る
  - **対処**: /etc/hostnameファイルの内容を確認し、正しく更新されているか確認

- **問題**: ホスト名に使用できない文字が含まれている
  - **対処**: RFC 1123準拠（英数字とハイフンのみ、先頭は英字）に修正

### メンテナンス

ホスト名の命名規則確認：
```bash
# 有効なホスト名かチェック
echo "web-01" | grep -E '^[a-zA-Z][a-zA-Z0-9-]{0,62}$'

# 長さをチェック（最大63文字）
echo -n "web-01" | wc -c
```

関連設定ファイルのバックアップ：
```bash
# バックアップ作成
sudo cp /etc/hostname /etc/hostname.backup
sudo cp /etc/hosts /etc/hosts.backup

# cloud-init環境の場合
sudo cp /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.backup
```

## アンインストール（手動）

ホスト名をデフォルトに戻す手順：

systemd環境：
```bash
# デフォルトホスト名（通常はlocalhost）に戻す
sudo hostnamectl set-hostname localhost

# または元のホスト名に戻す（バックアップがある場合）
sudo cp /etc/hostname.backup /etc/hostname
sudo hostnamectl set-hostname $(cat /etc/hostname)

# /etc/hostsファイルも更新
sudo sed -i "s/127.0.1.1.*/127.0.1.1\tlocalhost/" /etc/hosts

# 確認
hostname
hostnamectl status
```

Alpine Linux（OpenRC環境）：
```bash
# デフォルトホスト名に戻す
echo "localhost" | sudo tee /etc/hostname
sudo hostname -F /etc/hostname

# または元のホスト名に戻す（バックアップがある場合）
sudo cp /etc/hostname.backup /etc/hostname
sudo hostname -F /etc/hostname

# 確認
hostname
cat /etc/hostname
```

## 注意事項

- ホスト名の変更は多くのサービスに影響を与える可能性がある
- 特にクラスター環境では、ホスト名変更前に関連サービスへの影響を確認すること
- cloud-init環境では、`/etc/cloud/cloud.cfg`で`preserve_hostname: true`の設定が必要な場合がある
- ホスト名は一意である必要があり、ネットワーク内で重複しないよう注意すること
- Alpine Linuxでは`lbu commit`を実行しないと再起動時に設定が失われる場合がある（diskless/run-from-RAM構成の場合）