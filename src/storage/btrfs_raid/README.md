# btrfs ロール

btrfs RAID1（ミラー）ファイルシステムの作成とマウント設定を行う Ansible ロール。

## 概要

このロールは、Ubuntu/Debian ベースのシステムに btrfs-progs をインストールし、
複数のディスクを使用した btrfs RAID1 ファイルシステムを作成・マウントする。

## 対応 OS

- Ubuntu 24.04 LTS (Noble Numbat)

## 要件

- ansible.posix >= 1.0.0（mount モジュール使用）
- ホストに btrfs 用のディスクが接続されていること

## 変数

| 変数名                | デフォルト値              | 説明                         |
| --------------------- | ------------------------- | ---------------------------- |
| `btrfs_filesystems`   | `[]`                      | ファイルシステム定義リスト   |
| `btrfs_mount_options` | `compress=zstd:1,noatime` | デフォルトマウントオプション |
| `btrfs_force`         | `false`                   | 強制フォーマット             |

### btrfs_filesystems の構造

| フィールド        | 必須 | 説明                               |
| ----------------- | ---- | ---------------------------------- |
| `label`           | Yes  | ファイルシステムラベル             |
| `devices`         | Yes  | ディスクデバイスのリスト（2台以上）|
| `mountpoint.path` | Yes  | マウントポイントパス               |
| `mountpoint.mode` | No   | パーミッション（デフォルト0755）   |
| `mount_options`   | No   | マウントオプション                 |

### 例: 複数ディスクでRAID1構成

```yaml
btrfs_filesystems:
  - label: data_pool
    devices:
      - /dev/disk/by-id/ata-DISK1
      - /dev/disk/by-id/ata-DISK2
      - /dev/disk/by-id/ata-DISK3
      - /dev/disk/by-id/ata-DISK4
      # 必要に応じて追加
    mountpoint:
      path: /mnt/data
      mode: "0755"
    mount_options: "compress=zstd,noatime"
```

## 使用方法

### 方法 1: Ansible

1. インベントリで `btrfs_hosts` グループにホストを追加する
2. ホスト変数で `btrfs_filesystems` を設定する
3. playbook を実行する

```bash
ansible-playbook -i environments/beyond/inventory site.yml --limit btrfs_hosts
```

### 方法 2: 手動

1. btrfs-progs パッケージをインストールする

   ```bash
   apt update && apt install -y btrfs-progs
   ```

2. btrfs RAID1 ファイルシステムを作成する

   ```bash
   mkfs.btrfs -L data_pool -d raid1 -m raid1 \
     /dev/disk/by-id/ata-DISK1 \
     /dev/disk/by-id/ata-DISK2
   ```

3. マウントポイントを作成しマウントする

   ```bash
   mkdir -p /mnt/data
   mount /dev/disk/by-id/ata-DISK1 /mnt/data
   ```

4. /etc/fstab に追加する（UUID を使用）

   ```bash
   UUID=$(blkid -o value -s UUID /dev/disk/by-id/ata-DISK1)
   echo "UUID=$UUID /mnt/data btrfs compress=zstd,noatime 0 0" >> /etc/fstab
   ```

## ディスクの選択について

ディスクパスは `/dev/disk/by-id/` 配下のパスを使用すること。
`/dev/sdX` のようなパスは再起動時に変わる可能性があるため推奨しない。

ディスク一覧を確認するには：

```bash
ls -la /dev/disk/by-id/ | grep -v part
```

## 注意事項

- mkfs.btrfs は破壊的操作である。誤ったディスクを指定するとデータ消失の可能性がある
- btrfs RAID1 は最低2台のディスクが必要である
- 既存のファイルシステムがある場合、`btrfs_force: true` を設定しない限りスキップされる
