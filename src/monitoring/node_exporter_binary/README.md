# node_exporter_binary

Prometheus Node ExporterをGitHub Releasesからダウンロードしてインストール・管理するロールである。

## 概要

Node Exporterはホストマシンのハードウェアおよびオペレーティングシステムのメトリクスを収集し、HTTPエンドポイント経由で公開するエクスポーターである。本ロールはGitHub Releasesからバイナリーをダウンロードし、systemdでサービスとして管理する。aptパッケージに依存しないため、任意のバージョンを使用できる。

## 主要な変数

| 変数名                              | デフォルト値    | 説明                                   |
| ----------------------------------- | --------------- | -------------------------------------- |
| `node_exporter_version`             | `1.10.2`        | Node Exporterのバージョン              |
| `node_exporter_arch`                | `amd64`         | ターゲットアーキテクチャー             |
| `node_exporter_listen_address`      | `:9100`         | HTTPリッスンアドレス                   |
| `node_exporter_textfile_directory`  | 未定義          | textfileコレクターのディレクトリーパス |
| `node_exporter_extra_flags`         | `[]`            | 追加のCLIフラグ                        |
| `node_exporter_user`                | `node_exporter` | サービス実行ユーザー                   |
| `node_exporter_group`               | `node_exporter` | サービス実行グループ                   |
| `node_exporter_legacy_files`        | `[]`            | 移行後に削除するファイルパスのリスト   |
| `node_exporter_legacy_services`     | `[]`            | 移行後に停止・無効化・削除するサービス名のリスト |

## 使用例

### 方法1: Ansible

特別な変数の設定なしでそのまま使用できる。textfileコレクターを有効にしたい場合は`node_exporter_textfile_directory`を設定する。ディレクトリーは自動的に作成される。

```yaml
node_exporter_textfile_directory: "/var/lib/node_exporter/textfile_collector"
```

追加のコレクターを有効にしたい場合は`node_exporter_extra_flags`を設定する。

```yaml
node_exporter_extra_flags:
  - "--collector.systemd"
  - "--collector.processes"
```

### レガシー環境からの移行

以前の構成からこのロールに移行する場合、旧構成のファイルが残存することがある。`node_exporter_legacy_files`と`node_exporter_legacy_services`を設定することで、ロール適用時に自動的にクリーンアップされる。

```yaml
# 旧バイナリーと旧設定ファイルの削除
node_exporter_legacy_files:
  - "/usr/sbin/node_exporter"
  - "/etc/sysconfig/node_exporter"

# 旧サービスの停止・無効化・削除
node_exporter_legacy_services:
  - "prometheus-node-exporter-collectors.service"
```

### 方法2: 手動

1. GitHub Releasesから`node_exporter-{version}.linux-amd64.tar.gz`をダウンロードし、展開したバイナリーを`/usr/local/bin/node_exporter`に配置する
2. `node_exporter`システムユーザーおよびグループを作成する
3. systemdサービスファイルを`/etc/systemd/system/node_exporter.service`に作成し、`systemctl enable --now node_exporter`で起動する
