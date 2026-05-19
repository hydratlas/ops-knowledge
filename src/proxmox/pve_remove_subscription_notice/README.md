# pve_remove_subscription_notice

Proxmox VEの有効なサブスクリプションがない場合に表示されるサブスクリプション通知ポップアップを削除するロール

## 概要

### このドキュメントの目的
このロールは、Proxmox VE Web UIに表示されるサブスクリプション通知を削除する機能を提供する。`/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js`のパッチ適用と、パッケージ更新によるファイル置き換え後の自動再適用までを担当する。

### 実現される機能
- Proxmox VE Web UIのサブスクリプション通知ポップアップの非表示化
- ログイン時の煩わしい通知の削除
- `proxmoxlib.js`が再生成された際の自動再パッチ（systemd path ユニットによる inotify 監視）
- パッチ適用後の`pveproxy`再起動

### 設計方針

旧実装はAPTフック（`DPkg::Post-Invoke`）により再パッチを行っていたが、Debian 13（APT 3.x）環境ではフックが期待どおりに発火せずパッチが失われる事象が確認された。本実装ではAPTに依存せず、`proxmoxlib.js`そのものの変更を systemd の path ユニットで inotify 監視する方式とした。APTでも`dpkg -i`直叩きでもPVE側の自動更新でも、ファイルが書き換えられれば確実に発火する。

### 構成要素

| 種類 | パス | 役割 |
|------|------|------|
| シェルスクリプト | `/usr/local/sbin/pve-remove-subscription-notice` | パッチ適用本体（冪等） |
| systemd service | `/etc/systemd/system/pve-remove-subscription-notice.service` | スクリプトを呼ぶ oneshot サービス |
| systemd path | `/etc/systemd/system/pve-remove-subscription-notice.path` | `proxmoxlib.js`の変更を監視しサービスを起動 |

スクリプトはパッチ済みであれば何もせず終了する。パッチ適用に成功した場合のみ`pveproxy`を再起動する。

## 要件と前提条件

### 共通要件
- **OS**: Proxmox VE 8.x / 9.x（systemd 必須）
- **権限**: root権限またはsudo権限

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: ansible.builtin

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はない。

#### 依存関係
他のロールへの依存関係はない。

#### タグとハンドラー
| 種類 | 名前 | 説明 |
|------|------|------|
| ハンドラー | reload systemd | `systemctl daemon-reload`を実行 |
| ハンドラー | restart pve-remove-subscription-notice.path | path ユニットを再起動して監視設定を反映 |

#### 使用例

```yaml
---
- name: Remove Proxmox VE subscription notice
  hosts: pve
  become: true
  roles:
    - proxmox/pve_remove_subscription_notice
```

### 方法2: 手動での設定手順

#### ステップ1: パッチ適用スクリプトの配置

`/usr/local/sbin/pve-remove-subscription-notice`に以下の内容で配置し、`chmod 0755`する。

```sh
#!/bin/sh
set -eu
FILE=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
[ -f "$FILE" ] || exit 0
if grep -q 'void({ //Ext\.Msg\.show' "$FILE"; then
    exit 0
fi
sed -z -i 's/Ext\.Msg\.show({[[:space:]]*title: gettext(.No valid sub/void({ \/\/&/' "$FILE"
if grep -q 'void({ //Ext\.Msg\.show' "$FILE"; then
    systemctl restart pveproxy
fi
```

#### ステップ2: systemd ユニットの配置

`/etc/systemd/system/pve-remove-subscription-notice.service`:

```ini
[Unit]
Description=Re-apply subscription notice removal patch to proxmoxlib.js
ConditionPathExists=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
After=pveproxy.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/pve-remove-subscription-notice
```

`/etc/systemd/system/pve-remove-subscription-notice.path`:

```ini
[Unit]
Description=Watch proxmoxlib.js and re-apply subscription notice removal on change
After=pveproxy.service

[Path]
PathChanged=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
Unit=pve-remove-subscription-notice.service

[Install]
WantedBy=multi-user.target
```

#### ステップ3: 有効化と初回適用

```bash
systemctl daemon-reload
systemctl enable --now pve-remove-subscription-notice.path
systemctl start pve-remove-subscription-notice.service
```

## 運用管理

### 状態確認

```bash
# path ユニットの状態（active であれば監視中）
systemctl status pve-remove-subscription-notice.path

# 直近の再適用履歴
journalctl -u pve-remove-subscription-notice.service --since "7 days ago"

# パッチ適用状況
grep -c 'void({ //Ext\.Msg\.show' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
```

### 動作確認

`proxmox-widget-toolkit`を再インストールするとファイルが上書きされ、path ユニット経由でサービスが起動して再パッチされる。

```bash
apt-get install --reinstall proxmox-widget-toolkit
journalctl -u pve-remove-subscription-notice.service -n 20
grep -c 'void({ //Ext\.Msg\.show' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
```

### トラブルシューティング

#### パッチが当たらない
- `systemctl is-active pve-remove-subscription-notice.path`で path ユニットが active か確認する
- `proxmox-widget-toolkit`のバージョン更新でJavaScriptの構造が変わり sed の正規表現がマッチしなくなった可能性がある場合は、`/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js`内の`No valid sub`周辺を確認する
- ブラウザキャッシュの可能性もあるため Ctrl+F5 で再読み込みする

#### `pveproxy`が起動しない
sed 失敗時はスクリプト側で`systemctl restart pveproxy`を実行しないため、本ロールが原因で起動不能になる経路はない。それでも疑わしい場合はパッケージを再インストールして元に戻す。

```bash
apt-get install --reinstall proxmox-widget-toolkit
```

## アンインストール

```bash
systemctl disable --now pve-remove-subscription-notice.path
rm -f /etc/systemd/system/pve-remove-subscription-notice.path
rm -f /etc/systemd/system/pve-remove-subscription-notice.service
rm -f /usr/local/sbin/pve-remove-subscription-notice
systemctl daemon-reload
apt-get install --reinstall proxmox-widget-toolkit
```
