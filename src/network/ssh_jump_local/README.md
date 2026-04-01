# ssh_jump_local

ローカルネットワーク向けSSHジャンプホスト（踏み台サーバー）専用の設定を適用

## 概要

### このドキュメントの目的

このロールは、ローカルネットワーク向けのSSHジャンプホスト（踏み台サーバー）として機能するサーバーに必要な特別なSSH設定を適用する。Ansible自動設定と手動設定の両方の方法に対応している。

### 実現される機能

- ローカルユーザーの作成と`~/.ssh/authorized_keys`の配置
- admグループに属するユーザーのみにTTYアクセスを許可
- その他のユーザーはnologinコマンドに制限
- SSHトンネル（SOCKSプロキシ等）とTCP転送の有効化
- GSSAPI認証・Kerberos認証・X11転送の無効化
- ジャンプホストとしての安全な接続制御

パスワード認証の無効化やrootログインの禁止は`ssh_hardening`ロールが担当する。

## 要件と前提条件

### 共通要件

- OpenSSHサーバーがインストールされていること
- `/etc/ssh/sshd_config.d/`ディレクトリがSSHDの設定でインクルードされていること
- rootまたはsudo権限
- admグループが存在すること

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

| 変数名 | デフォルト値 | 説明 |
| --- | --- | --- |
| `ssh_jump_local_users` | `[]` | 作成するユーザーのリスト |

`ssh_jump_local_users`の各要素は以下のキーを持つ。

| キー | 必須 | デフォルト値 | 説明 |
| --- | --- | --- | --- |
| `name` | はい | - | ユーザー名 |
| `uid` | はい | - | ユーザーID（FreeIPAと一致させること） |
| `ssh_authorized_keys` | はい | - | SSH公開鍵のリスト |
| `password` | いいえ | - | パスワードハッシュ（`mkpasswd`等で生成） |
| `groups` | いいえ | - | 所属グループ（例: `"adm"`） |
| `shell` | いいえ | `/bin/bash` | ログインシェル |

#### 依存関係

なし

#### タグとハンドラー

**ハンドラー:**

- `Reload SSH`: SSHサービスを再読み込み

**タグ:**
このroleでは特定のタグは使用していない。

#### 使用例

基本的な使用例：

```yaml
- hosts: jump_int_local
  become: true
  roles:
    - ssh_jump_local
```

複数のロールと組み合わせる例：

```yaml
- hosts: jump_int_local
  become: true
  roles:
    - common
    - ssh_jump_local
    - firewall
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# SSH設定ディレクトリの確認
ls -la /etc/ssh/sshd_config.d/

# admグループの存在確認
getent group adm
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

# ジャンプホスト用設定ファイルの作成
sudo tee /etc/ssh/sshd_config.d/10-ssh-jump-local.conf > /dev/null << 'EOF'
# GSSAPI・Kerberos認証を無効化する（FreeIPA未登録ホストのため不要）
GSSAPIAuthentication no
KerberosAuthentication no

# X11転送を無効化する
X11Forwarding no

# SSHトンネル（SOCKS プロキシ等）を許可する
PermitTunnel yes
# TCP転送を許可する
AllowTcpForwarding yes

# admグループに属さないユーザーはログインを禁止する
Match Group !adm
  ForceCommand /sbin/nologin
  PermitTTY no
EOF

# 設定ファイルの権限設定
sudo chmod 644 /etc/ssh/sshd_config.d/10-ssh-jump-local.conf
sudo chown root:root /etc/ssh/sshd_config.d/10-ssh-jump-local.conf

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
sudo sshd -T | grep -E "permittunnel|allowtcpforwarding|x11forwarding|gssapiauthentication"

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
sudo cat /etc/ssh/sshd_config.d/10-ssh-jump-local.conf

# 設定がインクルードされているか確認
sudo grep -i "include" /etc/ssh/sshd_config
```

3. 有効な設定の確認

```bash
# 実際に適用されている設定を確認
sudo sshd -T | grep -E "permittunnel|allowtcpforwarding|x11forwarding|gssapiauthentication"
```

#### 接続テスト

別のホストから接続テスト：

```bash
# ジャンプホスト経由での接続
ssh -J jumphost-server target-server

# SOCKSプロキシを使用したトンネル
ssh -D 9080 jumphost-server

# 詳細な接続情報を表示
ssh -v -J jumphost-server target-server
```

#### よくある問題と対処

1. **admグループに属さないユーザーがログインできない**
   - 設計通りの動作である
   - 必要に応じてユーザーをadmグループに追加

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

4. **SOCKS プロキシが機能しない**
   ```bash
   # トンネル設定の確認
   sudo sshd -T | grep -E "permittunnel|allowtcpforwarding"
   # yesになっていることを確認
   ```

### メンテナンス

#### バックアップ

```bash
# SSH設定のバックアップ
sudo cp -a /etc/ssh/sshd_config.d /etc/ssh/sshd_config.d.backup-$(date +%Y%m%d)
```

#### ユーザーをadmグループに追加

ジャンプホストアクセスを許可するユーザーを追加する場合：

```bash
# ユーザーをadmグループに追加
sudo usermod -aG adm username

# グループメンバーシップの確認
groups username
```

#### グループベース制限の変更

別のグループで制限したい場合：

```bash
# 設定ファイルの編集
sudo vi /etc/ssh/sshd_config.d/10-ssh-jump-local.conf

# 例：wheelグループに変更
Match Group !wheel
  ForceCommand /sbin/nologin
  PermitTTY no

# 設定の再読み込み
sudo systemctl reload ssh
```

## アンインストール（手動）

以下の手順でジャンプホスト設定を削除する。

```bash
# 1. 設定ファイルの削除
sudo rm -f /etc/ssh/sshd_config.d/10-ssh-jump-local.conf

# 2. SSH設定の検証
sudo sshd -t

# 3. SSHサービスの再読み込み
sudo systemctl reload ssh    # Debian/Ubuntu
# または
sudo systemctl reload sshd   # RHEL/CentOS

# 4. 設定が削除されたことを確認
sudo sshd -T | grep -E "permittunnel|allowtcpforwarding|x11forwarding|gssapiauthentication"
```

注意: この設定を削除すると、すべてのユーザーが通常のSSHアクセスを持つようになる。

## 参考

- [OpenSSH Manual Pages](https://www.openssh.com/manual.html)
- [SSH Jump Host Configuration](https://www.ssh.com/academy/ssh/jump-host)
- [SSH Tunneling and SOCKS Proxy](https://www.ssh.com/academy/ssh/tunneling)
