# timezone

システムタイムゾーンを設定するロール

## 概要

### このドキュメントの目的
このロールはシステムのタイムゾーン設定機能を提供します。Ansibleによる自動設定と手動設定の両方の方法を説明します。

### 実現される機能
- システムタイムゾーンの統一的な設定
- NTPとの連携による正確な時刻管理
- アプリケーションやログのタイムスタンプの一貫性確保

## 要件と前提条件

### 共通要件
- systemdベースのLinuxディストリビューション（timedatectlコマンドが必要）
- root権限またはsudo権限を持つユーザーでの実行

### Ansible固有の要件
- Ansible 2.9以降
- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件
- timedatectlコマンドが利用可能であること

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `timezone` | 設定するタイムゾーン（例: "Asia/Tokyo", "UTC"） | なし | はい |

#### 依存関係
なし

#### タグとハンドラー
なし

#### 使用例

**基本的な使用例:**
```yaml
- hosts: all
  become: true
  vars:
    timezone: Asia/Tokyo
  roles:
    - timezone
```

**グループ変数での設定例:**
```yaml
# group_vars/all.yml
timezone: Asia/Tokyo

# playbook.yml
- hosts: all
  become: true
  roles:
    - timezone
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# 現在のタイムゾーン設定を確認
timedatectl status

# 利用可能なタイムゾーンの一覧を確認
timedatectl list-timezones | grep Asia
```

#### ステップ2: 設定

```bash
# タイムゾーンを設定（例: Asia/Tokyo）
sudo timedatectl set-timezone Asia/Tokyo

# UTC（協定世界時）に設定する場合
sudo timedatectl set-timezone UTC

# America/New_Yorkに設定する場合
sudo timedatectl set-timezone America/New_York
```

#### ステップ3: 設定の確認

```bash
# 設定が反映されたことを確認
timedatectl status

# 日時を確認
date

# ハードウェアクロックとの同期状態を確認
hwclock --show
```

## 運用管理

### 基本操作

```bash
# 現在のタイムゾーン設定を確認
timedatectl

# 詳細な時刻情報を表示
timedatectl show

# ローカル時刻とUTC時刻を表示
date && date -u

# 特定のタイムゾーンでの時刻を確認
TZ='America/New_York' date
TZ='Europe/London' date
```

### ログとモニタリング

**監視すべき項目:**
```bash
# システムログでタイムゾーン変更を確認
sudo journalctl -u systemd-timedated

# NTP同期状態を確認（時刻の正確性）
timedatectl show-timesync --all

# タイムゾーン変更の履歴
sudo grep timezone /var/log/syslog
```

### トラブルシューティング

**診断フロー:**

1. **タイムゾーンが設定されない場合**
   ```bash
   # timedatedサービスの状態を確認
   sudo systemctl status systemd-timedated
   
   # サービスを再起動
   sudo systemctl restart systemd-timedated
   ```

2. **時刻がずれている場合**
   ```bash
   # NTP同期の状態を確認
   timedatectl status | grep "NTP"
   
   # NTP同期を有効化
   sudo timedatectl set-ntp true
   ```

3. **アプリケーションが古いタイムゾーンを使用している場合**
   ```bash
   # 環境変数を確認
   echo $TZ
   
   # 一時的に環境変数を設定
   export TZ='Asia/Tokyo'
   
   # システム全体の設定を再読み込み
   sudo systemctl daemon-reload
   ```

### メンテナンス

**定期的な確認事項:**
```bash
# タイムゾーンデータベースの更新確認（月次）
apt list --upgradable | grep tzdata    # Debian/Ubuntu
dnf check-update | grep tzdata          # RHEL/CentOS/AlmaLinux

# タイムゾーンデータベースの更新
sudo apt update && sudo apt upgrade tzdata    # Debian/Ubuntu
sudo dnf update tzdata                        # RHEL/CentOS/AlmaLinux

# 夏時間（DST）の切り替え確認
zdump -v $(timedatectl show --property=Timezone --value) | grep $(date +%Y)
```

## アンインストール（手動）

```bash
# デフォルトのタイムゾーン（UTC）に戻す
sudo timedatectl set-timezone UTC

# または、ディストリビューションのデフォルトに戻す
# Debian/Ubuntu（デフォルト: Etc/UTC）
sudo timedatectl set-timezone Etc/UTC

# シンボリックリンクを直接操作する方法（非推奨）
# sudo rm /etc/localtime
# sudo ln -s /usr/share/zoneinfo/UTC /etc/localtime

# 設定の確認
timedatectl status
```