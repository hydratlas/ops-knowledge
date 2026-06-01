# backup_pull_sync

バックアップ集約・冗長化のパッシブ・プル同期（restic リポジトリのミラー）を行うロール

## 概要

### このドキュメントの目的

このロールは、ステートフルデータのバックアップ集約・冗長化基盤（インフラ層）のうち、パッシブ3台が VIP の NFS（アクティブ）から自ノードへ restic リポジトリ群をミラーする処理を担う。設計の詳細は実装計画書「ステートフルデータのバックアップ集約・冗長化設計（インフラ層）」を参照すること。

世代保持（`restic forget --prune`）はリポジトリを所有するアプリ側（`backup/restic_app_backup`）の責務であり、宛先4台は restic もリポジトリ・パスワードも持たない。宛先側は「暗号化済みリポジトリを置く NFS ＋ダムなミラー」に徹する。

`storage/rsync_install` が rsync パッケージの導入のみを担うのに対し、このロールはその上に定期実行（systemd timer + `Type=oneshot` service）のミラー処理を載せる。

### 実現される機能

- 自ノードが VIP を保持するか（= アクティブか）を、`eth0` への VIP 付与の有無だけで判定する。keepalived の状態ファイルや notify スクリプトに依存せず、フェイルオーバーに自動追従する。
- パッシブ（VIP なし）のときのみ、read-only でマウントした VIP の NFS からローカルの集約先へ restic リポジトリを `rsync -a --delete` でミラーする。restic リポジトリは内容アドレス方式で重複排除された append 構造であり、`--delete` を付けた素のミラーで安全に冗長化できる。アクティブ側で prune された pack をパッシブも追従削除するため、重複排除の効果がパッシブ側でも維持される。転送中の一時ロック（`locks/`）は持ち込まない。
- `flock` で多重起動を防止する。プル失敗（VIP / NFS 到達不能）は journal に記録され、次サイクルで再試行する。

## 要件と前提条件

- rsync が導入済みであること（`storage/rsync_install` を事前に適用）。
- VIP の NFS が read-only でマウントされていること（`storage/unified_mounts` で `backup_pull_sync_source_dir` にマウント）。
- keepalived により VIP が構成されていること（`network/keepalived`）。
- プレイブックレベルで `become: true` の指定が必要。

## 設定方法

### ロール変数

| 変数名 | 説明 | デフォルト値 |
| --- | --- | --- |
| `backup_pull_sync_vip_address` | アクティブ判定に用いる VIP（CIDR なし） | `10.120.60.54` |
| `backup_pull_sync_interface` | VIP 付与有無を確認するインターフェース | `eth0` |
| `backup_pull_sync_source_dir` | プル元（VIP の NFS のマウント先） | `/mnt/backup-src` |
| `backup_pull_sync_local_dir` | ローカルの集約先 | `/srv/backups` |
| `backup_pull_sync_pull_timeout` | プル service の実行時間上限（秒） | `1800` |

本プロジェクトでは `group_vars/backup_nfs.yml` で実値を与え、`backup_nfs` グループに適用する。

### 配置されるファイル

- `/usr/local/sbin/backup-pull.sh` … ミラー本体。
- `/etc/systemd/system/backup-pull.{service,timer}` … 毎時（`OnCalendar=hourly` ＋ `RandomizedDelaySec=300`）にミラーを起動。

### 手動設定の手順

1. 上記スクリプトを配置し、実行権限（`0755`）を付与する。VIP 判定は `ip -brief address show dev <iface>` に VIP が含まれるかで行う。
2. 上記2つの systemd ユニットを配置する。
3. `systemctl daemon-reload` を実行する。
4. `systemctl enable --now backup-pull.timer` でタイマーを有効化・起動する。

## 運用上の注意

- パッシブのミラーは `rsync -a --delete` であり、アクティブのリポジトリ状態をそのまま複製する。世代保持の権威はリポジトリを所有するアプリ側（`restic forget --prune`）に一元化されており、このロールは保持・刈り取りを一切判断しない。
- prune とミラーが同時刻に走るとロックの競合窓が生じ得るが、設計は低頻度・結果整合を許容しており、次サイクルのミラーで修復される。
