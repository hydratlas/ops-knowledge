# slurm_db

Slurmデータベースサーバー（slurmdbd + MariaDB）をUbuntu 24.04にインストールするロールである。slurmdbdデーモンとMariaDBをインストールし、クラスタのアカウンティングデータを管理する。

## 概要

このロールは以下を実行する：

- MariaDBサーバーのインストールと設定
- slurmdbdパッケージのインストール
- データベースとユーザーの作成（unix_socket認証）
- 設定ファイル（slurmdbd.conf、MariaDB設定）の配置
- 各種サービスの起動と有効化

## アーキテクチャ

```
slurm-db-01.int.home.arpa
  └── slurm_db ロール
      ├── MariaDB (ポート3306)
      └── slurmdbd (ポート6819)

slurm-ctrl-01.int.home.arpa
  └── slurm_ctrl ロール
      └── slurmctld (ポート6817)
          └── AccountingStorageHost → slurm-db-01
```

## 要件と前提条件

### 共通要件

- Ubuntu 24.04 LTS
- root権限またはsudo権限
- Slurm 23.11以降（Ubuntu 24.04標準パッケージ）

### Ansible固有の要件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要
- `community.mysql`コレクションが必要

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名           | デフォルト値         | 説明                                      |
| ---------------- | -------------------- | ----------------------------------------- |
| `slurm_db_name`  | `slurm_acct_db`      | データベース名                            |
| `slurm_db_user`  | `slurm`              | データベースユーザー                      |
| `slurm_dbd_host` | `{{ ansible_fqdn }}` | slurmdbdのホスト名                        |
| `slurm_dbd_addr` | `{{ ansible_fqdn }}` | slurmdbdのアドレス                        |
| `slurm_jwt_key`  | -（必須）            | Base64エンコードされたJWT key（32バイト） |

MariaDBはunix_socket認証を使用するため、パスワード設定は不要である。slurmdbdはローカルのUnixソケット経由でMariaDBに接続し、OSユーザー名（slurm）で認証される。

#### 依存関係

- `community.mysql`コレクション

#### 使用例

```yaml
- hosts: slurm_db_hosts
  become: true
  roles:
    - role: infrastructure/slurm_db
      vars:
        slurm_jwt_key: "{{ vault_slurm_jwt_key }}"
```

### 方法2: 手動での設定手順

以下はUbuntu 24.04でSlurmデータベースサーバーを手動セットアップする手順である。

#### ステップ1: MariaDBのインストール

MariaDBサーバーをインストールする。

```bash
sudo apt-get update
sudo apt-get install -y mariadb-server python3-pymysql
```

#### ステップ2: MariaDB設定の調整

Slurm用のMariaDB設定を追加する。

```bash
sudo tee /etc/mysql/mariadb.conf.d/90-slurm.cnf << 'EOF'
[mysqld]
bind-address = 0.0.0.0
innodb_buffer_pool_size = 1024M
innodb_log_file_size = 64M
innodb_lock_wait_timeout = 900
EOF

sudo systemctl restart mariadb
```

#### ステップ3: データベースの作成

MariaDBでSlurmアカウンティング用のデータベースとユーザーを作成する。unix_socket認証を使用するため、パスワードは不要である。

```bash
sudo mysql << 'EOF'
CREATE DATABASE slurm_acct_db;
CREATE USER 'slurm'@'localhost' IDENTIFIED VIA unix_socket;
GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'localhost';
FLUSH PRIVILEGES;
EOF
```

この設定により、slurmユーザーとして実行されるプロセスがUnixソケット経由で接続する場合、パスワードなしで認証される。

#### ステップ4: slurmdbdパッケージのインストール

slurmdbdパッケージをインストールする。

```bash
sudo apt-get install -y slurmdbd
```

#### ステップ5: JWT keyの配置

Slurm認証（auth/slurm）用のJWT keyを配置する。コントローラーノードと同じkeyを使用する必要がある。

```bash
echo "Base64エンコードされた文字列" | base64 -d | sudo tee /etc/slurm/slurm.key > /dev/null
sudo chown slurm:slurm /etc/slurm/slurm.key
sudo chmod 600 /etc/slurm/slurm.key
```

#### ステップ6: slurmdbd.confの作成

slurmdbdの設定ファイルを作成する。

```bash
sudo tee /etc/slurm/slurmdbd.conf << 'EOF'
AuthType=auth/slurm
DbdAddr=slurm-db-01.int.home.arpa
DbdHost=slurm-db-01.int.home.arpa
SlurmUser=slurm
DebugLevel=verbose
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/run/slurm/slurmdbd.pid

# MariaDB unix_socket authentication (no StorageHost/StoragePass needed)
StorageType=accounting_storage/mysql
StorageUser=slurm
StorageLoc=slurm_acct_db
EOF

sudo chown slurm:slurm /etc/slurm/slurmdbd.conf
sudo chmod 600 /etc/slurm/slurmdbd.conf
```

`DbdAddr`と`DbdHost`は環境に合わせて変更すること。

#### ステップ7: サービスの起動

slurmdbdを起動する。

```bash
sudo systemctl enable slurmdbd
sudo systemctl start slurmdbd

# slurmdbdの起動を待つ（ポート6819で待ち受け）
while ! ss -tlnp | grep -q ':6819'; do sleep 1; done
```

## 運用管理

### サービス状態の確認

```bash
sudo systemctl status mariadb
sudo systemctl status slurmdbd
```

### ログ確認

```bash
# slurmdbdのログ
sudo journalctl -u slurmdbd -f
sudo tail -f /var/log/slurm/slurmdbd.log
```

### トラブルシューティング

#### 診断フロー

1. サービス状態の確認

   ```bash
   sudo systemctl status mariadb
   sudo systemctl status slurmdbd
   ```

2. ポートの確認

   ```bash
   sudo ss -tlnp | grep -E '(6819|3306)'
   ```

3. データベース接続の確認（unix_socket認証）

   ```bash
   sudo -u slurm mysql slurm_acct_db -e "SHOW TABLES;"
   ```

#### よくある問題と対処方法

- **問題**: slurmdbdが起動しない
  - **対処**: MariaDBが起動しているか確認。slurmdbd.confのデータベース接続情報を確認

- **問題**: slurmctldから接続できない
  - **対処**: ファイアウォールでポート6819が開放されているか確認。JWT keyがコントローラーと一致しているか確認

- **問題**: 権限エラー
  - **対処**: ディレクトリの所有者がslurmユーザーであることを確認

## 注意事項

- JWT keyはクラスター全体で同じ値を使用する必要がある
- slurm_dbロールはslurm_ctrlロールより先に実行される必要がある
- Ubuntu 24.04のSlurm 23.11以降はMungeが不要である
