# freeipa_dirman_rotate

FreeIPA の Directory Manager (DM) パスワードを idm-01〜04 の全 389-ds インスタンスで共通の既知値へローテーションし、Vault 変数 `vault_freeipa_dirman_password` として一元管理するロール

## 概要

### このドキュメントの目的

FreeIPA の DM パスワードは初回インストール時にランダム生成され、本プロジェクトでは従来記録・管理されていなかった。しかし `ipa-restore` や `dsconf`・直接 LDAP 保守など 389-ds の低レベル操作は DM パスワードを必須とし、Kerberos 認証では代替できない。本ロールは DM パスワードを既知値へローテーションして Vault 管理下に置くことで、これらの DR・保守操作へ決定論的にパスワードを供給する。Ansible による自動設定と、それと等価な手動手順の両方を記載する。

背景・設計判断の詳細は実装計画書 `docs/engineering-records/202606/20260628-0257-freeipa-dirman-password-vault-management.md` を参照する。

### DM パスワードの 2 つの本質的制約

- **平文取得は不可能**: 389-ds は DM パスワードを `cn=config` の `nsslapd-rootpw` に一方向ハッシュ（既定 PBKDF2-SHA512）で保存する。既存値を取り出して Vault へ写すことはできず、既知値への再設定（ローテーション）しか手がない。
- **レプリカ間で複製されない**: `nsslapd-rootpw` は `cn=config` 配下でレプリケーション対象外であり、各インスタンスのローカル設定である。復旧先がどのノードでも同じ Vault 値で開けるよう、idm-01〜04 の全レプリカへ個別に同一の既知値を再設定する必要がある。

### 実現される機能

- 新 DM パスワードでの bind 成否で現状を判定（冪等性の担保）
- 未ローテーションのインスタンスのみ、LDAPI + SASL EXTERNAL（root オートバインド）で `nsslapd-rootpw` を Vault の既知値へ無停止で置換
- 置換後に新パスワードでの bind 成功を検証

## 要件と前提条件

### 共通要件

- **対象システム**: FreeIPA/IdM サーバー（`ipaservers` = idm-01〜04）
- **権限**: 対象ホスト上の root（`become: true`）。現 DM パスワードは不要
- **前提条件**: 389-ds が LDAPI ソケット上で root オートバインド（`nsslapd-ldapiautobind: on`、`nsslapd-ldapimaprootdn: cn=Directory Manager`）を有効にしていること。FreeIPA 既定で有効

### ローテーション手段の選定

| 手段 | 概要 | 停止 | 現 DM 要否 | 採否 |
| ---- | ---- | ---- | ---------- | ---- |
| (A) LDAPI + EXTERNAL | root が ldapi 経由で `cn=Directory Manager` にオートバインドし `ldapmodify` で `nsslapd-rootpw` を置換 | 不要 | 不要 | 採用（主・本ロール） |
| (B) `dse.ldif` 直編集 | `dirsrv` 停止 → `dse.ldif` の `nsslapd-rootpw` を `pwdhash` 生成ハッシュへ差し替え → 起動 | 要 | 不要 | フォールバック（手動） |
| (C) `dsconf` / rootdn bind | 現 DM もしくは rootdn でバインドして置換 | 不要 | 要 | 不採用（現 DM を持たない） |

(A) は現 DM を知らずに無停止で再設定でき、ハッシュ生成を server に委ねられる（平文を与えると `nsslapd-rootpwstoragescheme` に従い自動ハッシュ化）ため主手段とする。

### Ansible 固有の要件

- **Ansible バージョン**: 2.14 以上
- **認証情報**: 変数 `vault_freeipa_dirman_password` が定義されていること（`group_vars/all.yml`）
- 対象ホストに `openldap-clients`（`ldapwhoami`・`ldapmodify`）が導入されていること（本ロールが導入を保証する）

### 手動設定の要件

- 対象ホスト上で root 権限
- `ldapwhoami`・`ldapmodify`（オンライン手順）または `pwdhash`・`systemctl`（停止フォールバック）が利用可能

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

| 変数名                          | 説明                                              | デフォルト値                                                   | 必須 |
| ------------------------------- | ------------------------------------------------- | -------------------------------------------------------------- | ---- |
| `vault_freeipa_dirman_password` | 既知の DM パスワード（Vault 暗号化）              | -                                                              | はい |
| `freeipa_dirman_instance`       | 389-ds インスタンス名                            | `slapd-HOME-ARPA`                                              | いいえ |
| `freeipa_dirman_ldapi_socket`   | LDAPI ソケットのパス                             | `/run/{{ freeipa_dirman_instance }}.socket`                    | いいえ |
| `freeipa_dirman_ldapi_uri`      | percent-encode 済み ldapi:// URI                 | 上記ソケットから生成                                           | いいえ |
| `freeipa_dirman_password`       | ローテーションに用いる既知値                     | `{{ vault_freeipa_dirman_password }}`                          | いいえ |

#### 冪等性

新 DM パスワードでの bind が成功すれば再設定タスクはスキップされる。2 回目以降の適用は changed=0 となる。

#### タグとハンドラー

このロールにはハンドラーは定義されていない。`site.yml` 側で `freeipa_dirman` タグが付与される。

#### 使用例

```yaml
- hosts: ipaservers
  become: true
  gather_facts: false
  roles:
    - role: authentication/freeipa_dirman_rotate
```

### 方法2: 手動での設定手順（(A) オンライン・主手順）

各 idm ホスト上で root として実行する。`nsslapd-rootpw` に平文を与えると 389-ds が自動でハッシュ化する。`<KNOWN_DM_PASSWORD>` は Vault 値（`vault_freeipa_dirman_password`）に読み替える。

```bash
INST=slapd-HOME-ARPA
URI="ldapi://%2Frun%2F${INST}.socket"

# root オートバインド（SASL EXTERNAL）で nsslapd-rootpw を置換
ldapmodify -H "$URI" -Y EXTERNAL <<'LDIF'
dn: cn=config
changetype: modify
replace: nsslapd-rootpw
nsslapd-rootpw: <KNOWN_DM_PASSWORD>
LDIF

# 反映確認（dn: cn=Directory Manager が返れば成功）
ldapwhoami -x -H "$URI" -D "cn=Directory Manager" -w '<KNOWN_DM_PASSWORD>'
```

### 方法3: 停止フォールバック（(B)・LDAPI オートバインドが使えない場合）

LDAPI オートバインドが無効化されている等で (A) が使えない場合のみ用いる。当該インスタンスのみ短時間停止する。

```bash
INST=slapd-HOME-ARPA
HASH=$(pwdhash -s PBKDF2-SHA512 '<KNOWN_DM_PASSWORD>')
systemctl stop dirsrv@${INST}
# /etc/dirsrv/${INST}/dse.ldif の nsslapd-rootpw 行を ${HASH} へ差し替える
systemctl start dirsrv@${INST}
```

## 運用管理

### 基本操作

- DM パスワードの確認: `ldapwhoami -x -H "ldapi://%2Frun%2Fslapd-HOME-ARPA.socket" -D "cn=Directory Manager" -w '<Vault値>'`
- 無停止の確認: ローテーション前後で `systemctl show -p ActiveEnterTimestamp dirsrv@slapd-HOME-ARPA` が変化しないこと

### break-glass（Vault 値が失われた場合）

DM パスワードは平文取得不可だが、root による LDAPI オートバインドはパスワードに依存しないため、Vault 値が失われても任意の新値へ再設定して復帰できる。新しい既知値を生成し直して Vault を更新したうえで、方法2 のオンライン手順（または本ロールの再実行）で全台へ再ローテーションする。

### トラブルシューティング

#### 問題1: `ldapmodify -Y EXTERNAL` が `Insufficient access` を返す

**原因**: LDAPI オートバインドが無効、または root 以外で実行している。
**対処**: `become: true`（root）で実行する。`cn=config` の `nsslapd-ldapiautobind` / `nsslapd-ldapimaprootdn` を確認し、無効なら方法3（停止フォールバック）へ切り替える。

#### 問題2: ローテーション後も bind に失敗する

**原因**: 一部レプリカのみ適用された中途状態。`nsslapd-rootpw` はレプリカ非複製のため、未適用ノードは旧値のまま。
**対処**: `ipaservers` 全台へ適用し、2 回目適用で全台 changed=0（全台同一値）を確認する。

## アンインストール

DM パスワードの「未管理状態」へ戻すことは設計上意味を持たない（既知値を破棄しても 389-ds 上のハッシュは残るため）。本ロールの適用を取りやめる場合は `site.yml` のプレイから当該ロールを外すだけでよい。
