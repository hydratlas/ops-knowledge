# snapper ロール

Btrfs サブボリュームに対する Snapper の構成とタイマー有効化を行う Ansible ロール。

## 概要

このロールは Debian/Ubuntu 系システムに `snapper` パッケージを導入し、変数で指定された対象（例: `/`、`/home`）について Snapper コンフィグを`/etc/snapper/config-templates/default` から複製して配置する。`SUBVOLUME` を対象パスに書き換え、`/etc/default/snapper` の`SNAPPER_CONFIGS` を更新したうえで `TIMELINE_LIMIT_*` などの値を上書きし、`snapper-timeline.timer` と `snapper-cleanup.timer` を有効化する。

`snapper create-config` を呼ばないため、`@snapshots` サブボリュームを`/.snapshots` にマウントするフラットレイアウトでも、単一サブボリューム構成でも、同じ手順で適用できる。

スナップショットの保存先となる `<path>/.snapshots` が存在しない場合は、ネストサブボリュームとして `btrfs subvolume create` で作成し、所有者・パーミッションを `root:root` / `0750` に揃える。`@snapshots` をフラットレイアウトで `/.snapshots` にマウント済みのルート構成では既に存在するため作成はスキップされる。

定期的にスナップショットを取得して、誤操作などからファイルを復旧できるようにする。

## 対応 OS

- Ubuntu 24.04 LTS (Noble Numbat)
- Debian 系全般（`snapper` パッケージが提供されているリリース）

## 自動（Ansible ロール）

### 要件

- `community.general` コレクション（`community.general.ini_file` を使用）
- 対象パスが Btrfs サブボリュームであること
- `@snapshots` 構成の場合は、`/.snapshots` が `@snapshots` を指す形で `/etc/fstab` から既にマウントされていること（ロール自体はマウントには関与しない）

### 変数

| 変数名                     | デフォルト値                     | 説明                           |
| -------------------------- | -------------------------------- | ------------------------------ |
| `snapper_configs`          | `[ { name: root, path: / } ]`    | 設定対象のコンフィグ一覧       |
| `snapper_config_overrides` | `{ TIMELINE_LIMIT_YEARLY: "0" }` | 全コンフィグに適用するキー＝値 |
| `snapper_enable_timers`    | `true`                           | Snapper タイマーを有効化するか |

#### `snapper_configs` の構造

| フィールド | 必須 | 説明                               |
| ---------- | ---- | ---------------------------------- |
| `name`     | Yes  | `snapper -c <name>` のコンフィグ名 |
| `path`     | Yes  | 対象サブボリュームのマウントパス   |

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

### 冪等性

- `<path>/.snapshots` の作成は `ansible.builtin.stat` で存在確認したうえで、存在しない場合のみ `btrfs subvolume create` を実行する。
- コンフィグ配置は `ansible.builtin.copy` の `force: false` により、既存ファイルがあれば上書きしない。
- `SUBVOLUME` および上書き値は `community.general.ini_file` で行うため、既存値と一致する場合は変更されない。
- `/etc/default/snapper` の `SNAPPER_CONFIGS` は `ansible.builtin.lineinfile` で常に宣言した一覧へ収束させる。
- タイマーは `enabled: true, state: started` で常時収束させる。

## 手動

Ansible ロールを適用せずに手動で同等の設定を行う場合の手順。
`/` 単体にコンフィグを作成する例。

`/.snapshots` が存在しない場合のみネストサブボリュームとして作成する（`@snapshots` をフラットレイアウトでマウント済みのルート構成では既に存在するためスキップされる）。

```bash
sudo apt-get install --no-install-recommends -y snapper &&
( [ -e /.snapshots ] || sudo btrfs subvolume create /.snapshots ) &&
sudo chown root:root /.snapshots &&
sudo chmod 0750 /.snapshots &&
sudo install -o root -g root -m 0640 /etc/snapper/config-templates/default /etc/snapper/configs/root &&
sudo perl -pi -e 's|^SUBVOLUME=.*$|SUBVOLUME="/"|;' /etc/snapper/configs/root &&
sudo perl -pi -e 's|^SNAPPER_CONFIGS=.*$|SNAPPER_CONFIGS="root"|;' /etc/default/snapper &&
sudo perl -pi -e 's/^TIMELINE_LIMIT_YEARLY=.+$/TIMELINE_LIMIT_YEARLY="0"/g;' /etc/snapper/configs/root &&
sudo systemctl enable --now snapper-timeline.timer &&
sudo systemctl enable --now snapper-cleanup.timer
```

`/home` ディレクトリーでもスナップショットを保存する場合の追加設定。
この場合は `/home/.snapshots` にスナップショットが保存される。`/home/.snapshots` が存在しない場合のみネストサブボリュームとして作成する。

```bash
( [ -e /home/.snapshots ] || sudo btrfs subvolume create /home/.snapshots ) &&
sudo chown root:root /home/.snapshots &&
sudo chmod 0750 /home/.snapshots &&
sudo install -o root -g root -m 0640 /etc/snapper/config-templates/default /etc/snapper/configs/home &&
sudo perl -pi -e 's|^SUBVOLUME=.*$|SUBVOLUME="/home"|;' /etc/snapper/configs/home &&
sudo perl -pi -e 's|^SNAPPER_CONFIGS=.*$|SNAPPER_CONFIGS="root home"|;' /etc/default/snapper &&
sudo perl -pi -e 's/^TIMELINE_LIMIT_YEARLY=.+$/TIMELINE_LIMIT_YEARLY="0"/g;' /etc/snapper/configs/home
```

## 運用

### 状態確認

```bash
sudo systemctl status snapper-timeline.timer
sudo systemctl status snapper-cleanup.timer
sudo btrfs subvolume list /
sudo snapper -c root list
```

### スナップショットの削除

スナップショットの番号だけ表示する。

```bash
sudo snapper -c root --no-headers --csvout list --columns number
```

番号を指定して削除する。以下は #65 と #70 を削除する例。

```bash
sudo snapper -c root delete 65 70
```
