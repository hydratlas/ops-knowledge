# Dell Downloads リバースプロキシ

レガシー iDRAC（iDRAC8 等）のファームウェア更新を支援するための、Dell CDN（`dl.dell.com`）へのリバースプロキシである。

## 背景

レガシー iDRAC8 は Dell CDN（Akamai）との最新 TLS ハンドシェイクに対応できず、ファームウェア更新に失敗する。本ロールは HTTP で受け付けたリクエストを HTTPS で Dell CDN へ転送するリバースプロキシを構築し、この TLS 非互換性の問題を解消する。

参考: [idrac-legacy-lifecycle-proxy](https://github.com/gfk/idrac-legacy-lifecycle-proxy)

## 構成

- rootless Podman Quadlet による nginx コンテナで構成される
- `container/podman_rootless_quadlet_base` ロールに依存する
- DNS の書き換え機能は含まない

## 動作

1. iDRAC が HTTP でプロキシにリクエストを送信する
2. nginx がリクエストを HTTPS で `dl.dell.com` に転送する
3. カタログファイルのパス不一致（`/Catalog.xml.gz` → `/catalog/Catalog.xml.gz`）を自動で書き換える
4. HEAD リクエストには直接 200 を返す（接続確認用）

## 変数

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `dell_proxy_user` | `dell-proxy` | 実行ユーザー名 |
| `dell_proxy_listen_port` | `8080` | リッスンポート |
| `dell_proxy_backend_host` | `dl.dell.com` | プロキシ先ホスト |
| `dell_proxy_connect_timeout` | `60s` | 接続タイムアウト |
| `dell_proxy_send_timeout` | `60s` | 送信タイムアウト |
| `dell_proxy_read_timeout` | `300s` | 読取タイムアウト |

## 手動構築手順

### 前提条件

- Podman がインストールされていること
- rootless Podman の実行に必要な設定（subuid/subgid 等）が完了していること

### 手順

1. システムユーザーを作成する

```
sudo useradd -r -m -s /usr/sbin/nologin -c "Dell downloads reverse proxy rootless user" dell-proxy
```

2. 必要なディレクトリーを作成する

```
sudo -u dell-proxy mkdir -p ~/.config/dell-proxy
sudo -u dell-proxy mkdir -p ~/.config/containers/systemd
sudo -u dell-proxy mkdir -p ~/.local/share/nginx-cache
sudo -u dell-proxy mkdir -p ~/.local/share/nginx-run
```

3. nginx 設定ファイルを `~dell-proxy/.config/dell-proxy/nginx.conf` に配置する

4. Quadlet コンテナファイルを `~dell-proxy/.config/containers/systemd/dell-proxy.container` に配置する

5. サービスを有効化して起動する

```
sudo -u dell-proxy XDG_RUNTIME_DIR=/run/user/$(id -u dell-proxy) systemctl --user daemon-reload
sudo -u dell-proxy XDG_RUNTIME_DIR=/run/user/$(id -u dell-proxy) systemctl --user enable --now dell-proxy.service
```

### iDRAC の設定

iDRAC の Lifecycle Controller でファームウェア更新を行う際、ファイルの場所として HTTP を選択し、アドレスにプロキシホストの IP を、ポートに `8080`（またはカスタム設定したポート）を指定する。
