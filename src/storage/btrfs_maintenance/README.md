# btrfs_maintenance ロール

Btrfs ファイルシステムの定期メンテナンス（scrub・balance）を有効化する Ansible ロール。

## 概要

このロールは Debian/Ubuntu 系システムに `btrfsmaintenance` パッケージを導入し、
必要に応じて `/etc/default/btrfsmaintenance` の `BTRFS_BALANCE_PERIOD` と `BTRFS_SCRUB_PERIOD` を書き換える。

scrub はデータの整合性をチェックし、balance はデータの再配置を行う。
いずれも長期運用では定期実行することが推奨されている。

タイマーユニット自体は操作しない。`/etc/default/btrfsmaintenance` の変更は `btrfsmaintenance-refresh.path` が検知し、
`btrfs-balance.timer` および `btrfs-scrub.timer` の `OnCalendar` 再生成と有効化・無効化はパッケージ側のヘルパーが自動で行う。
パッケージのインストール直後は `btrfsmaintenance-refresh.path` が無効になっているため、本ロールが明示的に有効化する。

## 対応 OS

- Ubuntu 24.04 LTS (Noble Numbat)
- Debian 系全般（`btrfsmaintenance` パッケージが提供されているリリース）

## 要件

- 対象ホストのルートまたは対象マウントポイントが Btrfs であること

## 変数

| 変数名                             | デフォルト値 | 説明                              |
| ---------------------------------- | ------------ | --------------------------------- |
| `btrfs_maintenance_balance_period` | `weekly`     | `BTRFS_BALANCE_PERIOD` に設定する |
| `btrfs_maintenance_scrub_period`   | `weekly`     | `BTRFS_SCRUB_PERIOD` に設定する   |

受け付ける値は `none` / `daily` / `weekly` / `monthly` のいずれか、または `systemd.time(7)` の Calendar Events 書式（例: `Sat *-*-* 04:00:00`）。
パッケージ既定は balance が `none`（無効）、scrub が `monthly` だが、本ロールでは両方とも `weekly` をデフォルトとする。
`weekly` は `Mon *-*-* 00:00:00` に展開され、`AccuracySec=1h` によりホスト間で月曜0時〜1時の範囲に自動分散される。
同一ホスト内の balance と scrub は同じ時刻窓に重なるが、`BTRFS_ALLOW_CONCURRENCY="false"`（パッケージ既定）により直列化される。
1時間より広い分散や曜日分離が必要な場合は変数を明示指定する。

## 使用方法

```yaml
- hosts: btrfs_hosts
  roles:
    - role: storage/btrfs_maintenance
      vars:
        btrfs_maintenance_balance_period: "monthly"
        btrfs_maintenance_scrub_period: "weekly"
```

何も指定せずに `roles: [storage/btrfs_maintenance]` とすれば、パッケージ既定のスケジュールで動作する。

`site.yml` では `physical:tofu_virtual` を対象に、`ansible_mounts` を `gather_subset: mounts` で取得したうえで Btrfs マウントを持つホストにのみ自動適用される（ゼロコンフィグ）。LXC は親ホスト側でメンテナンスされるため対象から除外している。

## 確認

ロール適用後に状態を確認するには以下を実行する。

```bash
systemctl status btrfs-balance.timer
systemctl status btrfs-scrub.timer
systemctl list-timers btrfs-*
cat /etc/default/btrfsmaintenance
```

## 手動手順

Ansible ロールを適用せずに手動で同等の設定を行う場合は以下のとおり。`btrfsmaintenance` パッケージを導入し、`btrfsmaintenance-refresh.path` を有効化したうえで `/etc/default/btrfsmaintenance` の `BTRFS_BALANCE_PERIOD` と `BTRFS_SCRUB_PERIOD` を `weekly` に書き換える。タイマーの `OnCalendar` 再生成と有効化は `btrfsmaintenance-refresh.path` が `/etc/default/btrfsmaintenance` の変更を検知して自動で行うが、パッケージのインストール直後は無効になっているため明示的に有効化する。最後に `btrfsmaintenance-refresh.service` を明示的に起動してタイマーを即時再生成する。

```bash
sudo apt-get install --no-install-recommends -y btrfsmaintenance &&
sudo systemctl enable --now btrfsmaintenance-refresh.path &&
sudo perl -pi -e 's/^BTRFS_BALANCE_PERIOD=.+$/BTRFS_BALANCE_PERIOD="weekly"/g; s/^BTRFS_SCRUB_PERIOD=.+$/BTRFS_SCRUB_PERIOD="weekly"/g;' /etc/default/btrfsmaintenance &&
sudo systemctl start btrfsmaintenance-refresh.service
```

確認。

```bash
cat /etc/default/btrfsmaintenance
sudo systemctl status btrfs-balance.timer
sudo systemctl status btrfs-scrub.timer
systemctl list-timers btrfs-*
```
