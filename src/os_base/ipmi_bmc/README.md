# IPMI BMC

IPMI 2.0 および Redfish 対応 BMC（Baseboard Management Controller）の管理ロールである。`bmc_protocol` 変数でプロトコルを切り替え、IPMI は `ipmitool`、Redfish は `community.general.redfish_command` / `redfish_info` モジュールを使用する。

## 前提条件

- BMC がネットワーク経由で到達可能であること
- 操作元ホスト（`bmc_delegate_host`）が BMC に到達できること
- IPMI の場合: 操作元ホストが Debian 系または RHEL 系 OS であること（`ipmitool` はロールが自動インストールする）
- Redfish の場合: 操作元ホストに `python3-urllib3` がインストールされていること（`community.general.redfish_*` モジュールが使用する）

## ロール変数

### 共通変数

| 変数名                   | デフォルト値 | 説明                                                   |
| ------------------------ | ------------ | ------------------------------------------------------ |
| `bmc_protocol`           | `ipmi`       | プロトコル選択（`ipmi` / `redfish`）                   |
| `bmc_delegate_host`      | （必須）     | BMC 操作を実行する委任先ホスト                         |
| `bmc_power_action`       | `status`     | 電源操作（status / on / off / reset / cycle / soft）   |
| `bmc_boot_device`        | `disk`       | ブートデバイス（disk / pxe / cdrom / bios）            |
| `bmc_boot_persistent`    | `false`      | ブートデバイス設定を永続化するか                       |
| `bmc_rotate_credentials` | `false`      | 認証情報ローテーションを実行するか                     |

### IPMI 固有変数

| 変数名                   | デフォルト値 | 説明                                                   |
| ------------------------ | ------------ | ------------------------------------------------------ |
| `bmc_ipmi_interface`     | `lanplus`    | IPMI インターフェース                                  |
| `bmc_ipmi_username`      | （必須）     | IPMI 認証ユーザー名                                    |
| `bmc_ipmi_password`      | （必須）     | IPMI 認証パスワード                                    |
| `bmc_new_ipmi_username`  | `""`         | 新しい IPMI ユーザー名（空の場合は変更しない）         |
| `bmc_new_ipmi_password`  | `""`         | 新しい IPMI パスワード（ローテーション時は必須）       |
| `bmc_ipmi_user_id`       | `2`          | IPMI ユーザー ID（Supermicro のデフォルトは 2）        |

### Redfish 固有変数

| 変数名                        | デフォルト値 | 説明                                                       |
| ----------------------------- | ------------ | ---------------------------------------------------------- |
| `bmc_redfish_username`        | `""`         | Redfish 認証ユーザー名                                     |
| `bmc_redfish_password`        | `""`         | Redfish 認証パスワード                                     |
| `bmc_redfish_validate_certs`  | `false`      | TLS 証明書を検証するか                                     |
| `bmc_redfish_resource_id`     | `Self`       | Redfish Systems リソース ID（ベンダーにより異なる）        |
| `bmc_new_redfish_username`    | `""`         | 新しい Redfish ユーザー名（空の場合は変更しない）          |
| `bmc_new_redfish_password`    | `""`         | 新しい Redfish パスワード（ローテーション時は必須）        |

## 電源操作マッピング

| `bmc_power_action` | IPMI コマンド        | Redfish コマンド         |
| ------------------- | -------------------- | ------------------------ |
| `status`            | `chassis power status` | `GetSystemInventory`   |
| `on`                | `chassis power on`   | `PowerOn`                |
| `off`               | `chassis power off`  | `PowerForceOff`          |
| `reset`             | `chassis power reset` | `PowerForceRestart`     |
| `cycle`             | `chassis power cycle` | `PowerForceRestart`     |
| `soft`              | `chassis power soft`  | `PowerGracefulShutdown` |

## ブートデバイスマッピング

| `bmc_boot_device` | IPMI デバイス名 | Redfish デバイス名 |
| ------------------ | --------------- | ------------------ |
| `disk`             | `disk`          | `Hdd`              |
| `pxe`              | `pxe`           | `Pxe`              |
| `cdrom`            | `cdrom`         | `Cd`               |
| `bios`             | `bios`          | `BiosSetup`        |

## タグ

| タグ             | 説明                       |
| ---------------- | -------------------------- |
| `bmc_power`      | 電源操作を実行する         |
| `bmc_boot`       | ブートデバイスを設定する   |
| `bmc_credential` | 認証情報をローテーションする |

## 使用方法

`site.yml` には含まれず、専用のプレイブックをタグ指定で実行する。プロトコルはインベントリの `bmc_protocol` 変数で自動選択される。

### 電源操作

```bash
ansible-playbook bmc.yml -l <bmc-host> -t bmc_power -e bmc_power_action=status
```

### ブートデバイス設定

```bash
ansible-playbook bmc.yml -l <bmc-host> -t bmc_boot -e bmc_boot_device=pxe
```

### 認証情報ローテーション（IPMI）

```bash
ansible-playbook bmc.yml -l <bmc-host> -t bmc_credential \
  -e bmc_rotate_credentials=true \
  -e bmc_new_ipmi_password='<new-password>'
```

### 認証情報ローテーション（Redfish）

```bash
ansible-playbook bmc.yml -l <bmc-host> -t bmc_credential \
  -e bmc_rotate_credentials=true \
  -e bmc_new_redfish_password='<new-password>'
```

実行後、新しいパスワードを Vault 暗号化してインベントリ変数を更新すること。

## 既知の制限事項

- Redfish の `cycle` は Redfish 標準仕様に `PowerCycle` が未定義のベンダーがあるため `PowerForceRestart` にマッピングしている
- `bmc_redfish_resource_id` はベンダーにより異なる（AMI MegaRAC / GIGABYTE: `Self`、Dell iDRAC: `System.Embedded.1` 等）
