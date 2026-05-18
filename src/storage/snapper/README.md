# snapper ロール

Btrfs サブボリュームに対する Snapper の構成とタイマー有効化を行う Ansible ロール。

## 概要

このロールは Debian/Ubuntu 系システムに `snapper` パッケージを導入し、変数で指定された対象（例: `/`、`/home`）について Snapper コンフィグを`/usr/share/snapper/config-templates/default` から複製して配置する。`SUBVOLUME` を対象パスに書き換え、`/etc/default/snapper` の`SNAPPER_CONFIGS` を更新したうえで `TIMELINE_LIMIT_*` などの値を上書きし、`snapper-timeline.timer` と `snapper-cleanup.timer` を有効化する。

`snapper_configs` が空配列の場合は、タイマーを停止・無効化したうえで `snapper` パッケージを purge する（autoremove 付き）。ホストを Snapper 管理対象から外したいときは、当該ホストの `snapper_configs` を `[]` に設定するだけでよい。

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
- `snapper_configs` が空の場合はタイマー停止後に `apt purge`（`autoremove: true`）でパッケージごと削除する。インストール済みでないホストではタイマー操作はスキップされる。

## 手動

Ansible ロールを適用せずに手動で同等の設定を行う場合の手順。

### パッケージのインストール

`snapper` パッケージをインストールする。

```bash
sudo apt-get install --no-install-recommends -y snapper
```

### 設定の作成

#### `/etc/snapper/configs/$name`

対象コンフィグごとに `name` と `path` を変数に設定して、以下の一連のコマンドを実行する。`<path>/.snapshots` は存在しない場合のみネストサブボリュームとして作成する（`@snapshots` をフラットレイアウトでマウント済みのルート構成では既に存在するためスキップされる）。

まずルート（`/`）のコンフィグを作成する場合は、変数を設定する。

```bash
name="root" && path="/"
```

`/home` のコンフィグを作成する場合は、変数を以下のように設定する。

```bash
name="home" && path="/home"
```

変数を設定したうえで、以下のコマンドを実行する。別のコンフィグを追加する場合は、`name` と `path` を再設定して同じコマンドをもう一度実行する。

```bash
snap="${path%/}/.snapshots" &&
( [ -e "$snap" ] || sudo btrfs subvolume create "$snap" ) &&
sudo chown root:root "$snap" &&
sudo chmod 0750 "$snap" &&
sudo install -o root -g root -m 0640 /usr/share/snapper/config-templates/default "/etc/snapper/configs/$name" &&
sudo perl -pi -e "s|^SUBVOLUME=.*\$|SUBVOLUME=\"$path\"|;" "/etc/snapper/configs/$name" &&
sudo perl -pi -e 's/^TIMELINE_LIMIT_YEARLY=.+$/TIMELINE_LIMIT_YEARLY="0"/g;' "/etc/snapper/configs/$name"
```

#### `/etc/default/snapper`

`/etc/default/snapper` の `SNAPPER_CONFIGS` を、`/etc/snapper/configs` 配下のファイル名一覧から自動生成して書き換える。

```bash
configs=$(cd /etc/snapper/configs && ls | xargs) &&
sudo perl -pi -e "s|^SNAPPER_CONFIGS=.*\$|SNAPPER_CONFIGS=\"$configs\"|;" /etc/default/snapper
```

### タイマーの有効化

タイマーを有効化する。

```bash
sudo systemctl enable --now snapper-timeline.timer &&
sudo systemctl enable --now snapper-cleanup.timer
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
