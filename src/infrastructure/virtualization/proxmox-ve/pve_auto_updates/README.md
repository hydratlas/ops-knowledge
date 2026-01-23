# pve_auto_updates

Proxmox VEホストの自動セキュリティアップデートを設定するロール

## 概要

### このドキュメントの目的
このロールはProxmox VEホストにDebianセキュリティアップデートの自動適用機能を提供します。Ansibleによる自動設定と手動設定の両方の方法を説明します。

### 実現される機能
- Debianセキュリティパッチの自動適用
- 重要なセキュリティ脆弱性への迅速な対応
- システムの安定性を保ちながらセキュリティを維持
- Proxmox VEパッケージを除外した安全な自動更新

## 要件と前提条件

### 共通要件
- Proxmox VE 7.x以降
- インターネット接続またはローカルリポジトリへのアクセス
- root権限またはsudo権限を持つユーザーでの実行

### Ansible固有の要件
- Ansible 2.9以降
- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件
- apt-getコマンドが利用可能であること
- debconfツールがインストールされていること

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
- hosts: proxmox_hosts
  become: true
  roles:
    - pve_auto_updates
```

**他のProxmox VEロールと組み合わせた使用例:**
```yaml
- hosts: proxmox_hosts
  become: true
  roles:
    - pve_free_repo
    - pve_auto_updates
    - pve_remove_subscription_notice
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# システムのパッケージリストを更新
sudo apt update

# 現在のunattended-upgradesの状態を確認
dpkg -l | grep unattended-upgrades
```

#### ステップ2: インストール

```bash
# 必要なパッケージのインストール
sudo apt install -y unattended-upgrades apt-listchanges

# インストールの確認
dpkg -l | grep -E "(unattended-upgrades|apt-listchanges)"
```

#### ステップ3: 設定

```bash
# debconfを使用して自動アップデートを有効化
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | sudo debconf-set-selections
sudo dpkg-reconfigure -plow unattended-upgrades

# 自動アップデートの設定を作成
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null << 'EOF'
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};

Unattended-Upgrade::Automatic-Reboot "false";
EOF

# 権限を設定
sudo chmod 644 /etc/apt/apt.conf.d/50unattended-upgrades
sudo chown root:root /etc/apt/apt.conf.d/50unattended-upgrades
```

#### ステップ4: 起動と有効化

```bash
# systemdタイマーの有効化を確認
sudo systemctl is-enabled apt-daily.timer
sudo systemctl is-enabled apt-daily-upgrade.timer

# タイマーが無効な場合は有効化
sudo systemctl enable apt-daily.timer
sudo systemctl enable apt-daily-upgrade.timer

# タイマーを開始
sudo systemctl start apt-daily.timer
sudo systemctl start apt-daily-upgrade.timer
```

## 運用管理

### 基本操作

```bash
# 手動で即座に実行（ドライラン）
sudo unattended-upgrade --dry-run --debug

# 手動で即座に実行（実際に適用）
sudo unattended-upgrade -d

# 設定の確認
sudo unattended-upgrade --help

# 次回実行時刻の確認
systemctl list-timers apt-daily*
```

### ログとモニタリング

**ログファイルの場所:**
- `/var/log/unattended-upgrades/unattended-upgrades.log` - メインログ
- `/var/log/unattended-upgrades/unattended-upgrades-dpkg.log` - dpkgの詳細ログ
- `/var/log/apt/history.log` - apt履歴

**監視すべき項目:**
```bash
# 最新の自動更新ログを確認
sudo tail -n 50 /var/log/unattended-upgrades/unattended-upgrades.log

# エラーの確認
sudo grep ERROR /var/log/unattended-upgrades/unattended-upgrades.log

# 適用された更新の確認
sudo grep "Packages that will be upgraded" /var/log/unattended-upgrades/unattended-upgrades.log

# 再起動が必要なパッケージの確認
sudo cat /var/run/reboot-required 2>/dev/null
sudo cat /var/run/reboot-required.pkgs 2>/dev/null
```

### トラブルシューティング

**診断フロー:**

1. **自動更新が実行されない場合**
   ```bash
   # タイマーの状態を確認
   sudo systemctl status apt-daily.timer
   sudo systemctl status apt-daily-upgrade.timer
   
   # タイマーを再起動
   sudo systemctl restart apt-daily.timer
   sudo systemctl restart apt-daily-upgrade.timer
   ```

2. **設定が正しく適用されているか確認**
   ```bash
   # 有効な設定を表示
   sudo apt-config dump | grep -i unattended
   
   # Origins-Patternの確認
   sudo unattended-upgrade --dry-run -d 2>&1 | grep "Allowed origins"
   ```

3. **ディスク容量不足でエラーが発生する場合**
   ```bash
   # ディスク容量を確認
   df -h /var
   
   # 古いログを削除
   sudo rm -f /var/log/unattended-upgrades/*.log.*
   
   # aptキャッシュをクリア
   sudo apt clean
   ```

### メンテナンス

**定期的な確認事項:**
```bash
# ログのローテーション設定確認（月次）
ls -la /etc/logrotate.d/unattended-upgrades

# 自動更新の実行履歴確認（週次）
sudo grep "Starting unattended upgrades" /var/log/unattended-upgrades/unattended-upgrades.log | tail -10

# 保留中のセキュリティ更新確認（日次）
sudo unattended-upgrade --dry-run -d 2>&1 | grep "Packages that will be upgraded"
```

## アンインストール（手動）

```bash
# 自動更新の無効化
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean false" | sudo debconf-set-selections
sudo dpkg-reconfigure -plow unattended-upgrades

# タイマーの停止と無効化
sudo systemctl stop apt-daily.timer
sudo systemctl stop apt-daily-upgrade.timer
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer

# 設定ファイルの削除
sudo rm -f /etc/apt/apt.conf.d/50unattended-upgrades
sudo rm -f /etc/apt/apt.conf.d/20auto-upgrades

# パッケージのアンインストール（オプション）
sudo apt remove --purge unattended-upgrades apt-listchanges
sudo apt autoremove

# ログファイルの削除（オプション）
sudo rm -rf /var/log/unattended-upgrades/
```