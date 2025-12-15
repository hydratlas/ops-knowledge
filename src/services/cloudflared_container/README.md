# cloudflared

Cloudflare TunnelをPodman Quadletで専用ユーザーのrootlessコンテナとして実行

## 概要

### このドキュメントの目的
このロールは、Cloudflare Tunnelをrootlessコンテナとして安全に実行するための設定を提供します。Ansible自動設定と手動設定の両方の方法に対応しており、[podman_rootless_quadlet_base](../../infrastructure/container/podman_rootless_quadlet_base/README.md)を活用した共通セットアップを行います。

### 実現される機能
- Cloudflare Tunnelによるセキュアなリモートアクセス
- Rootless Podman Quadletによる非特権コンテナ実行
- 専用ユーザーによる分離された実行環境
- コンテナイメージの自動更新
- 読み取り専用コンテナによるセキュリティ強化
- 非特権ユーザーでのICMP Echo（ping）実行

## 要件と前提条件

### 共通要件
- 対応OS: Ubuntu (focal, jammy), Debian (buster, bullseye), RHEL/CentOS (8, 9)
- Podmanがインストールされていること
- systemdがインストールされていること
- loginctlコマンドが利用可能であること（systemd-loginパッケージ）
- ネットワーク接続（コンテナイメージの取得およびCloudflareへの接続用）
- 有効なCloudflare Tunnelトークン

### Ansible固有の要件
- Ansible 2.9以上
- 制御ノードから対象ホストへのSSH接続
- 対象ホストでのsudo権限

### 手動設定の要件
- rootまたはsudo権限
- 基本的なLinuxコマンドの知識

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | デフォルト値 | 説明 |
|--------|--------------|------|
| `cloudflared_user` | `cloudflared` | 実行ユーザー名 |
| `cloudflared_image` | `docker.io/cloudflare/cloudflared:latest` | 使用するコンテナイメージ |
| `cloudflared_token` | `""` | Cloudflare Tunnelトークン（必須） |
| `cloudflared_restart` | `always` | コンテナの再起動ポリシー |
| `cloudflared_restart_sec` | `5` | 再起動間隔（秒） |

注: `cloudflared_config_dir`と`cloudflared_systemd_dir`は、ユーザーのホームディレクトリから自動的に生成されます。

#### 依存関係
なし

#### タグとハンドラー

**ハンドラー:**
- `reload systemd user daemon`: systemdユーザーデーモンをリロード
- `restart cloudflared`: cloudflaredサービスを再起動

**タグ:**
このroleでは特定のタグは使用していません。

#### 使用例

基本的な使用例：
```yaml
- hosts: myhost
  roles:
    - role: cloudflared
      vars:
        cloudflared_token: "your-tunnel-token-here"
```

カスタムユーザー名を使用する場合：
```yaml
- hosts: myhost
  roles:
    - role: cloudflared
      vars:
        cloudflared_user: "tunnel-user"
        cloudflared_token: "your-tunnel-token-here"
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# アプリケーション名とユーザー名を設定
APP_NAME="cloudflared" &&
QUADLET_USER="cloudflared" &&
USER_COMMENT="Cloudflare Tunnel rootless user"
```

##### システムユーザーのセットアップ

システムユーザーを作成し、ルートレスコンテナ用のsubuid/subgidを割り当てます：

```bash
# ユーザーの作成（subuid/subgid付き）
USER_SHELL="/usr/sbin/nologin"  # 必要に応じて変更可能
sudo useradd --system --user-group --add-subids-for-system --shell "${USER_SHELL}" --comment "Cloudflare Tunnel rootless user" "cloudflared"

# systemd-journalグループへの追加
sudo usermod -aG systemd-journal "cloudflared"

# ユーザーのホームディレクトリーの取得
QUADLET_HOME=$(getent passwd "cloudflared" | cut -d: -f6)
```

ユーザーがログインしていなくてもサービスを実行できるようにsystemd lingeringを有効化します：

```bash
# lingeringを有効化
sudo loginctl enable-linger "cloudflared"
```

Quadletとコンテナストレージ用のディレクトリを作成します：

```bash
# 必要なディレクトリを作成
sudo mkdir -p "${QUADLET_HOME}/.config/cloudflared" &&
sudo mkdir -p "${QUADLET_HOME}/.config/containers/systemd" &&
sudo mkdir -p "${QUADLET_HOME}/.local/share/containers/storage"

# 所有権の設定
sudo chown -R "cloudflared:cloudflared" "${QUADLET_HOME}"

# パーミッションの設定
sudo chmod -R 755 "${QUADLET_HOME}"
```

#### ステップ2: インストール

##### 非特権ユーザーが ICMP Echo（ping）を実行可能にするカーネルパラメータの設定

```bash
# sysctlでping権限の設定
sudo tee /etc/sysctl.d/99-ping-group-range.conf << 'EOF' > /dev/null
net.ipv4.ping_group_range=0 2147483647
EOF

# sysctl設定のリロード
sudo sysctl --system
```

Podmanのインストールは各ディストリビューションのパッケージマネージャーを使用してください。

#### ステップ3: 設定

##### 環境変数ファイルの作成

```bash
# Cloudflare Tunnelトークンを設定（実際のトークンに置き換える）
TUNNEL_TOKEN="your-tunnel-token-here"

# 環境変数ファイルの作成
sudo -u cloudflared tee /home/cloudflared/.config/cloudflared/cloudflared.env << EOF > /dev/null
TUNNEL_TOKEN=${TUNNEL_TOKEN}
NO_AUTOUPDATE=true
EOF

# パーミッションの設定
sudo chmod 600 /home/cloudflared/.config/cloudflared/cloudflared.env
sudo chown cloudflared:cloudflared /home/cloudflared/.config/cloudflared/cloudflared.env
```

##### Podman Quadletコンテナファイルの作成

```bash
# Quadletコンテナ定義ファイルの作成
sudo -u cloudflared tee /home/cloudflared/.config/containers/systemd/cloudflared.container << 'EOF' > /dev/null
[Unit]
Description=Cloudflare Tunnel Service
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/cloudflare/cloudflared:latest
ContainerName=cloudflared
AutoUpdate=registry
LogDriver=journald
EnvironmentFile=%h/.config/cloudflared/cloudflared.env
Exec=tunnel run
NoNewPrivileges=true
ReadOnly=true
Volume=/etc/localtime:/etc/localtime:ro,z

[Service]
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# パーミッションの設定
sudo chmod 644 /home/cloudflared/.config/containers/systemd/cloudflared.container
sudo chown cloudflared:cloudflared /home/cloudflared/.config/containers/systemd/cloudflared.container
```

#### ステップ4: 起動と有効化

[podman_rootless_quadlet_base](../../infrastructure/container/podman_rootless_quadlet_base/README.md)を参照してサービスを起動します。

## 運用管理

### 基本操作

```bash
# サービスの状態確認
sudo -u cloudflared systemctl --user status cloudflared.service

# サービスの再起動
sudo -u cloudflared XDG_RUNTIME_DIR=/run/user/$(id -u cloudflared) systemctl --user restart cloudflared.service

# サービスの停止
sudo -u cloudflared XDG_RUNTIME_DIR=/run/user/$(id -u cloudflared) systemctl --user stop cloudflared.service

# サービスの開始
sudo -u cloudflared XDG_RUNTIME_DIR=/run/user/$(id -u cloudflared) systemctl --user start cloudflared.service
```

### ログとモニタリング

```bash
# ログの確認（最新の100行）
sudo -u cloudflared journalctl --user -u cloudflared.service --no-pager -n 100

# ログの確認（リアルタイム表示）
sudo -u cloudflared journalctl --user -u cloudflared.service -f

# コンテナの状態確認
sudo -u cloudflared podman ps --filter name=cloudflared

# トンネルステータスの確認
sudo -u cloudflared podman exec cloudflared cloudflared tunnel info
```

### トラブルシューティング

#### サービスが起動しない場合

1. トークンの確認
```bash
# 環境変数ファイルの確認（トークンが設定されているか）
sudo cat /home/cloudflared/.config/cloudflared/cloudflared.env
```

2. ネットワーク接続の確認
```bash
# Cloudflareへの接続確認
ping -c 4 cloudflare.com
```

3. コンテナイメージの確認
```bash
sudo -u cloudflared podman images | grep cloudflared
```

4. 詳細なログの確認
```bash
# 起動時のエラーメッセージを確認
sudo -u cloudflared journalctl --user -u cloudflared.service --no-pager -n 200
```

その他のcloudflared固有のコマンド以外は、[podman_rootless_quadlet_base](../../infrastructure/container/podman_rootless_quadlet_base/README.md)を参照してください。

### メンテナンス

#### バックアップ

```bash
# 設定ファイルのバックアップ
sudo tar -czf cloudflared-backup-$(date +%Y%m%d).tar.gz \
    /home/cloudflared/.config/cloudflared
```

#### アップデート

```bash
# 手動でのイメージ更新
sudo -u cloudflared podman pull docker.io/cloudflare/cloudflared:latest

# サービスの再起動
sudo -u cloudflared XDG_RUNTIME_DIR=/run/user/$(id -u cloudflared) systemctl --user restart cloudflared.service
```

自動更新は`podman-auto-update.timer`により定期的に実行されます。

## アンインストール（手動）

以下の手順でCloudflaredを完全に削除します。

```bash
# 1. サービスの停止
sudo -u cloudflared XDG_RUNTIME_DIR=/run/user/$(id -u cloudflared) systemctl --user stop cloudflared.service

# 2. Quadletファイルの削除
sudo rm -f /home/cloudflared/.config/containers/systemd/cloudflared.container

# 3. systemdデーモンのリロード
sudo -u cloudflared XDG_RUNTIME_DIR=/run/user/$(id -u cloudflared) systemctl --user daemon-reload

# 4. コンテナイメージの削除
sudo -u cloudflared podman rmi docker.io/cloudflare/cloudflared:latest

# 5. 環境変数ファイルの削除
# 警告: この操作により、トンネルトークンが削除されます
sudo rm -rf /home/cloudflared/.config/cloudflared

# 6. ping権限設定の削除（他のサービスが使用していない場合）
sudo rm -f /etc/sysctl.d/99-ping-group-range.conf
sudo sysctl --system

# 7. lingeringの無効化
sudo loginctl disable-linger cloudflared

# 8. ユーザーの削除
# 警告: このユーザーのホームディレクトリとすべてのデータが削除されます
sudo userdel -r cloudflared
```

## 参考

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)