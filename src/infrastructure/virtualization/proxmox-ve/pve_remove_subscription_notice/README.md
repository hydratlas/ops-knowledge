# pve_remove_subscription_notice

Proxmox VEの有効なサブスクリプションがない場合に表示されるサブスクリプション通知ポップアップを削除するロール

## 概要

### このドキュメントの目的
このロールは、Proxmox VE Web UIに表示されるサブスクリプション通知を削除する機能を提供します。Ansibleによる自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- Proxmox VE Web UIのサブスクリプション通知ポップアップの非表示化
- ログイン時の煩わしい通知の削除
- Proxmox VEの無料利用時のユーザビリティ向上

## 要件と前提条件

### 共通要件
- **OS**: Proxmox VE 6.x, 7.x, 8.x
- **権限**: root権限またはsudo権限
- **ネットワーク**: 特別な要件なし
- **リソース**: 特別な要件なし

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: ansible.builtin
- **制御ノード**: Python 3.6以上

### 手動設定の要件
- SSHまたはコンソールアクセス
- テキストエディタ（vi, nano等）
- sedコマンド

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はありません。

#### 依存関係
他のロールへの依存関係はありません。

#### タグとハンドラー
| 種類 | 名前 | 説明 |
|------|------|------|
| ハンドラー | restart pveproxy | pveproxyサービスを再起動して変更を適用 |

#### 使用例

基本的な使用例：
```yaml
---
- name: Remove Proxmox VE subscription notice
  hosts: proxmox_hosts
  become: yes
  roles:
    - pve_remove_subscription_notice
```

複数のProxmoxノードへの適用例：
```yaml
---
- name: Configure Proxmox VE cluster
  hosts: pve_cluster
  become: yes
  roles:
    - pve_free_repo
    - pve_remove_subscription_notice
    - pve_auto_updates
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

1. Proxmoxノードにroot権限でログイン：
```bash
ssh root@proxmox-host
```

2. 現在のproxmoxlib.jsファイルの確認：
```bash
ls -la /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
```

#### ステップ2: バックアップ作成

元のファイルのバックアップを作成：
```bash
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js \
   /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.$(date +%Y%m%d-%H%M%S)
```

#### ステップ3: 設定

サブスクリプション通知を無効化：
```bash
# sedを使用してJavaScriptファイルを修正
sed -i "s/Ext\.Msg\.show({/void({ \/\/Ext.Msg.show({/g" \
    /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
```

変更内容の確認：
```bash
# 変更が正しく適用されたか確認
grep -n "void({ //Ext.Msg.show({" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
```

#### ステップ4: 起動と有効化

pveproxyサービスを再起動して変更を適用：
```bash
systemctl restart pveproxy
systemctl status pveproxy
```

## 運用管理

### 基本操作

サービスの状態確認：
```bash
# pveproxyサービスの状態確認
systemctl status pveproxy

# 設定が適用されているか確認
grep -c "void({ //Ext.Msg.show({" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
```

### ログとモニタリング

関連ログファイル：
- `/var/log/pveproxy/access.log` - Webアクセスログ
- `/var/log/pveproxy/pveproxy.log` - pveproxyサービスログ
- `journalctl -u pveproxy` - systemdジャーナルログ

監視すべき項目：
- pveproxyサービスの稼働状態
- Web UIへのアクセス可能性
- Proxmoxアップデート後の設定維持状態

### トラブルシューティング

#### 問題1: 変更後もサブスクリプション通知が表示される
**原因**: ブラウザキャッシュが残っている
**対処方法**:
1. ブラウザのキャッシュをクリア
2. Ctrl+F5でハード再読み込み
3. シークレットモードで確認

#### 問題2: pveproxyが起動しない
**原因**: JavaScriptファイルの構文エラー
**対処方法**:
```bash
# バックアップから復元
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.* \
   /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```

#### 問題3: Proxmoxアップデート後に通知が再表示される
**原因**: アップデートによりファイルが上書きされた
**対処方法**: 再度設定手順を実行

診断フロー：
1. pveproxyサービスの状態確認
2. JavaScriptファイルの変更確認
3. ブラウザキャッシュのクリア
4. 別のブラウザでの動作確認

### メンテナンス

#### Proxmoxアップデート時の注意事項
```bash
# アップデート前にバックアップ
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js \
   /root/proxmoxlib.js.before-update

# アップデート実行
apt update && apt upgrade

# 変更が上書きされていないか確認
grep -c "void({ //Ext.Msg.show({" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# 必要に応じて再適用
```

#### 定期確認スクリプト
```bash
#!/bin/bash
# /usr/local/bin/check-subscription-notice.sh

if ! grep -q "void({ //Ext.Msg.show({" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; then
    echo "WARNING: Subscription notice is not disabled. Re-applying configuration..."
    sed -i "s/Ext\.Msg\.show({/void({ \/\/Ext.Msg.show({/g" \
        /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    systemctl restart pveproxy
fi
```

## アンインストール（手動）

設定を元に戻す手順：

1. バックアップから復元：
```bash
# バックアップファイルの確認
ls -la /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.*

# 最新のバックアップから復元
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak \
   /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
```

2. または、sedで元に戻す：
```bash
sed -i "s/void({ \/\/Ext\.Msg\.show({/Ext.Msg.show({/g" \
    /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
```

3. pveproxyサービスの再起動：
```bash
systemctl restart pveproxy
```

4. 変更の確認：
```bash
# Web UIにアクセスしてサブスクリプション通知が表示されることを確認
```