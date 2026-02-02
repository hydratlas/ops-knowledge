# zfs_dataset ロール

ZFS データセット（ファイルシステム）の作成と設定を行う Ansible ロール。

## 概要

このロールは、既存の ZFS プール上にデータセット（ファイルシステム）を作成し、quota やマウントポイントなどのプロパティを設定する。`community.general.zfs` モジュールを使用して冪等性を担保する。

プールの作成は、別途 `zpool` ロールで行う。

## 対応 OS

- Debian 12 (Bookworm)

## 要件

- community.general >= 5.0.0（zfs モジュール使用）
- 対象のホストに ZFS プールが作成されていること（`zpool` ロール実行後）

## 変数

| 変数名         | デフォルト値 | 説明                         |
| -------------- | ------------ | ---------------------------- |
| `zfs_datasets` | `[]`         | 作成するデータセットのリスト |

### zfs_datasets の構造

各データセットは以下のフィールドを持つ：

| フィールド   | 必須 | 説明                                                 |
| ------------ | ---- | ---------------------------------------------------- |
| `name`       | Yes  | データセット名（`pool/dataset` 形式）                |
| `properties` | No   | ZFS プロパティ（quota, mountpoint など）             |
| `owner`      | No   | マウントポイントの所有者                             |
| `group`      | No   | マウントポイントのグループ（省略時は owner と同じ）  |
| `mode`       | No   | マウントポイントのパーミッション（デフォルト: 0700） |

### 設定例

```yaml
zfs_datasets:
  - name: home_pool/sato
    properties:
      quota: 107374182400
      mountpoint: /nfs/home/sato
    owner: sato
    mode: "0700"
  - name: home_pool/tanaka
    properties:
      quota: 107374182400
      mountpoint: /nfs/home/tanaka
    owner: tanaka
    mode: "0700"
  - name: home_pool/shared
    properties:
      quota: 500G
      mountpoint: /nfs/home/shared
    mode: "0755"
```

### 使用可能なプロパティ

`properties` には、ZFS がサポートするすべてのプロパティを指定できる：

| プロパティ    | 説明                   | 例             |
| ------------- | ---------------------- | -------------- |
| `quota`       | データセットの容量制限 | `107374182400` |
| `reservation` | 予約容量               | `50G`          |
| `mountpoint`  | マウントポイント       | `/data`        |
| `compression` | 圧縮アルゴリズム       | `zstd`         |
| `atime`       | アクセス時刻の記録     | `off`          |
| `canmount`    | マウント可否           | `on`           |
| `recordsize`  | レコードサイズ         | `128K`         |
| `sync`        | 同期書き込みの動作     | `standard`     |

## 使用方法

### 方法 1: Ansible

1. `zpool` ロールでプールを作成する
2. インベントリで `zfs_dataset_hosts` グループにホストを追加する
3. ホスト変数で `zfs_datasets` を設定する
4. playbook を実行する

```bash
ansible-playbook -i environments/beyond/inventory site.yml --limit zfs_dataset_hosts
```

### 方法 2: 手動

1. データセットを作成する

   ```bash
   zfs create -o quota=107374182400 -o mountpoint=/nfs/home/username home_pool/username
   ```

2. 所有者を設定する

   ```bash
   chown username:username /nfs/home/username
   chmod 700 /nfs/home/username
   ```

## 注意事項

- データセットの親プールが存在しない場合、タスクは失敗する
- `owner` を指定する場合、そのユーザーがシステムに存在する必要がある
- 既存のデータセットがある場合、このロールはプロパティの変更のみを行う
- quota の変更は即座に反映される
