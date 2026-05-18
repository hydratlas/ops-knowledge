# opensm

InfiniBand Subnet Manager (OpenSM) を systemd テンプレート経由でポート GUID 単位に常駐させるロール

## 概要

### このドキュメントの目的

InfiniBand ファブリックでは各サブネットごとに 1 つの Subnet Manager (SM) が LID 配布・経路設定を行う必要がある。本ロールは OpenSM をインストールし、ホスト上の **各 IB ポートに対して独立した OpenSM プロセス**を systemd template unit `opensm@<port-guid>.service` として起動する。これにより、HCA の port1 と port2 が別々のサブネットに繋がる構成（直結 2 リンクなど）でもポート単位で正しく SM を割り当てられる。

### 実現される機能

- `opensm`、`infiniband-diags`、`rdma-core` パッケージの導入
- Ubuntu 同梱の単一インスタンス `opensm.service` の mask / disable
- `/etc/systemd/system/opensm@.service` テンプレートユニットの配置
- IB ポート GUID の自動検出（または host_vars での明示指定）
- 検出したポート GUID ごとに `opensm@<guid>.service` を enable & start

## 適用対象

OpenSM ホスト（典型的には IB ファブリックのサブネット管理を集中させる 1 台）にのみ適用する。直結相手側でも OpenSM を動かすとマスタ選出と切替時の瞬断要因になるため、本ロールを意図しないホストへ広げない。

## 要件と前提条件

- Debian/Ubuntu 系 OS
- `mlx4` または `mlx5` 等の HCA が認識されており、`link_layer=InfiniBand` のポートが存在すること
- カーネルが `phys_state=5: LinkUp` まで到達していること（SM がいないため `state=INIT` で止まっている状態が想定）
- 物理層リンクが上がる前段として、`network/mellanox_mft`（CX3 系の NV config 整備）と `network/mlx4_port_types`（port_type_array 設定）が適用済みであること

## ロール変数

| 変数名                       | デフォルト                                                          | 説明                                                                                                                          |
| ---------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `opensm_packages`            | `[opensm, infiniband-diags, rdma-core]`                             | 導入するパッケージリスト                                                                                                      |
| `opensm_port_guids`          | `[]`                                                                | 起動対象とするポート GUID（16桁hex）の配列。空のときは `/sys/class/infiniband/*/ports/*/gids/0` から自動検出する               |
| `opensm_log_dir`             | `/var/log/opensm`                                                   | OpenSM のログ出力先                                                                                                           |
| `opensm_unit_path`           | `/etc/systemd/system/opensm@.service`                               | テンプレートユニットの配置先                                                                                                  |
| `opensm_default_unit_mask`   | `true`                                                              | パッケージ同梱の単一インスタンス `opensm.service` を mask するかどうか                                                        |

## 依存関係

- `network/mellanox_mft`（ConnectX-3 系のみ。NV config 整備）
- `network/mlx4_port_types`（mlx4 系の場合のみ）

## 使用例

```yaml
- hosts: nas_physical
  become: true
  roles:
    - role: network/opensm
```

GUID を明示指定する場合は host_vars で:

```yaml
opensm_port_guids:
  - "ec0d9affffe81685"
  - "ec0d9affffe81686"
```

## ポート GUID の取得方法

`/sys/class/infiniband/<dev>/ports/<n>/gids/0` の出力（IPv6 表記）の下位 64 bit を結合する。例:

```
fe80:0000:0000:0000:ec0d:9aff:ffe8:1685
                    ^^^^^^^^^^^^^^^^^^^^
                    → ec0d9affffe81685
```

ロール内ではこの変換を `awk -F:` でシェル実行している。

## 注意点

- OpenSM プロセスが停止すると、SM が `SWEEP_INTERVAL` 内で見ているサブネットの LID 配布が止まり、新規 QP 確立が失敗する。`systemd` の `Restart=on-failure` を有効化しているが、`Prometheus`/Alloy 等のプロセス監視に組み込むことを推奨する。
- 直結 2 サブネット構成では、対向側（oz/polaris 等）には OpenSM を入れない。standby SM が必要な場合は別途設計する。
- `/usr/sbin/opensm -B` はバックグラウンド (forking) で動く。`Type=forking` + `PIDFile` でその挙動に合わせている。
- IB ポートが未認識の状態でロールを適用すると `assert` で停止する。先に `mlx4_port_types` などの前提ロールを通すこと。
