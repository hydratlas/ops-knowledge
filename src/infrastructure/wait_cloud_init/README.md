# wait-cloud-init

cloud-init完了待機ロール

## 概要

このロールは、cloud-initの初期化が完了するまで待機します。cloud-initが存在しない場合は、正常にスキップします。

## 機能

1. **cloud-init待機**: cloud-initの初期化完了まで待機

## 要件

- cloud-initコマンドの実行にroot権限が必要なため、プレイブックレベルで`become: true`の指定が必要
- cloud-initが存在しない場合は自動的にスキップ

## ロール変数

- `wait_cloud_init_enabled`: cloud-init待機を有効化（デフォルト: true）

## 使用例

```yaml
- hosts: cloud_instances
  become: true
  roles:
    - wait-cloud-init
    - other_roles  # cloud-init完了後に実行される
```

待機を無効化する場合：
```yaml
- hosts: cloud_instances
  become: true
  roles:
    - role: wait-cloud-init
      vars:
        wait_cloud_init_enabled: false  # cloud-init待機を無効化
```

## 設定内容

### cloud-init待機
- cloud-initステータスの確認
- 初期化完了まで待機
- cloud-initが存在しない場合は正常にスキップ
- VMのプロビジョニング後の設定競合を防止

## 手動での確認手順

### cloud-initのステータス確認

```bash
# cloud-initの現在のステータスを確認
sudo cloud-init status

# より詳細な情報を表示
sudo cloud-init status --long
```

### cloud-initの完了待機

```bash
# cloud-initの完了を待機（スクリプト内で使用）
sudo cloud-init status --wait

# cloud-initが存在するか確認してから待機
if command -v cloud-init >/dev/null 2>&1; then
    sudo cloud-init status --wait || [ $? -eq 2 ]
else
    echo "No cloud-init found, skipping wait"
fi
```

### cloud-initのログ確認

```bash
# cloud-initのメインログ
sudo cat /var/log/cloud-init.log

# cloud-init出力ログ
sudo cat /var/log/cloud-init-output.log

# cloud-initのステージ別実行時間
sudo cloud-init analyze show

# cloud-initのエラーや警告を確認
sudo cloud-init analyze blame
```