# apt_no_recommends

APT の推奨（Recommends）・提案（Suggests）パッケージの自動導入を無効化するロール

## 概要

### このドキュメントの目的

このロールは Debian 系ホストにおいて、APT が推奨・提案パッケージを自動導入しないよう設定する。これによりカーネル更新等での不要パッケージの流入を防ぐ。Ansible による自動設定と手動設定の両方の手順を説明する。

### 解決する問題

minimal クラウドイメージ（例: `ubuntu-24.04-minimal-cloudimg`）は initrd を生成せずにブートする設計で、初期状態では `initramfs-tools` を持たない。しかし Ubuntu のカーネルパッケージ `linux-image-X.X.X-generic` は `initramfs-tools` を Recommends（推奨）として要求するため、システム既定の `APT::Install-Recommends "1"` の下で行われるカーネル更新のたびに `initramfs-tools` が流入する。結果として、同じイメージ由来でもホストの更新履歴に応じてツールの有無がばらつく。

本ロールで Recommends をグローバルに無効化することで、全 apt 経路（自動更新・手動一括更新・手動 apt 操作）で不要パッケージの流入を恒久的に抑止する。

### 実現される機能

- apt 設定ドロップイン（`/etc/apt/apt.conf.d/99no-recommends`）の配置
- `APT::Install-Recommends "false"` による推奨パッケージの自動導入の無効化
- `APT::Install-Suggests "false"` による提案パッケージの自動導入の無効化（既定でも実質無効だが意図を明示）
- 非 Debian 系ホスト（Alpine 等）では `when` 条件によりスキップ

### 既存パッケージへの影響

- **既存パッケージは削除しない**: Recommends 無効化は将来の更新・新規導入にのみ作用する。既に導入済みのパッケージ（`initramfs-tools` を含む）はそのまま保持される。
- APT は既定で `APT::AutoRemove::RecommendsImportant "true"`（コンパイル時デフォルト）により、過去に Recommends で導入された自動マーク済みパッケージを `autoremove` から保護する。よって unattended-upgrades の `Remove-Unused-Dependencies "true"` と併用しても、既存の Recommends 由来パッケージが直ちに削除されることはない。
- 物理ホストやフルイメージ VM は既に `initramfs-tools` を保持しているため、Recommends 無効化後もカーネル更新時に既存の `initramfs-tools` で initrd が再生成される。起動への悪影響は無い。

## 要件と前提条件

### 共通要件

- Debian 系 OS（Debian, Ubuntu）。非 Debian 系では何も行わない
- root 権限または sudo 権限

### Ansible 固有の要件

- プレイブックレベルで `become: true` の指定が必要

### 手動設定の要件

- テキストエディターが利用可能であること

## 設定方法

### 方法1: Ansible Role を使用

#### ロール変数

なし。

#### 依存関係

なし。ただし apt 基盤設定であるため、パッケージ更新（`os_base/auto_update`）より前に適用する必要がある。`site.yml` では `os_base/pkg_cache_client` の直後（Phase 1）に配置している。

#### タグとハンドラー

`apt_no_recommends` タグを付与している。ハンドラーは持たない（ドロップインは次回以降の apt 操作で自動的に有効化される）。

#### 使用例

```yaml
- hosts: debian_hosts
  become: true
  roles:
    - role: os_base/apt_no_recommends
      tags: apt_no_recommends
```

### 方法2: 手動での設定手順

#### ステップ1: ドロップインファイルの作成

```bash
cat <<'EOF' | sudo tee /etc/apt/apt.conf.d/99no-recommends
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF
```

#### ステップ2: 設定値の確認

```bash
apt-config dump | grep -iE 'Install-Recommends|Install-Suggests'
# 期待: APT::Install-Recommends "false"; / APT::Install-Suggests "false";
```

## 運用管理

### 特定パッケージ導入時のみ Recommends を戻す

ある特定のパッケージについてだけ推奨依存も導入したい場合は、グローバル設定を変えずに `--install-recommends` を付けて導入する。

```bash
sudo apt-get install --install-recommends <pkg>
```

### initrd が必要なホストでの明示導入

将来、minimal イメージ由来の VM を initrd ありへ切り替える場合、Recommends 無効化下では `initramfs-tools` が自動導入されないため、明示的に導入する。

```bash
sudo apt-get install initramfs-tools
```

これは設計上意図した挙動である。`os_base/kernel_modules_disable` ロールのハンドラーは `initramfs-tools` の有無をガードしており、ツールが在れば使い無ければスキップする。

### トラブルシューティング

1. **新規プロビジョニングでパッケージが欠落する場合**: 暗黙の Recommends 依存に頼っていた可能性がある。当該パッケージを必要とするロールの `apt` タスクへ `name` で明示追加する。
2. **設定が効いていない場合**: `/etc/apt/apt.conf.d/` 配下に `Install-Recommends "true"` を明示する別のドロップインが無いか確認する。ファイル名は番号順に評価されるため、より大きい番号のファイルが優先される。

## アンインストール（手動）

```bash
sudo rm /etc/apt/apt.conf.d/99no-recommends
```

削除すれば即座に既定挙動（`APT::Install-Recommends "1"`）へ復帰する。既存の導入済みパッケージには手を加えないため、削除は無害である。
