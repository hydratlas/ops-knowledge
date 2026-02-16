# Cockpitをインストール（すべて管理者）
Red Hatが主に開発している、Linuxサーバーを管理および監視することができるWebコンソール。

## Cockpitをインストール
cockpit-pcpはメトリクスを収集・分析してくれるが、負荷がかかるので不要ならインストールしない。

### 通常版
```bash
sudo apt-get install --no-install-recommends -y \
  cockpit cockpit-ws cockpit-system cockpit-storaged cockpit-packagekit \
  cockpit-pcp
```

### バックポート版（新しい）
```bash
sudo apt-get install --no-install-recommends -y -t "$(lsb_release --short --codename)-backports" \
  cockpit cockpit-ws cockpit-system cockpit-storaged cockpit-packagekit \
  cockpit-pcp
```

## CockpitとNetworkManagerを連携させる
### 通常版
```bash
sudo apt-get install --no-install-recommends -y cockpit-networkmanager
```

### バックポート版（新しい）
```bash
sudo apt-get install --no-install-recommends -y \
  -t "$(lsb_release --short --codename)-backports" cockpit-networkmanager
```

## Cockpitを起動
```bash
sudo systemctl enable --now cockpit.socket

# http://xxx.local:9090
```
