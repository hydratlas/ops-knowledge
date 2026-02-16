# ssh_jump

SSHジャンプホスト（踏み台サーバー）専用の設定を適用

## 概要

### このドキュメントの目的

このロールは、SSHジャンプホスト（踏み台サーバー）として機能するサーバーに必要な特別なSSH設定を適用します。Ansible自動設定と手動設定の両方の方法に対応しています。

### 実現される機能

- 特定ユーザー（ansibleユーザー）のみにTTYアクセスを許可
- その他のユーザーはnologinコマンドに制限
- SSHエージェント転送の有効化
- ジャンプホストとしての安全な接続制御

## 要件と前提条件

### 共通要件

- OpenSSHサーバーがインストールされていること
- `/etc/ssh/sshd_config.d/`ディレクトリがSSHDの設定でインクルードされていること
- rootまたはsudo権限
- ansibleユーザーが存在すること（Ansible使用時）

### Ansible固有の要件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要
- 制御ノードから対象ホストへのSSH接続

### 手動設定の要件

- rootまたはsudo権限
- テキストエディタの基本操作
- SSHサービスの再読み込み権限

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

このロールは変数を使用しません。設定はテンプレートに固定されています。

#### 依存関係

なし

#### タグとハンドラー

**ハンドラー:**

- `reload ssh`: SSHサービスを再読み込み

**タグ:**
このroleでは特定のタグは使用していません。

#### 使用例

基本的な使用例：

```yaml
- hosts: jump_hosts
  become: true
  roles:
    - ssh_jump
```

複数のロールと組み合わせる例：

```yaml
- hosts: jump_hosts
  become: true
  roles:
    - common
    - ssh_jump
    - firewall
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# SSH設定ディレクトリの確認
ls -la /etc/ssh/sshd_config.d/
```

#### ステップ2: インストール

OpenSSHサーバーのインストール（必要な場合）：

Debian/Ubuntu:

```bash
sudo apt update
sudo apt install openssh-server
```

RHEL/CentOS:

```bash
sudo dnf install openssh-server
```

#### ステップ3: 設定

```bash
# SSH設定ディレクトリの作成
sudo mkdir -p /etc/ssh/sshd_config.d
sudo chmod 755 /etc/ssh/sshd_config.d

# ジャンプホスト用設定ファイルの作成（ansibleは実際のユーザー名に置換）
sudo tee /etc/ssh/sshd_config.d/10-ssh-jump.conf > /dev/null << 'EOF'
Match User ansible
    PermitTTY yes
    ForceCommand none

Match all
    PermitTTY no
    ForceCommand /usr/sbin/nologin
EOF

# 設定ファイルの権限設定
sudo chmod 644 /etc/ssh/sshd_config.d/10-ssh-jump.conf
sudo chown root:root /etc/ssh/sshd_config.d/10-ssh-jump.conf

# SSH設定の検証
sudo sshd -t
```

#### ステップ4: 起動と有効化

```bash
# SSHサービスの再読み込み
sudo systemctl reload ssh    # Debian/Ubuntu
# または
sudo systemctl reload sshd   # RHEL/CentOS

# サービスの状態確認
sudo systemctl status ssh    # Debian/Ubuntu
# または
sudo systemctl status sshd   # RHEL/CentOS
```

## 運用管理

### 基本操作

```bash
# SSH設定の検証
sudo sshd -t

# 現在の設定を表示
sudo sshd -T | grep -E "permittty|forcecommand"

# SSHサービスの管理
sudo systemctl status ssh    # 状態確認
sudo systemctl reload ssh    # 設定の再読み込み
sudo systemctl restart ssh   # サービスの再起動
```

### ログとモニタリング

```bash
# SSHログの確認（Debian/Ubuntu）
sudo journalctl -u ssh -f

# SSHログの確認（RHEL/CentOS）
sudo journalctl -u sshd -f

# 認証ログの確認
sudo tail -f /var/log/auth.log    # Debian/Ubuntu
sudo tail -f /var/log/secure      # RHEL/CentOS

# 接続中のSSHセッション確認
who
w
```

### トラブルシューティング

#### 設定エラーの診断

1. SSH設定の検証

```bash
sudo sshd -t
```

2. 設定ファイルの確認

```bash
# 設定ファイルの内容確認
sudo cat /etc/ssh/sshd_config.d/10-ssh-jump.conf

# 設定がインクルードされているか確認
sudo grep -i "include" /etc/ssh/sshd_config
```

3. 有効な設定の確認

```bash
# 実際に適用されている設定を確認
sudo sshd -T | grep -E "permittty|forcecommand"
```

#### 接続テスト

別のホストから接続テスト：

```bash
# ジャンプホスト経由での接続
ssh -J jumphost-server target-server

# 詳細な接続情報を表示
ssh -v -J jumphost-server target-server
```

#### よくある問題と対処

1. **ansibleユーザー以外がログインできない**
   - 設計通りの動作です
   - 必要に応じて設定ファイルでユーザーを追加

2. **設定変更が反映されない**

   ```bash
   sudo systemctl reload ssh
   ```

3. **SSHサービスが起動しない**
   ```bash
   # 設定エラーの確認
   sudo sshd -t
   # エラーメッセージに従って修正
   ```

### メンテナンス

#### バックアップ

```bash
# SSH設定のバックアップ
sudo cp -a /etc/ssh/sshd_config.d /etc/ssh/sshd_config.d.backup-$(date +%Y%m%d)
```

#### 追加ユーザーの設定

ジャンプホストアクセスを許可するユーザーを追加する場合：

```bash
# 設定ファイルの編集
sudo vi /etc/ssh/sshd_config.d/10-ssh-jump.conf

# 例：user1とuser2を追加
Match User ansible,user1,user2
    PermitTTY yes
    ForceCommand none

Match all
    PermitTTY no
    ForceCommand /usr/sbin/nologin

# 設定の再読み込み
sudo systemctl reload ssh
```

## アンインストール（手動）

以下の手順でジャンプホスト設定を削除します。

```bash
# 1. 設定ファイルの削除
sudo rm -f /etc/ssh/sshd_config.d/10-ssh-jump.conf

# 2. SSH設定の検証
sudo sshd -t

# 3. SSHサービスの再読み込み
sudo systemctl reload ssh    # Debian/Ubuntu
# または
sudo systemctl reload sshd   # RHEL/CentOS

# 4. 設定が削除されたことを確認
sudo sshd -T | grep -E "permittty|forcecommand"
```

注意: この設定を削除すると、すべてのユーザーが通常のSSHアクセスを持つようになります。

## 参考

- [OpenSSH Manual Pages](https://www.openssh.com/manual.html)
- [SSH Jump Host Configuration](https://www.ssh.com/academy/ssh/jump-host)
