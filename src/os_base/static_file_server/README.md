# static_file_server

ローカルネットワーク内で静的ファイルを HTTP 配信する nginx サーバーをインストール・設定するロール

## 概要

### このドキュメントの目的

このロールは Alpine Linux 上に nginx を使用した静的ファイルサーバーを構築する。Ansible による自動設定と手動設定の両方の手順を説明する。

### 実現される機能

- nginx パッケージのインストール
- ドキュメントルートディレクトリーの作成
- 設定ファイルのテンプレートデプロイ
- デフォルトサイト設定の削除（ポート競合回避）
- サービスの有効化と起動
- ディレクトリーインデックスの自動生成（autoindex）
- 大容量ファイル配信の最適化（sendfile, tcp_nopush, directio）

## 要件と前提条件

### 共通要件

- Alpine Linux
- root 権限または sudo 権限

### Ansible 固有の要件

- Ansible 2.9 以降
- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件

- apk コマンドが利用可能であること
- rc-service / rc-update コマンドが利用可能であること

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `static_file_server_listen_port` | リッスンポート | `80` |
| `static_file_server_document_root` | ドキュメントルート | `/var/www/files` |
| `static_file_server_server_name` | サーバー名 | `_`（全リクエスト受付） |
| `static_file_server_files` | ダウンロードして配置するファイルのリスト | `[]` |

`static_file_server_files` の各要素は以下のキーを持つ辞書である。

| キー | 説明 |
|------|------|
| `url` | ダウンロード元の URL |
| `dest` | `static_file_server_document_root` からの相対パス |

#### 依存関係

なし

#### タグとハンドラー

- ハンドラー `Restart nginx`: 設定ファイル変更時にサービスを再起動する

#### 使用例

```yaml
- hosts: static_file_servers
  become: true
  roles:
    - role: os_base/static_file_server
```

```yaml
- hosts: static_file_servers
  become: true
  roles:
    - role: os_base/static_file_server
      vars:
        static_file_server_listen_port: 8080
        static_file_server_document_root: /srv/files
        static_file_server_server_name: files.int.home.arpa
```

```yaml
- hosts: static_file_servers
  become: true
  roles:
    - role: os_base/static_file_server
      vars:
        static_file_server_files:
          - url: https://example.com/firmware/v1.0/bios.bin
            dest: firmware/bios.bin
```

### 方法2: 手動での設定手順

#### ステップ1: インストール

```bash
sudo apk add nginx
```

#### ステップ2: ドキュメントルートの作成

```bash
sudo mkdir -p /var/www/files
```

#### ステップ3: 設定

`/etc/nginx/http.d/static-file-server.conf` を作成し、以下の内容を記述する。

- `listen`: リッスンポート（デフォルト: `80`）
- `server_name`: サーバー名（デフォルト: `_`）
- `root`: ドキュメントルート（デフォルト: `/var/www/files`）
- `autoindex on`: ディレクトリーインデックスの自動生成を有効化する
- `sendfile on` / `tcp_nopush on` / `directio 16m`: 大容量ファイル配信の最適化

デフォルトサイト設定との競合を避けるため、`/etc/nginx/http.d/default.conf` を削除する。

```bash
sudo rm -f /etc/nginx/http.d/default.conf
```

#### ステップ4: 起動と有効化

```bash
sudo rc-update add nginx default
sudo rc-service nginx start
```

## 運用管理

### ファイル配置

ドキュメントルート（デフォルト: `/var/www/files`）にファイルを配置すると、HTTP 経由でアクセス可能になる。

```bash
# ファイルの配置
sudo cp firmware.bin /var/www/files/

# 配置したファイルの確認
ls -la /var/www/files/
```

### 基本操作

```bash
# サービスの状態確認
sudo rc-service nginx status

# サービスの再起動
sudo rc-service nginx restart

# 設定テスト
sudo nginx -t
```

### ログとモニタリング

- アクセスログ: `/var/log/nginx/access.log`
- エラーログ: `/var/log/nginx/error.log`

### トラブルシューティング

1. **サービスが起動しない場合**: `nginx -t` で設定の構文エラーを確認し、エラーログを調べる
2. **ポート競合が発生する場合**: `/etc/nginx/http.d/default.conf` が残っていないか確認する
3. **ファイルにアクセスできない場合**: ドキュメントルートのパーミッションと、ファイルの読み取り権限を確認する

## メンテナンス

```bash
# ログのローテーション確認
ls -la /var/log/nginx/

# ディスク使用量の確認
du -sh /var/www/files/
```

## アンインストール（手動）

```bash
sudo rc-service nginx stop
sudo rc-update del nginx default
sudo apk del nginx
sudo rm -rf /var/www/files /etc/nginx
```
