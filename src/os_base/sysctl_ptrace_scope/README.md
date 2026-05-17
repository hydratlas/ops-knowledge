# sysctl_ptrace_scope

`kernel.yama.ptrace_scope`をsysctlドロップインで永続化するロール

## 概要

### このドキュメントの目的

このロールは、Yama LSMの`kernel.yama.ptrace_scope`を`/etc/sysctl.d/`配下のドロップインファイルとして書き込み、再起動後も設定が維持されるようにする。Ansibleによる自動設定と手動設定の両方の方法を説明する。

### 実現される機能

- `/etc/sysctl.d/60-ptrace-scope.conf`に`kernel.yama.ptrace_scope`の設定を書き込む
- 設定変更時は`sysctl --system`をハンドラーで実行して即時反映する

### `kernel.yama.ptrace_scope`の値

| 値  | 挙動                                                                   |
| --- | ---------------------------------------------------------------------- |
| 0   | 同一uidの任意プロセスにptrace可能（古い挙動）                          |
| 1   | 直系の親プロセスのみptrace可能（多くのディストリビューションの既定値） |
| 2   | `CAP_SYS_PTRACE`を持つ管理者のみptrace可能（本ロールの既定）           |
| 3   | ptraceを完全に無効化（一度設定すると再起動まで戻せない）               |

本ロールに既定値はない（`sysctl_ptrace_scope_value`が未定義のときは何もしない）。本リポジトリの運用では`tofu_virtual`および`general`グループに対して`2`を設定している。値`3`は再起動するまで戻せないため、設定する場合はその挙動を理解した上で利用する。

## 要件と前提条件

### 共通要件

- Yama LSMが有効なLinuxカーネル（Ubuntu/Debian/RHEL系・AlmaLinux等の主要ディストリビューションでは既定で有効）
- root権限

### Ansible固有の要件

- Ansible 2.14以降
- プレイブックレベルで`become: true`

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                      | デフォルト | 説明                                                                       |
| --------------------------- | ---------- | -------------------------------------------------------------------------- |
| `sysctl_ptrace_scope_value` | （未定義） | `kernel.yama.ptrace_scope`に設定する値（0〜3）。未定義のときはドロップインファイルを配置せず、既に存在する場合は削除する |

ドロップインファイルの配置先は`/etc/sysctl.d/60-ptrace-scope.conf`にハードコードされている。デフォルトでは配置しない設計のため、適用したいグループの`group_vars`等で`sysctl_ptrace_scope_value`に値を与えることで有効化する。値を未定義に戻すと既存のドロップインファイルは削除され、ハンドラーで`sysctl --system`が実行される。`site.yml`では全Linuxホストに対してロールを適用しており、`group_vars/tofu_virtual.yml`および`group_vars/general.yml`で値`2`を与えている。

#### 依存関係

なし

#### タグとハンドラー

- ハンドラー: `reload sysctl`（`sysctl --system`を実行）

### 方法2: 手動での設定手順

`/etc/sysctl.d/60-ptrace-scope.conf`に以下を書き込む。

```
kernel.yama.ptrace_scope = 2
```

書き込み後、設定を即時反映するには次を実行する。

```bash
sudo sysctl --system
```

## 運用管理

### 確認方法

```bash
# 現在の値を確認
sysctl kernel.yama.ptrace_scope

# /etc/sysctl.d/ 配下の設定ファイルから読み込まれる値を確認
sudo sysctl --system 2>&1 | grep ptrace_scope

# ドロップインファイルの内容を確認
cat /etc/sysctl.d/60-ptrace-scope.conf
```

### トラブルシューティング

- **問題**: gdbやstrace等のデバッガが他プロセスにアタッチできない
  - **対処**: `ptrace_scope = 2`では`CAP_SYS_PTRACE`が必要。`sudo`経由で実行するか、一時的に`sudo sysctl -w kernel.yama.ptrace_scope=1`で値を緩める
- **問題**: 設定したのに値が反映されない
  - **対処**: 他のドロップイン（`/etc/sysctl.d/`や`/usr/lib/sysctl.d/`配下）が後勝ちで上書きしている可能性がある。`sudo sysctl --system`の出力を確認する

## アンインストール（手動）

```bash
sudo rm /etc/sysctl.d/60-ptrace-scope.conf
sudo sysctl --system
```
