# zpool ロール

ZFS ストレージプール（zpool）の作成と設定を行う Ansible ロール。

## 概要

このロールは、Debian ベースのシステムに ZFS をインストールし、ZFS プールを作成・設定する。`community.general.zpool` モジュールを使用して冪等性を担保する。

個人別の ZFS データセット（ファイルシステム）の作成は、別途 `zfs_dataset` ロールで行う。

## 対応 OS

- Debian 12 (Bookworm)

## 要件

- community.general >= 12.2.0（zpool モジュール使用）
- ホストに ZFS 対応のディスクが接続されていること

## 変数

| 変数名                       | デフォルト値 | 説明                           |
| ---------------------------- | ------------ | ------------------------------ |
| `zpool_name`                 | （必須）     | ZFS プール名                   |
| `zpool_mountpoint.path`      | （必須）     | マウントポイントパス           |
| `zpool_mountpoint.mode`      | （必須）     | マウントポイントのパーミッション |
| `zpool_vdevs`                | （必須）     | vdev 定義                      |
| `zpool_properties`           | `{ashift: 12}` | プールプロパティ             |
| `zpool_filesystem_properties` | 下記参照    | ファイルシステムプロパティ     |

### zpool_vdevs の構造

`community.general.zpool` モジュールの vdevs パラメータに直接渡される。各 vdev は以下のフィールドを持つ：

| フィールド | 必須 | 説明                                                   |
| ---------- | ---- | ------------------------------------------------------ |
| `type`     | No   | vdev タイプ（`mirror`, `raidz`, `raidz2`, `raidz3`）省略時は stripe |
| `role`     | No   | 特殊ロール（`cache`, `log`, `spare`）                  |
| `disks`    | Yes  | ディスクデバイスのリスト                               |

#### 例1: ミラー構成

```yaml
zpool_vdevs:
  - type: mirror
    disks:
      - /dev/disk/by-id/ata-DISK1
      - /dev/disk/by-id/ata-DISK2
```

#### 例2: RAID-Z2 構成

```yaml
zpool_vdevs:
  - type: raidz2
    disks:
      - /dev/disk/by-id/ata-DISK1
      - /dev/disk/by-id/ata-DISK2
      - /dev/disk/by-id/ata-DISK3
      - /dev/disk/by-id/ata-DISK4
```

#### 例3: ミラー + キャッシュ構成

```yaml
zpool_vdevs:
  - type: mirror
    disks:
      - /dev/disk/by-id/ata-DISK1
      - /dev/disk/by-id/ata-DISK2
  - role: cache
    disks:
      - /dev/disk/by-id/nvme-CACHE1
```

### zpool_filesystem_properties のデフォルト値

```yaml
zpool_filesystem_properties:
  compression: zstd
  atime: 'off'
  snapdir: visible
  xattr: sa
  canmount: 'off'
```

## 使用方法

### 方法 1: Ansible

1. インベントリで `zpool_hosts` グループにホストを追加する
2. ホスト変数で `zpool_vdevs` を設定する
3. playbook を実行する

```bash
ansible-playbook -i environments/beyond/inventory site.yml --limit zpool_hosts
```

### 方法 2: 手動

1. ZFS パッケージをインストールする

   ```bash
   apt update && apt install -y zfsutils-linux
   ```

2. カーネルモジュールをロードする

   ```bash
   modprobe zfs
   ```

3. プールを作成する（例: 2 台のディスクでミラー構成）

   ```bash
   zpool create \
     -o ashift=12 \
     -O compression=zstd \
     -O atime=off \
     -O snapdir=visible \
     -O xattr=sa \
     -O canmount=off \
     -O mountpoint=/nfs/home \
     home_pool \
     mirror \
     /dev/disk/by-id/ata-ST20000NM007D-xxx \
     /dev/disk/by-id/ata-ST20000NM007D-yyy
   ```

4. ZFS サービスを有効化する

   ```bash
   systemctl enable --now zfs-import-cache zfs-mount zfs.target
   ```

## ディスクの選択について

ディスクパスは `/dev/disk/by-id/` 配下のパスを使用すること。`/dev/sdX` のようなパスは VM 再作成時に変わる可能性があるため推奨しない。

ディスク一覧を確認するには：

```bash
ls -la /dev/disk/by-id/ | grep -v part
```

## 注意事項

- zpool create は破壊的操作である。誤ったディスクを指定するとデータ消失の可能性がある
- 既存プールの vdev 構成変更はこのロールではサポートしない
- プールが既に存在する場合、このロールはプロパティの変更のみを行う
