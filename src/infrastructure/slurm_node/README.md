# slurm_node

Slurm計算ノードをUbuntu 24.04にインストールするロールである。slurmdデーモンをインストールし、動的ノードとしてコントローラーに自動登録する。

## 概要

このロールは以下を実行する：

- slurmdパッケージのインストール
- slurmdの動的ノード+configlessモード設定（コントローラーから設定を自動取得し、自動登録）
- slurmdサービスの起動と有効化

## 要件と前提条件

### 共通要件

- Ubuntu 24.04 LTS
- root権限またはsudo権限
- Slurmコントローラー（slurm_ctrl）が設定済みであること
- コントローラーへのネットワーク接続

### Ansible固有の要件

- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件

- bashシェル
- sudo権限を持つユーザー

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数

##### 必須変数

| 変数名                  | 説明                                                 |
| ----------------------- | ---------------------------------------------------- |
| `slurm_controller_host` | コントローラーのホスト名（slurmdのconfigless接続先） |

##### オプション変数

| 変数名                | デフォルト値 | 説明                            |
| --------------------- | ------------ | ------------------------------- |
| `slurm_node_features` | `""`         | ノードのFeature（カンマ区切り） |
| `slurm_node_conf`     | `""`         | 追加の--confオプション          |

#### 依存関係

- slurm_ctrlロールが先に実行され、コントローラーが設定済みであること

#### 使用例

```yaml
- hosts: slurm_compute_nodes
  roles:
    - role: infrastructure/slurm_node
      vars:
        slurm_controller_host: "slurm-ctrl-01.int.home.arpa"
```

### 方法2: 手動での設定手順

以下はUbuntu 24.04でSlurm計算ノードを手動セットアップする手順である。動的ノード+configlessモードを使用するため、slurm.confのコピーやコントローラーへの静的登録は不要である。

#### ステップ1: パッケージのインストール

```bash
sudo apt-get update
sudo apt-get install -y slurmd
```

#### ステップ2: slurmdの動的ノード+configlessモード設定

slurmdがコントローラーから設定を自動取得し、動的ノードとして自動登録されるようにsystemdのオーバーライド設定を作成する。

```bash
# コントローラーホスト名を設定
CONTROLLER_HOST="slurm-ctrl-01.int.home.arpa"

# systemdオーバーライドディレクトリを作成
sudo mkdir -p /etc/systemd/system/slurmd.service.d

# 動的ノード+configlessモードの設定
sudo tee /etc/systemd/system/slurmd.service.d/dynamic.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/slurmd --systemd -s -Z --conf-server ${CONTROLLER_HOST}:6817
EOF

# systemdの設定をリロード
sudo systemctl daemon-reload
```

Featureを指定する場合（例：GPUノード）：

```bash
sudo tee /etc/systemd/system/slurmd.service.d/dynamic.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/slurmd --systemd -s -Z --conf-server ${CONTROLLER_HOST}:6817 --conf "Feature=gpu"
EOF
```

#### ステップ3: slurmdサービスの起動

```bash
sudo systemctl enable slurmd
sudo systemctl start slurmd
```

#### ステップ4: 動作確認

コントローラーまたはログインノードでノードの状態を確認する。

```bash
sinfo
scontrol show node <node_name>
```

ノードがidleまたはallocatedと表示されれば正常に動作している。動的ノードとして登録されるため、コントローラーのslurm.confに静的なNodeName行がなくてもノードが表示される。

## 運用管理

### 基本操作

ノード状態の確認：

```bash
# ローカルのslurmd状態
sudo systemctl status slurmd

# コントローラーから見たノード状態
scontrol show node $(hostname)
```

ノードの状態変更（コントローラーで実行）：

```bash
# ノードをdrainにする（新規ジョブの割り当て停止）
scontrol update nodename=node01 state=drain reason="maintenance"

# ノードを復帰させる
scontrol update nodename=node01 state=resume
```

### ログ確認

```bash
# slurmdのログ
sudo journalctl -u slurmd -f
sudo tail -f /var/log/slurm/slurmd.log
```

### トラブルシューティング

#### 診断フロー

1. サービス状態の確認

   ```bash
   sudo systemctl status slurmd
   ```

2. 設定ファイルの検証

   ```bash
   slurmd -Dvvv  # フォアグラウンドでデバッグ起動
   ```

3. コントローラーとの接続確認

   ```bash
   # コントローラーのポートに接続できるか確認
   nc -zv <controller_host> 6817
   ```

4. systemdオーバーライド設定の確認

   ```bash
   cat /etc/systemd/system/slurmd.service.d/dynamic.conf
   # --conf-serverのホスト名が正しいか確認
   ```

#### よくある問題と対処方法

- **問題**: ノードがdownになる
  - **対処**: slurmdが起動しているか確認。`sudo journalctl -u slurmd`でログを確認

- **問題**: "Unable to register"
  - **対処**: ファイアウォールでポート6817、6818がブロックされていないか確認。コントローラーのslurm.confで`SlurmctldParameters=enable_configless`が設定されているか確認

- **問題**: 権限エラー
  - **対処**: ディレクトリの所有者がslurmユーザーであることを確認

- **問題**: slurmdが起動しない
  - **対処**: systemdオーバーライド設定のコントローラーホスト名を確認。`sudo journalctl -u slurmd`でログを確認

## 注意事項

- configlessモードにより、slurm.confはコントローラーから自動取得されるため手動での同期は不要である
- 動的ノード機能により、コントローラーへの静的なNodeName登録は不要である
- ユーザーアカウントはクラスタ全体で同一のUID/GIDを持つ必要がある（FreeIPA等の集中認証を推奨）
