# nvme_disable_multipath

NVMe マルチパス（`nvme_core.multipath`）を無効化するカーネルパラメーターを GRUB に注入するロール。

## 概要

### このドキュメントの目的

このロールは、複数の NVMe ドライブが同一の NGUID/EUI64 を報告する不具合を持つホスト（例: ADATA LEGEND 960 の一部ファームウェア）に対して、`nvme_core.multipath=N` をカーネルコマンドラインに追加することで、duplicate IDs に起因するデータ破損リスクを根絶する。Ansible 自動設定と手動設定の両方の方法を説明する。

### 背景

Linux カーネルは `nvme_core.multipath=Y`（Ubuntu の既定）で動作する場合、同一 NGUID/EUI64 を持つ namespace を「マルチパス」として束ねる。ところが ADATA LEGEND 960 のように複数の独立した物理ドライブが同じ NGUID を返すファームウェアバグがあると、カーネルはそれらを 1 つの namespace と誤認するおそれがある。最新の Linux カーネルは起動時に重複 ID を検出して `clearing duplicate IDs for nsid <N>` のメッセージとともに NGUID を防御的にクリアするが、その際に「`use of /dev/disk/by-id/ may cause data corruption`」という警告も出力する。

`nvme_core.multipath=N` を渡すと NVMe マルチパス機構そのものが無効化され、duplicate IDs の検出ロジックも走らないため、上記の警告と潜在リスクをまとめて回避できる。

### 実現される機能

- `nvme_disable_multipath_enabled: true` のとき `/etc/default/grub.d/99-nvme-disable-multipath.cfg` を配置し、`GRUB_CMDLINE_LINUX` に `nvme_core.multipath=N` を追加する
- `nvme_disable_multipath_enabled: false`（既定）のときは同ファイルが存在すれば削除する
- 変更時は handler から `update-grub`（Debian/Ubuntu）または `grub2-mkconfig`（RHEL/AlmaLinux）を実行する

### 反映タイミング

カーネルパラメーターのため**反映には再起動が必要**である。本ロール単体ではホストを再起動しない。計画停止のタイミングで再起動を実施すること。

### 適用範囲

`site.yml` では物理マシン全般（`general`）と仮想マシン（`tofu_virtual`）に対して本ロールを適用しており、実際に有効化するかは `nvme_disable_multipath_enabled` を `host_vars`/`group_vars` で `true` にして制御する。

LXC（`tofu_lxc`）はホストカーネルを共有するため対象外、VyOS（`rt-*`）は独自イメージのため対象外としている。

### 既知の該当ホスト

| ホスト         | 該当ドライブ          | 備考                                                    |
| -------------- | --------------------- | ------------------------------------------------------- |
| `nas2024-ssd`  | ADATA LEGEND 960 × 4  | `dmesg` に `clearing duplicate IDs for nsid 1` を観測   |

## 要件と前提条件

### 共通要件

- Ubuntu 24.04/20.04 LTS、Debian 13、AlmaLinux OS 10、CentOS 7/6 のいずれか
- GRUB によりブートしていること（EFI/BIOS いずれも可）
- root 権限

### Ansible 固有の要件

- Ansible 2.14 以上
- プレイブックレベルで `become: true`

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名                                | デフォルト                                       | 説明                                                                                                |
| ------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| `nvme_disable_multipath_enabled`      | `false`                                          | `true` で `nvme_core.multipath=N` を有効にする。`false` のときはドロップインファイルが存在すれば削除する |
| `nvme_disable_multipath_dropin_path`  | `/etc/default/grub.d/99-nvme-disable-multipath.cfg` | 配置するドロップインのパス                                                                          |

#### 依存関係

なし

#### タグとハンドラー

- ハンドラー: `update grub`（Debian/Ubuntu は `update-grub`、RHEL/AlmaLinux は `grub2-mkconfig`）

#### 使用例

`site.yml` でのプレイ呼び出し例：

```yaml
- hosts: general:tofu_virtual
  become: true
  roles:
    - role: os_base/nvme_disable_multipath
```

該当ホストの `host_vars` で有効化する例（nas2024-ssd）：

```yaml
nvme_disable_multipath_enabled: true
```

### 方法2: 手動での設定手順

`/etc/default/grub.d/99-nvme-disable-multipath.cfg` を以下の内容で作成する。

```
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX nvme_core.multipath=N"
```

その後 Debian/Ubuntu では `sudo update-grub`、RHEL/AlmaLinux では `sudo grub2-mkconfig -o /boot/grub2/grub.cfg` を実行し、ホストを再起動する。

## 運用管理

### 確認方法

ドロップインが配置され GRUB 設定に反映されているか：

```bash
cat /etc/default/grub.d/99-nvme-disable-multipath.cfg
sudo grep -E 'linux\s+/.*vmlinuz' /boot/grub/grub.cfg | head -3
```

再起動後にカーネルパラメーターが効いているか：

```bash
cat /proc/cmdline | tr ' ' '\n' | grep nvme_core
# => nvme_core.multipath=N
```

`dmesg` から `clearing duplicate IDs for nsid` メッセージが消えていれば対策完了。

### トラブルシューティング

- **問題**: 再起動後も `/proc/cmdline` に `nvme_core.multipath=N` が現れない
  - **対処**: `update-grub` が実行されたかを確認。EFI 環境では `/boot/grub/grub.cfg` ではなく `/boot/efi/EFI/<distro>/grub.cfg` を参照している場合もあるため両方を確認する
- **問題**: マルチパス無効化により従来のデバイスパス（`/dev/nvme<N>c<M>n<X>`）が消えた
  - **対処**: 本パラメーターの想定挙動。`/dev/nvme<N>n<X>` を直接利用すること。fstab で UUID 参照していれば影響はない

## アンインストール（手動）

```bash
sudo rm /etc/default/grub.d/99-nvme-disable-multipath.cfg
sudo update-grub   # AlmaLinux は sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo reboot
```
