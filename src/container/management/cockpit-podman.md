# Cockpit-Podmanのインストール・実行

Cockpit-PodmanはCockpitのプラグインで、Podmanコンテナの管理機能をWeb UIで提供します。システム管理用のCockpitインターフェースから直接コンテナを操作でき、GUIでの管理が可能になります。

Podmanのみに対応。サーバー全体をウェブインターフェースで管理するCockpitの本体が入っていることを前提として、プラグインをインストールする。

### 通常版をインストールする場合
```bash
sudo apt-get install --no-install-recommends -y cockpit-podman
```

### バックポート版をインストールする場合
通常版よりバージョンが新しい。
```bash
sudo apt-get install --no-install-recommends -y \
  -t "$(lsb_release --short --codename)-backports" cockpit-podman
```
