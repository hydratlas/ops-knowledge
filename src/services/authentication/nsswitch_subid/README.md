# nsswitch_subid

コンテナのrootless実行に必要なsubuid/subgidマッピングをSSSDで集中管理するための設定ロール

## 概要

### このドキュメントの目的
このロールは、NSS（Name Service Switch）のsubuid/subgid設定機能を提供します。SSSDをプロバイダーとして設定することで、FreeIPAなどの集中管理システムからUID/GIDマッピング情報を取得できるようにします。Ansibleによる自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- NSS経由でのsubuid/subgid情報の集中管理
- rootlessコンテナのUID/GIDマッピング自動化
- FreeIPAとの統合によるユーザー名前空間の管理
- ローカルファイル管理からの脱却
- マルチホスト環境での一貫性確保

## 要件と前提条件

### 共通要件
- **OS**: Linux（Podman/Dockerのrootlessモードをサポート）
- **権限**: root権限またはsudo権限
- **パッケージ**: sssd, sssd-tools
- **統合**: FreeIPAサーバーまたは互換LDAPサーバー

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: ansible.builtin
- **実行権限**: become: true必須
- **前提ロール**: SSSDの事前設定

### 手動設定の要件
- SSSDが正しく設定され動作していること
- FreeIPAクライアントとして登録済み（推奨）
- テキストエディタ（vi, nano等）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はありません。

#### 依存関係
- SSSDが事前にインストール・設定されていること
- FreeIPAクライアント設定（推奨）

#### タグとハンドラー
| 種類 | 名前 | 説明 |
|------|------|------|
| ハンドラー | Restart sssd | SSSDサービスを再起動 |

#### 使用例

基本的な使用例：
```yaml
---
- name: Configure NSS subid for container hosts
  hosts: container_hosts
  become: yes
  roles:
    - nsswitch_subid
```

FreeIPAクライアント設定と組み合わせた例：
```yaml
---
- name: Setup container host with centralized subid management
  hosts: container_hosts
  become: yes
  roles:
    - freeipa_client
    - sssd_config
    - nsswitch_subid
    - podman_rootless
```

コンテナ環境の完全セットアップ例：
```yaml
---
- name: Configure complete container environment
  hosts: container_hosts
  become: yes
  tasks:
    - name: Ensure container packages are installed
      ansible.builtin.package:
        name:
          - podman
          - buildah
          - skopeo
        state: present

  roles:
    - nsswitch_subid
    
  post_tasks:
    - name: Verify subid configuration
      ansible.builtin.command: getent subuid {{ ansible_user }}
      register: subuid_check
      changed_when: false
      
    - name: Display subuid mapping
      ansible.builtin.debug:
        var: subuid_check.stdout
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

1. SSSDの動作確認：
```bash
# SSSDサービスの状態確認
sudo systemctl status sssd

# SSSDの設定確認
sudo sssctl config-check

# ドメイン情報の確認
sudo sssctl domain-list
```

2. 現在のNSS設定の確認：
```bash
# nsswitch.confのバックアップ
sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.$(date +%Y%m%d-%H%M%S)

# 現在の設定表示
cat /etc/nsswitch.conf
```

#### ステップ2: NSS設定の更新

nsswitch.confの編集：
```bash
# ファイルを編集
sudo vi /etc/nsswitch.conf

# または
sudo nano /etc/nsswitch.conf
```

以下の行を追加または更新：
```
# Name Service Switch configuration
passwd:     files sss systemd
group:      files sss systemd
shadow:     files sss
hosts:      files dns myhostname
networks:   files

# Container subuid/subgid mapping
subid:      sss
```

**重要**: `subid: files sss` のように複数のソースを指定すると、SSSDが正しく動作しない場合があります。`subid: sss` のみを指定してください。

#### ステップ3: 設定の適用

設定を適用して確認：
```bash
# SELinuxコンテキストの修正（SELinuxが有効な場合）
if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
    sudo restorecon /etc/nsswitch.conf
fi

# SSSDサービスの再起動
sudo systemctl restart sssd

# サービス状態の確認
sudo systemctl status sssd
```

#### ステップ4: 動作確認

subuid/subgidマッピングの確認：
```bash
# 現在のユーザーのsubuidを確認
getent subuid $(whoami)

# 現在のユーザーのsubgidを確認
getent subgid $(whoami)

# 特定ユーザーのマッピング確認
getent subuid username
getent subgid username

# SSSDキャッシュの確認
sudo sss_cache -u username
```

## 運用管理

### 基本操作

日常的な確認コマンド：
```bash
# subuidマッピングの一覧
getent subuid

# subgidマッピングの一覧
getent subgid

# 特定ユーザーの名前空間情報
podman unshare cat /proc/self/uid_map
podman unshare cat /proc/self/gid_map

# コンテナ実行時のUID/GID確認
podman run --rm alpine:latest id
```

### ログとモニタリング

関連ログファイル：
- `/var/log/sssd/sssd.log` - SSSDメインログ
- `/var/log/sssd/sssd_nss.log` - NSS関連ログ
- `/var/log/sssd/sssd_<domain>.log` - ドメイン固有ログ
- `journalctl -u sssd` - systemdジャーナル

監視すべき項目：
- SSSDサービスの稼働状態
- FreeIPAサーバーとの接続状態
- subuid/subgidクエリの応答時間
- キャッシュのヒット率
- エラーログの発生頻度

監視スクリプト例：
```bash
#!/bin/bash
# /usr/local/bin/check-subid-mapping.sh

echo "=== Subid Mapping Status Check ==="
echo "Date: $(date)"
echo

# SSSDサービス状態
echo "--- SSSD Service Status ---"
systemctl is-active sssd || echo "WARNING: SSSD is not running"

# NSS設定確認
echo -e "\n--- NSS Configuration ---"
grep "^subid:" /etc/nsswitch.conf || echo "WARNING: subid not configured in nsswitch.conf"

# マッピング確認
echo -e "\n--- Current User Mappings ---"
echo "User: $(whoami)"
getent subuid $(whoami) || echo "ERROR: No subuid mapping found"
getent subgid $(whoami) || echo "ERROR: No subgid mapping found"

# コンテナランタイムテスト
echo -e "\n--- Container Runtime Test ---"
if command -v podman &> /dev/null; then
    podman run --rm alpine:latest echo "Podman rootless: OK" || echo "Podman rootless: FAILED"
fi
```

### トラブルシューティング

#### 問題1: getent subuidが何も返さない
**原因**: SSSDが正しく設定されていないか、FreeIPAにsubuid情報がない
**対処方法**:
```bash
# SSSDの詳細ログを有効化
sudo sed -i 's/debug_level.*/debug_level = 9/g' /etc/sssd/sssd.conf
sudo systemctl restart sssd

# ログを確認
sudo tail -f /var/log/sssd/sssd_nss.log

# FreeIPAサーバー側で確認
ipa user-show username --all | grep -i sub
```

#### 問題2: コンテナ実行時に権限エラー
**原因**: subuid/subgidマッピングが正しく取得できていない
**対処方法**:
```bash
# キャッシュをクリア
sudo sss_cache -E

# ローカルファイルの確認
ls -la /etc/sub{u,g}id

# 名前空間の手動確認
podman unshare id
podman unshare cat /proc/self/{u,g}id_map
```

#### 問題3: SSSDサービスが起動しない
**原因**: 設定ファイルのエラーまたは依存関係の問題
**対処方法**:
```bash
# 設定ファイルの検証
sudo sssctl config-check

# 手動起動でエラー確認
sudo /usr/sbin/sssd -d 3 -i

# SELinuxの確認
sudo ausearch -m avc -ts recent | grep sssd
```

診断フロー：
1. NSS設定の構文確認
2. SSSDサービスの状態確認
3. FreeIPAサーバーとの接続確認
4. subuid/subgidクエリのテスト
5. コンテナランタイムでの動作確認

### メンテナンス

#### キャッシュ管理
```bash
#!/bin/bash
# /usr/local/bin/sssd-cache-maintenance.sh

# キャッシュ統計の表示
echo "=== SSSD Cache Statistics ==="
sudo sssctl cache-expire -E

# 特定ユーザーのキャッシュ更新
update_user_cache() {
    local user=$1
    echo "Updating cache for user: $user"
    sudo sss_cache -u $user
    getent subuid $user > /dev/null
    getent subgid $user > /dev/null
}

# 全ユーザーのキャッシュ更新
echo "Updating all user caches..."
for user in $(getent passwd | cut -d: -f1); do
    update_user_cache $user
done
```

#### 設定の監査
```bash
#!/bin/bash
# /usr/local/bin/audit-subid-config.sh

# 設定ファイルのチェックサム
echo "Configuration checksums:"
md5sum /etc/nsswitch.conf
md5sum /etc/sssd/sssd.conf

# アクティブな設定の確認
echo -e "\nActive NSS providers:"
grep -E "^(passwd|group|subid):" /etc/nsswitch.conf

# マッピングの統計
echo -e "\nSubid mapping statistics:"
getent subuid | wc -l | xargs echo "Total subuid mappings:"
getent subgid | wc -l | xargs echo "Total subgid mappings:"
```

## アンインストール（手動）

NSS subid設定を元に戻す手順：

1. nsswitch.confの設定を元に戻す：
```bash
# バックアップから復元
sudo cp /etc/nsswitch.conf.backup /etc/nsswitch.conf

# または手動で編集
sudo vi /etc/nsswitch.conf
# subid: の行を削除またはコメントアウト
```

2. ローカルファイルベースの設定に戻す（必要に応じて）：
```bash
# ローカルのsubuid/subgidファイルを作成
echo "$(whoami):100000:65536" | sudo tee -a /etc/subuid
echo "$(whoami):100000:65536" | sudo tee -a /etc/subgid

# nsswitch.confを更新
echo "subid: files" | sudo tee -a /etc/nsswitch.conf
```

3. SSSDサービスの再起動：
```bash
sudo systemctl restart sssd
```

4. 設定の確認：
```bash
# ローカルファイルからの読み込みを確認
getent subuid $(whoami)
getent subgid $(whoami)

# コンテナの動作確認
podman run --rm alpine:latest id
```

5. 不要なキャッシュのクリア：
```bash
sudo sss_cache -E
```