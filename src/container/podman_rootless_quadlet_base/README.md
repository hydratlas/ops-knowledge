# podman_rootless_quadlet_base

Rootless Podman Quadletの共通セットアップを提供する基本ロール

## 概要

### このドキュメントの目的
このロールは、Rootless Podman Quadletの共通セットアップを提供します。他のロールから`include_tasks`で呼び出して使用され、Ansible自動設定と手動設定の両方の方法に対応しています。

### 実現される機能
- 専用のシステムユーザーを非特権ユーザーとして作成（subuid/subgidを自動割り当て）
- Lingering有効化してユーザーがログインしていなくてもサービスを実行可能に
- 必要なディレクトリ構造の作成
- ユーザーの`podman-auto-update.timer`を有効化し、コンテナイメージの自動更新を設定
- セキュアなrootlessコンテナ実行環境の構築

## 要件と前提条件

### 共通要件
- Podmanがインストールされていること
- systemdがインストールされていること
- loginctlコマンドが利用可能であること（systemd-loginパッケージ）
- rootまたはsudo権限

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

| 変数名 | 必須 | デフォルト値 | 説明 |
|--------|------|--------------|------|
| `quadlet_user` | ✓ | - | コンテナを実行するユーザー名 |
| `quadlet_app_name` | ✓ | - | アプリケーション名（設定ディレクトリ名に使用） |
| `quadlet_user_comment` | × | `Rootless container user` | ユーザーのコメント |
| `quadlet_user_shell` | × | `/usr/sbin/nologin` | ユーザーのシェル |

**設定される変数:**

このロールは以下の変数を設定します（呼び出し元で使用可能）：
- `quadlet_uid`: ユーザーのUID
- `quadlet_gid`: ユーザーのGID
- `quadlet_home`: ユーザーのホームディレクトリ
- `quadlet_config_dir`: アプリケーション設定ディレクトリ (`~/.config/{app_name}`)
- `quadlet_systemd_dir`: Quadletファイル配置ディレクトリ (`~/.config/containers/systemd`)

#### 依存関係
なし（他のロールから呼び出されることを前提）

#### タグとハンドラー
このロールでは特定のタグやハンドラーは使用していません。

#### 使用例

他のロールのtasks/main.ymlから呼び出す例：
```yaml
---
- name: Include common Rootless Podman Quadlet setup
  ansible.builtin.include_tasks: ../../podman_rootless_quadlet_base/tasks/main.yml
  vars:
    quadlet_user: "myapp"
    quadlet_user_comment: "My Application rootless user"
    quadlet_app_name: "myapp"

- name: Set app specific facts
  ansible.builtin.set_fact:
    myapp_uid: "{{ quadlet_uid }}"
    myapp_home: "{{ quadlet_home }}"
    myapp_config_dir: "{{ quadlet_config_dir }}"
    myapp_systemd_dir: "{{ quadlet_systemd_dir }}"

# 以降、アプリケーション固有の設定を続ける
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

##### 変数の設定

まず、使用する変数を設定します：

```bash
APP_NAME="myapp"
QUADLET_USER="myapp"
USER_COMMENT="My Application rootless user"
```

##### システムユーザーのセットアップとディレクトリーの作成

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

システムユーザーを作成し、ルートレスコンテナ用のsubuid/subgidを割り当てます：

```bash
# ユーザーの作成（subuid/subgid付き）
USER_SHELL="/usr/sbin/nologin"  # 必要に応じて変更可能
sudo useradd --system --user-group --add-subids-for-system --shell "${USER_SHELL}" --comment "${USER_COMMENT}" "${QUADLET_USER}"

# systemd-journalグループへの追加
sudo usermod -aG systemd-journal "${QUADLET_USER}"
```

ユーザーがログインしていなくてもサービスを実行できるようにsystemd lingeringを有効化します：

```bash
# lingeringを有効化
sudo loginctl enable-linger "${QUADLET_USER}"
```

Quadletとコンテナストレージ用のディレクトリを作成します：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "${QUADLET_USER}" | cut -d: -f6)"

# 必要なディレクトリを作成
sudo mkdir -p "${QUADLET_HOME}/.config/${APP_NAME}" &&
sudo mkdir -p "${QUADLET_HOME}/.config/containers/systemd" &&
sudo mkdir -p "${QUADLET_HOME}/.local/share/containers/storage"

# 所有権の設定
sudo chown -R "${QUADLET_USER}:${QUADLET_USER}" "${QUADLET_HOME}"

# パーミッションの設定
sudo chmod -R 755 "${QUADLET_HOME}"
```

#### ステップ2: Podmanのインストール

Podmanのインストールは各ディストリビューションのパッケージマネージャーを使用してください。

#### ステップ3: Podman Quadletの設定

##### Quadletファイルなどの配置

以下を行います：

1. アプリケーション固有の設定ファイルを`${QUADLET_HOME}/.config/${APP_NAME}`に配置
2. Quadletファイル（.container、.volume、.network）を`${QUADLET_HOME}/.config/containers/systemd`に配置

#### ステップ4: 起動と有効化

##### Quadletサービスの起動と有効化

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

Quadletから生成されたサービスファイルを認識させるため、systemdユーザーデーモンをリロードしてから、サービスを起動します：

```bash
# systemdユーザーデーモンのリロード
sudo -u ${QUADLET_USER} \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user daemon-reload

# サービスの起動
sudo -u ${QUADLET_USER} \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user start "${APP_NAME}.service"
```

podman-auto-update.timerの起動と有効化によって、コンテナイメージの自動更新を有効にします：

```bash
# タイマーの起動と有効化
sudo -u ${QUADLET_USER} \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user enable --now podman-auto-update.timer
```


## 運用管理

### 基本操作
```bash
# アプリケーション名とユーザー名を設定
APP_NAME="myapp"
QUADLET_USER="myapp"
```

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

サービス操作：

```bash
# サービスの状態確認
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user status "${APP_NAME}.service"

# サービスの再起動
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user restart "${APP_NAME}.service"

# サービスの停止
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user stop "${APP_NAME}.service"

# サービスの開始
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user start "${APP_NAME}.service"
```

ログ確認：

```bash
# サービスのログの確認（最新の100行）
sudo -u "${QUADLET_USER}" \
  journalctl --user -u "${APP_NAME}.service" --no-pager -n 100

# サービスのログの確認（リアルタイム表示）
sudo -u "${QUADLET_USER}" \
  journalctl --user -u "${APP_NAME}.service" -f
```

コンテナ確認：

```bash
# コンテナの状態確認
sudo -u "${QUADLET_USER}" podman ps

# すべてのコンテナを表示（停止中も含む）
sudo -u "${QUADLET_USER}" podman ps -a

# コンテナの詳細情報
sudo -u "${QUADLET_USER}" podman inspect ${APP_NAME}

# コンテナイメージの一覧
sudo -u "${QUADLET_USER}" podman images

# 古いコンテナイメージのクリーンアップ
sudo -u "${QUADLET_USER}" podman image prune -f
```

設定・環境確認：

```bash
# subuid/subgidの確認
grep "${QUADLET_USER}" /etc/subuid /etc/subgid

# lingeringの確認
loginctl show-user "${QUADLET_USER}" --property=Linger

# ユーザー情報の確認
id "${QUADLET_USER}"
```

Quadletファイル管理：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "${QUADLET_USER}" | cut -d: -f6)"

# ファイルの存在確認
ls -la "${QUADLET_HOME}/${QUADLET_USER}/.config/containers/systemd/"

# 構文確認
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  /usr/libexec/podman/quadlet --dryrun --user

# Systemdのリロード
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user daemon-reload
```

自動更新：

```bash
# 自動更新タイマーの状態確認
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user status podman-auto-update.timer

# 自動更新のログ確認
sudo -u "${QUADLET_USER}" \
  journalctl --user -u podman-auto-update.service
```

作成されるディレクトリ：
- `/home/${QUADLET_USER}/` - ユーザーのホームディレクトリ
- `/home/${QUADLET_USER}/.config/` - 設定ディレクトリ
- `/home/${QUADLET_USER}/.config/${APP_NAME}/` - アプリケーション固有の設定
- `/home/${QUADLET_USER}/.config/containers/systemd/` - Quadletファイル配置場所
- `/home/${QUADLET_USER}/.local/share/containers/storage/` - コンテナストレージ


### メンテナンス

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

バックアップ：

```bash
# ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "${QUADLET_USER}" | cut -d: -f6)"

# 設定ファイルとQuadletファイルのバックアップ
sudo tar -czf "${APP_NAME}-backup-$(date +%Y%m%d).tar.gz" \
    "${QUADLET_HOME}/${QUADLET_USER}/.config/${APP_NAME}" \
    "${QUADLET_HOME}/${QUADLET_USER}/.config/containers/systemd"
```

手動更新：

```bash
# 手動でのイメージ更新
sudo -u "${QUADLET_USER}" podman pull <image-name>

# サービスの再起動
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u ${QUADLET_USER})" \
  systemctl --user restart "${APP_NAME}.service"
```

自動更新は`podman-auto-update.timer`により定期的に実行されます。


`podman auto-update`コマンドで、AutoUpdate=registryが設定された全コンテナを一括更新することもできます：

```bash
sudo -u ${QUADLET_USER} podman auto-update
```

## アンインストール（手動）

以下の手順でRootless Podman Quadlet環境を削除します。

```bash
# 追加のQuadletファイルの削除（必要に応じて）
sudo rm -f "/home/${QUADLET_USER}/.config/containers/systemd/${APP_NAME}.network"
sudo rm -f "/home/${QUADLET_USER}/.config/containers/systemd/${APP_NAME}.volume"
```

<!-- このファイルはgomplateで処理されます。デリミタ: 三重角括弧 -->

```bash
# 0. ユーザーのホームディレクトリーの取得
QUADLET_HOME="$(getent passwd "${QUADLET_USER}" | cut -d: -f6)"

# 1. サービスの停止
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "${QUADLET_USER}")" \
  systemctl --user stop "${APP_NAME}.service"

# 2. 自動更新タイマーの停止と無効化
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "${QUADLET_USER}")" \
  systemctl --user disable --now podman-auto-update.timer

# 3. Quadletコンテナ定義ファイルの削除
sudo rm -f \
  "${QUADLET_HOME}/${QUADLET_USER}/.config/containers/systemd/${APP_NAME}.container"

# 4. systemdユーザーデーモンのリロード
sudo -u "${QUADLET_USER}" \
  XDG_RUNTIME_DIR="/run/user/$(id -u "${QUADLET_USER}")" \
  systemctl --user daemon-reload

# 5. コンテナイメージの削除
sudo -u "${QUADLET_USER}" podman rmi "<image-name>"

# 6. アプリケーション設定の削除
# 警告: この操作により、アプリケーション固有の設定がすべて削除されます
sudo rm -rf "${QUADLET_HOME}/${QUADLET_USER}/.config/${APP_NAME}"

# 7. lingeringを無効化
sudo loginctl disable-linger "${QUADLET_USER}"

# 8. ユーザーの削除
# 警告: このユーザーのホームディレクトリとすべてのデータが削除されます
sudo userdel -r "${QUADLET_USER}"
```


## 参考

- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Rootless Podman Documentation](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [systemd.unit Documentation](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)