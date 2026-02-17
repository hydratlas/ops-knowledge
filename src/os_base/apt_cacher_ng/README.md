# apt_cacher_ng

apt-cacher-ng パッケージキャッシュサーバーをインストール・設定するロール

## 概要

### このドキュメントの目的

このロールは apt-cacher-ng のサーバー側の設定を提供する。Ansible による自動設定と手動設定の両方の手順を説明する。

### 実現される機能

- apt-cacher-ng パッケージのインストール
- 設定ファイルのテンプレートデプロイ
- サービスの有効化と起動
- Debian/Ubuntu リポジトリーのキャッシュ
- HTTPS パススルーの設定（オプション）

## 要件と前提条件

### 共通要件

- Debian 系 OS（Debian, Ubuntu）
- root 権限または sudo 権限
- キャッシュ用の十分なディスク容量

### Ansible 固有の要件

- Ansible 2.9 以降
- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件

- apt コマンドが利用可能であること
- systemctl コマンドが利用可能であること

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

すべての変数はデフォルトで空文字列である。空文字列の場合、設定ファイルにそのディレクティブを出力せず、apt-cacher-ng パッケージのデフォルト値がそのまま使用される。

| 変数名 | 説明 | パッケージデフォルト値 |
|--------|------|----------------------|
| `apt_cacher_ng_port` | リッスンポート | `3142` |
| `apt_cacher_ng_cache_dir` | キャッシュディレクトリー | `/var/cache/apt-cacher-ng` |
| `apt_cacher_ng_log_dir` | ログディレクトリー | `/var/log/apt-cacher-ng` |
| `apt_cacher_ng_ex_threshold` | 未参照ファイル削除までの日数 | `4` |
| `apt_cacher_ng_pass_through_pattern` | HTTPS パススルーパターン | なし |

#### 依存関係

なし

#### タグとハンドラー

- ハンドラー `restart apt-cacher-ng`: 設定ファイル変更時にサービスを再起動する

#### 使用例

```yaml
- hosts: apt_cache_servers
  become: true
  roles:
    - role: os_base/apt_cacher_ng
```

```yaml
- hosts: apt_cache_servers
  become: true
  roles:
    - role: os_base/apt_cacher_ng
      vars:
        apt_cacher_ng_port: 9999
        apt_cacher_ng_ex_threshold: 7
        apt_cacher_ng_pass_through_pattern: "^(.*):443$"
```

### 方法2: 手動での設定手順

#### ステップ1: インストール

```bash
sudo apt update
sudo apt install -y apt-cacher-ng
```

#### ステップ2: 設定

`/etc/apt-cacher-ng/acng.conf` を編集し、以下の項目を確認・変更する。

- `CacheDir`: キャッシュディレクトリー（デフォルト: `/var/cache/apt-cacher-ng`）
- `LogDir`: ログディレクトリー（デフォルト: `/var/log/apt-cacher-ng`）
- `Port`: リッスンポート（デフォルト: `3142`）
- `ExTreshold`: 未参照ファイルの削除日数（デフォルト: `4`）
- `PassThroughPattern`: HTTPS パススルーパターン（デフォルト: なし。HTTPS を通す場合は `^(.*):443$` を設定する）

#### ステップ3: 起動と有効化

```bash
sudo systemctl enable apt-cacher-ng
sudo systemctl start apt-cacher-ng
```

## 運用管理

### 基本操作

```bash
# サービスの状態確認
sudo systemctl status apt-cacher-ng

# サービスの再起動
sudo systemctl restart apt-cacher-ng

# キャッシュ使用量の確認
du -sh /var/cache/apt-cacher-ng/
```

### ログとモニタリング

- ログディレクトリー: `/var/log/apt-cacher-ng/`
- Web 管理画面: `http://<サーバーアドレス>:3142/acng-report.html`

### トラブルシューティング

1. **サービスが起動しない場合**: ログファイルを確認し、ポートの競合やディスク容量不足がないか調べる
2. **クライアントから接続できない場合**: ファイアウォール設定でリッスンポートが開放されているか確認する
3. **キャッシュが肥大化する場合**: `ExTreshold` の値を小さくするか、Web 管理画面からキャッシュの整理を実行する

### メンテナンス

```bash
# キャッシュの整理（期限切れファイルの削除）
# Web管理画面の「Expiration」機能を使用するか、以下のコマンドを実行
sudo /usr/lib/apt-cacher-ng/acngtool maint
```

## アンインストール（手動）

```bash
sudo systemctl stop apt-cacher-ng
sudo systemctl disable apt-cacher-ng
sudo apt purge -y apt-cacher-ng
sudo rm -rf /var/cache/apt-cacher-ng /var/log/apt-cacher-ng /etc/apt-cacher-ng
```
