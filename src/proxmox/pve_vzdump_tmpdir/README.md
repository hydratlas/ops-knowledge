# pve_vzdump_tmpdir

vzdumpバックアップの一時ディレクトリーをローカルに設定するロール

## 概要

### このドキュメントの目的

このロールはProxmox VEホストのvzdumpバックアップ時に使用する一時ディレクトリーをローカルの`/var/tmp`に設定する。Ansibleによる自動設定と手動設定の両方の方法を説明する。

### 実現される機能

- vzdumpの一時ディレクトリーをローカルファイルシステム（`/var/tmp`）に固定
- NFSマウント上でのバックアップ時に発生するPermission Deniedエラーの回避

### 背景

vzdumpはデフォルトでバックアップ先と同じストレージに一時ファイルを作成する。バックアップ先がNFSの場合、一時ファイル作成時にroot権限での書き込みがNFSの`root_squash`設定により拒否され、`Permission Denied`エラーが発生する。`tmpdir`をローカルの`/var/tmp`に設定することで、一時ファイルはローカルファイルシステム上に作成され、この問題を回避できる。これはProxmox公式ドキュメントで推奨されている方法であり、NFS側の権限変更は不要である。

## 要件と前提条件

### 共通要件

- Proxmox VE 7.x以降
- `/var/tmp`に十分な空き容量があること（バックアップ対象のVM/CTサイズ以上）

### Ansible固有の要件

- Ansible 2.9以降
- プレイブックレベルで`become: true`の指定が必要

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

このロールには設定可能な変数はない。

#### 依存関係

なし

#### タグとハンドラー

なし

#### 使用例

```yaml
- hosts: ve
  become: true
  roles:
    - pve_vzdump_tmpdir
```

### 方法2: 手動での設定手順

#### ステップ1: 現在の設定を確認

```bash
cat /etc/vzdump.conf
```

#### ステップ2: 空き容量を確認

```bash
df -h /var/tmp
```

#### ステップ3: 設定を追加

```bash
# /etc/vzdump.confにtmpdirを設定
echo 'tmpdir: /var/tmp' | sudo tee -a /etc/vzdump.conf
```

既に`tmpdir`行が存在する場合は、既存の行を編集する。

```bash
sudo sed -i 's/^#\?\s*tmpdir:.*/tmpdir: \/var\/tmp/' /etc/vzdump.conf
```

#### ステップ4: 設定を検証

```bash
grep '^tmpdir:' /etc/vzdump.conf
```

## 運用管理

### 基本操作

```bash
# 設定の確認
grep tmpdir /etc/vzdump.conf

# バックアップのテスト実行（VM ID 100の場合）
vzdump 100 --mode snapshot --compress zstd --storage <storage-name>
```

### トラブルシューティング

1. **バックアップ時に「No space left on device」エラーが発生する場合**

   `/var/tmp`の空き容量を確認し、不要なファイルを削除する。

   ```bash
   df -h /var/tmp
   ls -lah /var/tmp/
   ```

2. **設定が反映されない場合**

   `/etc/vzdump.conf`の内容を確認し、`tmpdir`行が正しく記載されていることを確認する。コメントアウトされていないことも確認する。

   ```bash
   grep -n tmpdir /etc/vzdump.conf
   ```

## アンインストール（手動）

```bash
# tmpdir行を削除
sudo sed -i '/^tmpdir:/d' /etc/vzdump.conf
```
