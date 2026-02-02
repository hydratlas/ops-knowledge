# Kanidm Clientのセットアップ
## 前提
step-cli（クライアント）をインストールしてプライベート認証局のルート証明書を取得しておく必要がある。

## リポジトリーの設定（Debian系）
```bash
wget -q -O - "https://kanidm.github.io/kanidm_ppa/kanidm_ppa.asc" | \
  sudo tee /etc/apt/keyrings/kanidm_ppa.asc > /dev/null &&
sudo tee "/etc/apt/sources.list.d/kanidm_ppa.sources" > /dev/null << EOF
Types: deb
URIs: https://kanidm.github.io/kanidm_ppa
Suites: $(grep -oP '(?<=^VERSION_CODENAME=).+(?=$)' /etc/os-release)
Components: stable
Signed-By: /etc/apt/keyrings/kanidm_ppa.asc
Architectures: $(dpkg --print-architecture)
EOF
```

## パッケージをインストール・設定（Debian系）
```bash
sudo apt-get install -U -y kanidm &&
sudo mkdir -p "/etc/kanidm" &&
sudo tee "/etc/kanidm/config" > /dev/null << EOF
uri = "https://idm-01.int.home.arpa:8443"
ca_path = "/usr/local/share/ca-certificates/private-ca.crt"
#verify_hostnames = false
#verify_ca = false
EOF
```

## HTTPS接続の確認
```bash
wget --debug -O - https://idm-01.int.home.arpa:8443
```

## テスト実行
```bash
kanidm logout --name admin
```
