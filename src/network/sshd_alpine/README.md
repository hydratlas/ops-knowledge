# sshd_alpine

Alpine LinuxにOpenSSHサーバーをインストールし、`sshd_config.d`方式での設定分割を有効化した上でサービスを起動するロール

## 概要

### このドキュメントの目的

このロールはAlpine Linux上でOpenSSHサーバーをセットアップし、`ssh_hardening`や`ssh_host_key`等のロールがドロップイン形式で設定を追加できる土台を整える。Ansibleによる自動設定と、それに相当する手動設定の両方の手順を示す。

### 実現される機能

- `openssh`パッケージのインストール
- `/etc/ssh/sshd_config.d`ディレクトリーの作成
- `/etc/ssh/sshd_config`への`Include /etc/ssh/sshd_config.d/*.conf`の追加（先頭挿入）
- 初回起動時のSSHホストキー生成（`ssh-keygen -A`）
- OpenRCランレベル`default`への`sshd`サービス登録と起動

## 要件と前提条件

### 共通要件

- 対象ホストのOSがAlpine Linuxであること（`ansible_os_family == "Alpine"`のときのみ実行）
- root権限またはsudo権限を持つユーザーでの実行
- インターネット接続（`openssh`パッケージ取得のため）

### Ansible固有の要件

- `community.general`コレクション（`community.general.apk`モジュールを使用）
- プレイブックレベルで`become: true`の指定

### 手動設定の要件

- `apk`コマンドおよびOpenRC（`rc-service`、`rc-update`）が利用可能であること

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                  | 説明                                                       | デフォルト値 | 必須   |
| ----------------------- | ---------------------------------------------------------- | ------------ | ------ |
| `sshd_service_enabled`  | sshdサービスをOpenRCのdefaultランレベルに登録するかどうか  | `true`       | いいえ |
| `sshd_service_state`    | sshdサービスの起動状態（`started` / `stopped`等）          | `started`    | いいえ |

#### 依存関係

なし。ただし通常は`ssh_hardening`や`ssh_host_key`の前提として適用される。

#### ハンドラー

- `Restart sshd (OpenRC)`: `sshd_config`が変更された際にsshdサービスを再起動

#### 使用例

```yaml
- hosts: alpine_hosts
  become: true
  roles:
    - role: sshd_alpine
```

### 方法2: 手動での設定手順

#### ステップ1: パッケージのインストール

```sh
sudo apk add openssh
```

#### ステップ2: 設定ディレクトリーの作成とIncludeの追加

```sh
sudo mkdir -p /etc/ssh/sshd_config.d
sudo chown root:root /etc/ssh/sshd_config.d
sudo chmod 755 /etc/ssh/sshd_config.d

grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config || \
  sudo sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
```

#### ステップ3: ホストキー生成

```sh
[ -f /etc/ssh/ssh_host_ed25519_key ] || sudo ssh-keygen -A
```

#### ステップ4: サービスの有効化と起動

```sh
sudo rc-update add sshd default
sudo rc-service sshd start
```

## 運用管理

### 基本操作

```sh
sudo rc-service sshd status
sudo rc-service sshd restart
sudo rc-service sshd reload
```

### ログとモニタリング

```sh
sudo tail -n 100 /var/log/messages
```

### トラブルシューティング

```sh
# 設定ファイルの構文チェック
sudo sshd -t

# 実効的に適用されている設定を確認
sudo sshd -T | less

# ランレベルへの登録状況
rc-update show default | grep sshd
```

### メンテナンス

```sh
sudo apk update
sudo apk upgrade openssh
sudo rc-service sshd restart
```

## アンインストール（手動）

```sh
sudo rc-service sshd stop
sudo rc-update del sshd default
sudo apk del openssh

# 設定ディレクトリーやホストキーを削除する場合
sudo rm -rf /etc/ssh/sshd_config.d
sudo rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub
```
