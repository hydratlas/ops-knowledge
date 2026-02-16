# fuse_overlayfs

fuse-overlayfsインストールロール

## 概要

### このドキュメントの目的
このロールは、NFSやその他のネットワークファイルシステム上でoverlayfsを利用するために必要なfuse-overlayfsパッケージをインストールする。

### 実現される機能
- fuse-overlayfsパッケージのインストール
- NFS上でのoverlayfsストレージドライバーの利用を可能にする
- ネイティブoverlayfsをサポートしないファイルシステムでのオーバーレイマウント

### 背景
NFSなどのネットワークファイルシステムはカーネルレベルのoverlayfsをネイティブにサポートしていない。fuse-overlayfsを使用することで、FUSEベースのオーバーレイファイルシステムを利用し、この制限を回避できる。

## 要件と前提条件

### 共通要件
- サポートされるOS：
  - RHEL/CentOS/AlmaLinux/Rocky Linux 8以降
  - Fedora 33以降
  - Debian 11以降
  - Ubuntu 20.04以降
- インターネット接続（パッケージダウンロード用）

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要
- 制御ノードから対象ホストへのSSH接続

### 手動設定の要件
- rootまたはsudo権限

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はない。OSファミリーに基づいて自動的にパッケージマネージャーを選択する。

#### 依存関係
このロールには依存関係はない。

#### タグとハンドラー
このロールでは特定のタグやハンドラーは使用していない。

#### 使用例

基本的な使用例：
```yaml
- hosts: nfs_home_client_hosts
  become: true
  roles:
    - infrastructure/fuse_overlayfs
```

### 方法2: 手動での設定手順

#### ステップ1: fuse-overlayfsのインストール

##### Debian/Ubuntu系
```bash
sudo apt-get update
sudo apt-get install -y fuse-overlayfs
```

##### RHEL/CentOS/AlmaLinux/Rocky Linux系
```bash
sudo dnf install -y fuse-overlayfs
```

#### ステップ2: 動作確認

fuse-overlayfsがインストールされたことを確認：
```bash
which fuse-overlayfs
fuse-overlayfs --version
```

## 運用管理

### トラブルシューティング

#### 診断フロー
1. fuse-overlayfsがインストールされているか確認
2. FUSEデバイスへのアクセス権限を確認

#### よくある問題と対処

**問題**: パーミッションエラー
```bash
# FUSEへのアクセス権限を確認
ls -la /dev/fuse

# ユーザーがfuseグループに所属しているか確認
groups $USER
```

## アンインストール（手動）

fuse-overlayfsを削除する場合：

**Debian/Ubuntu系：**
```bash
sudo apt-get remove -y fuse-overlayfs
```

**RHEL/CentOS/Fedora系：**
```bash
sudo dnf remove -y fuse-overlayfs
```

注意：fuse-overlayfsを削除すると、NFSホームディレクトリを使用しているユーザーのコンテナランタイム動作に影響を与える可能性がある。
