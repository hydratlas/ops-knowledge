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

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

システムユーザーを作成し、ルートレスコンテナ用のsubuid/subgidを割り当てます：

```bash
# ユーザーの作成（subuid/subgid付き）
USER_SHELL="/usr/sbin/nologin"  # 必要に応じて変更可能
sudo useradd --system --user-group --add-subids-for-system --shell "${USER_SHELL}" --comment "Cloudflare Tunnel rootless user" "cloudflared"

# systemd-journalグループへの追加
sudo usermod -aG systemd-journal "cloudflared"
```

ユーザーがログインしていなくてもサービスを実行できるようにsystemd lingeringを有効化します：

```bash
# lingeringを有効化
sudo loginctl enable-linger "cloudflared"
```

Quadletとコンテナストレージ用のディレクトリを作成します：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "cloudflared" | cut -d: -f6)"

# 必要なディレクトリを作成
sudo mkdir -p "${QUADLET_HOME}/.config/cloudflared" &&
sudo mkdir -p "${QUADLET_HOME}/.config/containers/systemd" &&
sudo mkdir -p "${QUADLET_HOME}/.local/share/containers/storage"

# 所有権の設定
sudo chown -R "cloudflared:cloudflared" "${QUADLET_HOME}"

# パーミッションの設定
sudo chmod -R 755 "${QUADLET_HOME}"
```

#### ステップ2: Podmanのインストール

Podmanのインストールは各ディストリビューションのパッケージマネージャーを使用してください。

非特権ユーザーが ICMP Echo（ping）を実行可能にするカーネルパラメータの設定：

```bash
# sysctlでping権限の設定
sudo tee /etc/sysctl.d/99-ping-group-range.conf << 'EOF' > /dev/null
net.ipv4.ping_group_range=0 2147483647
EOF

# sysctl設定のリロード
sudo sysctl --system
```

#### ステップ3: Podman Quadletの設定

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
Volume=/etc/localtime:/etc/localtime:ro

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

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

Quadletから生成されたサービスファイルを認識させるため、systemdユーザーデーモンをリロードしてから、サービスを起動します：

```bash
# systemdユーザーデーモンのリロード
sudo -u cloudflared \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user daemon-reload

# サービスの起動
sudo -u cloudflared \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user start "cloudflared.service"
```

podman-auto-update.timerの起動と有効化によって、コンテナイメージの自動更新を有効にします：

```bash
# タイマーの起動と有効化
sudo -u cloudflared \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user enable --now podman-auto-update.timer
```


## 運用管理

### 基本操作

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

サービス操作：

```bash
# サービスの状態確認
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user status "cloudflared.service"

# サービスの再起動
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user restart "cloudflared.service"

# サービスの停止
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user stop "cloudflared.service"

# サービスの開始
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user start "cloudflared.service"
```

ログ確認：

```bash
# サービスのログの確認（最新の100行）
sudo -u "cloudflared" \
  journalctl --user -u "cloudflared.service" --no-pager -n 100

# サービスのログの確認（リアルタイム表示）
sudo -u "cloudflared" \
  journalctl --user -u "cloudflared.service" -f
```

コンテナ確認：

```bash
# コンテナの状態確認
sudo -u "cloudflared" podman ps

# すべてのコンテナを表示（停止中も含む）
sudo -u "cloudflared" podman ps -a

# コンテナの詳細情報
sudo -u "cloudflared" podman inspect cloudflared

# コンテナイメージの一覧
sudo -u "cloudflared" podman images

# 古いコンテナイメージのクリーンアップ
sudo -u "cloudflared" podman image prune -f
```

設定・環境確認：

```bash
# subuid/subgidの確認
grep "cloudflared" /etc/subuid /etc/subgid

# lingeringの確認
loginctl show-user "cloudflared" --property=Linger

# ユーザー情報の確認
id "cloudflared"
```

Quadletファイル管理：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "cloudflared" | cut -d: -f6)"

# ファイルの存在確認
ls -la "${QUADLET_HOME}/cloudflared/.config/containers/systemd/"

# 構文確認
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  /usr/libexec/podman/quadlet --dryrun --user

# Systemdのリロード
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user daemon-reload
```

自動更新：

```bash
# 自動更新タイマーの状態確認
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user status podman-auto-update.timer

# 自動更新のログ確認
sudo -u "cloudflared" \
  journalctl --user -u podman-auto-update.service
```

作成されるディレクトリ：
- `/home/cloudflared/` - ユーザーのホームディレクトリ
- `/home/cloudflared/.config/` - 設定ディレクトリ
- `/home/cloudflared/.config/cloudflared/` - アプリケーション固有の設定
- `/home/cloudflared/.config/containers/systemd/` - Quadletファイル配置場所
- `/home/cloudflared/.local/share/containers/storage/` - コンテナストレージ


cloudflared固有の操作：
```bash
# トンネルステータスの確認
sudo -u cloudflared podman exec cloudflared cloudflared tunnel info

# Cloudflareへの接続確認
ping -c 4 cloudflare.com

# 環境変数ファイルの確認（トークンが設定されているか）
sudo cat /home/cloudflared/.config/cloudflared/cloudflared.env
```

### メンテナンス

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

バックアップ：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "cloudflared" | cut -d: -f6)"

# 設定ファイルとQuadletファイルのバックアップ
sudo tar -czf "cloudflared-backup-$(date +%Y%m%d).tar.gz" \
    "${QUADLET_HOME}/cloudflared/.config/cloudflared" \
    "${QUADLET_HOME}/cloudflared/.config/containers/systemd"
```

手動更新：

```bash
# 手動でのイメージ更新
sudo -u "cloudflared" podman pull docker.io/cloudflare/cloudflared:latest

# サービスの再起動
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u cloudflared)" \
  systemctl --user restart "cloudflared.service"
```

自動更新は`podman-auto-update.timer`により定期的に実行されます。


## アンインストール（手動）

以下の手順でCloudflaredを完全に削除します。

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

```bash
# 0. ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "cloudflared" | cut -d: -f6)"

# 1. サービスの停止
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "cloudflared")" \
  systemctl --user stop "cloudflared.service"

# 2. 自動更新タイマーの停止と無効化
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "cloudflared")" \
  systemctl --user disable --now podman-auto-update.timer

# 3. Quadletコンテナ定義ファイルの削除
sudo rm -f \
  "${QUADLET_HOME}/cloudflared/.config/containers/systemd/cloudflared.container"

# 4. systemdユーザーデーモンのリロード
sudo -u "cloudflared" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "cloudflared")" \
  systemctl --user daemon-reload

# 5. コンテナイメージの削除
sudo -u "cloudflared" podman rmi "docker.io/cloudflare/cloudflared:latest"

# 6. アプリケーション設定の削除
# 警告: この操作により、アプリケーション固有の設定がすべて削除されます
sudo rm -rf "${QUADLET_HOME}/cloudflared/.config/cloudflared"

# 7. lingeringを無効化
sudo loginctl disable-linger "cloudflared"

# 8. ユーザーの削除
# 警告: このユーザーのホームディレクトリとすべてのデータが削除されます
sudo userdel -r "cloudflared"
```


```bash
# 9. ping権限設定の削除（他のサービスが使用していない場合）
sudo rm -f /etc/sysctl.d/99-ping-group-range.conf
sudo sysctl --system
```

## 参考

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)