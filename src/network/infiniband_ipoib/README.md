# infiniband_ipoib

ConnectX-3 上で IPoIB Connected Mode を構成するロール

## 概要

### このドキュメントの目的

IB ファブリックが ACTIVE 化した後段で、Linux 側に IPoIB インターフェースを Connected Mode（CM）で生やし、`hi` セグメント (`10.130.0.0/16`) の /30 アドレスを採番する。Netplan による IP 設定と、udev ルールによる `mode=connected` 切替を組み合わせる。

### 実現される機能

- `rdma-core` 等の IPoIB / RDMA ユーザー空間パッケージの導入
- `/etc/modules-load.d/infiniband-ipoib.conf` で `ib_ipoib`/`rdma_cm`/`ib_umad` をブート時にロード
- `/etc/udev/rules.d/90-ipoib-mode.rules` で IPoIB インターフェース (ARPHRD_INFINIBAND, type=32) を Connected Mode に設定
- `/etc/netplan/90-infiniband.yaml` で IP/MTU を設定（MTU 65520）
- `/etc/hosts` に対向ピアのホスト名を追記
- 既存インターフェースが datagram のままなら即時 connected に切り替え、netplan apply を発火

## 要件と前提条件

- 事前に [`network/mlx4_port_types`](../mlx4_port_types/) で `port_type_array=1,1` を投入し、ポートが IB モードで `ACTIVE` 化していること
- 上流のサブネットに Subnet Manager（[`network/opensm`](../opensm/)）が動作していること
- ConnectX-3 非搭載ホスト、または `infiniband_ipoib_interfaces` が空のホストでは `meta: end_host` でスキップ

## ロール変数

| 変数名                              | デフォルト                                  | 説明                                                                  |
| ----------------------------------- | ------------------------------------------- | --------------------------------------------------------------------- |
| `infiniband_ipoib_packages`         | `[rdma-core]`                               | 導入するパッケージ                                                    |
| `infiniband_ipoib_modules`          | `[ib_ipoib, rdma_cm, ib_umad]`              | `modules-load.d` 経由でブート時にロードするカーネルモジュール         |
| `infiniband_ipoib_mode`             | `connected`                                 | IPoIB リンク種別（`connected` / `datagram`）                          |
| `infiniband_ipoib_mtu`              | `65520`                                     | netplan で設定する MTU                                                |
| `infiniband_ipoib_interfaces`       | `[]`                                        | IPoIB インターフェース定義（`name` と `address` を持つ dict のリスト） |
| `infiniband_ipoib_hosts_entries`    | `[]`                                        | `/etc/hosts` に追記するエントリー（`ip` と `names` を持つ dict のリスト） |
| `infiniband_ipoib_netplan_path`     | `/etc/netplan/90-infiniband.yaml`           | netplan 配置先                                                        |
| `infiniband_ipoib_modules_load_path`| `/etc/modules-load.d/infiniband-ipoib.conf` | modules-load.d 配置先                                                 |
| `infiniband_ipoib_udev_rule_path`   | `/etc/udev/rules.d/90-ipoib-mode.rules`     | udev ルール配置先                                                     |

## ハンドラー

- `udev-reload-trigger`: `udevadm control --reload` + `udevadm trigger --subsystem-match=net --action=change`
- `netplan-apply`: `netplan apply`

## 使用例

`host_vars/nas2024-ssd.int.home.arpa.yml`:

```yaml
infiniband_ipoib_interfaces:
  - name: ibp65s0       # mlx4_0 port1, Link A (→ oz)
    address: 10.130.61.1/30
  - name: ibp65s0d1     # mlx4_0 port2, Link B (→ polaris)
    address: 10.130.61.5/30
infiniband_ipoib_hosts_entries:
  - ip: 10.130.61.1
    names: nas2024-ssd-hi-oz.hi.home.arpa
  - ip: 10.130.61.2
    names: oz-hi.hi.home.arpa
  - ip: 10.130.61.5
    names: nas2024-ssd-hi-polaris.hi.home.arpa
  - ip: 10.130.61.6
    names: polaris-hi.hi.home.arpa
```

## 注意点

- 起動時の動作は udev ルールに依存する。IPoIB インターフェースが `add` イベントで現れた時点で `mode=connected` が書き込まれ、その後 netplan が MTU/IP を設定する。
- mode を datagram から connected に切り替えると IPoIB インターフェースがリセットされる。本ロールは適用時にも `netplan apply` をかけて IP を貼り直す。
- 純粋な IB ネイティブ RDMA（NFSoRDMA）の listen には IPoIB の IP が使われる（RDMA CM）。L2 完結のため iptables での制御はできない点に注意。
