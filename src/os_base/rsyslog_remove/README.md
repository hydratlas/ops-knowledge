# rsyslog_remove

rsyslogパッケージを除去するロールである。

## 概要

このインフラではログ収集をGrafana Alloyがsystemd journal（`loki.source.journal`）から直接行っており、rsyslogは不要である。

Proxmox VE 9のカーネル6.17では、AppArmorのプロファイルスタッキングにおけるクロスチェック機構のバグにより、LXCコンテナ内のrsyslogdが`/run/systemd/journal/dev-log`への`sendmsg`操作をDENIEDされる問題がある（LP #2123821、LP #2121552）。rsyslogを除去することで、AppArmorのクロスチェック自体が発生しなくなり、ホスト側dmesgへのauditログの大量出力も解消する。

## 修正内容

1. **rsyslogサービスの停止と無効化**: systemd環境では`rsyslog.service`を、OpenRC環境（Alpine Linux）では`rc-service`/`rc-update`を使用してサービスを停止・無効化する
2. **rsyslogパッケージの除去**: `rsyslog`パッケージを除去する（Debian系・RHEL系・Alpine Linuxに対応）

rsyslogがインストールされていない場合は何も行わない。

## 手動での適用手順

### systemd環境（Debian系・RHEL系）

1. `systemctl stop rsyslog`でrsyslogサービスを停止する
2. `systemctl disable rsyslog`で自動起動を無効にする
3. Debian系は`apt purge rsyslog`、RHEL系は`dnf remove rsyslog`でパッケージを除去する

### OpenRC環境（Alpine Linux）

1. `rc-service rsyslog stop`でrsyslogサービスを停止する
2. `rc-update del rsyslog`で自動起動を無効にする
3. `apk del rsyslog`でパッケージを除去する

## 注意事項

rsyslog除去後は`/var/log/syslog`が生成されなくなる。ログの確認には`journalctl`を使用する。
