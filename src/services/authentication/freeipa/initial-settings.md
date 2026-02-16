# FreeIPAサーバーの初期設定
## Password Policy
WebUIの「Policy」→「Password Policy」→「global_policy」
- Max lifetime (days)（パスワードの有効日数）: 0
- Min lifetime (hours)（パスワードの変更後に、次に変更するまでに最低時間）: 1
- History size (number of passwords)（再利用できないパスワードの数）: 1
- Character classes（パスワードで使用する必要のある文字クラスの数）: 4
- Min length（パスワードの最小長）: 12
- Max failures（アカウントロックまでの最大ログイン失敗数）: 6
- Failure reset interval (seconds)（ログイン失敗数をリセットするまでの秒数）: 60
- Lockout duration (seconds)（アカウントロックの秒数）: 600

## ID Ranges
WebUIの「IPA Server」→「ID Ranges」
- id_rangeを1000から99000個にする
- subid_rangeを100000から4294867296個にする

## Default shell
WebUIの「IPA Server」→「Configuration」
- `/bin/bash`

## Default user authentication types
WebUIの「IPA Server」→「Configuration」
