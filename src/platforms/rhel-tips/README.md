# Red Hat Enterprise Linux系ディストリビューションのtips

RHEL系ディストリビューション（Red Hat、CentOS、Rocky Linux等）での運用に役立つ設定やカスタマイズ方法をまとめたドキュメントです。

## Cloud-init有効時にDHCPからDNSサーバーを設定する
AlmaLinuxのクラウドイメージにはCloud-initが入っている。そのためNetworkManagerに対して`99-cloud-init.conf`によって`dns = none`が設定され、`/etc/resolv.conf`がNetworkManagerで管理されなくなる。これにはDHCPでDNSサーバーを取得している場合に、それが反映されなくなるという問題がある。そこで、`99-cloud-init.conf`より後の名前になる`99-z-dns-default.conf`を追加して、`dns = default`に戻す。
```bash
sudo install \
  -m 644 -o "root" -g "root" \
  /dev/stdin "/etc/NetworkManager/conf.d/99-z-dns-default.conf" << EOS > /dev/null &&
[main]
dns = default
EOS
sudo systemctl restart NetworkManager.service
```

## nanoのインストール
```bash
sudo dnf install -y nano
```

## SELinuxの無効化
```bash
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config &&
sudo reboot
```

## SELinuxの有効化
```bash
sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config &&
sudo reboot
```
