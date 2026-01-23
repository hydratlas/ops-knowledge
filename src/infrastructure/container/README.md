# container

コンテナ関連のAnsibleロール群。DockerとPodmanの両方に対応し、コンテナ環境の構築と管理を行います。

## 概要

このディレクトリには、コンテナ環境構築に関する以下のロールが含まれています：

### 基本ロール
- **podman** - Podmanのインストールと基本設定
- **podman_docker** - Docker互換コマンドの設定
- **podman_auto_update** - コンテナイメージの自動更新設定

### Rootlessコンテナ関連
- **podman_rootless_quadlet_base** - Rootless Podman Quadletの共通セットアップ
- **containers_user_storage_config** - Rootlessコンテナ用ストレージ設定
- **create_containers_storage_dir** - コンテナストレージディレクトリの作成

### ドキュメント
- **install-docker-rootless.md** - Docker Rootlessのインストール手順
- **install-docker.md** - Dockerのインストール手順
- **run.md** - コンテナ実行のヒント集
- **management/** - コンテナ管理ツールのドキュメント

## DockerとPodmanの比較

DockerとPodmanは互換性のあるコンテナエンジンですが、それぞれ異なる特徴があります：

### Podmanの利点
- **セキュリティ**: デフォルトでrootlessモードで動作し、より安全
- **systemd統合**: Quadletによるsystemdネイティブなサービス管理が可能
- **デーモンレス**: 常駐プロセスが不要でリソース効率的
- **Kubernetes互換**: Pod概念やYAML形式のサポート
- **複数フォーマット対応**: Docker、OCI、Singularityコンテナを実行可能
- **Docker Compose対応**: podman-composeで既存のcompose.ymlを利用可能

### Dockerの利点
- **エコシステム**: 最も広く使われており、ツールやドキュメントが豊富
- **Docker Compose**: 公式のcompose機能で複数コンテナを簡単管理
- **独自リポジトリ**: ディストリビューションに依存せず最新版を利用可能
- **Swarm Mode**: シンプルなクラスタ構築が可能
- **Docker Desktop**: GUI環境での開発が容易

### 推奨事項

本プロジェクトでは以下の理由によりPodmanを推奨しています：
- Rootlessモードによる高いセキュリティ
- systemdとの優れた統合性
- リソース効率の良さ
- エンタープライズ環境での実績

ただし、以下の場合はDockerの利用も検討してください：
- 既存のDocker Swarmクラスタがある場合
- Docker Desktop環境が必要な場合
- 特定のDockerのみ対応ツールを使用する場合

## メンテナンス

### 未使用オブジェクトの削除

#### Podmanの場合
```bash
# 停止コンテナ、未使用ネットワーク、未使用イメージを削除
podman system prune --all --force

# 未使用ボリュームを削除
podman volume prune --force
```

#### Dockerの場合
```bash
# 停止コンテナ、未使用ネットワーク、未使用イメージを削除
docker system prune --all --force

# 未使用ボリュームを削除
docker volume prune --force
```

## 参考資料

### ドキュメント
- [Podman Documentation](https://docs.podman.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Red Hat: Podman vs Docker](https://www.redhat.com/en/topics/containers/what-is-podman)

### コミュニティディスカッション
- [Why are you using podman instead of docker? : r/podman](https://www.reddit.com/r/podman/comments/1eu5d2k/why_are_you_using_podman_instead_of_docker/)
- [docker or k8s? : r/selfhosted](https://www.reddit.com/r/selfhosted/comments/1dowhi3/docker_or_k8s/)

### 書籍
- [Podmanイン・アクション](https://www.amazon.co.jp/dp/4798070203) - Podmanの実践的な使い方
- [systemdの思想と機能](https://www.amazon.co.jp/dp/429713893X) - Quadlet理解のための基礎知識
