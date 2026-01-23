# slurm_ctrl

Slurmコントローラー（ヘッドノード）をUbuntu 24.04にインストールするロールである。slurmctldデーモンをインストールし、クラスタのジョブスケジューリングを管理する。

## アーキテクチャ

```
slurm-db-01.int.home.arpa
  └── slurm_db ロール
      ├── MariaDB (ポート3306)
      └── slurmdbd (ポート6819)

slurm-ctrl-01.int.home.arpa (プライマリ)
slurm-ctrl-02.int.home.arpa (バックアップ1)
slurm-ctrl-03.int.home.arpa (バックアップ2)
slurm-ctrl-04.int.home.arpa (バックアップ3)
  └── slurm_ctrl ロール
      └── slurmctld (ポート6817)
          ├── AccountingStorageHost → slurm-db-01
          └── StateSaveLocation → ローカルストレージ
```

slurmdbd と MariaDB は `slurm_db` ロールで別ホストに配置される。slurmctld は slurmdbd に接続してアカウンティングデータを管理する。

### HA 構成

本プロジェクトでは、複数の slurmctld ホストによる高可用性（HA）構成を採用している。

- **プライマリ/バックアップ**: `slurm_controller_hosts` リストの最初のホストがプライマリ、以降がバックアップとなる
- **フェイルオーバー**: プライマリが停止すると、バックアップが自動的に引き継ぐ
- **ローカルストレージ方式**: 各コントローラーがローカルに状態を保存し、フェイルオーバー時は slurmd から状態を再収集する

#### ローカルストレージ方式のトレードオフ

| 項目 | 説明 |
|------|------|
| メリット | NFS 障害という単一障害点がない、構成がシンプル |
| デメリット | フェイルオーバー時に数秒〜数十秒の再構築時間が発生 |

共有ストレージ（NFS/GlusterFS/Ceph 等）を使用する構成も可能だが、運用負荷を考慮し本プロジェクトではローカルストレージ方式を採用している。

## 設計方針：動的ノード管理

本プロジェクトでは、Slurm 20.11以降で導入された**動的ノード（Dynamic Nodes）**機能を採用している。これにより、`slurm.conf`に個別の`NodeName`行を静的に定義する必要がなくなる。

### 動的ノードの利点

| 項目         | 静的定義                       | 動的ノード         |
| ------------ | ------------------------------ | ------------------ |
| ノード追加時 | slurm.conf編集→slurmctld再起動 | slurmd起動のみ     |
| ノード削除時 | slurm.conf編集→slurmctld再起動 | 自動的にダウン扱い |
| 設定の一貫性 | 手動で同期が必要               | 自動管理           |

### 仕組み

1. **コントローラー側**：`slurm.conf`に`MaxNodeCount`を設定し、`Nodes=ALL`を使用したパーティションを定義する
2. **計算ノード側**：`slurmd -Z`オプションで起動し、自動的にコントローラーに登録される

### 関連するAnsibleロール

- `slurm_db`：データベースサーバー用。slurmdbd と MariaDB をインストールする
- `slurm_ctrl`：コントローラーノード用。動的ノード対応の`slurm.conf`を生成する
- `slurm_node`：計算ノード用。systemdのオーバーライド設定で`slurmd -Z`を有効化する
- `slurm_login`：ログインノード用

### 動的ノード用の変数

#### slurm_ctrl

| 変数名                 | 説明                   | デフォルト値 |
| ---------------------- | ---------------------- | ------------ |
| `slurm_max_node_count` | クラスタの最大ノード数 | `100`        |

#### slurm_node

| 変数名                | 説明                            | デフォルト値 |
| --------------------- | ------------------------------- | ------------ |
| `slurm_node_features` | ノードのFeature（カンマ区切り） | `""`         |
| `slurm_node_conf`     | 追加の--confオプション          | `""`         |

### Feature別パーティションの設定例

GPUノードとCPUノードを分けたい場合、slurm.conf.j2テンプレートをカスタマイズする必要がある。現在のテンプレートはシンプルな単一パーティション構成である。

## 概要

このロールは以下を実行する：

- slurmctldパッケージのインストール
- 設定ファイル（slurm.conf、cgroup.conf）の配置
- リモートのslurmdbdへの接続確認
- slurmctldサービスの起動と有効化

## 要件と前提条件

### 共通要件

- Ubuntu 24.04 LTS
- root権限またはsudo権限
- Slurm 23.11以降（Ubuntu 24.04標準パッケージ、Munge不要）
- slurm_db ロールが先に実行されていること

### Ansible固有の要件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件

- bashシェル
- sudo権限を持つユーザー
- テキストエディタ（nano、vim等）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

| 変数名                   | デフォルト値             | 説明                                       |
| ------------------------ | ------------------------ | ------------------------------------------ |
| `slurm_cluster_name`     | `cluster`                | クラスタ名                                 |
| `slurm_controller_hosts` | `["{{ ansible_fqdn }}"]` | コントローラーホストのリスト（HA構成対応） |
| `slurm_db_host`          | `""`                     | slurmdbdホストのFQDN（必須）               |
| `slurm_max_node_count`   | `100`                    | 動的ノードの最大数                         |
| `slurm_jwt_key`          | -（必須）                | Base64エンコードされたJWT key（32バイト）  |

#### 使用例

```yaml
- hosts: slurm_controllers
  roles:
    - role: infrastructure/slurm_ctrl
      vars:
        slurm_cluster_name: "my-cluster"
        slurm_controller_hosts:
          - "slurm-ctrl-01.int.home.arpa"  # プライマリ
          - "slurm-ctrl-02.int.home.arpa"  # バックアップ
        slurm_db_host: "slurm-db-01.int.home.arpa"
        slurm_jwt_key: "{{ vault_slurm_jwt_key }}"
```

#### JWT keyの管理

JWT keyはSlurm認証（auth/slurm）に使用される32バイトのバイナリデータである。クラスター全体で同じkeyを使用する必要があるため、変数として管理する。

##### 新規JWT keyの生成

```bash
dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64
```

生成された文字列を`slurm_jwt_key`変数に設定する。

##### 既存JWT keyの取得

既存の環境からJWT keyを取得するには以下のコマンドを使用する。

```bash
cat /etc/slurm/slurm.key | base64
```

##### セキュリティ上の注意

JWT keyは秘密情報であるため、Ansible Vaultで暗号化して管理することを推奨する。

```bash
# Vaultファイルの作成
ansible-vault create group_vars/slurm_controllers/vault.yml

# 以下の内容を記載
vault_slurm_jwt_key: "生成したBase64文字列"
```

##### VMを再作成する際の注意

コントローラーVMを再作成する場合は、既存のJWT keyを引き継ぐこと。新しいkeyを生成すると、既存の計算ノードやログインノードとの認証が失敗する。

### 方法2: 手動での設定手順

以下はUbuntu 24.04でSlurmコントローラーを手動セットアップする手順である。

**前提条件**: slurm-db-01 でslurmdbdが起動していること。

#### ステップ1: Slurmパッケージのインストール

slurmctldパッケージをインストールする。

```bash
sudo apt-get install -y slurmctld
```

#### ステップ2: checkpointディレクトリの作成

slurmctld用のcheckpointディレクトリを作成する。

```bash
sudo mkdir -p /var/lib/slurm/checkpoint
sudo chown slurm:slurm /var/lib/slurm/checkpoint
sudo chmod 755 /var/lib/slurm/checkpoint
```

#### ステップ3: JWT keyの配置

Slurm認証（auth/slurm）用のJWT keyを配置する。slurm-db-01と同じkeyを使用する必要がある。

```bash
echo "Base64エンコードされた文字列" | base64 -d | sudo tee /etc/slurm/slurm.key > /dev/null
sudo chown slurm:slurm /etc/slurm/slurm.key
sudo chmod 600 /etc/slurm/slurm.key
```

#### ステップ4: slurm.confの作成

メインの設定ファイルを作成する。以下は動的ノード対応の設定例である。

```bash
sudo tee /etc/slurm/slurm.conf << 'EOF'
# クラスタ設定
ClusterName=cluster
# HA構成: 複数のSlurmctldHostを定義（最初がプライマリ）
SlurmctldHost=slurm-ctrl-01.int.home.arpa
SlurmctldHost=slurm-ctrl-02.int.home.arpa
SlurmctldHost=slurm-ctrl-03.int.home.arpa
SlurmctldHost=slurm-ctrl-04.int.home.arpa
SlurmctldParameters=enable_configless

# プロセス管理
MpiDefault=none
ProctrackType=proctrack/cgroup
ReturnToService=1
SlurmctldPidFile=/run/slurm/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=/run/slurm/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/lib/slurm/slurmd
SlurmUser=slurm
StateSaveLocation=/var/lib/slurm/checkpoint
SwitchType=switch/none
TaskPlugin=task/affinity

# タイムアウト設定
InactiveLimit=0
KillWait=30
MinJobAge=300
SlurmctldTimeout=120
SlurmdTimeout=300
Waittime=0

# スケジューリング
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

# ログ・アカウンティング設定
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=slurm-db-01.int.home.arpa
JobCompType=jobcomp/none
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=info
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=/var/log/slurm/slurmd.log

# 動的ノード設定
# 計算ノードは slurmd -Z で自動登録されるため、静的なNodeName定義は不要
MaxNodeCount=100

# パーティション定義
PartitionName=debug Nodes=ALL Default=YES MaxTime=INFINITE State=UP
EOF

sudo chown slurm:slurm /etc/slurm/slurm.conf
sudo chmod 644 /etc/slurm/slurm.conf
```

`SlurmctldHost`と`AccountingStorageHost`は環境に合わせて変更すること。`MaxNodeCount`はクラスタの最大ノード数に応じて調整する。

#### ステップ5: cgroup.confの作成

cgroup設定ファイルを作成する。

```bash
sudo tee /etc/slurm/cgroup.conf << 'EOF'
ConstrainCores=yes
ConstrainDevices=yes
ConstrainRAMSpace=yes
ConstrainSwapSpace=yes
EOF

sudo chown slurm:slurm /etc/slurm/cgroup.conf
sudo chmod 644 /etc/slurm/cgroup.conf
```

#### ステップ6: slurmdbdへの接続確認

slurmctldを起動する前に、slurmdbdへの接続を確認する。

```bash
# slurmdbdのポートに接続できることを確認
nc -zv slurm-db-01.int.home.arpa 6819
```

#### ステップ7: サービスの起動

slurmctldを起動する。

```bash
sudo systemctl enable slurmctld
sudo systemctl start slurmctld
```

## 運用管理

### 基本操作

クラスタ状態の確認：

```bash
# ノード状態の確認
sinfo

# ジョブキューの確認
squeue

# 詳細なノード情報
scontrol show nodes

# 設定のリロード
scontrol reconfigure
```

### アカウンティング操作

```bash
# クラスタの登録確認
sacctmgr show cluster

# クラスタを登録（初回のみ）
sacctmgr add cluster cluster

# アカウント情報の確認
sacctmgr show account

# ユーザーの使用状況レポート
sreport user topusage
```

### ログ確認

```bash
# slurmctldのログ
sudo journalctl -u slurmctld -f
sudo tail -f /var/log/slurm/slurmctld.log
```

### トラブルシューティング

#### 診断フロー

1. サービス状態の確認

   ```bash
   sudo systemctl status slurmctld
   ```

2. 設定ファイルの検証

   ```bash
   slurmctld -Dvvv  # フォアグラウンドでデバッグ起動
   ```

3. ポートの確認

   ```bash
   sudo ss -tlnp | grep -E '(6817|6818)'
   ```

4. slurmdbdへの接続確認

   ```bash
   nc -zv slurm-db-01.int.home.arpa 6819
   ```

#### よくある問題と対処方法

- **問題**: slurmctldが起動しない
  - **対処**: slurm.confの構文エラーを確認。slurmdbdが起動しているか確認

- **問題**: slurmdbdに接続できない
  - **対処**: ファイアウォールでポート6819が開放されているか確認。JWT keyがslurmdbdと一致しているか確認

- **問題**: ノードがdownになる
  - **対処**: 計算ノードのslurmdが起動しているか確認

- **問題**: 権限エラー
  - **対処**: ディレクトリの所有者がslurmユーザーであることを確認

- **問題**: アカウンティングが機能しない
  - **対処**: `sacctmgr show cluster`でクラスタが登録されているか確認。登録されていない場合は`sacctmgr add cluster cluster`で登録

## 注意事項

- slurm.confはconfiglessモードにより、計算ノードやログインノードがコントローラーから自動取得する
- 動的ノード機能により、静的なNodeName定義は不要である
- slurm_db ロールが先に実行され、slurmdbdが起動している必要がある
- Ubuntu 24.04のSlurm 23.11以降はMungeが不要だが、古いバージョンのSlurmと混在する場合はMunge設定が必要
- HA構成ではフェイルオーバー時に slurmd から状態を再収集するため、数秒〜数十秒の再構築時間が発生する
- HA構成のフェイルオーバーは自動的に行われるが、プライマリの復旧時にはサービスの再起動が必要な場合がある
