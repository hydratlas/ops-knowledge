# vyos_v2

VyOSルーターの設定を構造化変数とJinja2テンプレートで宣言的に管理し、差分検出による冪等な適用を実現するロール

## 概要

### このドキュメントの目的

このロールは、従来の`network/vyos`ロール（setコマンドリストの逐次適用方式）を置き換えるために設計された新しい構成管理方式である。構造化されたYAML変数からJinja2テンプレートでsetコマンドを生成し、現在の設定との差分を検出して変更がある場合のみ適用する。

### 実現される機能

- 差分検出による冪等な設定適用（変更がなければスキップ）
- 構造化YAML変数による可読性の高い設定管理
- `--diff`オプションによる変更内容の可視化
- セクション別テンプレートによる保守性の向上

### 従来ロール（network/vyos）との違い

| 項目 | network/vyos（従来） | network/vyos_v2（本ロール） |
|------|---------------------|---------------------------|
| 変数形式 | setコマンド文字列のリスト | 構造化YAML辞書 |
| 冪等性 | なし（毎回changed） | あり（差分検出） |
| 実行速度 | 数分（毎回全行適用） | 数秒（変更なし時はスキップ） |
| 差分表示 | 不可 | 可能（追加/削除コマンドを表示） |

### 移行方法

1. `site.yml`で`network/vyos`を`network/vyos_v2`に変更する
2. `vyos_dhcp_mapping_config`は引き続き使用される（変更不要）
3. `vyos_base_config`と`vyos_custom_config`は`vyos_v2_*`変数に置き換え済み

## 要件と前提条件

### 共通要件

- **OS**: VyOS 1.4.x（Sagitta）
- **権限**: VyOSの設定権限を持つユーザー
- **ネットワーク**: SSH接続可能な環境

### Ansible固有の要件

- **コレクション**: vyos.vyos
- **接続タイプ**: network_cli
- **依存変数**: `vyos_password`（Ansible Vault暗号化）、`vyos_dhcp_mapping_config`（DHCPマッピング）

## 設定方法

### ロール変数

#### 必須変数（グループレベル）

| 変数名 | 説明 |
|--------|------|
| `vyos_v2_firewall` | ファイアウォールルール定義 |
| `vyos_v2_vrrp` | VRRPグループとsync-group定義 |
| `vyos_v2_conntrack_sync` | conntrack-sync設定 |
| `vyos_v2_nat` | NAT（destination/source）ルール定義 |
| `vyos_v2_static_routes` | スタティックルート定義 |
| `vyos_v2_dhcp_server` | DHCPサーバー設定（サブネット定義） |
| `vyos_v2_dns_forwarding` | DNS転送設定 |
| `vyos_v2_ntp` | NTPサーバー設定 |
| `vyos_v2_ssh` | SSHサービス設定 |
| `vyos_v2_system` | システム設定（ログイン、syslog等） |
| `vyos_v2_containers` | コンテナー定義 |

#### 必須変数（ホストレベル）

| 変数名 | 説明 |
|--------|------|
| `vyos_v2_hostname` | ホスト名 |
| `vyos_v2_interfaces` | インターフェース設定（アドレス、hw-id等） |
| `vyos_v2_conntrack_peer` | conntrack-syncピアのIPアドレス |
| `vyos_v2_dhcp_ha` | DHCP HA設定（status, remote, source-address） |
| `vyos_v2_nat_extra_destination_rules` | ホスト固有のDNATルール |

#### オプション変数（ホストレベル）

| 変数名 | 説明 | デフォルト |
|--------|------|-----------|
| `vyos_v2_vrrp_priority` | VRRP優先度 | 未定義（テンプレートでスキップ） |
| `vyos_v2_vrrp_preempt_delay` | VRRPプリエンプト遅延（秒） | 未定義（テンプレートでスキップ） |

#### 必須変数（グループレベル・追加）

| 変数名 | 説明 |
|--------|------|
| `vyos_v2_health_check_gateway` | VRRPヘルスチェック対象IP |

#### デフォルト変数

| 変数名 | 説明 | デフォルト |
|--------|------|-----------|
| `vyos_v2_managed_regex` | 管理対象コマンドのフィルターパターン | （設定済み） |
| `vyos_v2_delete_commands` | 適用前に実行するdeleteコマンド | （設定済み） |

### DHCPスタティックマッピング

DHCPスタティックマッピングには2つの変数形式がある。`vyos_v2_dhcp_static_mappings`が定義されていればそちらが使用され、未定義の場合は`vyos_dhcp_mapping_config`にフォールバックする。

#### vyos_v2_dhcp_static_mappings（推奨・v2形式）

構造化YAMLリストで、各エントリはホスト名とネットワーク情報で構成される。`generate_dhcp_mapping.py`で自動生成される。

| フィールド | 説明 |
|-----------|------|
| `hostname` | ホスト名 |
| `networks[].segment` | ネットワークセグメント名（pub, int, hi, mgmt） |
| `networks[].ip` | IPアドレス |
| `networks[].subnet` | サブネット（CIDR表記） |
| `networks[].mac` | MACアドレス（オプション、指定時のみDHCP static-mappingを生成） |

#### vyos_dhcp_mapping_config（既存形式・フォールバック用）

setコマンド文字列のリスト。`vyos_v2_dhcp_static_mappings`が未定義の環境で使用される。

### テンプレート構成

```
templates/
├── config_commands.j2          # メインテンプレート（全セクション統合）
└── sections/
    ├── container.j2            # コンテナー設定
    ├── dhcp_static_mapping.j2  # DHCPスタティックマッピング（v2形式）
    ├── firewall.j2             # ファイアウォールルール
    ├── high_availability.j2    # VRRP/sync-group設定
    ├── interfaces.j2           # インターフェース設定
    ├── nat.j2                  # NAT（DNAT/SNAT）設定
    ├── protocols.j2            # スタティックルート
    ├── service.j2              # 各種サービス設定
    └── system.j2               # システム設定
```

### 使用例

```yaml
- hosts: vyos
  gather_facts: false
  tags: vyos
  roles:
    - role: network/vyos_v2
      tags: vyos_v2
```

## 動作の仕組み

1. 必須変数の存在確認
2. VRRPヘルスチェックスクリプトの配置
3. `show configuration commands`で現在の設定を取得
4. テンプレートから望ましいsetコマンドを生成
5. 両者を正規化（クォート除去、ソート）して比較
6. 差分がある場合のみ、管理対象セクションをdelete→set で再構築

### 差分検出の仕組み

比較時には以下の正規化を行う。

- 単一引用符の除去（VyOSの出力形式の揺れを吸収）
- パスワード行の除外（`plaintext-password`と`encrypted-password`はVyOS内部で変換されるため比較不能）
- 管理対象セクションのみをフィルター（VyOS自動生成の設定を除外）
