# Dockgeのインストール・実行

Dockgeは、Docker Composeファイルを管理するためのWebベースのGUIツールです。複数のComposeプロジェクトを視覚的に管理でき、YAMLファイルの編集から実行まで、ブラウザ上で完結できます。

## インストール
```bash
sudo mkdir -p /opt/stacks /opt/dockge &&
sudo wget -O /opt/dockge/compose.yaml https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml
```

## 実行（root限定）
```bash
cd /opt/dockge
if type docker-compose >/dev/null 2>&1; then
  sudo docker-compose up -d
else
  sudo docker compose up -d
fi
```
ポート5001にアクセスするとウェブユーザーインターフェースが表示される。
