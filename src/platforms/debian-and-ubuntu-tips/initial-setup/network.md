# ネットワーク周り（すべて管理者）
## mDNSのインストール
LAN内にDNSサーバーがない場合、mDNSをインストールすると「ホスト名.local」でSSH接続できるようになる。mDNSがインストールされていない場合は以下でインストールできる。
```bash
sudo apt-get install --no-install-recommends -y avahi-daemon
```

## systemd-timesyncdによるNTP (Network Time Protocol)の設定
### 状況確認
```bash
systemctl status systemd-timesyncd.service
```

### NTPサーバーを最適化
```bash
sudo perl -pi -e 's/^NTP=.+$/NTP=time.cloudflare.com ntp.jst.mfeed.ad.jp time.windows.com/g' '/etc/systemd/timesyncd.conf'
```

### systemd-timesyncdの無効化
仮想マシンのゲストの場合は、ホストで時計合わせをするため無効にする。
```bash
sudo systemctl disable --now systemd-timesyncd.service
```

## NetworkManagerをコマンドで変更
### 現在のコネクションを確認
```bash
nmcli connection show
```

### 現在のIPアドレス設定を確認
```bash
nmcli connection show "Wired connection 1"
```

### IPアドレスを変更
```bash
sudo nmcli connection modify "Wired connection 1" ipv4.addresses "xxx.xxx.xxx.xxx/24, xxx.xxx.xxx.xxx/24"
```

### 再起動
```bash
sudo reboot
```
