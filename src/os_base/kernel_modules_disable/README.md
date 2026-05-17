# kernel_modules_disable

CISベンチマーク準拠で未使用カーネルモジュールをロード不可にするロール

## 概要

### このドキュメントの目的

このロールは、Ubuntu 24.04 LTSおよびAlmaLinux OS 10のCISベンチマークが推奨する「未使用カーネルモジュールの無効化」を一括で適用する。Ansible自動設定と手動設定の両方の方法を説明する。

### 実現される機能

- `kernel_modules_disable_enabled: true`のとき`/etc/modprobe.d/cis-disable-modules.conf`にCIS推奨モジュールの`install ... /bin/false`および`blacklist`を書き込む
- `kernel_modules_disable_enabled: false`(既定)のときは同ファイルが存在すれば削除する
- 必要に応じてinitramfsを再生成する(handler)
- オプションで実行中のモジュールをアンロードする

### 適用範囲とLXCの扱い

`site.yml`では`tofu_virtual:tofu_lxc:physical:legacy`に対して本ロールを適用しており、実際に有効化するかは`kernel_modules_disable_enabled`(`group_vars`側)で決める。新しいグループに適用範囲を広げたい場合も`site.yml`の編集は不要で、対象グループの`group_vars`で本変数を`true`にするだけでよい。

### 対象モジュール

| カテゴリー             | モジュール                                                                  |
| ---------------------- | --------------------------------------------------------------------------- |
| ファイルシステム       | `cramfs`, `freevxfs`, `hfs`, `hfsplus`, `jffs2`, `udf`                      |
| ネットワーク(用途特殊) | `dccp`, `tipc`, `rds`, `sctp`, `atm`, `can`, `can_raw`, `can_bcm`, `can_gw` |
| ネットワーク(レガシー) | `ax25`, `netrom`, `rose`, `x25`                                             |
| ライン規律             | `n_hdlc`                                                                    |
| IPsec関連              | `esp4`, `esp6`, `ipcomp4`, `ipcomp6`                                        |
| RPC / 暗号             | `rxrpc`, `algif_aead`                                                       |

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

- Ubuntu 24.04 LTSまたはAlmaLinux OS 10(他のDebian/RHEL系でも動作する想定)
- root権限

### Ansible固有の要件

- Ansible 2.14以上
- `community.general`コレクション(`modprobe`モジュール使用、`kernel_modules_disable_unload_running: true`時のみ)
- プレイブックレベルで`become: true`

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                                  | デフォルト             | 説明                                                                                                                                     |
| --------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `kernel_modules_disable_enabled`        | `false`                | `true`でCISモジュール無効化を有効にする。`false`のときは`/etc/modprobe.d/cis-disable-modules.conf`が存在すれば削除する                   |
| `kernel_modules_disable_list`           | 上記対象モジュール一覧 | 無効化するモジュールのリスト。各要素は`name`/`cis`/`note`を持つ                                                                          |
| `kernel_modules_disable_unload_running` | `false`                | `true`の場合、適用時点で実行中のモジュールを`rmmod`相当でアンロードする。既存サービスへの影響を避けたい場合は`false`のまま次回起動で反映 |

#### 依存関係

なし

#### タグとハンドラー

- ハンドラー: `rebuild initramfs`(Ubuntuは`update-initramfs -u`、AlmaLinuxは`dracut --force`)

#### 使用例

基本(設定書き込みのみ、再起動時に反映)：

```yaml
- hosts: tofu_virtual:tofu_lxc:physical:legacy
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
