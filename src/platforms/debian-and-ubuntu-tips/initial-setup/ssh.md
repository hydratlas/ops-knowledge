# SSH
## SSHサーバーのインストール（管理者）
### インストール
```bash
sudo apt-get install --no-install-recommends -y openssh-server
```

### sshd_config.dディレクトリーの作成・有効化
以下のコマンドを実行することによって、`/etc/ssh/sshd_config.d`ディレクトリーを作成するとともに、`/etc/ssh/sshd_config`ファイルで`/etc/ssh/sshd_config.d/*.conf`ファイルを読み込む`Include`行がコメントアウトされていたらコメントアウトを解除し、コメントアウトがなかったら末尾に追記する。
```bash
sudo mkdir -p "/etc/ssh/sshd_config.d" &&
PERL_SCRIPT="s@^#Include /etc/ssh/sshd_config\.d/\*\.conf\$@Include /etc/ssh/sshd_config.d/*.conf@g" &&
sudo perl -pi -e "$PERL_SCRIPT" "/etc/ssh/sshd_config" &&
REGEX='^Include /etc/ssh/sshd_config\.d/\*\.conf$' &&
if ! grep -qP "$REGEX" "/etc/ssh/sshd_config";then
  echo -e "Include /etc/ssh/sshd_config.d/*.conf" | sudo tee -a "/etc/ssh/sshd_config" > /dev/null
fi
```

### パスワードによるログインおよびrootユーザーでのログインの禁止
`/etc/ssh/sshd_config.d`ディレクトリー下に設定ファイルを追加して、ssh.serviceを再起動する。
```bash
sudo tee "/etc/ssh/sshd_config.d/90-local.conf" << EOS > /dev/null &&
PasswordAuthentication no
PermitRootLogin no
EOS
sudo sshd -t &&
sudo systemctl restart ssh.service
```
`sudo sshd -T | grep -i -e PasswordAuthentication -e PermitRootLogin`コマンドを実行することによって、設定が反映されていることを確認できる。

## SSHサーバーの設定変更（管理者）
### 共通
`grep -i Include /etc/ssh/sshd_config`コマンドで/etc/ssh/sshd_config.d/*.confが読み込まれる設定になっていることを確認し、読み込まれていなかったら上記の手順により読み込まれるようにする。

### ポートの追加・変更
#### ソケットの編集
はじめに、`sudo nano /lib/systemd/system/ssh.socket`コマンドでソケットのファイルを編集する。以下のように`[Socket]`セクションに`ListenStream`の無指定（リセット用）、使いたいポート（複数行可）を書く。
```
[Socket]
ListenStream=
ListenStream=22
ListenStream=10022
```

#### 設定の追加・反映・確認
次に以下のコマンドで`/etc/ssh/sshd_config.d`ディレクトリー下に設定ファイルを追加する。
```bash
sudo tee -a "/etc/ssh/sshd_config.d/92-port-change.conf" << EOS > /dev/null &&
Port 22
Port 10022
EOS
sudo sshd -t &&
sudo systemctl daemon-reload &&
sudo systemctl restart ssh.socket &&
sudo systemctl restart ssh.service &&
ss -nlt
```
最後の`ss -nlt`コマンドによる表示で、StateがLISTENであるポートが意図したとおりなら完了。SSHクライアントから、`ssh`コマンドに`-p <port>`オプションを追加して接続する。

### 古い方式の禁止
古いタイプの各種方式を禁止する設定。新しいUbuntuまたはDebianを使えばこのような設定は不要である。たとえばUbuntu 24.04では以下の設定をしてもしなくても同じ設定になる。

`sudo sshd -T | grep -i -e Ciphers -e MACs -e PubkeyAcceptedKeyTypes -e PubkeyAcceptedAlgorithms -e KexAlgorithms`コマンドで現在の設定を確認できる。
```bash
sudo tee "/etc/ssh/sshd_config.d/91-local.conf" << EOS > /dev/null &&
Ciphers -*-cbc
KexAlgorithms -*-sha1
PubkeyAcceptedKeyTypes -ssh-rsa*,ssh-dss*
EOS
sudo sshd -t &&
sudo systemctl restart ssh.service
```
PubkeyAcceptedKeyTypesはOpenSSH 8.5からPubkeyAcceptedAlgorithmsに名前が変わっている。Ubuntu 20.04は8.2、22.04は8.9である。しかし、OpenSSH 8.5以降でもPubkeyAcceptedKeyTypesによる禁止設定は効果がある。

## ユーザーにauthorized_keysを追記（各ユーザー）
### ステップ1（変数にキーを格納）
#### 文字列からの場合
```bash
KEYS=$(cat << EOS
ssh-ed25519 xxxxx
ssh-ed25519 xxxxx
EOS
)
```

#### GitHubからの場合
```bash
KEYS="$(wget -qO - https://github.com/<username>.keys)"
```

### ステップ2（設定）
#### 現在ログインしているユーザーの場合
```bash
mkdir -p "$HOME/.ssh" &&
tee -a "$HOME/.ssh/authorized_keys" <<< "$KEYS" > /dev/null &&
chmod u=rw,go= "$HOME/.ssh/authorized_keys"
```

#### 現在ログインしていないユーザーの場合
```bash
USER_HOME="$(grep "$USER_NAME" /etc/passwd | cut -d: -f6)" &&
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.ssh" &&
sudo -u "$USER_NAME" tee -a "$USER_HOME/.ssh/authorized_keys" <<< "$KEYS" > /dev/null &&
sudo chmod u=rw,go= "$USER_HOME/.ssh/authorized_keys"
```

## SSHキーを生成（各ユーザー）
```bash
mkdir -p "$HOME/.ssh" &&
ssh-keygen -t rsa   -b 4096 -N '' -C '' -f "$HOME/.ssh/id_rsa" &&
ssh-keygen -t ecdsa  -b 521 -N '' -C '' -f "$HOME/.ssh/id_ecdsa" &&
ssh-keygen -t ed25519       -N '' -C '' -f "$HOME/.ssh/id_ed25519"
```
