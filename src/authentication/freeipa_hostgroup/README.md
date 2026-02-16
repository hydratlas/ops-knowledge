# ipahostgroup

FreeIPA/IdMのホストグループメンバーシップを管理し、ホストの論理的なグループ化を実現するロール

## 概要

### このドキュメントの目的
このロールは、FreeIPA/IdMのホストグループ管理機能を提供します。ホストを論理的にグループ化し、HBAC（Host-Based Access Control）ルールやsudoルールでの一括管理を可能にします。Automember機能を使用する場合は、このロールは不要になることがあります。Ansibleによる自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- ホストグループの作成と管理
- ホストのグループメンバーシップ管理
- HBACルールでの使用を目的としたホスト分類
- sudoルールでの一括適用
- 管理の簡素化と一元化

## 要件と前提条件

### 共通要件
- **システム**: FreeIPA/IdMサーバー 4.x以上
- **権限**: FreeIPA管理者権限またはホストグループ管理権限
- **ネットワーク**: FreeIPAサーバーへのHTTPS（443）接続
- **前提条件**: ホストがFreeIPAに登録済み

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: freeipa.ansible_freeipa
- **実行権限**: become: true必須
- **認証**: ipaadmin_passwordまたはKerberosチケット

### 手動設定の要件
- FreeIPA CLIツール（ipa コマンド）
- 有効なKerberosチケットまたは管理者パスワード
- FreeIPA Web UIへのアクセス（オプション）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|--------------|------|
| `ipaadmin_password` | FreeIPA管理者パスワード | - | はい |
| `ipahostgroup_name` | ホストグループ名 | - | はい |
| `ipahostgroup_hosts` | グループに追加するホストのリスト | - | はい |

#### 依存関係
- freeipa.ansible_freeipa コレクションがインストールされていること

#### タグとハンドラー
このロールにはタグやハンドラーは定義されていません。

#### 使用例

基本的な使用例：
```yaml
---
- name: Configure FreeIPA host groups
  hosts: localhost
  become: yes
  vars:
    ipaadmin_password: "{{ vault_ipa_admin_password }}"
    ipahostgroup_name: webservers
    ipahostgroup_hosts:
      - web01.example.com
      - web02.example.com
      - web03.example.com
  roles:
    - ipahostgroup
```

動的インベントリを使用した例：
```yaml
---
- name: Add hosts to groups based on inventory
  hosts: localhost
  become: yes
  vars:
    ipaadmin_password: "{{ vault_ipa_admin_password }}"
  tasks:
    - name: Create web servers group
      ansible.builtin.include_role:
        name: ipahostgroup
      vars:
        ipahostgroup_name: webservers
        ipahostgroup_hosts: "{{ groups['web'] | map('regex_replace', '$', '.example.com') | list }}"
      when: groups['web'] is defined

    - name: Create database servers group
      ansible.builtin.include_role:
        name: ipahostgroup
      vars:
        ipahostgroup_name: dbservers
        ipahostgroup_hosts: "{{ groups['database'] | map('regex_replace', '$', '.example.com') | list }}"
      when: groups['database'] is defined
```

複数環境での使用例：
```yaml
---
- name: Configure host groups for multiple environments
  hosts: localhost
  become: yes
  vars:
    ipaadmin_password: "{{ vault_ipa_admin_password }}"
    environments:
      - name: production
        groups:
          - name: prod-webservers
            hosts:
              - prod-web01.example.com
              - prod-web02.example.com
          - name: prod-dbservers
            hosts:
              - prod-db01.example.com
              - prod-db02.example.com
      - name: staging
        groups:
          - name: stage-webservers
            hosts:
              - stage-web01.example.com
          - name: stage-dbservers
            hosts:
              - stage-db01.example.com
  tasks:
    - name: Create host groups for each environment
      ansible.builtin.include_role:
        name: ipahostgroup
      vars:
        ipahostgroup_name: "{{ item.1.name }}"
        ipahostgroup_hosts: "{{ item.1.hosts }}"
      loop: "{{ environments | subelements('groups') }}"
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

1. FreeIPA管理者として認証：
```bash
# Kerberosチケットの取得
kinit admin

# チケットの確認
klist
```

2. 現在のホストグループの確認：
```bash
# すべてのホストグループを表示
ipa hostgroup-find

# 特定のホストグループを検索
ipa hostgroup-find --hostgroup-name="*web*"
```

#### ステップ2: ホストグループの作成

新しいホストグループの作成：
```bash
# 基本的なホストグループ作成
ipa hostgroup-add webservers --desc="Web Server Hosts"

# 詳細な設定を含む作成
ipa hostgroup-add dbservers \
    --desc="Database Server Hosts" \
    --setattr="businesscategory=Production"

# 作成したグループの確認
ipa hostgroup-show webservers
```

#### ステップ3: ホストの追加

ホストグループへのホスト追加：
```bash
# 単一ホストの追加
ipa hostgroup-add-member webservers --hosts=web01.example.com

# 複数ホストの一括追加
ipa hostgroup-add-member webservers \
    --hosts={web01.example.com,web02.example.com,web03.example.com}

# CSVリストからのホスト追加
for host in $(cat webservers.txt); do
    ipa hostgroup-add-member webservers --hosts=$host
done
```

スクリプトを使用した一括追加：
```bash
#!/bin/bash
# /usr/local/bin/add-hosts-to-group.sh

HOSTGROUP=$1
HOSTS_FILE=$2

if [ -z "$HOSTGROUP" ] || [ -z "$HOSTS_FILE" ]; then
    echo "Usage: $0 <hostgroup> <hosts_file>"
    exit 1
fi

# ホストグループの存在確認
if ! ipa hostgroup-show "$HOSTGROUP" &>/dev/null; then
    echo "Creating hostgroup: $HOSTGROUP"
    ipa hostgroup-add "$HOSTGROUP" --desc="Auto-created group"
fi

# ホストを追加
while IFS= read -r host; do
    if [ -n "$host" ]; then
        echo "Adding $host to $HOSTGROUP"
        ipa hostgroup-add-member "$HOSTGROUP" --hosts="$host"
    fi
done < "$HOSTS_FILE"
```

#### ステップ4: Automember設定（オプション）

自動メンバーシップルールの設定：
```bash
# Automemberルールの作成
ipa automember-add --type=hostgroup webservers

# ホスト名パターンによる条件追加
# web*.example.comにマッチするホストを自動追加
ipa automember-add-condition webservers --type=hostgroup \
    --inclusive-regex='^web[0-9]+\.example\.com$' --key=fqdn

# データベースサーバー用のルール
ipa automember-add --type=hostgroup dbservers
ipa automember-add-condition dbservers --type=hostgroup \
    --inclusive-regex='^(db|mysql|postgres)[0-9]+\.example\.com$' --key=fqdn

# Automemberルールの確認
ipa automember-show webservers --type=hostgroup

# 既存ホストへのルール適用
ipa automember-rebuild --type=hostgroup
```

## 運用管理

### 基本操作

日常的な管理コマンド：
```bash
# ホストグループの一覧表示
ipa hostgroup-find

# グループメンバーの確認
ipa hostgroup-show webservers

# ホストの所属グループ確認
ipa host-show web01.example.com --all | grep "Member of host-groups"

# ホストグループの統計情報
ipa hostgroup-find --sizelimit=0 | grep "Number of entries"
```

### ログとモニタリング

関連ログファイル：
- `/var/log/httpd/error_log` - FreeIPA APIエラー
- `/var/log/dirsrv/slapd-*/access` - LDAPアクセスログ
- `/var/log/dirsrv/slapd-*/errors` - LDAPエラーログ
- `/var/log/krb5kdc.log` - Kerberos認証ログ

監視すべき項目：
- ホストグループメンバーシップの変更
- Automemberルールの実行状況
- 不正なグループ割り当て
- 孤立したホスト（グループ未所属）
- API呼び出しのエラー率

監視スクリプト例：
```bash
#!/bin/bash
# /usr/local/bin/monitor-hostgroups.sh

echo "=== FreeIPA Host Group Status ==="
echo "Date: $(date)"
echo

# ホストグループ統計
echo "--- Host Group Statistics ---"
total_groups=$(ipa hostgroup-find --sizelimit=0 2>/dev/null | grep -c "Host-group:")
echo "Total host groups: $total_groups"

# 空のホストグループ
echo -e "\n--- Empty Host Groups ---"
for group in $(ipa hostgroup-find --sizelimit=0 --raw | grep "cn:" | awk '{print $2}'); do
    member_count=$(ipa hostgroup-show "$group" --all | grep -c "Member hosts:")
    if [ "$member_count" -eq 0 ]; then
        echo "  - $group"
    fi
done

# グループに属さないホスト
echo -e "\n--- Hosts Without Groups ---"
for host in $(ipa host-find --sizelimit=0 --raw | grep "fqdn:" | awk '{print $2}'); do
    groups=$(ipa host-show "$host" --all 2>/dev/null | grep "Member of host-groups:" | wc -l)
    if [ "$groups" -eq 0 ]; then
        echo "  - $host"
    fi
done

# Automemberルール
echo -e "\n--- Automember Rules ---"
ipa automember-find --type=hostgroup
```

### トラブルシューティング

#### 問題1: ホストをグループに追加できない
**原因**: ホストがFreeIPAに登録されていない
**対処方法**:
```bash
# ホストの存在確認
ipa host-show hostname.example.com

# ホストが存在しない場合は先に追加
ipa host-add hostname.example.com --force

# その後グループに追加
ipa hostgroup-add-member webservers --hosts=hostname.example.com
```

#### 問題2: Automemberルールが適用されない
**原因**: 正規表現の誤りまたはルールの優先順位問題
**対処方法**:
```bash
# ルールのテスト
ipa automember-default-group-show --type=hostgroup

# ルールの詳細確認
ipa automember-show webservers --type=hostgroup

# 手動でルールを再構築
ipa automember-rebuild --type=hostgroup --hosts=web01.example.com

# 全ホストに対して再構築
ipa automember-rebuild --type=hostgroup
```

#### 問題3: ホストグループの削除ができない
**原因**: HBACルールやsudoルールで使用中
**対処方法**:
```bash
# 依存関係の確認
ipa hostgroup-show webservers --all

# HBACルールでの使用確認
ipa hbacrule-find --hostgroup=webservers

# sudoルールでの使用確認
ipa sudorule-find --hostgroup=webservers

# 依存関係を削除してから再試行
ipa hbacrule-remove-host rule_name --hostgroups=webservers
```

診断フロー：
1. Kerberosチケットの有効性確認
2. ホストのFreeIPA登録状態確認
3. ホストグループの存在確認
4. Automemberルールの確認
5. APIエラーログの確認

### メンテナンス

#### ホストグループの整理
```bash
#!/bin/bash
# /usr/local/bin/cleanup-hostgroups.sh

# 空のホストグループを検出
echo "=== Empty Host Groups Cleanup ==="
for group in $(ipa hostgroup-find --sizelimit=0 --raw | grep "cn:" | awk '{print $2}'); do
    # デフォルトグループはスキップ
    if [[ "$group" == "ipaservers" ]]; then
        continue
    fi
    
    members=$(ipa hostgroup-show "$group" --raw | grep "member:" | wc -l)
    if [ "$members" -eq 0 ]; then
        echo "Empty group found: $group"
        read -p "Delete this group? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ipa hostgroup-del "$group"
        fi
    fi
done
```

#### ホストグループレポート生成
```bash
#!/bin/bash
# /usr/local/bin/hostgroup-report.sh

OUTPUT_FILE="/tmp/hostgroup-report-$(date +%Y%m%d).csv"

echo "Group Name,Description,Member Count,Members" > "$OUTPUT_FILE"

for group in $(ipa hostgroup-find --sizelimit=0 --raw | grep "cn:" | awk '{print $2}'); do
    desc=$(ipa hostgroup-show "$group" --raw | grep "description:" | cut -d: -f2- | xargs)
    members=$(ipa hostgroup-show "$group" --raw | grep "member:" | awk -F',' '{print $1}' | awk -F'=' '{print $2}' | tr '\n' ';')
    count=$(ipa hostgroup-show "$group" --raw | grep -c "member:")
    
    echo "\"$group\",\"$desc\",$count,\"$members\"" >> "$OUTPUT_FILE"
done

echo "Report generated: $OUTPUT_FILE"
```

## アンインストール（手動）

ホストグループ設定を削除する手順：

1. ホストグループからホストを削除：
```bash
# 特定のホストを削除
ipa hostgroup-remove-member webservers --hosts=web01.example.com

# すべてのホストを削除
for host in $(ipa hostgroup-show webservers --raw | grep "member:" | awk -F',' '{print $1}' | awk -F'=' '{print $2}'); do
    ipa hostgroup-remove-member webservers --hosts="$host"
done
```

2. Automemberルールの削除：
```bash
# 条件を削除
ipa automember-remove-condition webservers --type=hostgroup \
    --inclusive-regex='^web[0-9]+\.example\.com$' --key=fqdn

# Automemberルールを削除
ipa automember-del webservers --type=hostgroup
```

3. ホストグループの削除：
```bash
# 依存関係の確認
ipa hbacrule-find --hostgroup=webservers
ipa sudorule-find --hostgroup=webservers

# ホストグループを削除
ipa hostgroup-del webservers
```

4. 削除の確認：
```bash
# グループが削除されたことを確認
ipa hostgroup-show webservers

# ホストの所属グループを再確認
ipa host-show web01.example.com --all | grep "Member of host-groups"
```