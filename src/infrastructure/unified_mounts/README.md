# unified_mounts

統合マウント管理ロール

## 概要

このロールは、ローカルファイルシステム、NFS、CIFS等のマウントを単一のインターフェースで管理します。

### 実現される機能

- 必要なクライアントパッケージの自動インストール（NFS、CIFS）
- マウントポイントディレクトリの自動作成
- `/etc/fstab`エントリの管理

## 要件と前提条件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

## 設定方法

### 直接リスト形式 (`unified_mounts`)

```yaml
unified_mounts:
  # ローカルファイルシステム
  - src: /dev/sdb1
    path: /data
    fstype: ext4
    opts: defaults,noatime
    dump: 0
    passno: 2
    state: mounted
    mode: '0755'

  # NFSマウント
  - src: "10.120.61.53:/home"
    path: /nfs/home
    fstype: nfs4
    opts: "nofail,hard,bg,fsc"
    state: mounted

  # CIFSマウント
  - src: "//server/share"
    path: /mnt/cifs
    fstype: cifs
    opts: "credentials=/etc/samba/creds,uid=1000"
    state: mounted
```

### パターン/セレクタ形式 (`unified_mount_patterns` + `unified_mount_selectors`)

大規模環境でマウントパターンを共通定義し、ホスト毎に選択する場合に有用です。

`group_vars/all.yml`:
```yaml
unified_mount_patterns:
  home:
    src: "10.120.61.53:/home"
    path: /nfs/home
    fstype: nfs4
    opts: "nofail,hard,bg,fsc"
    state: mounted
  ssd2024:
    src: "10.120.61.52:/ssd2024"
    path: /nfs/ssd2024
    fstype: nfs4
    opts: "nofail,hard,bg,fsc"
    state: mounted
```

`host_vars/server1.yml`:
```yaml
unified_mount_selectors:
  - home
  - ssd2024
```

## ロール変数

| 変数名 | 説明 | デフォルト値 | 必須 |
|--------|------|-------------|------|
| `unified_mounts` | マウント設定のリスト | `[]` | いいえ |
| `unified_mount_patterns` | マウントパターンの辞書 | `{}` | いいえ |
| `unified_mount_selectors` | 適用するパターン名のリスト | `[]` | いいえ |

### マウント設定の属性

| 属性 | 説明 | デフォルト値 | 必須 |
|------|------|-------------|------|
| `src` | ソースデバイスまたはリモートパス | なし | はい |
| `path` | マウントポイントのパス | なし | はい |
| `fstype` | ファイルシステムタイプ | なし | はい |
| `opts` | マウントオプション | なし | いいえ |
| `dump` | dumpフラグ | `0` | いいえ |
| `passno` | fsckパス番号 | `0` | いいえ |
| `state` | マウント状態 | `mounted` | いいえ |
| `mode` | ディレクトリのパーミッション | `'0755'` | いいえ |
| `owner` | ディレクトリの所有者 | `root` | いいえ |
| `group` | ディレクトリのグループ | `root` | いいえ |

### state の値

| 値 | 説明 |
|----|------|
| `mounted` | マウントし、fstabに追加 |
| `present` | fstabに追加のみ（マウントしない） |
| `unmounted` | アンマウントするが、fstabには残す |
| `absent` | アンマウントし、fstabから削除 |

## 依存関係

なし
