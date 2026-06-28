# kernel_modules_disable

CISベンチマーク準拠で未使用カーネルモジュールをロード不可にするロール

## 概要

### このドキュメントの目的

このロールは、各ディストリビューションのCISベンチマークが推奨する「未使用カーネルモジュールの無効化」を一括で適用する。Ansible自動設定と手動設定の両方の方法を説明する。

無効化対象のモジュールリストはディストリビューションをまたいで実質的に共通化できるため、`defaults/main.yml`の`kernel_modules_disable_list`に単一のフルセットとして定義している。`install <module> /bin/false`はカーネルに該当モジュールが存在しなくても害がないため、新しいkernelで削除済みのレガシーモジュールも含めて全ホストに同一リストを適用している。各CISベンチマークでの章番号対応は後述の[CISベンチマーク章番号対応表](#cisベンチマーク章番号対応表)を参照のこと。

### 実現される機能

- `kernel_modules_disable_enabled: true`のとき`/etc/modprobe.d/cis-disable-modules.conf`にCIS推奨モジュールの`install ... /bin/false`および`blacklist`を書き込む
- `kernel_modules_disable_enabled: false`(既定)のときは同ファイルが存在すれば削除する
- 必要に応じてinitramfsを再生成する(handler)。ただしinitramfs再生成ツールが存在しないホスト(initrd無しのminimalクラウドイメージ等)ではハンドラーをスキップし、modprobe.dのランタイム抑止のみでCIS目的を満たす
- オプションで実行中のモジュールをアンロードする

### 適用範囲とLXCの扱い

`site.yml`では`tofu_virtual:general:legacy`に対して本ロールを適用しており、実際に有効化するかは`kernel_modules_disable_enabled`(`group_vars`側)で決める。LXC(`tofu_lxc`)はホストカーネルを共有するため対象外、VyOS(`rt-*`)は独自イメージのため対象外としている。

### 対応ディストリビューション

| 対象                   | 参照CISベンチマーク                                           |
| ---------------------- | ------------------------------------------------------------- |
| Ubuntu 24.04 LTS       | CIS Benchmark v1.0.0                                          |
| Ubuntu 20.04 LTS       | CIS Benchmark v2.0.1                                          |
| Debian 13 (Trixie)     | (Ubuntu 24.04と同等を採用、Debian固有のCIS Benchmarkは未公開) |
| AlmaLinux 10 / RHEL 10 | CIS Benchmark v1.0.0                                          |
| CentOS 7 / RHEL 7      | CIS Benchmark v3.1.1                                          |
| CentOS 6 / RHEL 6      | CIS Benchmark v2.0.0                                          |

### 対象モジュール

全ディストリビューションで以下のフルセットを適用する。

| カテゴリー                                         | モジュール                                                                  |
| -------------------------------------------------- | --------------------------------------------------------------------------- |
| ファイルシステム                                   | `cramfs`, `freevxfs`, `hfs`, `hfsplus`, `jffs2`, `udf`                      |
| ネットワーク(用途特殊)                             | `dccp`, `tipc`, `rds`, `sctp`, `atm`, `can`, `can_raw`, `can_bcm`, `can_gw` |
| ネットワーク(レガシー・一般)                       | `ax25`, `netrom`, `rose`, `x25`                                             |
| ネットワーク(レガシー・AppleTalk関連)              | `appletalk`, `p8022`, `p8023`, `psnap`, `llc`                               |
| ネットワーク(レガシー・新しいカーネルでは削除済み) | `decnet`, `ipx`                                                             |
| ライン規律                                         | `n_hdlc`                                                                    |
| IPsec関連                                          | `esp4`, `esp6`, `ipcomp4`, `ipcomp6`                                        |
| RPC / 暗号                                         | `rxrpc`, `algif_aead`                                                       |

### CISベンチマーク章番号対応表

各CISベンチマークでの章番号は以下のとおり。`-`は当該ベンチマークで明示的な推奨項目が無いもの(セキュリティ対策として本ロールが独自に含めているモジュール)。

#### ファイルシステム

| モジュール | Ubuntu 24.04 v1.0.0 | Ubuntu 20.04 v2.0.1 | Debian 13        | RedHat 10 v1.0.0   | RedHat 7 v3.1.1 | RedHat 6 v2.0.0 |
| ---------- | ------------------- | ------------------- | ---------------- | ------------------ | --------------- | --------------- |
| `cramfs`   | L1 1.1.1.1          | L1 1.1.1.1          | Ubuntu 24.04準拠 | L1 1.1.1.1         | L1 1.1.1.1      | L1 1.1.1.1      |
| `freevxfs` | L1 1.1.1.2          | L1 1.1.1.2          | 〃               | L1 1.1.1.2         | L1 1.1.1.2      | L1 1.1.1.2      |
| `hfs`      | L1 1.1.1.3          | L1 1.1.1.4          | 〃               | L1 1.1.1.3         | L1 1.1.1.4      | L1 1.1.1.4      |
| `hfsplus`  | L1 1.1.1.4          | L1 1.1.1.5          | 〃               | L1 1.1.1.4         | L1 1.1.1.5      | L1 1.1.1.5      |
| `jffs2`    | L1 1.1.1.5          | L1 1.1.1.3          | 〃               | L1 1.1.1.5         | L1 1.1.1.3      | L1 1.1.1.3      |
| `udf`      | L2 1.1.1.7/1.1.1.8  | L1 1.1.1.7          | 〃               | L2 1.1.1.7/1.1.1.8 | L2 1.1.1.7      | L2 1.1.1.7      |

#### ネットワークプロトコル(用途特殊)

| モジュール | Ubuntu 24.04 v1.0.0 | Ubuntu 20.04 v2.0.1 | Debian 13        | RedHat 10 v1.0.0 | RedHat 7 v3.1.1 | RedHat 6 v2.0.0 |
| ---------- | ------------------- | ------------------- | ---------------- | ---------------- | --------------- | --------------- |
| `dccp`     | L2 3.2.1            | L2 3.4.1            | Ubuntu 24.04準拠 | L2 3.2.1         | L2 3.5.1        | L2 4.4.1        |
| `tipc`     | L2 3.2.2            | L2 3.4.4            | 〃               | L2 3.2.2         | L2 3.5.4        | L2 4.4.4        |
| `rds`      | L2 3.2.3            | L2 3.4.3            | 〃               | L2 3.2.3         | L2 3.5.3        | L2 4.4.3        |
| `sctp`     | L2 3.2.4            | L2 3.4.2            | 〃               | L2 3.2.4         | L2 3.5.2        | L2 4.4.2        |

#### その他(全ディストリビューションでCIS推奨外の追加無効化)

`atm`、`can`系、`ax25`/`netrom`/`rose`/`x25`/`decnet`/`appletalk`/`ipx`/`p8022`/`p8023`/`psnap`/`llc`、`n_hdlc`、`esp4`/`esp6`/`ipcomp4`/`ipcomp6`、`rxrpc`、`algif_aead`はいずれのCISベンチマークにも明示的な項目は無いが、過去のLPE脆弱性実績や用途の特殊性を踏まえ本ロールで一律に無効化している。

### 対象外モジュール(意図的に維持)

- `usb-storage`: USBストレージを業務で利用するため
- `overlay` / `overlayfs`: コンテナイメージのoverlayfsで必要
- `squashfs`: liveイメージおよびsnap等で必要

### 注意事項

- IPsec関連(`esp4`/`esp6`/`ipcomp4`/`ipcomp6`)を無効化しているため、IPsec VPN(StrongSwan/Libreswan)を新規導入する場合はリストから除外すること
- `sctp`を無効化しているため、SIP/Diameter等のテレコムスタックを動かす場合はリストから除外すること
- `rds`はOracle RAC interconnectで使用される。Oracle RAC環境では除外すること

## 要件と前提条件

### 共通要件

- Ubuntu 24.04/20.04 LTS、Debian 13、AlmaLinux OS 10、CentOS 7/6 のいずれか
- root権限

### Ansible固有の要件

- Ansible 2.14以上
- `community.general`コレクション(`modprobe`モジュール使用、`kernel_modules_disable_unload_running: true`時のみ)
- プレイブックレベルで`become: true`

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                                  | デフォルト                | 説明                                                                                                                                     |
| --------------------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `kernel_modules_disable_enabled`        | `false`                   | `true`でCISモジュール無効化を有効にする。`false`のときは`/etc/modprobe.d/cis-disable-modules.conf`が存在すれば削除する                   |
| `kernel_modules_disable_list`           | `defaults/main.yml`で定義 | 無効化するモジュールのリスト。各要素は`name`と`note`を持つ。全ディストリビューション共通のフルセットを既定値としている                   |
| `kernel_modules_disable_unload_running` | `false`                   | `true`の場合、適用時点で実行中のモジュールを`rmmod`相当でアンロードする。既存サービスへの影響を避けたい場合は`false`のまま次回起動で反映 |

#### 依存関係

なし

#### タグとハンドラー

- ハンドラー: `rebuild initramfs`(Ubuntuは`update-initramfs -u`、AlmaLinuxは`dracut --force`)
- ハンドラーはinitramfs再生成ツールの存在検出でガードされ、ツールが無いホストではスキップされる。検出パスはos_family別マップ`kernel_modules_disable_initramfs_tool`(既定: Debian=`/usr/sbin/update-initramfs`、RedHat=`/usr/bin/dracut`)で定義し、非標準配置のホストがあれば上書きできる

#### 使用例

基本(設定書き込みのみ、再起動時に反映)：

```yaml
- hosts: tofu_virtual:general
  become: true
  roles:
    - role: os_base/kernel_modules_disable
```

実際に有効化したいグループの`group_vars`で次のように指定する。

```yaml
kernel_modules_disable_enabled: true
```

実行中モジュールも即時アンロードする例：

```yaml
- hosts: tofu_virtual
  become: true
  roles:
    - role: os_base/kernel_modules_disable
      vars:
        kernel_modules_disable_enabled: true
        kernel_modules_disable_unload_running: true
```

### 方法2: 手動での設定手順

`/etc/modprobe.d/cis-disable-modules.conf`に対象モジュールごとに以下の2行を書き込む。

```
install <module> /bin/false
blacklist <module>
```

書き込み後、Ubuntuは`sudo update-initramfs -u`、AlmaLinuxは`sudo dracut --force`でinitramfsを再生成する。次回起動でautoload抑止が有効になる。

実行中のモジュールを即時アンロードする場合は`sudo modprobe -r <module>`。依存先がある場合は依存モジュールから先にアンロードする。

## 運用管理

### 確認方法

設定が反映されているかの確認：

```bash
# 全モジュールに対するinstall設定を一覧
modprobe --showconfig | grep -E '^(install|blacklist) (cramfs|udf|sctp|dccp|tipc|rds)'

# 明示的にロード試行(失敗するはず)
sudo modprobe cramfs && echo "FAIL: loaded" || echo "OK: blocked"

# 現在ロードされているモジュール一覧
lsmod
```

### トラブルシューティング

- **問題**: あるアプリケーションが起動しなくなった
  - **対処**: 該当モジュールを`kernel_modules_disable_list`から除外して再適用する
- **問題**: 設定したのにモジュールがロードされる
  - **対処**: initramfsから読み込まれている可能性。`update-initramfs -u`または`dracut --force`を実行して再起動する
- **問題**: ハンドラー`Rebuild initramfs`が`skipping`になる
  - **対処**: 正常な挙動。initrd無しのminimalクラウドイメージ等では`update-initramfs`/`dracut`が存在せずinitramfs再生成は不要なため、ハンドラーをスキップする。modprobe.dのランタイム抑止のみでCIS目的は達成される。なお`os_base/apt_no_recommends`ロールによりカーネル更新時の`initramfs-tools`流入が抑止されるため、minimalイメージでは今後も同ツールが導入されずスキップが維持される
- **問題**: `usb-storage`まで無効化されてしまった
  - **対処**: 本ロールは`usb-storage`を対象としていない。他のロールや手動設定を確認する

## アンインストール（手動）

```bash
sudo rm /etc/modprobe.d/cis-disable-modules.conf
# Ubuntu
sudo update-initramfs -u
# AlmaLinux
sudo dracut --force
sudo reboot
```
