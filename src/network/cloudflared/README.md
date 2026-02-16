# cloudflared

Cloudflare Tunnel をインストール・設定するロール。

## 概要

このロールは cloudflared のインストールと、トークンベースの Tunnel サービス設定を行う。パッケージのインストールのみ、または Tunnel 設定を含めた完全な構成の両方に対応している。

### 実現される機能

- cloudflared のインストール（Debian 系・RHEL 系・Alpine Linux）
- トークンベースの Tunnel サービス登録・起動
- Alpine Linux: 公式バイナリの直接ダウンロードと毎日の自動更新

## 要件と前提条件

### 共通要件

- 対応 OS: Debian 系, RHEL 系, Alpine Linux
- ネットワーク接続
- root または sudo 権限

### Tunnel 設定を行う場合の追加要件

- Cloudflare アカウントと管理対象ドメイン
- Cloudflare ダッシュボードで作成した Tunnel のトークン

#### Tunnel の作成とトークンの取得

Cloudflare ダッシュボードでトンネルを作成し、トークンを取得する。

1. [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) にアクセス
2. ネットワーク → コネクタ を選択
3. 「トンネルを作成する」をクリック
4. トンネル名を入力して作成
5. 「Install and run a connector」画面でトークンをコピー

トークンは `eyJ...` で始まる長い文字列である。

#### ローカルホストの SSH を公開する場合

Public Hostnames を追加してローカルホストの SSH サーバーを Tunnel 経由で公開できる。

1. 「Configure」タブの **Public Hostnames** セクションで「Add a public hostname」をクリック
2. 以下の設定を入力:
   - **Subdomain**: 任意の名前（例: `jump`）
   - **Domain**: 管理対象ドメインを選択
   - **Type**: `SSH`
   - **URL**: `localhost:22`
3. 「Save hostname」をクリック

この設定により、`<subdomain>.<domain>` への SSH 接続が Tunnel を経由してサーバーの SSH サーバー（ポート 22）に転送される。クライアント側の SSH 設定については [Cloudflare Tunnel SSH 設定ガイド](../../../docs/cloudflare-tunnel-ssh.md) を参照。

## 設定方法

### 方法1: Ansible での設定

#### パッケージのインストールのみ

変数を設定せずにロールを適用すると、cloudflared パッケージのインストールのみを行う。

```yaml
- hosts: target_hosts
  roles:
    - role: services/cloudflared
```

#### Tunnel サービスの完全構成

トークンを設定すると、サービスの登録・起動まで行う。

```yaml
- hosts: jump_hosts
  roles:
    - role: services/cloudflared
      vars:
        cloudflared_token: "{{ vault_cloudflared_token }}"
```

#### 変数

| 変数名                           | 必須 | デフォルト                         | 説明                                    |
| -------------------------------- | ---- | ---------------------------------- | --------------------------------------- |
| `cloudflared_token`              | No   | `""`                               | Tunnel トークン（Vault 暗号化推奨）     |
| `cloudflared_service_enabled`    | No   | `true`                             | サービスの自動起動を有効化              |
| `cloudflared_service_state`      | No   | `started`                          | サービスの状態                          |
| `cloudflared_binary_path`        | No   | `/usr/local/bin/cloudflared`       | バイナリのインストール先（Alpine のみ） |
| `cloudflared_download_url`       | No   | GitHub Releases の最新バイナリ URL | ダウンロード URL（Alpine のみ）         |
| `cloudflared_auto_update`        | No   | `true`                             | 毎日の自動更新を有効化（Alpine のみ）   |
| `cloudflared_auto_update_hour`   | No   | `"3"`                              | 自動更新の実行時刻（時）（Alpine のみ） |
| `cloudflared_auto_update_minute` | No   | `"30"`                             | 自動更新の実行時刻（分）（Alpine のみ） |

#### トークンの管理

トークンは機密情報のため、Ansible Vault で暗号化して管理することを推奨する。

```bash
# トークンを Vault で暗号化
ansible-vault encrypt_string 'eyJ...<TOKEN>'
```

出力された暗号化文字列を `group_vars` または `host_vars` に配置する。

### 方法2: 手動での設定

#### ステップ1: 環境準備（リポジトリの設定）

**Debian 系の場合:**

```bash
# キーリングディレクトリの作成
sudo mkdir -p --mode=0755 /etc/apt/keyrings

# GPG キーのインポート
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /etc/apt/keyrings/cloudflare-main.gpg > /dev/null

# リポジトリの追加
sudo tee /etc/apt/sources.list.d/cloudflared.sources > /dev/null << 'EOF'
Types: deb
URIs: https://pkg.cloudflare.com/cloudflared
Suites: any
Components: main
Signed-By: /etc/apt/keyrings/cloudflare-main.gpg
EOF

# パッケージリストの更新
sudo apt-get update
```

**RHEL 系の場合:**

```bash
# リポジトリの追加
sudo dnf config-manager --add-repo https://pkg.cloudflare.com/cloudflared-ascii.repo

# リポジトリキャッシュの更新
sudo dnf makecache
```

**Alpine Linux の場合:**

公式バイナリを直接ダウンロードする。リポジトリの設定は不要である。

#### ステップ2: インストール

```bash
# Debian 系
sudo apt-get install -y cloudflared

# RHEL 系
sudo dnf install -y cloudflared

# Alpine Linux（公式バイナリを直接ダウンロード）
doas wget -O /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
doas chmod 755 /usr/local/bin/cloudflared
doas mkdir -p /var/log/cloudflared
```

#### ステップ3: Tunnel 設定（オプション）

Tunnel サービスとして実行する場合、トークンを使用してサービスをインストールする。

**Debian 系・RHEL 系の場合（systemd）:**

```bash
# サービスとしてインストール（トークンは Cloudflare ダッシュボードから取得）
sudo cloudflared service install <TOKEN>

# サービスを起動
sudo systemctl enable --now cloudflared
```

**Alpine Linux の場合（OpenRC）:**

```bash
# init スクリプトを作成
cat << 'EOF' | doas tee /etc/init.d/cloudflared
#!/sbin/openrc-run

name="cloudflared"
description="Cloudflare Tunnel daemon"

command="/usr/local/bin/cloudflared"
command_args="tunnel run --token <TOKEN>"
command_user="root"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"

output_log="/var/log/cloudflared/cloudflared.log"
error_log="/var/log/cloudflared/cloudflared.log"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner root:root --mode 0755 /var/log/cloudflared
}
EOF
doas chmod 755 /etc/init.d/cloudflared

# サービスを起動
doas rc-update add cloudflared default
doas rc-service cloudflared start
```

**Alpine Linux: 自動更新の設定（オプション）:**

毎日 3:30 に自動更新を実行する場合:

```bash
# 更新スクリプトを作成
cat << 'EOF' | doas tee /usr/local/bin/cloudflared-update
#!/bin/sh
set -e

BINARY_PATH="/usr/local/bin/cloudflared"

CURRENT_VERSION=""
if [ -x "$BINARY_PATH" ]; then
    CURRENT_VERSION=$("$BINARY_PATH" version 2>/dev/null | head -1 || echo "")
fi

UPDATE_OUTPUT=$("$BINARY_PATH" update 2>&1) || {
    logger -t cloudflared-update "cloudflared update failed: $UPDATE_OUTPUT"
    exit 1
}

if echo "$UPDATE_OUTPUT" | grep -q "is up to date"; then
    logger -t cloudflared-update "cloudflared is already up to date"
else
    NEW_VERSION=$("$BINARY_PATH" version 2>/dev/null | head -1 || echo "")
    logger -t cloudflared-update "Updated cloudflared: $CURRENT_VERSION -> $NEW_VERSION"
    rc-service cloudflared restart 2>/dev/null || true
    logger -t cloudflared-update "Service restarted successfully"
fi
EOF
doas chmod 755 /usr/local/bin/cloudflared-update

# cron ジョブを設定
echo "30 3 * * * /usr/local/bin/cloudflared-update" | doas crontab -
```

## 運用管理

**Debian 系・RHEL 系の場合（systemd）:**

```bash
# バージョン確認
cloudflared version

# サービス状態確認
systemctl status cloudflared

# ログ確認
journalctl -u cloudflared -f
```

**Alpine Linux の場合（OpenRC）:**

```bash
# バージョン確認
cloudflared version

# サービス状態確認
rc-service cloudflared status

# ログ確認
tail -f /var/log/messages | grep cloudflared
```

## アンインストール

### サービスのアンインストール

サービスをインストールしている場合のみ実行する。

**Debian 系・RHEL 系の場合（systemd）:**

```bash
sudo cloudflared service uninstall
sudo systemctl daemon-reload
```

**Alpine Linux の場合（OpenRC）:**

```bash
doas rc-service cloudflared stop
doas rc-update del cloudflared default
doas rm -f /etc/init.d/cloudflared
```

### パッケージとリポジトリの削除

**Debian 系の場合:**

```bash
sudo apt-get remove --purge -y cloudflared
sudo apt-get autoremove -y
sudo rm -f /etc/apt/sources.list.d/cloudflared.sources
sudo rm -f /etc/apt/keyrings/cloudflare-main.gpg
sudo apt-get update
```

**RHEL 系の場合:**

```bash
sudo dnf remove -y cloudflared
sudo dnf autoremove -y
sudo rm -f /etc/yum.repos.d/cloudflared-ascii.repo
sudo dnf clean all
```

**Alpine Linux の場合:**

```bash
# バイナリと関連ファイルの削除
doas rm -f /usr/local/bin/cloudflared
doas rm -f /usr/local/bin/cloudflared-update
doas rm -rf /var/log/cloudflared
doas crontab -r  # cron ジョブを削除（他のジョブがある場合は個別に削除）
```

## 関連ドキュメント

- [Cloudflare Tunnel SSH 設定ガイド](../../../docs/cloudflare-tunnel-ssh.md) - クライアント側の SSH 設定
- [Cloudflare Zero Trust - Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) - 公式ドキュメント
