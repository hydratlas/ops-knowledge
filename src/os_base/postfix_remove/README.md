# postfix_remove

postfixパッケージを除去するロールである。

## 概要

このインフラではメール送信を一切使用しておらず、postfixは不要である。

postfixはOSテンプレート作成時にデフォルトでインストールされたものであり、Ansibleで明示的に管理されていない。`inet_interfaces = loopback-only`のローカル配信専用構成だが、メールクライアント（`bsd-mailx`、`mailutils`等）もインストールされておらず、メールキューやメールスプールも空であるため、実質的に何も機能していない。

## 修正内容

1. **postfixサービスの停止と無効化**: systemd環境では`postfix.service`を、OpenRC環境（Alpine Linux）では`rc-service`/`rc-update`を使用してサービスを停止・無効化する
2. **postfixパッケージの除去**: `postfix`パッケージを除去する（Debian系・RHEL系・Alpine Linuxに対応）

postfixがインストールされていない場合は何も行わない。

## 手動での適用手順

### systemd環境（Debian系・RHEL系）

1. `systemctl stop postfix`でpostfixサービスを停止する
2. `systemctl disable postfix`で自動起動を無効にする
3. Debian系は`apt purge postfix`、RHEL系は`dnf remove postfix`でパッケージを除去する

### OpenRC環境（Alpine Linux）

1. `rc-service postfix stop`でpostfixサービスを停止する
2. `rc-update del postfix`で自動起動を無効にする
3. `apk del postfix`でパッケージを除去する

## 注意事項

postfix除去後は`/usr/sbin/sendmail`が利用できなくなる。このインフラではsendmailを呼び出すパッケージやスクリプトが存在しないため、影響はない。
