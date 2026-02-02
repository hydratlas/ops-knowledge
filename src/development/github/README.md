# アカウントを使い分けるGitHubクライアントの設定方法
一つのシステムで複数のGitHubアカウントを扱うとき、SSHキーやGPGキーをアカウントごとに分けることでコンフリクトを防ぎ、安全にリポジトリーを操作できます。本ドキュメントでは、その手順を説明します。

## 対応環境
- Linux
    - Bash
- Windows
    - Windows Terminal上のGit Bash

## システム全体の設定
複数のアカウントを扱うにあたり、マシン全体に必要なパッケージをインストールし、環境設定を行います。

### パッケージのインストール
#### Linux（Debian系）
GitやGPGが未インストールの場合は以下のコマンドで導入してください。
```bash
sudo apt-get install -y git gpg
```

#### Windows
Git Bashがインストールされていれば、GitとGPGは準備できている。

### 【元に戻す】パッケージをアンインストール
インストールしたパッケージを削除する場合は、以下のコマンドを実行します。

#### Linux
```bash
sudo apt-get purge -y git gpg
```

### 変数の準備
本手順では以下の変数を設定してから進める想定です。ドキュメント中で何度か繰り返し登場するため、最初に定義しておくとスムーズに作業できます。
- `$github_short_username`: SSHのホスト名設定で使用するための短い名前
- `$github_mail`: GitHubが用意したプライベートメールアドレス
    - GitHubから自動付与される「123456789+username@users.noreply.github.com」形式のメールアドレスです。実際のメールアドレスを公開しないために利用します
    - [GitHubの設定 > Emails](https://github.com/settings/emails)で確認できます

以下の例のように変数を設定します。

```bash
github_short_username="abc" &&
github_mail="123456789+username@users.noreply.github.com" &&
github_username="${github_mail#*+}" &&
github_username="${github_username%@*}" &&
github_userid="${github_username} <${github_mail}>"
```

### SSHキーペアとSSH設定ファイルの作成
ホスト名ごとに異なるSSHキーを使用できるよう、SSHの設定ファイル(~/.ssh/config)に接続設定を追加します。

```bash
keyfile="$HOME/.ssh/id_ed25519_${github_username}"
ssh-keygen -t ed25519 -N "" -C "" -f "${keyfile}" &&
tee -a "$HOME/.ssh/config" << EOS > /dev/null &&
Host github-${github_short_username}
    HostName github.com
    IdentityFile ~/.ssh/id_ed25519_${github_username}
    User git
EOS
cat "${keyfile}.pub"
```

実行後には、次の手順を実施します。

1. 最後に表示された公開鍵をコピーします
1. [GitHubの設定 > SSH and GPG keys > New SSH key](https://github.com/settings/keys)にペーストしてください
    - Titleにはデバイス名をつけると区別しやすいです

### 【デバッグ】SSHキーペアの確認
SSHキーが正しく生成されているかを確認するときは、以下のコマンドでファイルリストを確認します。

```bash
ls -la "$HOME/.ssh"
```

### 【デバッグ】.ssh/configの確認
SSHの設定ファイルが正しい内容になっているか確認します。

```bash
cat "$HOME/.ssh/config"
```

### 【デバッグ】.ssh/configの編集
SSHの設定ファイルを編集します。

```bash
nano "$HOME/.ssh/config"
```

### 【元に戻す】生成したSSHキーペアの削除
不要になったSSHキーや誤って作成してしまったキーは以下のコマンドで削除できます。合わせて~/.ssh/configの該当行もファイルの編集によって削除してください。

```bash
rm "${keyfile}.pub" &&
rm "${keyfile}"
```

### GPGキーペアの作成
コミット署名やタグ署名などを行う場合は、GPGキーの作成とGitHubへの登録が必要です。

コミット署名やタグ署名を行うことを強く推奨します。署名付きのコミットやタグは、改ざんやなりすましを防ぎ、コードの信頼性を確保するために非常に重要です。

```bash
gpg --pinentry-mode loopback --passphrase "" \
  --quick-gen-key "${github_userid}" future-default - 0 &&
gpg --armor --export "${github_userid}"
```

実行後には、次の手順を実施します。

1. 最後に表示された公開鍵をコピーします
1. [GitHubの設定 > SSH and GPG keys > New GPG key](https://github.com/settings/keys)にペーストしてください
    - Titleにはデバイス名をつけると区別しやすいです

### 【デバッグ】GPGキー（秘密鍵）のリストの確認
生成したGPGキーが正しく登録されているかを確認するときは、秘密鍵のリストを確認します（公開鍵のみのリスト表示はできません）。

```bash
gpg --list-secret-keys
```

### 【元に戻す】生成したGPGキーペアの削除
GPGキーが不要になった場合や再作成したい場合は、以下のコマンドを使用します。

```bash
gpg --delete-secret-keys "${github_userid}" &&
gpg --delete-keys "${github_userid}"
```

## プロジェクトごとの設定
ここからは各プロジェクトのディレクトリー単位で行う設定の手順です。複数のリポジトリーを扱う場合、それぞれのディレクトリーに対して同様の操作を行います。

### ディレクトリーの準備
1. 任意の場所にプロジェクト用のディレクトリーを作成します
2. シェルのカレントディレクトリーを、今作成したプロジェクト用ディレクトリーに移動します

### 変数の準備
さきほどと同様に、以下の変数を設定しておくと便利です。

```bash
github_short_username="abc" &&
github_mail="123456789+username@users.noreply.github.com" &&
github_username="${github_mail#*+}" &&
github_username="${github_username%@*}" &&
github_userid="${github_username} <${github_mail}>"
```

### 中身があるGitHubリポジトリーの場合
既存リポジトリーをクローンする例です。先頭3文字を使い、SSH設定ファイルで登録したホスト名を指定します。

```bash
git clone "git@github-${github_short_username}:<repository owner>/<repository name>".git .
```

### 空であるGitHubリポジトリーの場合
GitHub上に空のリポジトリーを作成してから、以下のコマンドで初期化とリモート登録を行います。

```bash
git init --initial-branch=main &&
git remote add origin "git@github-${github_short_username}:<repository owner>/<repository name>.git"
```

### メールアドレスなどの設定
コミットで正しいユーザー名・メールアドレス・署名キーを使用するために、以下の設定を行います。プロジェクト単位で設定することで、他のプロジェクトに影響を与えずに済みます。

```bash
git config user.name "${github_username}" &&
git config user.email "${github_mail}" &&
git config commit.gpgsign true &&
key_id="$(gpg --list-secret-keys --with-colons "${github_userid}" | awk -F: '$1 == "sec" { print $5 }')" &&
git config user.signingkey "${key_id}" &&
cat .git/config
```

### 【デバッグ】メールアドレスなどの設定の確認
```bash
cat .git/config
```

## まとめ
上記の流れで設定を行うことで、複数のGitHubアカウントを安全かつ混乱なく扱うことができます。
