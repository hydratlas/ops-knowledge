# cloudflared

Cloudflare Tunnel をインストール・設定するロール。

## 概要

このロールは cloudflared パッケージのインストールと、トークンベースの Tunnel サービス設定を行う。パッケージのインストールのみ、または Tunnel 設定を含めた完全な構成の両方に対応している。

### 実現される機能

- cloudflared パッケージのインストール（Debian 系・RHEL 系）
- トークンベースの Tunnel サービス登録・起動

## 要件と前提条件

### 共通要件

- 対応 OS: Debian 系, RHEL 系
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

| 変数名                        | 必須 | デフォルト | 説明                                |
| ----------------------------- | ---- | ---------- | ----------------------------------- |
| `cloudflared_token`           | No   | `""`       | Tunnel トークン（Vault 暗号化推奨） |
| `cloudflared_service_enabled` | No   | `true`     | サービスの自動起動を有効化          |
| `cloudflared_service_state`   | No   | `started`  | サービスの状態                      |

#### トークンの管理

トークンは機密情報のため、Ansible Vault で暗号化して管理することを推奨する。

```bash
# トークンを Vault で暗号化
ansible-vault encrypt_string --vault-password-file .vault_password 'eyJ...<TOKEN>'
```

出力された暗号化文字列を `group_vars` または `host_vars` に配置する。

### 方法2: 手動での設定

#### ステップ1: 環境準備（リポジトリの設定）

**Debian 系の場合:**

```bash
# GPG キーのインポート
wget -O - https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/cloudflare-main.gpg > /dev/null

# リポジトリの追加
VERSION_CODENAME="$(grep -oP '(?<=^VERSION_CODENAME=).+' /etc/os-release | tr -d '\"')" &&
sudo tee "/etc/apt/sources.list.d/cloudflared.sources" > /dev/null << EOF
Types: deb
URIs: https://pkg.cloudflare.com/cloudflared
Suites: ${VERSION_CODENAME}
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

#### ステップ2: インストール

```bash
# Debian 系
sudo apt-get install -y cloudflared

# RHEL 系
sudo dnf install -y cloudflared
```

#### ステップ3: Tunnel 設定（オプション）

Tunnel サービスとして実行する場合、トークンを使用してサービスをインストールする。

```bash
# サービスとしてインストール（トークンは Cloudflare ダッシュボードから取得）
sudo cloudflared service install <TOKEN>

# サービスを起動
sudo systemctl enable --now cloudflared
```

## 運用管理

```bash
# バージョン確認
cloudflared version

# サービス状態確認
systemctl status cloudflared

# ログ確認
journalctl -u cloudflared -f
```

## アンインストール

### サービスのアンインストール

サービスをインストールしている場合のみ実行する。

```bash
sudo cloudflared service uninstall
sudo systemctl daemon-reload
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

## 関連ドキュメント

- [Cloudflare Tunnel SSH 設定ガイド](../../../docs/cloudflare-tunnel-ssh.md) - クライアント側の SSH 設定
- [Cloudflare Zero Trust - Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) - 公式ドキュメント
