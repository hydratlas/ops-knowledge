# podman_user_linger

systemdユーザーセッションのlinger有効化ロール

## 概要

### このドキュメントの目的

このロールは、指定されたユーザーに対してsystemdのlingerを有効化し、ログインセッションがなくてもユーザーのsystemdインスタンスを起動状態に維持する。

### 実現される機能

- 指定されたユーザーに対する`loginctl enable-linger`の実行
- `/run/user/<uid>`ディレクトリの永続的な存在を保証
- systemdユーザーセッションのブート時自動起動

### 背景

Slurmジョブなど非対話的なセッションからPodmanを実行する場合、sshログインとは異なりsystemdのユーザーセッションが自動的に起動しない。そのため`/run/user/<uid>`（XDG_RUNTIME_DIR）が存在せず、Podmanは警告を出力してcgroupfsにフォールバックする。lingerを有効化することで、この問題を解決できる。

## 要件と前提条件

### 共通要件

- サポートされるOS：
  - RHEL/CentOS/AlmaLinux/Rocky Linux 8以降
  - Fedora 33以降
  - Debian 11以降
  - Ubuntu 20.04以降
- systemdが起動していること

### Ansible固有の要件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要
- 制御ノードから対象ホストへのSSH接続

### 手動設定の要件

- rootまたはsudo権限

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名              | デフォルト値 | 説明                               |
| ------------------- | ------------ | ---------------------------------- |
| `shared_home_users` | `[]`         | lingerを有効化するユーザーのリスト |

`shared_home_users`の各要素には`name`属性が必要である。通常、`all.yml`で定義される。

#### 依存関係

このロールには依存関係はない。

#### タグとハンドラー

このロールでは特定のタグやハンドラーは使用していない。

#### 使用例

基本的な使用例：

```yaml
- hosts: container_env_hosts
  become: true
  roles:
    - infrastructure/container/podman_user_linger
```

### 方法2: 手動での設定手順

#### ステップ1: 現在の状態を確認

特定のユーザーのlinger状態を確認：

```bash
loginctl show-user <username> --property=Linger
```

#### ステップ2: lingerを有効化

```bash
sudo loginctl enable-linger <username>
```

#### ステップ3: 動作確認

lingerが有効化されたことを確認：

```bash
loginctl show-user <username> --property=Linger
# Linger=yes と表示されれば成功
```

`/run/user/<uid>`が存在することを確認：

```bash
ls -la /run/user/$(id -u <username>)
```

## 運用管理

### トラブルシューティング

#### 診断フロー

1. ユーザーのlinger状態を確認
2. `/run/user/<uid>`の存在を確認
3. systemdユーザーインスタンスの状態を確認

#### よくある問題と対処

**問題**: lingerを有効化しても`/run/user/<uid>`が作成されない

```bash
# systemdユーザーインスタンスの状態を確認
systemctl --user status

# 手動でユーザーセッションを開始
machinectl shell <username>@
```

**問題**: Podmanがまだcgroupfsにフォールバックする

```bash
# XDG_RUNTIME_DIRが正しく設定されているか確認
echo $XDG_RUNTIME_DIR

# cgroupのバージョンを確認
stat -fc %T /sys/fs/cgroup/
```

## アンインストール（手動）

lingerを無効化する場合：

```bash
sudo loginctl disable-linger <username>
```

注意：lingerを無効化すると、そのユーザーのログインセッションがなくなった時点で`/run/user/<uid>`が削除される。Slurmジョブ等からのPodman実行に影響を与える可能性がある。
