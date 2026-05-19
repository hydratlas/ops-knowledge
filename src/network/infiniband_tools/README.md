# infiniband_tools

InfiniBand 接続サーバー向けの benchmark / 診断ツール常設ロール

## 概要

### このドキュメントの目的

InfiniBand を備えたサーバーで benchmark や障害切り分けを行う際に頻繁に必要となるユーザー空間ツールを、ベンチマーク実施のたびに `apt install` → `apt remove --autoremove` で出し入れする運用を解消するためのロールである。対象パッケージはあらかじめ常設しておく方針に切り替える。

### 実現される機能

- `perftest`（`ib_write_bw` / `ib_read_bw` / `ib_send_bw` / `ib_write_lat` など RDMA 性能計測コマンド）のインストール
- `infiniband-diags`（`ibstat` / `iblinkinfo` / `ibv_devices` / `ibhosts` など IB 診断コマンド）のインストール
- `fio`（NFSoRDMA・ローカルストレージ性能計測用の汎用 I/O ベンチマーク）のインストール
- Mellanox HCA 非搭載ホストでの自動スキップ（`lspci -d 15b3:` の結果が空なら `end_host`）

## 適用対象

InfiniBand HCA が接続された物理サーバーに適用する。本リポジトリでは `nas_physical`（nas2024-ssd）と `slurm_compute_physical`（oz、polaris）の 2 グループが該当する。`site.yml` から `nas_physical:slurm_compute_physical` パターンでまとめて適用する。

## 要件と前提条件

- Debian/Ubuntu 系 OS（Ubuntu 24.04 で動作確認）
- Mellanox HCA（ConnectX-3 など）が PCI 上に存在すること
- パッケージリポジトリへ到達可能であること（`apt_cacher_ng` 経由でも可）

## ロール変数

| 変数名 | 既定値 | 説明 |
| ------ | ------ | ---- |
| `infiniband_tools_packages` | `[perftest, infiniband-diags, fio]` | 常設するパッケージリスト。host_vars / group_vars で増減可能 |

## 依存関係

なし。`network/opensm` および `network/infiniband_ipoib` で導入される `rdma-core` / `infiniband-diags` と一部重複するが、APT は冪等にスキップするため副作用はない。

## 関連ドキュメント

- `docs/engineering-records/202605/20260519-1751-nfsordma-perf-tuning-ideas.md` — perftest を逐一導入・撤去していた運用の記録
- `docs/engineering-records/202605/20260519-0047-nfsordma-fio-benchmark.md` — fio 逐次導入・撤去の記録
- `docs/engineering-records/202605/20260519-1837-nfsordma-perf-tuning-result.md` — 撤去確認の記録

## 手動設定の方法

恒久運用としてはロール適用に統一するが、緊急時の単発作業として手動で導入する場合は以下のコマンドで等価である。

```bash
sudo apt install -y perftest infiniband-diags fio
```
