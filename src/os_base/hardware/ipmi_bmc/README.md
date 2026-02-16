# IPMI BMC

Supermicro 等の IPMI 2.0 対応 BMC（Baseboard Management Controller）の管理方法である。`ipmitool` を使用してリモートから電源操作・ブートデバイス設定・認証情報管理を行う。

## 前提条件

- BMC が mgmt ネットワーク（10.140.0.0/16）に接続されていること
- 操作元ホスト（jump-mgmt-04）に `ipmitool` がインストールされていること
- SOCKS5 プロキシは UDP 非対応のため、DevContainer からの直接 IPMI 通信は不可能である

## Ansible による操作

`site.yml` には含まれず、`bmc.yml` をタグ指定で実行する。

### 電源操作

```bash
# 電源状態確認
uv run ansible-playbook bmc.yml -l beyond-bmc.mgmt.home.arpa -t bmc_power -e bmc_power_action=status

# 電源オン
uv run ansible-playbook bmc.yml -l beyond-bmc.mgmt.home.arpa -t bmc_power -e bmc_power_action=on

# 電源オフ（ハード）
uv run ansible-playbook bmc.yml -l beyond-bmc.mgmt.home.arpa -t bmc_power -e bmc_power_action=off

# 電源リセット
uv run ansible-playbook bmc.yml -l beyond-bmc.mgmt.home.arpa -t bmc_power -e bmc_power_action=reset
```

### ブートデバイス設定

```bash
# PXE ブート（次回のみ）
uv run ansible-playbook bmc.yml -l beyond-bmc.mgmt.home.arpa -t bmc_boot -e bmc_boot_device=pxe

# BIOS 設定画面（次回のみ）
uv run ansible-playbook bmc.yml -l beyond-bmc.mgmt.home.arpa -t bmc_boot -e bmc_boot_device=bios

# ディスクブート（永続）
uv run ansible-playbook bmc.yml -l beyond-bmc.mgmt.home.arpa -t bmc_boot -e bmc_boot_device=disk -e bmc_boot_persistent=true
```

### 認証情報ローテーション

```bash
uv run ansible-playbook bmc.yml -l bmc_supermicro -t bmc_credential \
  -e bmc_rotate_credentials=true \
  -e bmc_new_ipmi_password='NewSecurePassword123'
```

実行後、新しいパスワードを Vault 暗号化して `group_vars/bmc_supermicro.yml` を更新すること。

```bash
cd ansible && uv run ansible-vault encrypt_string 'NewSecurePassword123' --name 'bmc_ipmi_password'
```

## 手動操作（ipmitool）

jump-mgmt-04 から直接実行する場合の手順である。

### 基本的な状態確認

```bash
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN chassis status
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN sdr list
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN sensor list
```

### BMC 情報

```bash
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN bmc info
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN lan print
```

### ユーザー管理

```bash
# ユーザー一覧
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN user list

# パスワード変更（ユーザー ID 2 = デフォルトの ADMIN ユーザー）
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN user set password 2 'NewPassword'

# ユーザー名変更
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN user set name 2 'newusername'
```

### SOL（Serial Over LAN）コンソール

```bash
# SOL 有効化
ipmitool -I lanplus -H 10.140.91.151 -U ADMIN -P ADMIN sol activate

# SOL 切断: ~. で切断
```
