# mellanox_mft

NVIDIA Mellanox Firmware Tools (MFT) インストールロール

## 概要

### このドキュメントの目的

このロールは、Mellanox/NVIDIA 製 NIC の firmware 管理および NV configuration 操作を行うための proprietary MFT パッケージ（`mlxconfig`、`flint`、`mst` を含む）を Debian/Ubuntu 系ホストに導入する。Ubuntu 標準の `mstflint` パッケージは ConnectX-3 系（Device ID 4099）の `mstconfig` 実装を欠くため、ConnectX-3 の NV config（`LINK_TYPE_P[12]` 等）を読み書きするには proprietary MFT が必須となる。

### 実現される機能

- 既存 `mstflint` パッケージの撤去
- MFT 4.21.0-99 の SHA256 検証付きダウンロードと展開
- 同梱 `install.sh` による `mft` および `kernel-mft-dkms` の導入（DKMS で `mst_pci` / `mst_pciconf` カーネルモジュールを現行カーネル向けにビルド）
- インストール直後の `mst start` 実行による `/dev/mst/*` 生成

## 採用バージョンの根拠

ConnectX-3 を扱う本ロールでは MFT **4.21.0-99** を既定とする。MFT 4.31.0-149 はサポートカード一覧に ConnectX-3 を載せているが、Ubuntu 24.04 (noble) + 6.8 系カーネル環境で `mst start` がランタイム検出に失敗し `/dev/mst/*` が生成されない事象を確認している。4.21.0-99 は同環境で正常動作する。新しいバージョンに切り替える際は事前に対象ホストで `mst status -v` が ConnectX-3 を列挙することを必ず確認すること。

## 要件と前提条件

### 共通要件

- Debian/Ubuntu 系 OS
- root 権限または sudo 権限
- インターネット接続（`mellanox.com` への HTTPS GET）
- Mellanox/NVIDIA 製 PCI NIC が搭載されていること（ConnectX-3 以降）

### Ansible 固有の要件

- `become: true` の指定が必要
- `ansible.builtin.apt` / `ansible.builtin.get_url` / `ansible.builtin.unarchive` の利用

### 手動設定の要件

- `curl`、`tar`、`dpkg`、`apt`、`dkms`

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名                          | デフォルト                                                                                          | 説明                                                                                |
| ------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `mellanox_mft_version`          | `4.21.0-99`                                                                                         | 導入する MFT のバージョン。`dpkg` の `mft` パッケージ Version と一致判定に使う      |
| `mellanox_mft_arch`             | `x86_64`                                                                                            | アーキテクチャ                                                                      |
| `mellanox_mft_pkg_basename`     | `mft-{{ version }}-{{ arch }}-deb`                                                                  | tgz の basename                                                                     |
| `mellanox_mft_download_url`     | `https://www.mellanox.com/downloads/MFT/{{ pkg_basename }}.tgz`                                     | 取得元 URL                                                                          |
| `mellanox_mft_download_sha256`  | `215ff22d42ec69c571618d03d0979e0530122731d9b6e68d30eee524f588d468`                                  | tgz の SHA256                                                                       |
| `mellanox_mft_workdir`          | `/opt/mft`                                                                                          | tgz 展開先ディレクトリ                                                              |
| `mellanox_mft_remove_mstflint`  | `true`                                                                                              | Ubuntu 標準 `mstflint` を取り外すかどうか                                           |
| `mellanox_mft_enable_service`   | `true`                                                                                              | インストール後に `mst start` を実行して `/dev/mst/*` を生成するかどうか             |

#### 依存関係

なし

#### タグとハンドラー

- タグ: なし
- ハンドラー: なし

#### 使用例

```yaml
- hosts: nas_physical
  become: true
  roles:
    - network/mellanox_mft
```

特定のホストだけで適用する場合は host_vars で変数を上書きするか、`hosts:` を絞る。

### 方法2: 手動での設定手順

```bash
# 既存の mstflint を撤去
sudo apt-mark unhold mstflint 2>/dev/null || true
sudo apt-get -y remove mstflint

# ビルド依存
sudo apt-get -y install gcc make dkms linux-headers-$(uname -r)

# MFT 4.21.0-99 取得とインストール
sudo install -d -m 0755 /opt/mft
cd /opt/mft
sudo curl -fSL -o mft-4.21.0-99-x86_64-deb.tgz \
  https://www.mellanox.com/downloads/MFT/mft-4.21.0-99-x86_64-deb.tgz
echo '215ff22d42ec69c571618d03d0979e0530122731d9b6e68d30eee524f588d468  mft-4.21.0-99-x86_64-deb.tgz' \
  | sha256sum -c -
sudo tar xzf mft-4.21.0-99-x86_64-deb.tgz
sudo /opt/mft/mft-4.21.0-99-x86_64-deb/install.sh

# デバイスノード生成と動作確認
sudo mst start
sudo mst status -v
sudo mlxconfig -d /dev/mst/mt4099_pciconf0 q
```

## 注意点

- MFT 4.21.0-99 同梱の `/etc/systemd/system/mst.service` は SysV init script 形式で書かれており systemd unit として起動できない。本ロールでは有効化しない。
- `/dev/mst/*` は再起動で消えるため、起動時の自動ロードは行わない方針とする。再起動後に `mlxconfig` 等を使う際は `sudo mst start` を実行する。
- proprietary MFT は `/usr/bin/mst*` を含む複数の名前空間で Ubuntu 標準 `mstflint` と競合する。`mellanox_mft_remove_mstflint: false` で取り外しを抑止すると壊れる可能性が高い。
- ConnectX-3 用に固定された 4.21.0-99 を ConnectX-4 以降のホストで使うこと自体は問題ないが、新世代カードの新機能（NV config キー）にアクセスできない場合がある。新世代カードしかないホストでは MFT 最新版を別の変数組で導入することを推奨する。
