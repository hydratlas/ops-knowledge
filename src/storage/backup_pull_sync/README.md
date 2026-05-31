# backup_pull_sync

バックアップ集約・冗長化のパッシブ・プル同期と世代刈りを行うロール

## 概要

### このドキュメントの目的

このロールは、ステートフルデータのバックアップ集約・冗長化基盤（インフラ層）のうち、パッシブ3台が VIP の NFS（アクティブ）から自ノードへ世代をプルする処理と、各ノードが独立に古い世代を刈る処理を担う。設計の詳細は実装計画書「ステートフルデータのバックアップ集約・冗長化設計（インフラ層）」を参照すること。

`storage/rsync_install` が rsync パッケージの導入のみを担うのに対し、このロールはその上に定期実行（systemd timer + `Type=oneshot` service）のプル処理・刈り取り処理を載せる。

### 実現される機能

- 自ノードが VIP を保持するか（= アクティブか）を、`eth0` への VIP 付与の有無だけで判定する。keepalived の状態ファイルや notify スクリプトに依存せず、フェイルオーバーに自動追従する。
- パッシブ（VIP なし）のときのみ、read-only でマウントした VIP の NFS からローカルの集約先へ rsync でプルする。`--update` を付けタイムスタンプの巻き戻しを防ぎ、`--delete` は付けず世代の巻き添え削除を防ぐ。書き込み途中の `.tmp-*` は除外する。
- VIP 保持状態に応じた保持世代数（アクティブは短く、パッシブは長く）で、各アプリ・ディレクトリーの古い世代を刈る。
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
| `backup_pull_sync_retain_active` | アクティブ時の保持世代数 | `3` |
| `backup_pull_sync_retain_passive` | パッシブ時の保持世代数 | `5` |
| `backup_pull_sync_pull_timeout` | プル service の実行時間上限（秒） | `1800` |

本プロジェクトでは `group_vars/backup_nfs.yml` で実値を与え、`backup_nfs` グループに適用する。

### 配置されるファイル

- `/usr/local/sbin/backup-pull.sh` … プル本体。
- `/usr/local/sbin/backup-prune.sh` … 世代刈り本体。
- `/etc/systemd/system/backup-pull.{service,timer}` … 毎時（`OnCalendar=hourly` ＋ `RandomizedDelaySec=300`）にプルを起動。
- `/etc/systemd/system/backup-prune.{service,timer}` … 日次（`OnCalendar=daily`）に世代刈りを起動。

### 手動設定の手順

1. 上記2つのスクリプトを配置し、実行権限（`0755`）を付与する。VIP 判定は `ip -brief address show dev <iface>` に VIP が含まれるかで行う。
2. 上記4つの systemd ユニットを配置する。
3. `systemctl daemon-reload` を実行する。
4. `systemctl enable --now backup-pull.timer backup-prune.timer` でタイマーを有効化・起動する。

## 運用上の注意

- 世代名はソート可能なタイムスタンプであることを前提に、降順で新しい世代を残す。アプリ側の整合済みアーティファクトは `<集約先>/<app>/<timestamp>/` の構造で配置すること。
- 保持期間はアクティブを短く・パッシブを長くする。プルが `--delete` を持たないため、ある世代はまずアクティブから消え、その後パッシブから消える順序を保つ必要がある。アクティブをパッシブより長くすると刈り取りが無効化されるため、逆転させてはならない。
