# IPMI BMC

Supermicro 等の IPMI 2.0 対応 BMC（Baseboard Management Controller）の管理ロールである。`ipmitool` を使用してリモートから電源操作・ブートデバイス設定・認証情報管理を行う。

## 前提条件

- BMC がネットワーク経由で到達可能であること
- 操作元ホスト（`bmc_delegate_host`）が Debian 系または RHEL 系 OS であること（`ipmitool` はロールが自動インストールする）

## ロール変数

| 変数名                   | デフォルト値 | 説明                                                   |
| ------------------------ | ------------ | ------------------------------------------------------ |
| `bmc_ipmi_interface`     | `lanplus`    | IPMI インターフェース                                  |
| `bmc_ipmi_username`      | （必須）     | IPMI 認証ユーザー名                                    |
| `bmc_ipmi_password`      | （必須）     | IPMI 認証パスワード                                    |
| `bmc_delegate_host`      | （必須）     | ipmitool を実行する委任先ホスト                        |
| `bmc_power_action`       | `status`     | 電源操作（status / on / off / reset / cycle / soft）   |
| `bmc_boot_device`        | `disk`       | ブートデバイス（disk / pxe / cdrom / bios）            |
| `bmc_boot_persistent`    | `false`      | ブートデバイス設定を永続化するか                       |
| `bmc_rotate_credentials` | `false`      | 認証情報ローテーションを実行するか                     |
| `bmc_new_ipmi_username`  | `""`         | 新しい IPMI ユーザー名（空の場合は変更しない）         |
| `bmc_new_ipmi_password`  | `""`         | 新しい IPMI パスワード（ローテーション時は必須）       |
| `bmc_ipmi_user_id`       | `2`          | IPMI ユーザー ID（Supermicro のデフォルトは 2）        |

## タグ

| タグ             | 説明                       |
| ---------------- | -------------------------- |
| `bmc_power`      | 電源操作を実行する         |
| `bmc_boot`       | ブートデバイスを設定する   |
| `bmc_credential` | 認証情報をローテーションする |

## 使用方法

`site.yml` には含まれず、専用のプレイブックをタグ指定で実行する。

### 電源操作

```bash
ansible-playbook bmc.yml -l <bmc-host> -t bmc_power -e bmc_power_action=status
```

### ブートデバイス設定

```bash
ansible-playbook bmc.yml -l <bmc-host> -t bmc_boot -e bmc_boot_device=pxe
```

### 認証情報ローテーション

```bash
ansible-playbook bmc.yml -l <bmc-host> -t bmc_credential \
  -e bmc_rotate_credentials=true \
  -e bmc_new_ipmi_password='<new-password>'
```

実行後、新しいパスワードを Vault 暗号化してインベントリ変数を更新すること。
