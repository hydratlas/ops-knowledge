# podman_auto_update

Podmanコンテナの自動更新を有効化するロール

## 概要

### このドキュメントの目的
このロールは、Podmanの自動更新機能を有効化し、コンテナイメージの自動更新を実現します。Ansible自動設定と手動設定の両方の方法に対応しており、運用中のコンテナを最新の状態に保つための自動化を提供します。

### 実現される機能
- `podman-auto-update.timer`による定期的な更新チェック
- `AutoUpdate=registry`ラベルが設定されたコンテナの自動更新
- 新しいイメージバージョンの自動検出とダウンロード
- 更新後のコンテナ自動再起動
- 更新失敗時の自動ロールバック機能

## 要件と前提条件

### 共通要件
- Podmanがインストールされていること
- systemdがインストールされていること
- コンテナイメージがレジストリから取得可能であること
- インターネット接続（レジストリアクセス用）

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要
- 制御ノードから対象ホストへのSSH接続

### 手動設定の要件
- rootまたはsudo権限
- systemctlコマンドの実行権限
- 基本的なLinuxコマンドの知識

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はありません。

#### 依存関係
- 推奨: `infrastructure.container.podman`（Podmanのインストール）

#### タグとハンドラー
このroleでは特定のタグやハンドラーは使用していません。

#### 使用例

基本的な使用例：
```yaml
- hosts: container_hosts
  become: true
  roles:
    - infrastructure.container.podman_auto_update
```

Podmanインストールと組み合わせる例：
```yaml
- hosts: container_hosts
  become: true
  roles:
    - infrastructure.container.podman
    - infrastructure.container.podman_auto_update
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

Podmanとsystemdの状態を確認します：
```bash
# Podmanのインストール確認
podman --version

# systemdのバージョン確認
systemctl --version

# podman-auto-updateサービスの存在確認
systemctl list-unit-files | grep podman-auto-update
```

#### ステップ2: インストール

通常、podman-auto-updateはPodmanと一緒にインストールされますが、ない場合は追加でインストールします：

**Debian/Ubuntu系：**
```bash
# Podman関連パッケージの確認
dpkg -l | grep podman

# 必要に応じて再インストール
sudo apt-get install --reinstall podman
```

**RHEL/CentOS系：**
```bash
# Podman関連パッケージの確認
rpm -qa | grep podman

# 必要に応じて再インストール
sudo dnf reinstall podman
```

#### ステップ3: 設定

自動更新タイマーの設定を確認・調整します：
```bash
# タイマー設定の確認
systemctl cat podman-auto-update.timer

# デフォルトの実行時刻を確認（通常は毎日00:00）
systemctl list-timers --all | grep podman-auto-update

# カスタムタイマー設定を作成（例：毎日午前3時に実行）
sudo mkdir -p /etc/systemd/system/podman-auto-update.timer.d/
sudo tee /etc/systemd/system/podman-auto-update.timer.d/override.conf << 'EOF'
[Timer]
OnCalendar=
OnCalendar=daily
RandomizedDelaySec=30m
Persistent=true
EOF

# systemdの設定をリロード
sudo systemctl daemon-reload
```

#### ステップ4: 起動と有効化

自動更新タイマーを有効化して起動します：
```bash
# タイマーの有効化と起動
sudo systemctl enable --now podman-auto-update.timer

# タイマーの状態確認
sudo systemctl status podman-auto-update.timer

# 次回実行時刻の確認
systemctl list-timers podman-auto-update.timer

# 手動で更新を実行してテスト
sudo systemctl start podman-auto-update.service
```

## 運用管理

### 基本操作

```bash
# タイマーの状態確認
systemctl status podman-auto-update.timer

# サービスの状態確認
systemctl status podman-auto-update.service

# 手動で更新を実行
sudo systemctl start podman-auto-update.service

# 更新対象のコンテナを確認
podman auto-update --dry-run

# 実際に更新を実行（手動）
sudo podman auto-update
```

### ログとモニタリング

```bash
# 更新ログの確認
journalctl -u podman-auto-update.service

# 最新の更新実行結果
journalctl -u podman-auto-update.service -n 50

# リアルタイムでログを監視
journalctl -u podman-auto-update.service -f

# 特定期間のログを確認
journalctl -u podman-auto-update.service --since "2024-01-01" --until "2024-01-31"

# タイマーの実行履歴
systemctl list-timers --all | grep podman-auto-update
```

### トラブルシューティング

#### 診断フロー
1. タイマーの有効化状態を確認
2. サービスの最終実行結果を確認
3. 対象コンテナのラベル設定を確認
4. レジストリへの接続性を確認

#### よくある問題と対処

**問題**: タイマーが実行されない
```bash
# タイマーの状態確認
systemctl status podman-auto-update.timer

# タイマーの再起動
sudo systemctl restart podman-auto-update.timer

# systemdログの確認
journalctl -u podman-auto-update.timer
```

**問題**: コンテナが更新されない
```bash
# コンテナのラベル確認
podman inspect <container_name> | grep -i autoupdate

# 正しいラベルの設定
podman run --label io.containers.autoupdate=registry ...

# 更新対象の確認
podman auto-update --dry-run
```

**問題**: 更新後にコンテナが起動しない
```bash
# エラーログの確認
journalctl -u podman-auto-update.service -n 100

# コンテナの状態確認
podman ps -a

# 手動でコンテナを起動
podman start <container_name>

# イメージの確認
podman images | grep <image_name>
```

### メンテナンス
```bash
# 古いイメージのクリーンアップ
podman image prune -f

# 未使用のボリュームのクリーンアップ
podman volume prune -f
```

### コンテナ側の設定

自動更新を有効にするには、コンテナに以下のラベルを設定する必要があります：

**Podman Quadletの場合：**
```ini
[Container]
AutoUpdate=registry
```

**docker-compose.ymlの場合：**
```yaml
services:
  myapp:
    labels:
      - "io.containers.autoupdate=registry"
```

**podman runの場合：**
```bash
podman run --label io.containers.autoupdate=registry \
  --name myapp \
  docker.io/example/myapp:latest
```

## アンインストール（手動）

以下の手順でPodman自動更新機能を無効化します：

```bash
# 1. タイマーの停止と無効化
sudo systemctl stop podman-auto-update.timer
sudo systemctl disable podman-auto-update.timer

# 2. サービスの停止
sudo systemctl stop podman-auto-update.service

# 3. カスタム設定の削除（作成した場合）
sudo rm -rf /etc/systemd/system/podman-auto-update.timer.d/

# 4. systemdの設定をリロード
sudo systemctl daemon-reload

# 5. 状態の確認
systemctl status podman-auto-update.timer
systemctl status podman-auto-update.service

# 6. 自動更新ラベルの削除（必要な場合）
# 各コンテナから手動でラベルを削除するか、
# コンテナを再作成する際にラベルを付けない
```

注意事項:
- 自動更新は`registry`タイプのみサポート（ローカルイメージの更新は対象外）
- 更新時はコンテナが一時的に停止・再起動されるため、ダウンタイムが発生
- 更新に失敗した場合は、古いイメージでコンテナが再起動される
- 重要なサービスでは、更新時刻を業務時間外に設定することを推奨