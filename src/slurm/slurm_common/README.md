# slurm_common

Slurmクラスターに参加するノード（ログインノード・計算ノード）の共通セットアップを行うロールである。slurm_loginおよびslurm_nodeロールの依存ロールとして使用される。

## 概要

このロールは以下を実行する：

- slurm_controller_hostおよびslurm_jwt_keyの必須変数バリデーション
- JWT認証キーの配置（`/etc/slurm/slurm.key`）

## 要件と前提条件

### 共通要件

- Ubuntu 24.04 LTS
- root権限またはsudo権限
- Slurmコントローラー（slurm_ctrl）が設定済みであること

### Ansible固有の要件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

## 設定方法

### ロール変数

#### 必須変数

| 変数名                  | 説明                                                |
| ----------------------- | --------------------------------------------------- |
| `slurm_controller_host` | コントローラーのホスト名（configless接続先）        |
| `slurm_jwt_key`         | JWT認証キー（Base64エンコード済み、32バイト）        |

### 使用方法

このロールは直接使用せず、slurm_loginまたはslurm_nodeロールの依存ロールとして自動的に実行される。

## 注意事項

- このロールは単独で使用することを想定していない
- JWT鍵はAnsible Vaultで暗号化して管理すること
