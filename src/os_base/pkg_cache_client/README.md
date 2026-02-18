# pkg_cache_client

パッケージキャッシュプロキシーのクライアント設定を行うロール

## 概要

### このドキュメントの目的

このロールは apt-cacher-ng 等のキャッシュプロキシーを利用するためのクライアント側設定を提供する。Debian 系と RedHat 系の両方に対応しており、Ansible による自動設定と手動設定の両方の手順を説明する。

### 実現される機能

#### Debian 系（Debian, Ubuntu）

- apt のプロキシー設定ファイル（`/etc/apt/apt.conf.d/02proxy`）の配置
- パッケージダウンロードのキャッシュプロキシー経由化
- OS 標準の `.sources` ファイルを HTTP URI で上書き配備（apt-cacher-ng がキャッシュ可能にするため）
- HTTPS リポジトリー（サードパーティー等）はプロキシーを迂回して直接接続

#### RedHat 系（AlmaLinux）

- dnf のプロキシー設定（`/etc/dnf/dnf.conf`）
- `/etc/yum.repos.d/*.repo` の metalink/mirrorlist をコメントアウトし、baseurl を HTTP で有効化（apt-cacher-ng がキャッシュ可能にするため）

## 要件と前提条件

### 共通要件

- Debian 系 OS（Debian, Ubuntu）または RedHat 系 OS（AlmaLinux）
- root 権限または sudo 権限
- キャッシュプロキシーサーバーへのネットワーク到達性

### Ansible 固有の要件

- Ansible 2.9 以降
- プレイブックレベルで `become: true` の指定が必要
- `apt_cache_proxy_url` 変数の設定が必須

### 手動設定の要件

- テキストエディターが利用可能であること

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名 | デフォルト値 | 説明 |
|--------|-------------|------|
| `apt_cache_proxy_url` | `""` (空文字) | プロキシー URL（必須） |
| `pkg_cache_debian_components` | `"main"` | Debian の `.sources` に記載するコンポーネント |
| `pkg_cache_ubuntu_components` | `"main restricted universe multiverse"` | Ubuntu の `.sources` に記載するコンポーネント |
| `apt_cacher_ng_repositories` | (インベントリーで定義) | リポジトリー定義の辞書。各エントリの `client_url` フィールドをテンプレートで参照する。詳細は `os_base/apt_cacher_ng` ロールを参照 |

#### 依存関係

なし。ただし、プロキシーサーバー（`os_base/apt_cacher_ng` ロール等）が別途稼働していることが前提である。`apt_cacher_ng_repositories` 変数はインベントリーの `group_vars` で定義し、サーバー側（`apt_cacher_ng`）とクライアント側（本ロール）の両方で共有する。

#### タグとハンドラー

なし

#### 使用例

```yaml
- hosts: debian_hosts
  become: true
  roles:
    - role: os_base/pkg_cache_client
      vars:
        apt_cache_proxy_url: "http://apt-cache.int.home.arpa:3142"
```

### 方法2: 手動での設定手順（Debian 系）

#### ステップ1: プロキシー設定ファイルの作成

HTTPS リポジトリーはプロキシーを迂回する設定を含める。

```bash
cat <<'EOF' | sudo tee /etc/apt/apt.conf.d/02proxy
Acquire::http::Proxy "http://apt-cache.int.home.arpa:3142";
Acquire::https::Proxy "DIRECT";
EOF
```

#### ステップ2: `.sources` ファイルの配備

OS 標準の `.sources` ファイルを HTTP URI で上書きする。apt-cacher-ng の Remap 設定にマッチする URI を使用する（Ansible ロールでは `apt_cacher_ng_repositories` の `client_url` から自動取得される）。

Debian の場合（`/etc/apt/sources.list.d/debian.sources`）:

```
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://deb.debian.org/debian-security
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

Ubuntu の場合（`/etc/apt/sources.list.d/ubuntu.sources`）:

```
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

Suites のコードネーム部分は使用中のリリースに合わせて変更する。

#### ステップ3: 動作確認

```bash
sudo apt update
```

プロキシー経由でパッケージリストが取得されることを確認する。

### 方法3: 手動での設定手順（RedHat 系）

#### ステップ1: dnf プロキシー設定

`/etc/dnf/dnf.conf` の `[main]` セクションにプロキシー設定を追加する。

```bash
sudo dnf config-manager --setopt=proxy=http://apt-cache.int.home.arpa:3142 --save
```

#### ステップ2: リポジトリーファイルの変更

`/etc/yum.repos.d/*.repo` ファイルの metalink と mirrorlist をコメントアウトし、baseurl を HTTP で有効化する。

```bash
sudo sed -i 's|^metalink=|# metalink=|' /etc/yum.repos.d/*.repo
sudo sed -i 's|^mirrorlist=|# mirrorlist=|' /etc/yum.repos.d/*.repo
sudo sed -i 's|^#\?\s*baseurl=https://|baseurl=http://|' /etc/yum.repos.d/*.repo
```

#### ステップ3: 動作確認

```bash
sudo dnf makecache
```

プロキシー経由でメタデータが取得されることを確認する。

## 運用管理

### 基本操作

```bash
# 現在のプロキシー設定を確認
cat /etc/apt/apt.conf.d/02proxy

# プロキシー経由での接続テスト
apt-config dump | grep -i proxy
```

### トラブルシューティング

#### Debian 系

1. **プロキシーに接続できない場合**: プロキシーサーバーが稼働しているか、ネットワーク到達性があるか確認する
2. **HTTPS リポジトリーで `403 CONNECT denied` が発生する場合**: `02proxy` に `Acquire::https::Proxy "DIRECT";` が設定されているか、また `.sources` ファイルの URI が HTTP になっているか確認する
3. **プロキシーを一時的にバイパスしたい場合**: `-o Acquire::http::Proxy=false` オプションを使用する

```bash
sudo apt -o Acquire::http::Proxy=false update
```

#### RedHat 系

1. **プロキシーに接続できない場合**: `/etc/dnf/dnf.conf` の `proxy` 設定値が正しいか確認する
2. **metalink/mirrorlist が残っている場合**: `/etc/yum.repos.d/*.repo` で metalink や mirrorlist がコメントアウトされているか確認する（有効なままだと baseurl が無視される）
3. **プロキシーを一時的にバイパスしたい場合**: `--setopt=proxy=` オプションを使用する

```bash
sudo dnf --setopt=proxy= makecache
```

## アンインストール（手動）

### Debian 系

```bash
sudo rm /etc/apt/apt.conf.d/02proxy
```

### RedHat 系

`/etc/dnf/dnf.conf` から `proxy` 行を削除し、`/etc/yum.repos.d/*.repo` の metalink/mirrorlist を復元する。

```bash
sudo dnf config-manager --setopt=proxy= --save
```
