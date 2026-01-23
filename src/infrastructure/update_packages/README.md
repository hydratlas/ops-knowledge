# update_packages

システムパッケージを最新版に更新するロール

## 概要

### このドキュメントの目的
このロールはシステムパッケージの更新機能を提供します。Ansibleによる自動更新と手動更新の両方の方法を説明します。

### 実現される機能
- OSパッケージの最新版への更新
- セキュリティパッチの適用
- 依存関係の自動解決と更新
- Debian系とRHEL系の両ディストリビューションへの対応

## 要件と前提条件

### 共通要件
- インターネット接続またはローカルリポジトリへのアクセス
- root権限またはsudo権限を持つユーザーでの実行
- 十分なディスク容量（更新パッケージのダウンロード用）

### Ansible固有の要件
- Ansible 2.9以降
- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件
- apt（Debian系）またはdnf/yum（RHEL系）コマンドが利用可能であること

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はありません。

#### 依存関係
なし

#### タグとハンドラー
なし

#### 使用例

**基本的な使用例:**
```yaml
- hosts: all
  become: true
  roles:
    - update_packages
```

**特定のホストグループのみ更新:**
```yaml
- hosts: web_servers
  become: true
  roles:
    - update_packages
```

**他のロールと組み合わせた使用例:**
```yaml
- hosts: all
  become: true
  roles:
    - update_packages
    - timezone
    - ssh_secure
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

**Debian/Ubuntu:**
```bash
# 現在のパッケージ状態を確認
apt list --upgradable

# ディスク容量を確認
df -h /var/cache/apt/
```

**RHEL/CentOS/AlmaLinux:**
```bash
# 利用可能な更新を確認
sudo dnf check-update

# ディスク容量を確認
df -h /var/cache/dnf/
```

#### ステップ2: パッケージリストの更新

**Debian/Ubuntu:**
```bash
# パッケージリストを更新
sudo apt update
```

**RHEL/CentOS/AlmaLinux:**
```bash
# メタデータキャッシュをクリア（オプション）
sudo dnf clean all

# リポジトリメタデータを更新
sudo dnf makecache
```

#### ステップ3: パッケージの更新

**Debian/Ubuntu:**
```bash
# 全パッケージを更新（依存関係も含む）
sudo apt dist-upgrade -y

# または、より安全な更新方法
sudo apt upgrade -y
```

**RHEL/CentOS/AlmaLinux:**
```bash
# 全パッケージを更新
sudo dnf update -y

# セキュリティ更新のみ適用する場合
sudo dnf update --security -y
```

#### ステップ4: 更新後の確認

```bash
# 再起動が必要かを確認
# Debian/Ubuntu
test -f /var/run/reboot-required && echo "再起動が必要です"

# RHEL/CentOS/AlmaLinux
sudo needs-restarting -r

# 更新されたパッケージの一覧を確認
# Debian/Ubuntu
grep " upgrade " /var/log/dpkg.log

# RHEL/CentOS/AlmaLinux
sudo dnf history info last
```

## 運用管理

### 基本操作

```bash
# 更新可能なパッケージの一覧表示
# Debian/Ubuntu
apt list --upgradable

# RHEL/CentOS/AlmaLinux
sudo dnf check-update

# 特定のパッケージのみ更新
# Debian/Ubuntu
sudo apt install package-name

# RHEL/CentOS/AlmaLinux
sudo dnf update package-name
```

### ログとモニタリング

**ログファイルの場所:**
- Debian/Ubuntu: `/var/log/apt/`, `/var/log/dpkg.log`
- RHEL/CentOS/AlmaLinux: `/var/log/dnf.log`, `/var/log/yum.log`

**監視すべき項目:**
```bash
# 最近の更新履歴を確認
# Debian/Ubuntu
grep " upgrade " /var/log/dpkg.log | tail -20

# RHEL/CentOS/AlmaLinux
sudo dnf history list | head -10

# 自動更新の状態を確認（設定されている場合）
# Debian/Ubuntu
sudo systemctl status unattended-upgrades

# RHEL/CentOS/AlmaLinux
sudo systemctl status dnf-automatic
```

### トラブルシューティング

**診断フロー:**

1. **パッケージの依存関係エラー**
   ```bash
   # Debian/Ubuntu
   sudo apt --fix-broken install
   sudo dpkg --configure -a
   
   # RHEL/CentOS/AlmaLinux
   sudo dnf check
   sudo rpm --rebuilddb
   ```

2. **ディスク容量不足**
   ```bash
   # キャッシュをクリア
   # Debian/Ubuntu
   sudo apt clean
   sudo apt autoclean
   
   # RHEL/CentOS/AlmaLinux
   sudo dnf clean all
   ```

3. **リポジトリエラー**
   ```bash
   # リポジトリ設定を確認
   # Debian/Ubuntu
   sudo apt-cache policy
   
   # RHEL/CentOS/AlmaLinux
   sudo dnf repolist -v
   ```

### メンテナンス

**パッケージのホールド（更新を防ぐ）:**
```bash
# Debian/Ubuntu
sudo apt-mark hold package-name
apt-mark showhold  # ホールド中のパッケージを表示
sudo apt-mark unhold package-name  # ホールドを解除

# RHEL/CentOS/AlmaLinux
sudo dnf install dnf-plugin-versionlock
sudo dnf versionlock add package-name
sudo dnf versionlock list
sudo dnf versionlock delete package-name
```

**定期的な確認事項:**
```bash
# カーネル更新後の不要なカーネルを削除（月次）
# Debian/Ubuntu
sudo apt autoremove --purge

# RHEL/CentOS/AlmaLinux
sudo dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q)

# パッケージデータベースの整合性確認
# Debian/Ubuntu
sudo dpkg --audit

# RHEL/CentOS/AlmaLinux
sudo rpm -Va
```

## アンインストール（手動）

このロールは更新作業を行うものであり、アンインストールの概念は適用されません。ただし、特定のパッケージを以前のバージョンに戻す場合は以下の手順を使用します：

```bash
# パッケージのダウングレード
# Debian/Ubuntu
sudo apt install package-name=specific-version
# 利用可能なバージョンを確認
apt-cache madison package-name

# RHEL/CentOS/AlmaLinux
sudo dnf downgrade package-name
# 利用可能なバージョンを確認
sudo dnf --showduplicates list package-name

# システム全体を特定の日付の状態に戻す
# RHEL/CentOS/AlmaLinux のみ
sudo dnf history list
sudo dnf history undo transaction-id
```