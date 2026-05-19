# system_ca_certs

制御ノードのCAバンドルを対象ホストのシステム信頼ストアに追加し、システム全体（curl/openssl/Python等）でモダンなルートCAを利用できるようにするロールである。

## 概要

CentOS 7・RHEL 7のようなEOLディストリビューションではシステム同梱のCA証明書バンドルが古く、Let's Encryptの`ISRG Root X1`など近年のルートCAを含まない。本ロールは制御ノード（DevContainer）の`/etc/ssl/certs/ca-certificates.crt`を`/etc/pki/ca-trust/source/anchors/`に配置し、`update-ca-trust extract`を実行することで、システム全体のCAバンドル（`/etc/pki/tls/certs/ca-bundle.crt`を介して各種ライブラリーが参照）を新鮮に保つ。

`update-ca-trust extract`は同名既存CAとの重複を許容し、新規ルートのみが実質的に追加される。

`update-ca-trust`機構を採用するため、対応OSは`RedHat`系のみである。`Debian`系の`update-ca-certificates`は`/usr/local/share/ca-certificates/`配下を**個別の証明書ファイル**として扱うためバンドル形式を直接配置できず、対応が必要となれば別途バンドルを分割するなどの拡張が必要となる。本ロールは`RedHat`以外のホストでは何も実施しない（`when:`でblock全体をスキップ）。同一プレイで適用される後続ロール（`os_base/python_ca_certs`など）には影響を与えない。

## 主要な変数

| 変数名 | デフォルト値 | 説明 |
|--------|--------------|------|
| `system_ca_certs_source` | `/etc/ssl/certs/ca-certificates.crt` | 制御ノード上のCAバンドルファイルパス |
| `system_ca_certs_anchor_filename` | `modern-ca-bundle.crt` | アンカーディレクトリーに配置するファイル名 |

## 使用例

```yaml
- hosts: legacy
  become: true
  roles:
    - role: os_base/system_ca_certs
    - role: os_base/python_ca_certs
```

`os_base/system_ca_certs`は`os_base/python_ca_certs`より**前**に適用する。これにより、Pythonのsymlink先となるシステムバンドルが先に更新される。

## 動作条件

- 対象OSは`RedHat`系のみ（それ以外のOSではblockごとスキップされ、同一プレイの後続ロールには干渉しない）
- アンカーファイルの内容が前回と変わらなければ`update-ca-trust extract`は実行されない（冪等）
- 制御ノードのCAバンドルとシステムバンドルにすでに同じルートが含まれている場合、`update-ca-trust`は重複を吸収するため出力上は追加されない
