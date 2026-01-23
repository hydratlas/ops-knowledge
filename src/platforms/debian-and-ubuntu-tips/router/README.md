# ルーターとして設定する
- Ubuntu Server 24.04を使って、SNAT、DNSキャッシュサーバーおよびDHCPサーバーができるルーターを設定する
  - DNSキャッシュサーバーおよびDHCPサーバーはオンで、SNATはオフのネットワークセグメントも対応可能
- そのように設定するルーターを2台用意して、VRRP（Virtual Router Redundancy Protocol）によって冗長性を確保する
- NAT64対応
  - IPv4アドレスをIPv6アドレスに変換する方法: `IFS='.' read -r -a octets <<< "192.0.20.1" && ipv4_hex=$(printf "%02x%02x%02x%02x" "${octets[0]}" "${octets[1]}" "${octets[2]}" "${octets[3]}") && echo "64:ff9b::$(echo $ipv4_hex | sed 's/\(..\)\(..\)\(..\)\(..\)/\1\2:\3\4/')"`

## 変数の準備
この例は次のような構成を想定している
- SNATをする内側のネットワークは2個（`eth1`および`eth2`）
  - 1以上の任意の個数を指定可能
- VRRPによる仮想IPアドレス: `192.168.2.1`および`192.168.3.1`
- ホスト名`router1`のIPアドレス: `192.168.2.2`および`192.168.3.2`
- ホスト名`router2`のIPアドレス: `192.168.2.3`および`192.168.3.3`
- DHCPによるIPアドレスの最大配布数は`192.168.n.17`から`254`までを2分割しているため、119個
  - 変更可能
- `dhcp_hosts`で固定的にDHCPアドレスを配布可能
  - MACアドレスだけではなくクライアントIDも指定可能（ただしテストでは機能していない）
    - クライアントIDの取得方法: `sudo netplan ip leases eth0 | grep -oP '^CLIENTID=\K.*' | sed 's/\(..\)/\1:/g' | sed 's/:$//'`
- `virtual_router_id`は`1`としているが、`0`から`255`までの範囲で同じネットワークの別のVRRPと重ならない値にする

```bash
sudo apt-get install -y jq &&
JSON='{
  "router_host": ["router1", "router2"],
  "outside": {
    "interface": ["eth0", "eth0"]
  },
  "vrrp": {
    "state": ["MASTER", "BACKUP"],
    "priority": ["100", "90"],
    "advert_int": "1"
  },
  "ntp": {
    "ip_address": ["162.159.200.1", "210.173.160.87"]
  },
  "inside": [
    {
      "interface": ["eth1", "eth1"],
      "mac_address": ["XX:XX:XX:XX:XX:XX", "XX:XX:XX:XX:XX:XX"],
      "ip_address": ["192.168.2.2", "192.168.2.3"],
      "virtual_ip_address": "192.168.2.1",
      "cidr": "24",
      "forwarding": {
        "is_enabled": true
      },
      "dhcp_range": [["192.168.2.17", "192.168.2.135"], ["192.168.2.136", "192.168.2.254"]],
      "virtual_router_id": "1"
    },
    {
      "interface": ["eth2", "eth2"],
      "mac_address": ["XX:XX:XX:XX:XX:XX", "XX:XX:XX:XX:XX:XX"],
      "ip_address": ["192.168.3.2", "192.168.3.3"],
      "virtual_ip_address": "192.168.3.1",
      "cidr": "24",
      "forwarding": {
        "is_enabled": true
      },
      "dhcp_range": [["192.168.3.17", "192.168.3.135"], ["192.168.3.136", "192.168.3.254"]],
      "virtual_router_id": "1", 
      "dhcp_hosts": [
        {
          "hostname": "client1",
          "ip_address": "192.168.3.10",
          "mac_address": "XX:XX:XX:XX:XX:XX"
        },
        {
          "hostname": "client2",
          "ip_address": "192.168.3.11",
          "id": "xxxxxxxxxxxxxxxxxxxxxxxxxx"
        }
      ]
    }
  ]
}' &&
echo "${JSON}" | jq -c "."
```

## 関数の準備
- setup_netplan
- setup_keepalived
- setup_nftables
- setup_dnsmasq
```bash
eval "$(wget --no-cache -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/router")"
```

## ネットワーク設定（Netplan）
```bash
setup_netplan "${JSON}"
```
やりなおすときは、そのままやりなおして構わない。

## VRRP（Virtual Router Redundancy Protocol）
### 設定
```bash
setup_keepalived "${JSON}"
```
やりなおすときは、そのままやりなおして構わない。

Dnsmasqで`bind-dynamic`を指定しない場合には、フェイルオーバー時に（IPアドレス変更時に）Dnsmasqが機能しないので、フェイルオーバー時にDnsmasqを再起動させるようにする。この再起動のスクリプトではroot権限が必要なため、このスクリプトを使う際には`script_user`は`root`に設定する必要がある。

### テスト
Dnsmasqが動いているかどうかでフェイルオーバーを行うため、Dnsmasqをインストールした後に行う。
```bash
sudo systemctl stop dnsmasq.service
sudo systemctl start dnsmasq.service
```

## IPマスカレードおよびファイアウォール設定（nftables）
### 設定
```bash
setup_nftables "${JSON}"
```
やりなおすときは、そのままやりなおして構わない。

### 現在の永続的な設定の確認
```bash
cat /etc/nftables.conf
```

### IPマスカレードのログ確認
```bash
journalctl --dmesg --no-pager -n 1000 | grep "nft masquerade:"
```

## DNSキャッシュサーバーおよびDHCPサーバー
### 設定
```bash
setup_dnsmasq "${JSON}"
```
やりなおすときは、そのままやりなおして構わない。

### DHCPクライアントからの要求の確認
```bash
sudo journalctl -u dnsmasq | grep "DHCPDISCOVER"
```

### 確認（クライアント側）
```bash
ip a
ip r
sudo netplan ip leases eth0
cat /run/systemd/resolve/resolv.conf
dig "@$(resolvectl status | grep 'DNS Servers' | head -n 1 | awk '{print $3}')" google.com
watch dig "@$(resolvectl status | grep 'DNS Servers' | head -n 1 | awk '{print $3}')" google.com
```
`watch `を前に付けると1秒間隔で自動的に取得できる。