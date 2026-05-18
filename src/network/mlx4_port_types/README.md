# mlx4_port_types

ConnectX-3 (mlx4_core) のポートモードを起動時から強制するロール

## 概要

### このドキュメントの目的

ConnectX-3 系 HCA は両ポートで InfiniBand と Ethernet を切替可能な VPI 設計だが、Linux の `mlx4_core` モジュールは boot 時の port mode を `modprobe options mlx4_core port_type_array=<P1>,<P2>` で決定する。本ロールは `/etc/modprobe.d/mlx4_core.conf` を Ansible 管理下に置き、3 台（`nas2024-ssd`、`oz`、`polaris`）で IB モードを揃える。

### 実現される機能

- `/etc/modprobe.d/mlx4_core.conf` の冪等な配置
- ConnectX-3 非搭載ホストでは `meta: end_host` でスキップ
- 設定変更時にハンドラ経由で `mlx4_*` モジュールを reload し、再起動なしで反映

## 要件と前提条件

- Linux カーネル `mlx4_core` を含むこと（ConnectX-3 標準）
- `lspci` が利用可能であること
- NV config (`LINK_TYPE_P[12]`) が `VPI(3)` または対応値であること
  - `LINK_TYPE_P*=ETH(2)` 固定の HCA では `port_type_array=1,1` を書いてもドライバー側で拒否される
  - 該当する場合は事前に `network/mellanox_mft` ロール + `mlxconfig set LINK_TYPE_P*=3` で NV config を整える

## ロール変数

| 変数名                       | デフォルト                       | 説明                                                                  |
| ---------------------------- | -------------------------------- | --------------------------------------------------------------------- |
| `mlx4_port_types_array`      | `1,1`                            | `port_type_array` の値。`1=IB`、`2=ETH`、`3=auto`。両ポート個別に指定 |
| `mlx4_port_types_conf_path`  | `/etc/modprobe.d/mlx4_core.conf` | 配置先パス                                                            |

## 依存関係

なし（NV config の準備は `network/mellanox_mft` 等が別途担当）

## ハンドラー

- `reload-mlx4`: `modprobe -r ib_ipoib mlx4_ib mlx4_en mlx4_core` → `modprobe mlx4_core mlx4_ib mlx4_en`

## 使用例

```yaml
- hosts: nas_physical:slurm_compute_physical
  become: true
  roles:
    - network/mlx4_port_types
```

ホスト個別に値を変えたい場合は `host_vars` で `mlx4_port_types_array` を上書きする。

## 注意点

- ハンドラ起動中は IB/Ethernet (mlx4_en 経由) の通信が瞬断する。本番では事前に Slurm ジョブの drain、NFS クライアントの停止等を検討すること。
- ConnectX-4 以降は `mlx5_core` が担当するため本ロールは関与しない。新世代カード向けには別ロールを用意する。
- `port_type_array` で要求できる port type は、firmware が `caps.supported_type` で広告するビット範囲内に限る。範囲外を指定すると `mlx4_core: Requested port type for port N is not supported on this HCA` が dmesg に出て初期化に失敗する。
