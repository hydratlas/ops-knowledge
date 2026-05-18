# snapper ロール

Btrfs サブボリュームに対する Snapper の構成とタイマー有効化を行う Ansible ロール。

## 概要

このロールは Debian/Ubuntu 系システムに `snapper` パッケージを導入し、
変数で指定された対象（例: `/`、`/home`）について Snapper コンフィグを作成する。
作成後、`TIMELINE_LIMIT_*` などの値を上書きし、`snapper-timeline.timer` と
`snapper-cleanup.timer` を有効化する。

## 対応 OS

- Ubuntu 24.04 LTS (Noble Numbat)
- Debian 系全般（`snapper` パッケージが提供されているリリース）

## 要件

- `community.general` コレクション（`community.general.ini_file` を使用）
- 対象パスが Btrfs サブボリュームであること
- スナップショット保存先（例: `<path>/.snapshots`）の準備が済んでいること
  - `@snapshots` サブボリュームを `/.snapshots` にマウントして利用する構成の場合、
    Snapper の `create-config` が `<path>/.snapshots` を新規作成しようとして失敗する。
    その場合は事前に [`debian-and-ubuntu-tips/initial-setup/btrfs.md`](../../platforms/debian-and-ubuntu-tips/initial-setup/btrfs.md)
    に記載された初回手順（umount → rm → create-config → subvolume delete → mkdir → mount -a）
    を一度だけ手動で実行すること。
  - 通常の単一サブボリューム構成では、このロールのみで完結する。

## 変数

| 変数名                       | デフォルト値                       | 説明                              |
| ---------------------------- | ---------------------------------- | --------------------------------- |
| `snapper_configs`            | `[ { name: root, path: / } ]`      | 設定対象のコンフィグ一覧          |
| `snapper_config_overrides`   | `{ TIMELINE_LIMIT_YEARLY: "0" }`   | 全コンフィグに適用するキー＝値    |
| `snapper_enable_timers`      | `true`                             | Snapper タイマーを有効化するか    |

### `snapper_configs` の構造

| フィールド | 必須 | 説明                                 |
| ---------- | ---- | ------------------------------------ |
| `name`     | Yes  | `snapper -c <name>` のコンフィグ名   |
| `path`     | Yes  | 対象サブボリュームのマウントパス     |

### 例: ルートと /home の両方にコンフィグを作成

```yaml
- hosts: snapper_hosts
  roles:
    - role: storage/snapper
      vars:
        snapper_configs:
          - name: root
            path: /
          - name: home
            path: /home
        snapper_config_overrides:
          TIMELINE_LIMIT_YEARLY: "0"
          TIMELINE_LIMIT_MONTHLY: "6"
```

## 冪等性について

- コンフィグ作成は `/etc/snapper/configs/<name>` の存在で判定するため、二度目以降はスキップされる。
- 値の上書きは `community.general.ini_file` で行うため、既存値と一致する場合は変更されない。
- タイマーは `enabled: true, state: started` で常時収束させる。

## 確認

```bash
systemctl status snapper-timeline.timer
systemctl status snapper-cleanup.timer
sudo btrfs subvolume list /
sudo snapper -c root list
```

## 手動手順

Ansible ロールを適用せずに手動で同等の設定を行う場合は以下のとおり。定期的にスナップショットを取得して、誤操作などからファイルを復旧できるようにする。この場合は `/.snapshots` ディレクトリーにスナップショットが保存される。`@snapshots` サブボリュームがすでにあることを前提にしている。

```bash
sudo apt-get install --no-install-recommends -y snapper &&
mountpoint --quiet --nofollow /boot/efi &&
sudo umount /.snapshots &&
sudo rm -d /.snapshots &&
sudo snapper -c root create-config / &&
sudo btrfs subvolume delete /.snapshots &&
sudo mkdir -p /.snapshots &&
sudo mount -a &&
sudo perl -pi -e 's/^TIMELINE_LIMIT_YEARLY=.+$/TIMELINE_LIMIT_YEARLY="0"/g;' /etc/snapper/configs/root &&
sudo systemctl enable --now snapper-timeline.timer &&
sudo systemctl enable --now snapper-cleanup.timer
```

`/home` ディレクトリーでもスナップショットを保存する場合の追加設定。この場合は `/home/.snapshots` にスナップショットが保存される。

```bash
sudo snapper -c home create-config /home &&
sudo perl -pi -e 's/^TIMELINE_LIMIT_YEARLY=.+$/TIMELINE_LIMIT_YEARLY="0"/g;' /etc/snapper/configs/home
```

確認。

```bash
sudo systemctl status snapper-timeline.timer
sudo systemctl status snapper-cleanup.timer

sudo btrfs subvolume list /
sudo snapper -c root list
```

スナップショットの削除に向けて、スナップショットの番号だけ表示する。

```bash
sudo snapper -c root --no-headers --csvout list --columns number
```

スナップショットの削除。この場合、#65と#70が削除される。

```bash
sudo snapper -c root delete 65 70
```

## 範囲外

- `grub-btrfs` 経由のスナップショットからの起動設定は扱わない。
- Btrfs ファイルシステム自体の作成・マウントは `storage/btrfs_raid` ロールが扱う。
