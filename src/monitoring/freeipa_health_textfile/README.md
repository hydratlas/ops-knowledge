# freeipa_health_textfile

FreeIPA のヘルス状態を Prometheus textfile collector 形式で出力するロール

## 概要

### このドキュメントの目的

FreeIPA サーバー（idm-01〜04）のヘルス状態を、外部 exporter を追加せず node_exporter の textfile collector 機構に載せてメトリクス化することを目的とする。とくに `ipactl status` で検知できるコアサービスの停止と、CA REST（pki-tomcatd）の undeploy 型障害（プロセスは active だが Web アプリが死亡し getStatus が 200 を返さない状態）を1メトリクスで区別できるようにする。Ansible による自動設定と、それと等価な手動手順の両方を記載する。

### 実現される機能

- ヘルス出力スクリプトを systemd timer から root 権限で定期実行する
- 次のメトリクスを `.prom` ファイルへアトミックに書き込む
  - `freeipa_ipactl_status{service="<name>"}`: `ipactl status` の各サービスを RUNNING なら 1、それ以外 0
  - `freeipa_ca_getstatus_code`: CA REST `getStatus` の HTTP ステータスコード（200=正常 / 4xx・5xx=undeploy 型障害 / 0=停止・到達不可）
  - `freeipa_health_export_timestamp_seconds`: 最終出力時刻（Unix 秒）
- `.prom` は一時ファイルへ書いてから `rename` することで、node_exporter による読み取り中の破損を避ける

本ロールはメトリクスの出力（ソース）のみを担う。出力先の textfile collector の有効化は `monitoring/node_exporter_binary` ロール（`node_exporter_textfile_directory` 変数）が担当し、収集は metrics-01〜04 の vmagent、可視化は Grafana が担う。

## 要件と前提条件

### 共通要件

- **対象システム**: FreeIPA/IdM サーバー（AlmaLinux）
- **権限**: root（`ipactl` の実行および `/etc/ipa/ca.crt` の読み取りに必要）
- **前提条件**:
  - `monitoring/node_exporter_binary` が適用済みで `node_exporter_textfile_directory` が有効であること（node_exporter 実行ユーザー・グループおよび出力ディレクトリーが存在すること）
  - `metrics` セグメントからの `9100/tcp` が firewalld で開放されていること（`node_exporter_binary` の `node_exporter_firewalld_sources` で設定）

### Ansible 固有の要件

- **Ansible バージョン**: 2.14 以上
- **コレクション**: なし（`ansible.builtin` のみ）

### 手動設定の要件

- 対象ホスト上で `bash`・`curl`・`ipactl`・`systemctl` が利用可能であること

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名                            | 説明                                                       | デフォルト値                                            |
| --------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------- |
| `freeipa_health_textfile_directory` | `.prom` の出力先（node_exporter の textfile ディレクトリーと一致させる） | `/var/lib/node_exporter/textfile_collector`             |
| `freeipa_health_prom_filename`    | 出力する `.prom` ファイル名                                | `freeipa_health.prom`                                   |
| `freeipa_health_file_owner`       | `.prom` の所有者                                           | `node_exporter`                                         |
| `freeipa_health_file_group`       | `.prom` の所有グループ                                     | `node_exporter`                                         |
| `freeipa_health_script_path`      | ヘルス出力スクリプトの配置先                               | `/usr/local/bin/freeipa-health-export.sh`              |
| `freeipa_health_ca_getstatus_url` | CA REST getStatus エンドポイント（FQDN。証明書 SAN と一致させる） | `https://{{ inventory_hostname }}:8443/ca/admin/ca/getStatus` |
| `freeipa_health_ca_cacert`        | CA 証明書（自己署名の検証用）                             | `/etc/ipa/ca.crt`                                       |
| `freeipa_health_curl_timeout`     | curl のタイムアウト（秒）                                  | `10`                                                    |
| `freeipa_health_interval`         | timer の実行間隔（`OnUnitActiveSec`）                     | `2min`                                                  |
| `freeipa_health_initial_delay`    | 起動後の初回実行までの遅延（`OnBootSec`）                | `1min`                                                  |
| `freeipa_health_service_name`     | systemd ユニットのベース名                                 | `freeipa-health-export`                                 |

#### 依存関係

`monitoring/node_exporter_binary`（同一 play で先に適用すること）

#### タグとハンドラー

タグは定義していない（呼び出し側の play で付与する）。ハンドラーは `reload systemd daemon`（systemd 再読み込み）と `run freeipa health export`（oneshot サービスの即時実行）の2つ。

#### 使用例

```yaml
- hosts: ipaservers
  become: true
  gather_facts: false
  roles:
    - role: monitoring/node_exporter_binary
    - role: monitoring/freeipa_health_textfile
```

`node_exporter_textfile_directory` および firewalld 開放元は `group_vars/ipaservers.yml` で与える。

### 方法2: 手動

1. `/usr/local/bin/freeipa-health-export.sh` にヘルス出力スクリプトを配置する（root:root, 0755）。スクリプトは `ipactl status` の各サービス状態と CA REST `getStatus` の HTTP コードを `.prom` 形式で一時ファイルへ書き出し、`mv` で `/var/lib/node_exporter/textfile_collector/freeipa_health.prom`（所有者 `node_exporter`）へアトミックに配置する
2. `/etc/systemd/system/freeipa-health-export.service`（`Type=oneshot`）と `freeipa-health-export.timer`（`OnUnitActiveSec=2min`）を作成する
3. `systemctl daemon-reload` 後に `systemctl enable --now freeipa-health-export.timer` で有効化する
4. `curl -s localhost:9100/metrics | grep freeipa_` で `freeipa_ipactl_status` / `freeipa_ca_getstatus_code` が見えることを確認する

## 注意点

- **FreeIPA への侵襲**: スクリプトは `ipactl status` と CA REST を呼ぶため、`freeipa_health_interval` を保守的に保つ（既定 2 分）。
- **SELinux**: AlmaLinux で SELinux が enforcing の場合、node_exporter による textfile ディレクトリー読み取りや 9100 listen が阻害されないか確認する。
- **受動的可視化**: 本構成は通知を行わない。ダッシュボードの定例確認で人が見る運用を併設すること。
