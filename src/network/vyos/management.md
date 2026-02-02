# VyOSの管理・運用
## 通信を確認
```bash
ping google.com
```

## インターフェースのオフ、オン
```bash
IF_NAME=eth0 &&
/bin/vbash << EOS
source /opt/vyatta/etc/functions/script-template
configure
set interfaces ethernet ${IF_NAME} disable
commit
save
delete interfaces ethernet ${IF_NAME} disable
commit && save && exit
EOS
```

## 現在の設定を確認
```bash
show configuration | cat

show configuration commands | cat
```

## ログを表示
```bash
monitor log
show log tail
```

## DHCPサーバーに関して、リース情報を表示
```bash
show dhcp server leases | cat
```

## DHCPサーバーに関して、リース情報を削除
```bash
show dhcp server leases | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | while read -r ip; do
    clear dhcp-server lease "$ip"
done
```

## DHCPサーバーに関して、特定のホストのリース情報を削除
```bash
hostname="aaa" &&
show dhcp server leases | awk '$10 == '"\"${hostname}\""' {print $1}' | while read -r ip; do
    clear dhcp-server lease "$ip"
done
```

## 初期化
```bash
/bin/vbash << EOS
source /opt/vyatta/etc/functions/script-template
configure
load /opt/vyatta/etc/config.boot.default
commit && save && exit
EOS
```

## 応用的な設定

### Lokiにログを送信
```bash
/bin/vbash << EOS
source /opt/vyatta/etc/functions/script-template
configure
set service monitoring telegraf loki url http://<hostname>
set service monitoring telegraf loki metric-name-label metric
commit && save && exit
EOS
```
`metric-name-label`の値にハイフン(-)は使えない。

Telegrafに渡っている設定は`/run/telegraf/telegraf.conf`から確認できる。

### Node Exporter
```bash
add container image quay.io/prometheus/node-exporter:latest &&
/bin/vbash << EOS
source /opt/vyatta/etc/functions/script-template
configure
set container name node-exporter allow-host-networks
set container name node-exporter description 'Node Exporter'
set container name node-exporter image 'quay.io/prometheus/node-exporter:latest'
set container name node-exporter port node-exporter destination '9100'
set container name node-exporter port node-exporter source '9100'
set container name node-exporter port node-exporter protocol 'tcp'
set container name node-exporter volume hostroot destination '/host'
set container name node-exporter volume hostroot source '/'
set container name node-exporter volume hostroot mode ro
commit && save && exit
EOS
```
`http://<hostname>:9100/metrics`にアクセスして動作を確認できる。再起動するときは`restart container node-exporter`コマンドで再起動させる。
