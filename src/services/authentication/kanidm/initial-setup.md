# Kanidmの初期セットアップ
Kanidm Clientから操作する。

## adminアカウントで管理
### adminアカウントにログイン
```bash
kanidm login --name admin
```
必要に応じて`--debug`オプションを付ける。

adminユーザーはKanidmサーバー全体の管理者である。

### LDAPのDNを変更
SSHジャンプサーバーに使う分には不要。
```bash
kanidm system domain set-ldap-basedn --name admin dc=home,dc=arpa
```

### adminアカウントからログアウト
```bash
kanidm logout --name admin
```
