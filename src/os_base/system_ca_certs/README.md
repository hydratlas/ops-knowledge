# system_ca_certs

制御ノードのCAバンドルを対象ホストのシステム信頼ストアに追加し、システム全体（curl/openssl/Python等）でモダンなルートCAを利用できるようにするロールである。

## 概要

CentOS 7・RHEL 7のようなEOLディストリビューション、および古いUbuntuではシステム同梱のCA証明書バンドルが古く、Let's Encryptの`ISRG Root X1`など近年のルートCAを含まない場合がある。本ロールは制御ノード（DevContainer）の`/etc/ssl/certs/ca-certificates.crt`を対象ホストのシステム信頼ストアに配置し、ディストリビューション標準の更新コマンドを実行することで、システム全体のCAバンドルを新鮮に保つ。

OS系統ごとの動作は次の通りである。

| OS family | 配置先 | 更新コマンド | 出力バンドル |
|-----------|--------|-------------|-------------|
| RedHat    | `/etc/pki/ca-trust/source/anchors/` | `update-ca-trust extract` | `/etc/pki/tls/certs/ca-bundle.crt` |
| Debian    | `/usr/local/share/ca-certificates/` | `update-ca-certificates`  | `/etc/ssl/certs/ca-certificates.crt` |

`RedHat`系の`update-ca-trust extract`は同名既存CAとの重複を吸収し、新規ルートのみが実質的に追加される。`Debian`系の`update-ca-certificates`は`/usr/local/share/ca-certificates/`配下の`.crt`ファイルをそのままバンドル末尾に追記する（バンドル形式の単一`.crt`も正しく処理されることを実機調査で確認済み）。重複排除はしないが、SSL検証では1つでも有効なチェーンがあれば成立するため機能上の影響はない。

CentOS 6など古いRedHat系では`/etc/pki/tls/certs/ca-bundle.crt`が`ca-trust`配下へのsymlinkではなく静的ファイルとして残っている場合がある。この状態では`update-ca-trust extract`を実行しても当該ファイルが更新されないため、本ロールは事前に`/etc/pki/tls/certs/ca-bundle.crt`がsymlinkかを確認し、静的ファイルなら`update-ca-trust force-enable`を実行して`ca-trust`管理下に切り替える。

両系統に該当しないOSではblockがスキップされ、同一プレイで適用される後続ロール（`os_base/python_ca_certs`など）には影響を与えない。

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

- 対象OSは`RedHat`系および`Debian`系（それ以外のOSではblockごとスキップされ、同一プレイの後続ロールには干渉しない）
- 配置するCAバンドルファイルの内容が前回と変わらなければ更新コマンドは実行されない（冪等）
- `RedHat`系では`update-ca-trust`が重複を吸収するため出力上は追加されない
- `Debian`系では重複排除されないため、システムバンドルにすでに含まれるCAはバンドル内で重複する可能性があるが、SSL検証上の影響はない
