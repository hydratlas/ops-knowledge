# curl

Alpine Linux に curl コマンドをインストールするロール

## 概要

### このドキュメントの目的

このロールは Alpine Linux 上に curl パッケージをインストールする。Ansible による自動設定と手動設定の両方の手順を説明する。

### 実現される機能

- curl パッケージのインストール

## 要件と前提条件

### 共通要件

- Alpine Linux
- root 権限または sudo 権限

### Ansible 固有の要件

- Ansible 2.9 以降
- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件

- apk コマンドが利用可能であること

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

なし

#### 依存関係

なし

#### タグとハンドラー

なし

#### 使用例

```yaml
- hosts: static_file_servers
  become: true
  roles:
    - role: os_base/curl
```

### 方法2: 手動での設定手順

#### ステップ1: インストール

```bash
sudo apk add curl
```

## 運用管理

### 基本操作

```bash
# バージョン確認
curl --version
```

### トラブルシューティング

1. **curl コマンドが見つからない場合**: `apk info curl` でパッケージがインストールされているか確認する

## アンインストール（手動）

```bash
sudo apk del curl
```
