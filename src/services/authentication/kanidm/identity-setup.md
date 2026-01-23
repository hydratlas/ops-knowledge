# Kanidmのアイデンティティをセットアップ

Kanidm Clientから操作する。

## idm_adminアカウントにログイン

```bash
kanidm login --name idm_admin
```

idm_adminユーザーはID管理の管理者である。

## 「kishida230」ユーザーを作る

### ユーザーの作成

```bash
kanidm person create --name idm_admin kishida230 "F. Kishida"
```

### パスワード以外の設定

```bash
kanidm person update --name idm_admin kishida230 --legalname "Fumio Kishida" &&
kanidm person update --name idm_admin kishida230 --mail "kishida230@example.com" --mail "kishida230_2@example.com" &&
kanidm person posix set --name idm_admin kishida230 --shell /bin/bash &&
kanidm person posix set --name idm_admin kishida230 --gidnumber 2001 &&
kanidm person ssh add-publickey --name idm_admin kishida230 tag1 "ssh-ed25519 ...."
```

### パスワードの設定

SSHジャンプサーバーに使う分には不要。

まず、Google Authenticator（Google認証システム）などのOTPアプリをスマホに入れておく。

```bash
kanidm person credential update --name idm_admin kishida230
```

対話的に設定する。

- cred update (? for help) # : pw
- New password: パスワードを入力
- Confirm password: パスワードを入力
- cred update (? for help) # : totp
- TOTP Label: main
- QRコードが表示されるので、OTPアプリで読み込む。そうすると6桁の認証コードが表示される
- TOTP: 6桁の認証コードを入力
- cred update (? for help) # : commit
- Do you want to commit your changes? [y/n]: y

### posixパスワードの設定

```bash
kanidm person posix set-password --name idm_admin kishida230
```

対話的に設定する。

- New password: パスワードを入力
- Confirm password: パスワードを入力

### ユーザーの確認

```bash
kanidm person get --name idm_admin kishida230
```

### 全ユーザーの確認

```bash
kanidm person list --name idm_admin
```

### posix extensionsの確認

```bash
kanidm person posix show --name idm_admin kishida230
```

### ユーザーの変更

#### 名前の変更

```bash
kanidm person update --name idm_admin kishida230 --newname kishida230_2
```

#### 表示名の変更

```bash
kanidm person update --name idm_admin kishida230 --displayname "Fumio K."
```

### ユーザーの削除

```bash
kanidm person delete --name idm_admin kishida230
```

## 「ssh-jump」グループを作る

### グループの作成

```bash
kanidm group create --name idm_admin ssh-jump &&
kanidm group posix set --name idm_admin ssh-jump --gidnumber 2003
```

### グループの確認

```bash
kanidm group get --name idm_admin ssh-jump
```

### 全グループの確認

```bash
kanidm group list --name idm_admin
```

### グループのメンバーにユーザーを追加

```bash
kanidm group add-members --name idm_admin ssh-jump kishida230
```

### グループのメンバーとなっているユーザーを表示

```bash
kanidm group list-members --name idm_admin ssh-jump
```

### グループのメンバーからユーザーを削除

```bash
kanidm group remove-members --name idm_admin ssh-jump kishida230
```

### グループの名前の変更

```bash
kanidm group rename --name idm_admin ssh-jump ssh-jump2
```

### グループの削除

```bash
kanidm group delete --name idm_admin ssh-jump
```

## idm_adminアカウントからログアウト

```bash
kanidm logout --name idm_admin
```

## 【不要】「ssh-jump-service」サービスアカウントの作成

### サービスアカウントの作成

```bash
kanidm service-account create --name idm_admin ssh-jump-service "SSH jump Service" idm_admins
```

### トークンの生成

```bash
kanidm service-account api-token generate ssh-jump-service "SSH jump Token" --name idm_admin
```

### トークンの状態の確認

```bash
kanidm service-account api-token status --name idm_admin ssh-jump-service
```

### サービスアカウントの削除

```bash
kanidm service-account delete --name idm_admin ssh-jump-service
```
