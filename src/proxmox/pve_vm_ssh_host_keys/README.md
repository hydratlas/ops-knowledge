# pve_vm_ssh_host_keys

Proxmox VE仮想マシンのSSHホストキーを永続化し、VM再作成時のホストキー警告を防止するロール

## 概要

### このドキュメントの目的
このロールは、Proxmox VE環境でのVM SSHホストキーの管理機能を提供します。virtiofs共有ストレージを使用してホストキーを永続化し、VMの再作成やリビルド時でも同じSSHホストキーを維持できるようにします。Ansibleによる自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- VM SSHホストキーの永続化
- VM再作成時のSSH接続警告の防止
- virtiofs共有ストレージを介したホストキー管理
- 複数VMのホストキー一元管理
- セキュアなホストキー配布

## 要件と前提条件

### 共通要件
- **OS**: Proxmox VE 6.x, 7.x, 8.x（ホスト側）
- **権限**: root権限（Proxmox VEホスト上）
- **ストレージ**: virtiofs共有ストレージの事前設定
- **VM OS**: Linux系OS（Debian, Ubuntu, RHEL等）

### Ansible固有の要件
- **Ansible バージョン**: 2.9以上
- **コレクション**: ansible.builtin
- **制御ノード**: Python 3.6以上
- **実行対象**: Proxmox VEホスト

### 手動設定の要件
- SSHアクセス（Proxmox VEホストおよびVM）
- ssh-keygenコマンド
- virtiofs共有の事前設定

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|--------------|------|
| `pve_vm_ssh_host_keys` | VMごとのSSHホストキー設定リスト | `[]` | はい |
| `pve_vm_ssh_host_keys[].vmid` | VM ID | - | はい |
| `pve_vm_ssh_host_keys[].key` | SSH秘密鍵の内容 | - | はい |
| `pve_vm_ssh_host_keys[].key_pub` | SSH公開鍵の内容 | - | はい |

#### 依存関係
他のロールへの依存関係はありません。

#### タグとハンドラー
このロールにはタグやハンドラーは定義されていません。

#### 使用例

基本的な使用例：
```yaml
---
- name: Configure VM SSH host keys on Proxmox VE host
  hosts: proxmox_hosts
  become: yes
  vars:
    pve_vm_ssh_host_keys:
      - vmid: 100
        key: |
          -----BEGIN OPENSSH PRIVATE KEY-----
          b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
          ...
          -----END OPENSSH PRIVATE KEY-----
        key_pub: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHg..."
      - vmid: 101
        key: |
          -----BEGIN OPENSSH PRIVATE KEY-----
          ...
          -----END OPENSSH PRIVATE KEY-----
        key_pub: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJk..."
  roles:
    - pve_vm_ssh_host_keys
```

複数VMの一括設定例：
```yaml
---
- name: Generate and deploy SSH host keys for VMs
  hosts: proxmox_hosts
  become: yes
  tasks:
    - name: Generate SSH host keys for each VM
      ansible.builtin.command:
        cmd: ssh-keygen -t ed25519 -f /tmp/ssh_host_{{ item }}_key -N '' -C ''
      loop:
        - 100
        - 101
        - 102
      changed_when: true

    - name: Read generated keys
      ansible.builtin.slurp:
        src: "/tmp/ssh_host_{{ item.vmid }}_key{{ item.suffix }}"
      register: ssh_keys
      loop:
        - { vmid: 100, suffix: "" }
        - { vmid: 100, suffix: ".pub" }
        - { vmid: 101, suffix: "" }
        - { vmid: 101, suffix: ".pub" }
        - { vmid: 102, suffix: "" }
        - { vmid: 102, suffix: ".pub" }

    - name: Deploy SSH host keys
      ansible.builtin.include_role:
        name: pve_vm_ssh_host_keys
      vars:
        pve_vm_ssh_host_keys: "{{ ssh_keys_formatted }}"
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

1. Proxmox VEホストにroot権限でログイン：
```bash
ssh root@proxmox-host
```

2. virtiofs共有ディレクトリの確認：
```bash
# virtiofs共有の基本ディレクトリを確認
ls -la /mnt/pve/virtiofs-share/
```

3. 作業ディレクトリの作成：
```bash
mkdir -p /tmp/ssh-keys-setup
cd /tmp/ssh-keys-setup
```

#### ステップ2: SSHホストキーの生成

単一VMのキー生成：
```bash
# VM IDを設定
VMID=100

# Ed25519キーペアを生成（推奨）
ssh-keygen -t ed25519 -f ssh_host_ed25519_key_${VMID} -N '' -C "vm-${VMID}"

# RSAキーペアも生成（互換性のため）
ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key_${VMID} -N '' -C "vm-${VMID}"

# ECDSAキーペアも生成（必要に応じて）
ssh-keygen -t ecdsa -b 521 -f ssh_host_ecdsa_key_${VMID} -N '' -C "vm-${VMID}"
```

複数VMの一括キー生成スクリプト：
```bash
#!/bin/bash
# /tmp/generate-vm-ssh-keys.sh

VM_IDS="100 101 102 103"

for VMID in $VM_IDS; do
    echo "Generating SSH host keys for VM ${VMID}..."
    
    # Ed25519キー（推奨）
    ssh-keygen -t ed25519 -f ssh_host_ed25519_key_${VMID} -N '' -C "vm-${VMID}" -q
    
    # RSAキー（互換性）
    ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key_${VMID} -N '' -C "vm-${VMID}" -q
    
    echo "Keys generated for VM ${VMID}"
done
```

#### ステップ3: 設定

virtiofs共有へのキー配置：
```bash
# VM IDを設定
VMID=100

# VMごとのディレクトリ作成
mkdir -p /mnt/pve/virtiofs-share/${VMID}/ssh_host_key
chmod 700 /mnt/pve/virtiofs-share/${VMID}/ssh_host_key

# Ed25519キーの配置
cp ssh_host_ed25519_key_${VMID} /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_ed25519_key
cp ssh_host_ed25519_key_${VMID}.pub /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_ed25519_key.pub

# RSAキーの配置
cp ssh_host_rsa_key_${VMID} /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_rsa_key
cp ssh_host_rsa_key_${VMID}.pub /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_rsa_key.pub

# パーミッション設定
chmod 600 /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_*_key
chmod 644 /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_*_key.pub

# 所有者設定
chown -R root:root /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/
```

VM側でのホストキー適用スクリプト（cloud-initやVM初回起動時に実行）：
```bash
#!/bin/bash
# /usr/local/bin/restore-ssh-host-keys.sh

# virtiofs共有のマウント確認
if ! mountpoint -q /mnt/host-ssh-keys; then
    echo "Mounting virtiofs share..."
    mount -t virtiofs host-ssh-keys /mnt/host-ssh-keys
fi

# 既存のホストキーをバックアップ
if [ ! -d /etc/ssh/original-keys ]; then
    mkdir -p /etc/ssh/original-keys
    cp /etc/ssh/ssh_host_* /etc/ssh/original-keys/ 2>/dev/null || true
fi

# virtiofs共有からホストキーをコピー
echo "Restoring SSH host keys from virtiofs share..."
cp /mnt/host-ssh-keys/ssh_host_* /etc/ssh/ 2>/dev/null

# パーミッション修正
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

# SSHサービス再起動
systemctl restart ssh || systemctl restart sshd

echo "SSH host keys restored successfully"
```

#### ステップ4: 起動と有効化

systemdサービスとして自動化（VM側）：
```bash
# サービスファイル作成
cat > /etc/systemd/system/restore-ssh-host-keys.service << 'EOF'
[Unit]
Description=Restore SSH Host Keys from virtiofs
After=network.target
Before=ssh.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/restore-ssh-host-keys.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# サービス有効化
systemctl daemon-reload
systemctl enable restore-ssh-host-keys.service
systemctl start restore-ssh-host-keys.service
```

## 運用管理

### 基本操作

ホストキーの確認：
```bash
# Proxmox VEホスト側で確認
ls -la /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/

# フィンガープリント確認
for key in /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/*.pub; do
    echo "=== $(basename $key) ==="
    ssh-keygen -lf "$key"
done

# VM側で適用されているキーの確認
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

### ログとモニタリング

関連ログファイル：
- `/var/log/syslog` - システムログ（virtiofs関連）
- `/var/log/auth.log` - SSH認証ログ
- `journalctl -u ssh` - SSHサービスログ
- `journalctl -u restore-ssh-host-keys` - ホストキー復元サービスログ

監視すべき項目：
- virtiofs共有のマウント状態
- SSHホストキーファイルの存在と権限
- SSH接続時のホストキー警告
- VM再作成後のSSH接続性

### トラブルシューティング

#### 問題1: virtiofs共有がマウントされない
**原因**: VM設定でvirtiofs共有が正しく設定されていない
**対処方法**:
```bash
# VM設定確認（Proxmox VEホスト側）
qm config ${VMID} | grep virtiofs

# 手動マウント（VM側）
mount -t virtiofs host-ssh-keys /mnt/host-ssh-keys
```

#### 問題2: ホストキーが適用されない
**原因**: パーミッションエラーまたはファイルパスの誤り
**対処方法**:
```bash
# パーミッション確認と修正
ls -la /mnt/host-ssh-keys/
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
```

#### 問題3: SSH接続時にホストキー警告が出る
**原因**: 新しいホストキーが正しく配布されていない
**対処方法**:
```bash
# クライアント側でknown_hostsから古いエントリを削除
ssh-keygen -R vm-hostname

# 新しいホストキーのフィンガープリント確認
ssh-keyscan -H vm-hostname >> ~/.ssh/known_hosts
```

診断フロー：
1. virtiofs共有のマウント状態確認
2. ホストキーファイルの存在確認
3. ファイルのパーミッション確認
4. SSHサービスの状態確認
5. ログファイルの確認

### メンテナンス

#### ホストキーのローテーション
```bash
#!/bin/bash
# /usr/local/bin/rotate-vm-ssh-keys.sh

VMID=$1
if [ -z "$VMID" ]; then
    echo "Usage: $0 <VMID>"
    exit 1
fi

# バックアップディレクトリ作成
BACKUP_DIR="/mnt/pve/virtiofs-share/${VMID}/ssh_host_key/backup-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# 既存キーのバックアップ
cp /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_* "$BACKUP_DIR/"

# 新しいキーの生成
ssh-keygen -t ed25519 -f /tmp/new_ssh_host_ed25519_key -N '' -C "vm-${VMID}-$(date +%Y%m%d)"

# 新しいキーの配置
cp /tmp/new_ssh_host_ed25519_key* /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/

# パーミッション設定
chmod 600 /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_*_key
chmod 644 /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/ssh_host_*_key.pub

# 一時ファイル削除
rm -f /tmp/new_ssh_host_*

echo "SSH host keys rotated for VM ${VMID}"
```

#### バックアップとリストア
```bash
# 全VMのSSHホストキーバックアップ
tar czf /backup/vm-ssh-host-keys-$(date +%Y%m%d).tar.gz /mnt/pve/virtiofs-share/*/ssh_host_key/

# リストア
tar xzf /backup/vm-ssh-host-keys-20240301.tar.gz -C /
```

## アンインストール（手動）

SSHホストキー管理を削除する手順：

1. VM側でオリジナルのホストキーに戻す：
```bash
# VM側で実行
# オリジナルキーのリストア（バックアップがある場合）
if [ -d /etc/ssh/original-keys ]; then
    cp /etc/ssh/original-keys/* /etc/ssh/
    systemctl restart ssh
fi

# または新しいキーを生成
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
systemctl restart ssh
```

2. systemdサービスの無効化（VM側）：
```bash
systemctl disable restore-ssh-host-keys.service
systemctl stop restore-ssh-host-keys.service
rm -f /etc/systemd/system/restore-ssh-host-keys.service
systemctl daemon-reload
```

3. virtiofs共有からキーを削除（Proxmox VEホスト側）：
```bash
# 特定VMのキー削除
rm -rf /mnt/pve/virtiofs-share/${VMID}/ssh_host_key/

# または全VMのキー削除（注意して実行）
# rm -rf /mnt/pve/virtiofs-share/*/ssh_host_key/
```

4. クライアント側のknown_hosts更新：
```bash
# 影響を受けるVMのエントリを削除
ssh-keygen -R vm-hostname
```