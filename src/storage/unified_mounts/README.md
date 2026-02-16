# unified_mounts

統合マウント管理ロール

## 概要

このロールは、ローカルファイルシステム、NFS、CIFS等のマウントを単一のインターフェースで管理する。

### 実現される機能

- 必要なクライアントパッケージの自動インストール（NFS、CIFS）
- マウントポイントディレクトリの自動作成
- NFSマウントはsystemdオートマウントで管理（ハングを回避）
- 非NFSマウントは`/etc/fstab`エントリで管理
- FS-Cache（`fsc`オプション）使用時に`cachefilesd`を自動インストール・有効化

### NFSマウントの特殊処理

NFSマウント（fstype: nfs/nfs4）は、systemdオートマウントを使用する。これにより、以下の利点がある。

- **Ansibleのハング回避**: NFSサーバーが応答しない場合でも、Ansible実行がブロックされない
- **オンデマンドマウント**: マウントポイントへのアクセス時に初めてマウントが実行される
- **自動アンマウント**: 10分間アクセスがないと自動的にアンマウントされる（TimeoutIdleSec=600）
- **設定変更の自動反映**: NFSサーバーのIPアドレスやマウントオプションが変更された場合、automountユニットが自動的に再起動され、新しい設定が即座に反映される

## 要件と前提条件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

## 設定方法

### 直接リスト形式 (`unified_mounts`)

```yaml
unified_mounts:
  # ローカルファイルシステム
  - src: /dev/sdb1
    path: /data
    fstype: ext4
    opts: defaults,noatime
    dump: 0
    passno: 2
    state: mounted
    mode: '0755'

  # NFSマウント（systemdオートマウントで管理）
  - src: "10.120.61.53:/home"
    path: /nfs/home
    fstype: nfs4
    opts: "nofail,hard,fsc"
    state: mounted

  # CIFSマウント
  - src: "//server/share"
    path: /mnt/cifs
    fstype: cifs
    opts: "credentials=/etc/samba/creds,uid=1000"
    state: mounted
```

### パターン/セレクタ形式 (`unified_mount_patterns` + `unified_mount_selectors`)

大規模環境でマウントパターンを共通定義し、ホスト毎に選択する場合に有用である。

`group_vars/all.yml`:
```yaml
unified_mount_patterns:
  home:
    src: "10.120.61.53:/home"
    path: /nfs/home
    fstype: nfs4
    opts: "nofail,hard,fsc"
    state: mounted
  ssd2024:
    src: "10.120.61.52:/ssd2024"
    path: /nfs/ssd2024
    fstype: nfs4
    opts: "nofail,hard,fsc"
    state: mounted
```

`host_vars/server1.yml`:
```yaml
unified_mount_selectors:
  - home
  - ssd2024
```

## ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `unified_mounts` | マウント設定のリスト | `[]` | いいえ |
| `unified_mount_patterns` | マウントパターンの辞書 | `{}` | いいえ |
| `unified_mount_selectors` | 適用するパターン名のリスト | `[]` | いいえ |

### マウント設定の属性

| 属性 | 説明 | デフォルト値 | 必須 |
|------|------|-------------|------|
| `src` | ソースデバイスまたはリモートパス | なし | はい |
| `path` | マウントポイントのパス | なし | はい |
| `fstype` | ファイルシステムタイプ | なし | はい |
| `opts` | マウントオプション | なし（NFSの場合: `nofail,hard,_netdev`） | いいえ |
| `dump` | dumpフラグ（非NFSのみ） | `0` | いいえ |
| `passno` | fsckパス番号（非NFSのみ） | `0` | いいえ |
| `state` | マウント状態 | `mounted` | いいえ |
| `mode` | ディレクトリのパーミッション | `'0755'` | いいえ |
| `owner` | ディレクトリの所有者 | `root` | いいえ |
| `group` | ディレクトリのグループ | `root` | いいえ |

### state の値

#### 非NFSマウント（従来動作）

| 値 | 説明 |
|----|------|
| `mounted` | マウントし、fstabに追加 |
| `present` | fstabに追加のみ（マウントしない） |
| `unmounted` | アンマウントするが、fstabには残す |
| `absent` | アンマウントし、fstabから削除 |

#### NFSマウント（systemdオートマウント）

| 値 | 説明 |
|----|------|
| `mounted` | automount有効化＋起動（デフォルト） |
| `present` | ユニット配置＋有効化のみ（起動しない） |
| `absent` | ユニット停止＋削除 |

## systemdユニットの命名規則

NFSマウントのsystemdユニット名は、マウントパスから生成される。

| マウントパス | ユニット名 |
|-------------|-----------|
| `/nfs/home` | `nfs-home.mount`, `nfs-home.automount` |
| `/nfs/ssd2024` | `nfs-ssd2024.mount`, `nfs-ssd2024.automount` |

## 運用

### NFSマウントの状態確認

```bash
# automountユニットの状態確認
systemctl status nfs-home.automount

# 実際にマウントされているか確認
systemctl status nfs-home.mount

# マウント一覧
mount | grep nfs
```

### トラブルシューティング

NFSサーバーへの接続に問題がある場合、マウントポイントにアクセスするまでエラーは発生しない。アクセス時にタイムアウトする場合は、以下を確認する。

```bash
# NFSサーバーへの接続確認
showmount -e <nfs-server-ip>

# mountユニットのログ確認
journalctl -u nfs-home.mount
```

### FS-Cache の運用

マウントオプションに`fsc`を指定すると、NFSの読み込みデータをローカルディスクにキャッシュする。同じファイルの繰り返し読み込みが高速化され、NFSサーバーの負荷も軽減される。

```bash
# cachefilesdサービスの状態確認
systemctl status cachefilesd

# キャッシュ統計の確認
cat /proc/fs/fscache/stats

# キャッシュディレクトリの使用量確認
du -sh /var/cache/fscache
```

キャッシュは`/var/cache/fscache`に保存される。ディスク空き容量が7%を下回るとキャッシュの削除が開始され、3%を下回ると新規キャッシュの作成が停止する。

## NFS stale file handle 自動再マウント機能

NFSサーバーのフェイルオーバー時に発生する「Stale file handle」エラーを自動検出し、再マウントを行う機能である。

### 機能概要

systemd timerを使用して定期的にNFSマウントの状態を監視する。マウントポイントへのアクセスがタイムアウトした場合やエラーが発生した場合、遅延アンマウント（umount -l）を実行し、automountユニットを再起動する。

### 有効化

`group_vars`または`host_vars`で以下の変数を設定する。

```yaml
unified_mounts_stale_check_enabled: true
```

### 設定変数

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `unified_mounts_stale_check_enabled` | 機能の有効化フラグ | `false` |
| `unified_mounts_stale_check_interval` | 監視間隔（systemd timer形式） | `"30s"` |
| `unified_mounts_stale_check_timeout` | statコマンドのタイムアウト秒数 | `5` |

### 監視間隔の設定例

```yaml
# 30秒ごと（デフォルト）
unified_mounts_stale_check_interval: "30s"

# 1分ごと
unified_mounts_stale_check_interval: "1min"

# 5分ごと
unified_mounts_stale_check_interval: "5min"
```

### 配置されるファイル

| パス | 説明 |
|------|------|
| `/usr/local/sbin/nfs-stale-check.sh` | 監視スクリプト |
| `/etc/systemd/system/nfs-stale-check.service` | systemd serviceユニット |
| `/etc/systemd/system/nfs-stale-check.timer` | systemd timerユニット |

### 運用

```bash
# timerの状態確認
systemctl status nfs-stale-check.timer

# 次回実行予定の確認
systemctl list-timers nfs-stale-check.timer

# 手動実行
systemctl start nfs-stale-check.service

# ログの確認
journalctl -t nfs-stale-check
```

### 動作フロー

1. timerが設定間隔でserviceを起動
2. serviceがスクリプトを実行
3. スクリプトが各NFSマウントポイントに対して`stat`コマンドでアクセスを試みる
4. タイムアウトまたはエラーの場合、遅延アンマウントを実行
5. automountユニットを再起動（次回アクセス時に新しい接続が確立される）

## 依存関係

なし
