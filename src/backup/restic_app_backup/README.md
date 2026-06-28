# restic_app_backup

ステートフルデータのバックアップにおける**アプリケーション層**（各アプリが整合点をローカルで取得し restic リポジトリへ投入し、世代を刈るまで）を担うロール

## 概要

### このドキュメントの目的

VictoriaMetrics・VictoriaLogs・MariaDB（Slurm アカウンティング）・FreeIPA といったステートフルなアプリのデータを、アプリごとの restic リポジトリへ日次で投入し世代管理する。整合点（consistency point）の取得はアプリ固有であり、各アプリの手段を `restic_app_backup_jobs` の `pre_command`／`post_command`／`source_path` として差し込む（長い手続きは `hooks` でスクリプト化してファイル化する）。集約・冗長化（宛先 NFS・パッシブミラー）はインフラ層（`storage/backup_pull_sync` 等）が別途担い、本ロールはそこへ手を入れない。Ansible による自動構成と、それと等価な手動手順の両方を記載する。

背景・設計判断の詳細は実装計画書 `docs/engineering-records/202606/20260601-1316-restic-application-layer-implementation-plan.md` を参照する。

### 責務分界

- 宛先4台（`backup-01`〜`04`）は restic を一切持たない「暗号化済みリポジトリを置く NFS ＋ダムなミラー」に徹する。
- `restic backup` も `restic forget --prune`（世代刈り）も、リポジトリを所有する**アプリ側**（＝本ロール）で実行する。
- アプリごとに1リポジトリ（`/mnt/backup-dst/<job>`）。各ノードは自分のリポジトリにしか書かないため、ノード間で restic ロックが競合しない。

### 実現される機能

- restic 公式静的バイナリ（`restic_<version>_linux_amd64.bz2`）を `SHA256SUMS` で検証して `/usr/local/bin/restic` へ配置（OS 非依存・冪等）
- 全リポジトリ共通の単一鍵（`vault_restic_password`）を `/etc/restic/repo.pass`（`0600`）へ配布
- ジョブごとの日次 backup（整合点投入＋`forget`）と週次 prune（pack 再パック）の systemd タイマー
- VM の安定パス＋ハードリンク・スナップショット方式（親照合で新規 part のみ再ハッシュ）
- VL の partition snapshot を `files_from` 方式で 1 スナップショットへ投入（snapshot 一覧を毎回生成）

### 日次 backup と週次 prune の分離

整合点投入（日次・軽量）と pack 再パック（週次・重量）を別スクリプト・別タイマーに分け、重い `restic prune` の VIP NFS 越し I/O を日次経路から隔離する。

- **日次**: `restic backup`（整合点投入）＋ `restic forget`（参照だけを刈る、pack 再パックなし）。`OnCalendar=daily` ＋ `RandomizedDelaySec=1800`。
- **週次**: `restic prune`（参照を失った pack を再パック・解放）。`OnCalendar=weekly` ＋ `RandomizedDelaySec=3600`。

`RandomizedDelaySec` は複数アプリ・複数ノードの I/O が VIP NFS（＝アクティブ1台）へ同時集中するのを避ける。`restic-backup@<job>.service` と `restic-prune@<job>.service` は `flock -n /run/restic-<job>.lock` で同一ロックを共有し、多重起動と backup/prune の同時実行を防ぐ。

### 安定パス＋ハードリンク・スナップショット方式（VM）

VictoriaMetrics の data part は確定後に不変であり、スナップショット API はその part を**ハードリンク**でスナップショット・ディレクトリーに並べる（データ複製なし・瞬時）。これを毎回同じ安定パス（`/mnt/vm-snapshot`）へ `mount --bind` で提示して restic に食わせると、未変更 part は restic の親照合 `(path, mtime, size, inode)` で一致し、restic は新規 part だけを読んでハッシュする。`vmbackup -origin` のような自前増分は不要（restic が世代間差分を担う）。MariaDB・FreeIPA は出力が毎回新規ファイル・小容量のため安定パス最適化は使わず、使い捨て `$STAGING` のままとする。

### partition snapshot ＋ files-from 方式（VL）

VictoriaLogs の partition snapshot API は単一の安定パスへ束ねられず、`create` のたびにパーティション別の多数の snapshot パス（保持 366 日で 1 回 ≈ 142 件）を JSON 配列で返す。多数の `mount --bind` は非現実的なため、`pre_command` で返却パスをホスト側絶対パスへ読み替えた一覧ファイル（`$STAGING/files.txt`）を生成し、`files_from` で 1 スナップショットへ投入する。snapshot id がパスに含まれ毎回変わるため親照合は効かず毎回再ハッシュとなるが、VL は小容量で許容範囲であり、storage 重複は restic の dedup が吸収する。snapshot は溜まると retention を阻害するため、`pre_command`／`post_command` の双方で `list`→`delete?path=` により全削除する（`post_command` 実行時には `$STAGING` が消えているため、`create` の控えではなく `list` から取得し直して消す）。

## 要件と前提条件

### 共通要件

- **対象システム**: 自リポジトリを所有するアプリノード（`monitoring` / `slurm_db` / `idm-01`）。`restic_app_backup_jobs` が空のホストは全タスクを no-op。
- **権限**: 対象ホスト上の root（`become: true`）。bind mount・umount・restic はすべて root で実行する。
- **VIP NFS の rw マウント**: 各アプリノードは VIP NFS を rw でマウント（`/mnt/backup-dst`）し、その下の自リポジトリへ書く。マウントは `storage/unified_mounts` をアプリ側 `group_vars` で併用して用意する（本ロールは前提とするのみ）。
- **整合点取得コマンド**: VM/VL は `curl`・`jq`（本ロールが導入）、MariaDB は `mariadb-dump`、FreeIPA は `ipa-backup`（各アプリ導入済み前提）。

### Ansible 固有の要件

- **Ansible バージョン**: 2.14 以上
- **認証情報**: 変数 `vault_restic_password`（`group_vars/all.yml`）が定義されていること
- 対象ホストがインターネット経由で GitHub Releases へ到達できること（VyOS NAT 経由）

### 手動設定の要件

- 対象ホスト上で root 権限
- `curl`・`jq`・`bzip2`（`bunzip2`）・`flock`（util-linux）が利用可能

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名                            | 説明                                                       | デフォルト値          | 必須   |
| --------------------------------- | ---------------------------------------------------------- | --------------------- | ------ |
| `vault_restic_password`           | 全リポジトリ共通の暗号鍵（Vault 暗号化）                   | -                     | はい   |
| `restic_app_backup_jobs`          | ジョブ定義リスト（下記）                                  | `[]`                  | はい※  |
| `restic_app_backup_version`       | restic のバージョン（公式静的バイナリ）                   | `0.18.1`              | いいえ |
| `restic_app_backup_repo_base`     | VIP NFS の rw マウント先（リポジトリのベース）             | `/mnt/backup-dst`     | いいえ |
| `restic_app_backup_password_file` | リポジトリ・パスワード・ファイルの配置先                  | `/etc/restic/repo.pass` | いいえ |
| `restic_app_backup_keep_daily`    | `forget` で残す日次世代数                                  | `7`                   | いいえ |
| `restic_app_backup_keep_weekly`   | `forget` で残す週次世代数                                  | `4`                   | いいえ |

※ `restic_app_backup_jobs` が空のホストでは、restic インストール・鍵配布・unit 配置をすべてスキップする。

#### ジョブ定義（`restic_app_backup_jobs` の各要素）

| キー           | 説明                                                              | 必須   |
| -------------- | ---------------------------------------------------------------- | ------ |
| `name`         | ジョブ名（= リポジトリ名・unit インスタンス名）                  | はい   |
| `pre_command`  | 整合点を作るシェル断片（`$STAGING` 利用可）。単純な dump 1 行などは直接書いてよいが、長く複雑な手続き（VM/VL の snapshot 操作、FreeIPA の `ipa-backup` + autofs keepalive 等）は `hooks` でスクリプト化し、ここからは実行パスを 1 行で呼ぶ | はい   |
| `post_command` | 後始末のシェル断片（VM/VL の snapshot 削除・umount 等）。`$STAGING` は post 実行前に削除されるため中身は参照不可（API 再取得等で賄う） | いいえ |
| `hooks`        | `templates/restic-hooks/` 配下へ配置するフックスクリプト名のリスト。各 `<名>.sh.j2` を `/usr/local/lib/restic-hooks/<名>.sh`（`0750`）へ展開する。整合点ロジックを YAML へインライン展開せずファイル化し（shellcheck 可・重複解消）、`pre_command`／`post_command` からその実行パスを呼ぶために使う | いいえ |
| `source_path`  | `restic backup` に渡すパス（省略時は `$STAGING`）。`files_from` とは排他 | いいえ |
| `files_from`   | `restic backup --files-from` に渡すパス一覧ファイル（`pre_command` が 1 行 1 パスで生成）。対象が多数・可変で単一パスに束ねられない場合（VL の partition snapshot 等）に使う。指定時は `source_path` より優先 | いいえ |
| `keep_daily` / `keep_weekly` | 既定の世代数の上書き                                | いいえ |

整合点ロジックのファイル化（フック方式）について、フックは親 `restic-backup-<job>.sh` から**別プロセス**として実行されるが、親が `export` した `$STAGING`・`$RESTIC_REPOSITORY` 等の環境変数は引き継ぐ（シェル変数は独立する）。後段の `restic backup` は `pre_command` のシェル変数ではなく `$STAGING` 配下のファイルか固定パス経由でのみ整合点を受け取るため、フックの別プロセス化による影響はない。フックの先頭には `set -euo pipefail` を置き、親の `set -e` に依存しない。VM/VL のフックが参照する環境固有値（データディレクトリー・認証キーファイルのパス）は `group_vars/monitoring.yml` で与え、ポートは各コンテナ役の defaults（`victoria_metrics_container_port` / `victorialogs_container_port`）を再利用する。

#### 冪等性

restic バイナリは導入済みバージョンが一致すれば再導入をスキップする。鍵・スクリプト・unit はテンプレートの内容一致で changed=0 となる。タイマーは `enabled`・`started` を冪等に保証する。

#### タグとハンドラー

unit テンプレート変更時に `Reload systemd daemon` ハンドラーが走る。`site.yml` 側で `restic` タグが付与される。

#### 使用例

```yaml
- hosts: monitoring
  become: true
  gather_facts: false
  roles:
    - role: backup/restic_app_backup
```

ジョブ定義はアプリ側 `group_vars` / `host_vars` に置く（実値は本プロジェクトの該当ファイルを参照）。

### 方法2: 手動での設定手順

各アプリノード上で root として実行する。

1. **restic バイナリの配置**

   ```bash
   VER=0.18.1
   cd /tmp
   curl -fsSLO "https://github.com/restic/restic/releases/download/v${VER}/restic_${VER}_linux_amd64.bz2"
   curl -fsSLO "https://github.com/restic/restic/releases/download/v${VER}/SHA256SUMS"
   grep "restic_${VER}_linux_amd64.bz2" SHA256SUMS | sha256sum -c -
   bunzip2 -c "restic_${VER}_linux_amd64.bz2" > /usr/local/bin/restic
   chmod 0755 /usr/local/bin/restic
   ```

2. **鍵ファイルの配置**（中身は Vault 値 `vault_restic_password`）

   ```bash
   install -d -m 0700 /etc/restic
   printf '%s\n' '<VAULT_RESTIC_PASSWORD>' > /etc/restic/repo.pass
   chmod 0600 /etc/restic/repo.pass
   ```

3. **整合点投入の手動実行**（例: MariaDB）

   ```bash
   export RESTIC_REPOSITORY=/mnt/backup-dst/slurmdbd
   export RESTIC_PASSWORD_FILE=/etc/restic/repo.pass
   STAGING=$(mktemp -d /var/tmp/restic-slurmdbd.XXXXXX)
   mariadb-dump --single-transaction --routines --triggers --databases slurm_acct_db > "$STAGING/slurm_acct_db.sql"
   restic cat config >/dev/null 2>&1 || restic init
   restic backup --tag slurmdbd "$STAGING"
   restic forget --keep-daily 7 --keep-weekly 4
   rm -rf "$STAGING"
   ```

## 運用管理

### 基本操作

- スナップショット一覧: `RESTIC_REPOSITORY=/mnt/backup-dst/<job> RESTIC_PASSWORD_FILE=/etc/restic/repo.pass restic snapshots`
- 整合性検査: `restic check`（パッシブ3台でも通ること）
- タイマー確認: `systemctl list-timers 'restic-*'`
- 直近の実行ログ: `journalctl -u restic-backup@<job>.service`

### 復旧

復旧は常に VIP NFS のリポジトリから行う（「復旧は常に VIP から」）。

- **MariaDB**: `restic restore` でダンプを取り出し `mariadb slurm_acct_db < dump.sql`
- **VictoriaMetrics**: `restic restore` で `big`/`small`/`indexdb`/`metadata` を取り出し、VM を停止して
  データディレクトリー（`data/{big,small,indexdb}`）へ part を戻して再起動する。なお本ジョブが
  restic に投入するのは snapshot 直下（データ本体への symlink ツリー）ではなく、その実体
  （`data/{big,small,indexdb}/snapshots/<snap>`、ハードリンク）を安定パスへ bind したものである
  （`templates/restic-hooks/victoriametrics-pre.sh.j2` 冒頭の実機検証メモを参照）。`vmrestore` は vmbackup 形式の
  リモートストレージを前提とするため本方式の復旧手段ではない。具体的な復旧手順は実機で確定する。
- **VictoriaLogs**: partition snapshot API（`/internal/partition/snapshot/create`、`partition_prefix`
  省略で全件）がパーティション別の多数（保持 366 日で 1 回 ≈ 142 件）の snapshot パスを JSON 配列で
  返すため、`pre_command` でそれらをホスト側絶対パスへ読み替えた一覧ファイルを生成し、`files_from`
  方式（`restic backup --files-from`）で 1 スナップショットに収める。snapshot id がパスに含まれ毎回
  変わるため親照合は効かず毎回再ハッシュとなるが、VL は小容量で許容範囲（storage 重複は restic の
  dedup で吸収）。snapshot は溜まると retention を阻害するため pre/post 双方で `list`→`delete?path=`
  により全削除する。復旧は `restic restore` で取り出した partition snapshot を VL の `detach`／`attach`
  手順で戻す（具体手順は実機で確定）。設計詳細は `templates/restic-hooks/victorialogs-pre.sh.j2` 冒頭のメモを参照。
- **FreeIPA**: `restic restore` で `ipa-full-*` を取り出し、`vault_freeipa_dirman_password` を用いて `ipa-restore`（フルはオフライン）。フル復元はトポロジーを過去時点へ巻き戻すため、復元後は idm-02〜04 を削除し idm-01 から `ipa-replica-install` し直す。詳細は `roles/authentication/freeipa_dirman_rotate/README.md` を参照。

### トラブルシューティング

#### 問題1: 日次ジョブが `unable to create lock` で失敗する

**原因**: 前回ジョブが異常終了し `/run/restic-<job>.lock` が残った、または backup と prune が重複起動した。
**対処**: `flock -n` は取得不可なら即終了する設計のため通常は無害だが、リポジトリ側のロックが残った場合は `restic unlock` を実行する。

#### 問題2: VM/VL の日次 backup が毎回フル再投入になる

**原因**: 安定パスの bind が外れている、または snapshot のハードリンクが維持されていない。
**対処**: `pre_command` の `mount --bind` 後に `/mnt/vm-snapshot` がマウントされているか、`restic backup` の `Added to the repository` 量が新規 part 相当に収まるかを確認する。

#### 問題3: idm-02〜04 で restic 関連の構成がされない

**原因**: 仕様。FreeIPA はデータがレプリカ間同期のため `idm-01` のみで取得する。`restic_app_backup_jobs` は `host_vars/idm-01` にのみ与え、他は空（no-op）。

## アンインストール

`site.yml` のプレイから本ロールを外し、対象ホストで以下を実行する。

```bash
systemctl disable --now 'restic-backup@*.timer' 'restic-prune@*.timer'
rm -f /etc/systemd/system/restic-backup@.{service,timer} /etc/systemd/system/restic-prune@.{service,timer}
rm -f /usr/local/sbin/restic-backup-*.sh /usr/local/sbin/restic-prune-*.sh
rm -rf /usr/local/lib/restic-hooks
systemctl daemon-reload
```

リポジトリ本体（`/mnt/backup-dst/<job>`）と鍵（`/etc/restic/repo.pass`）は、復旧素材を失わないよう意図的に残す。完全に破棄する場合のみ手動で削除する。
