# VyOS v3 Role

## 概要

VyOSルーターの設定を管理するロール。vyos（v1）ロールと同じ変数を使用しつつ、自動バックアップとコミットコメントを追加した改良版である。

## 使用方法

### 必須変数

| 変数名                      | 説明                           |
| --------------------------- | ------------------------------ |
| `vyos_base_config`          | ベース設定コマンドのリスト     |
| `vyos_health_check_gateway` | VRRPヘルスチェック先IPアドレス |

### オプション変数

| 変数名                     | 説明                             | デフォルト値 |
| -------------------------- | -------------------------------- | ------------ |
| `vyos_dhcp_mapping_config` | DHCP固定IPマッピング設定のリスト | `[]`         |
| `vyos_custom_config`       | カスタム設定コマンドのリスト     | `[]`         |
| `vyos_backup`              | 設定バックアップの有効化         | `true`       |

### Playbookでの使用例

```yaml
- hosts: vyos
  roles:
    - network/vyos
```

## 動作の仕組み

1. `vyos_base_config` の存在を検証
2. VRRPヘルスチェックスクリプトを作成
3. `vyos_base_config` + `vyos_dhcp_mapping_config` + `vyos_custom_config` を結合
4. `vyos_config` モジュールで一括適用（`match: none`）
5. 設定を永続化

## バックアップの確認

Ansible制御ホストの`backup/`ディレクトリにバックアップが保存される。

```bash
ls -la backup/rt-01.int.home.arpa_config.*
```

## 関連ドキュメント

- [VyOS公式ドキュメント](https://docs.vyos.io/)
- [Ansible vyos_config モジュール](https://docs.ansible.com/ansible/latest/collections/vyos/vyos/vyos_config_module.html)
