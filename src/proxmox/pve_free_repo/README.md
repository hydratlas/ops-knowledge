# pve_free_repo

Proxmox VEのリポジトリをエンタープライズ版から無料版に切り替えるロール

## 概要

### このドキュメントの目的
このロールはProxmox VEのリポジトリ設定を管理し、エンタープライズリポジトリから無料/非サブスクリプションリポジトリへの切り替え機能を提供します。Ansibleによる自動設定と手動設定の両方の方法を説明します。

### 実現される機能
- エンタープライズリポジトリの無効化
- PVE no-subscriptionリポジトリの有効化
- Ceph no-subscriptionリポジトリの設定
- 既存設定の自動バックアップ

## 要件と前提条件

### 共通要件
- Proxmox VE 7.x以降
- インターネット接続（Proxmoxリポジトリへのアクセス）
- root権限またはsudo権限を持つユーザーでの実行

### Ansible固有の要件
- Ansible 2.9以降
- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件
- apt-getコマンドが利用可能であること
- `/etc/os-release` ファイルが存在すること

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `ceph_version` | 使用するCephのバージョン | `reef` | いいえ |

**利用可能なCephバージョン:**
- `quincy` - Ceph 17.x
- `reef` - Ceph 18.x（デフォルト）
- `squid` - Ceph 19.x

#### 依存関係
なし

#### タグとハンドラー

**ハンドラー:**
- `Update apt cache`: リポジトリ変更後にaptキャッシュを更新

#### 使用例

**基本的な使用例:**
```yaml
- hosts: proxmox_hosts
  become: true
  roles:
    - pve_free_repo
```

**Cephバージョンを指定する場合:**
```yaml
- hosts: proxmox_hosts
  become: true
  vars:
    ceph_version: quincy
  roles:
    - pve_free_repo
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# 現在のリポジトリ設定を確認
ls -la /etc/apt/sources.list.d/

# Debianのバージョンを確認
cat /etc/os-release | grep VERSION_CODENAME

# 現在の設定をバックアップ
sudo cp -a /etc/apt/sources.list.d /etc/apt/sources.list.d.backup-$(date +%Y%m%d)
```

#### ステップ2: エンタープライズリポジトリの無効化

```bash
# PVEエンタープライズリポジトリをバックアップ
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sudo mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak
fi

# Cephリポジトリをバックアップ（存在する場合）
if [ -f /etc/apt/sources.list.d/ceph.list ]; then
    sudo mv /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list.bak
fi
```

#### ステップ3: 無料リポジトリの設定

```bash
# OSバージョンを取得
CODENAME=$(grep -oP '(?<=^VERSION_CODENAME=).+' /etc/os-release | tr -d '"')

# PVE no-subscriptionリポジトリを作成（新しいDEB822形式）
sudo tee /etc/apt/sources.list.d/pve-no-subscription.sources > /dev/null << EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: ${CODENAME}
Components: pve-no-subscription
EOF

# Ceph no-subscriptionリポジトリを作成（Cephを使用する場合）
# デフォルトはreef、必要に応じてquincyやsquidに変更
CEPH_VERSION="reef"
sudo tee /etc/apt/sources.list.d/ceph.sources > /dev/null << EOF
Types: deb
URIs: http://download.proxmox.com/debian/ceph-${CEPH_VERSION}
Suites: ${CODENAME}
Components: no-subscription
EOF

# 権限を設定
sudo chmod 644 /etc/apt/sources.list.d/pve-no-subscription.sources
sudo chmod 644 /etc/apt/sources.list.d/ceph.sources
```

#### ステップ4: リポジトリの更新

```bash
# GPGキーが正しく設定されていることを確認
sudo apt-get update

# エラーがある場合はGPGキーを再インポート
wget https://download.proxmox.com/debian/proxmox-release-${CODENAME}.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-${CODENAME}.gpg
```

## 運用管理

### 基本操作

```bash
# 現在のリポジトリ設定を確認
apt-cache policy

# 特定のパッケージのバージョンを確認
apt-cache policy proxmox-ve
apt-cache policy ceph

# リポジトリの有効/無効を確認
grep -r "^deb" /etc/apt/sources.list.d/
```

### ログとモニタリング

**監視すべき項目:**
```bash
# リポジトリ更新のエラーを確認
sudo apt-get update 2>&1 | grep -E "(Err|W:)"

# パッケージの依存関係を確認
sudo apt-get check

# 利用可能なアップデートを確認
apt list --upgradable
```

### トラブルシューティング

**診断フロー:**

1. **リポジトリエラーが発生する場合**
   ```bash
   # GPGキーの問題を確認
   sudo apt-key list
   
   # 不足しているキーを追加
   sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys [KEY_ID]
   ```

2. **404エラーが発生する場合**
   ```bash
   # リポジトリURLの確認
   cat /etc/apt/sources.list.d/*.sources
   
   # Debianバージョンとの整合性を確認
   echo "Current codename: $(lsb_release -cs)"
   ```

3. **パッケージの競合が発生する場合**
   ```bash
   # 競合するパッケージを確認
   sudo apt-get -f install
   
   # 依存関係の問題を解決
   sudo apt-get --fix-broken install
   ```

### メンテナンス

**定期的な確認事項:**
```bash
# リポジトリファイルの整合性確認（月次）
ls -la /etc/apt/sources.list.d/*.{list,sources} 2>/dev/null

# 無効化されたリポジトリの確認
ls -la /etc/apt/sources.list.d/*.bak 2>/dev/null

# Cephバージョンの確認（Ceph使用時）
ceph --version 2>/dev/null || echo "Ceph not installed"
```

## アンインストール（手動）

```bash
# エンタープライズリポジトリに戻す場合

# 無料リポジトリを無効化
sudo rm -f /etc/apt/sources.list.d/pve-no-subscription.sources
sudo rm -f /etc/apt/sources.list.d/ceph.sources

# エンタープライズリポジトリを復元
if [ -f /etc/apt/sources.list.d/pve-enterprise.list.bak ]; then
    sudo mv /etc/apt/sources.list.d/pve-enterprise.list.bak /etc/apt/sources.list.d/pve-enterprise.list
fi

if [ -f /etc/apt/sources.list.d/ceph.list.bak ]; then
    sudo mv /etc/apt/sources.list.d/ceph.list.bak /etc/apt/sources.list.d/ceph.list
fi

# リポジトリ情報を更新
sudo apt-get update

# 注意: エンタープライズリポジトリには有効なサブスクリプションが必要です
```