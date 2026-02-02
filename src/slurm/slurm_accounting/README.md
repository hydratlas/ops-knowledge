# slurm_accounting

Slurmアカウンティングデータベースのアカウントとユーザーを管理するロールである。sacctmgrコマンドを使用して、アカウントの作成とユーザーの追加を行う。

## アカウント構造

本ロールはフラット型（複数アカウント）の構造を採用している。

```
root
├── admins  # 管理者
└── users   # 一般ユーザー
```

階層を持たず、すべてのアカウントがrootの直下に配置される。グループごとにFairShareやリソース制限を設定可能である。

## 要件と前提条件

### 共通要件

- Ubuntu 24.04 LTS
- slurm_ctrl ロールが先に実行されていること
- slurmctld が起動していること

### Ansible固有の要件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名           | デフォルト値 | 説明                         |
| ---------------- | ------------ | ---------------------------- |
| `slurm_accounts` | `[]`         | 作成するアカウントのリスト   |
| `slurm_users`    | `[]`         | アカウントに追加するユーザー |

#### slurm_accounts の構造

| フィールド    | 必須 | 説明             |
| ------------- | ---- | ---------------- |
| `name`        | Yes  | アカウント名     |
| `description` | No   | アカウントの説明 |

#### slurm_users の構造

| フィールド | 必須 | 説明                 |
| ---------- | ---- | -------------------- |
| `name`     | Yes  | ユーザー名           |
| `account`  | Yes  | 所属するアカウント名 |

#### 使用例

```yaml
- hosts: slurm_ctrl_hosts
  become: true
  roles:
    - role: infrastructure/slurm_accounting
      vars:
        slurm_accounts:
          - name: admins
            description: "Administrators"
          - name: users
            description: "General users"
        slurm_users:
          - name: sato
            account: admins
          - name: suzuki
            account: users
```

### 方法2: 手動での設定手順

以下はsacctmgrコマンドを使用してアカウントとユーザーを手動設定する手順である。

#### ステップ1: アカウントの作成

```bash
sacctmgr add account admins Description="Administrators" --immediate
sacctmgr add account users Description="General users" --immediate
```

#### ステップ2: ユーザーの追加

```bash
sacctmgr add user sato Account=admins --immediate
sacctmgr add user suzuki Account=users --immediate
```

#### ステップ3: 確認

```bash
# アカウント一覧
sacctmgr show account

# ユーザー一覧
sacctmgr show user

# アソシエーション（ユーザーとアカウントの関連）
sacctmgr show associations
```

## 運用管理

### アカウント・ユーザーの確認

```bash
# アカウント一覧
sacctmgr show account --parsable2

# ユーザー一覧
sacctmgr show user --parsable2

# アソシエーション詳細
sacctmgr show associations format=Account,User,Partition,Share
```

### ユーザーの削除

```bash
sacctmgr delete user name=username --immediate
```

### アカウントの削除

```bash
# 所属ユーザーがいないことを確認してから削除
sacctmgr delete account name=accountname --immediate
```

### FairShareの設定

```bash
# アカウントにFairShareを設定
sacctmgr modify account admins set FairShare=100

# ユーザーにFairShareを設定
sacctmgr modify user sato set FairShare=50
```

## 注意事項

- ユーザーはFreeIPAなどの認証基盤に存在している必要がある（Slurmはユーザー認証自体は行わない）
- アカウントを削除する前に、所属するユーザーをすべて削除または移動する必要がある
- 本ロールは冪等性を持ち、既存のアカウント・ユーザーはスキップされる
- HA構成の場合、任意の1台のコントローラーで実行すれば全体に反映される
