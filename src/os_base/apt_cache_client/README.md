# apt_cache_client

apt パッケージキャッシュプロキシーのクライアント設定を行うロール

## 概要

### このドキュメントの目的

このロールは apt-cacher-ng 等のキャッシュプロキシーを利用するためのクライアント側設定を提供する。Ansible による自動設定と手動設定の両方の手順を説明する。

### 実現される機能

- apt のプロキシー設定ファイル（`/etc/apt/apt.conf.d/02proxy`）の配置
- パッケージダウンロードのキャッシュプロキシー経由化
- `/etc/apt/mirrors/*.list` 内の公式ミラー URL を HTTPS から HTTP へ変換（apt-cacher-ng がキャッシュ可能にするため）
- HTTPS リポジトリー（サードパーティー等）はプロキシーを迂回して直接接続

## 要件と前提条件

### 共通要件

- Debian 系 OS（Debian, Ubuntu）
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

#### 依存関係

なし。ただし、プロキシーサーバー（`os_base/apt_cacher_ng` ロール等）が別途稼働していることが前提である。

#### タグとハンドラー

なし

#### 使用例

```yaml
- hosts: debian_hosts
  become: true
  roles:
    - role: os_base/apt_cache_client
      vars:
        apt_cache_proxy_url: "http://apt-cache.int.home.arpa:3142"
```

### 方法2: 手動での設定手順

#### ステップ1: プロキシー設定ファイルの作成

HTTPS リポジトリーはプロキシーを迂回する設定を含める。

```bash
cat <<'EOF' | sudo tee /etc/apt/apt.conf.d/02proxy
Acquire::http::Proxy "http://apt-cache.int.home.arpa:3142";
Acquire::https::Proxy "DIRECT";
EOF
```

#### ステップ2: 公式ミラー URL を HTTP に変換

Debian Trixie 以降ではミラーファイルがデフォルトで HTTPS を使用するため、apt-cacher-ng でキャッシュするには HTTP に変換する必要がある。

```bash
sudo sed -i 's|https://|http://|g' /etc/apt/mirrors/*.list
```

#### ステップ3: 動作確認

```bash
sudo apt update
```

プロキシー経由でパッケージリストが取得されることを確認する。

## 運用管理

### 基本操作

```bash
# 現在のプロキシー設定を確認
cat /etc/apt/apt.conf.d/02proxy

# プロキシー経由での接続テスト
apt-config dump | grep -i proxy
```

### トラブルシューティング

1. **プロキシーに接続できない場合**: プロキシーサーバーが稼働しているか、ネットワーク到達性があるか確認する
2. **HTTPS リポジトリーで `403 CONNECT denied` が発生する場合**: `02proxy` に `Acquire::https::Proxy "DIRECT";` が設定されているか、またはミラー URL が HTTP に変換されているか確認する
3. **プロキシーを一時的にバイパスしたい場合**: `-o Acquire::http::Proxy=false` オプションを使用する

```bash
sudo apt -o Acquire::http::Proxy=false update
```

## アンインストール（手動）

```bash
sudo rm /etc/apt/apt.conf.d/02proxy
```
