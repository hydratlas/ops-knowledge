# slurm_login

Slurmログインノード（ジョブ投入用）をUbuntu 24.04にインストールするロールである。slurm-clientパッケージとsackdをインストールし、ユーザーがジョブを投入できるようにする。

## 概要

このロールは以下を実行する：

- slurm-clientおよびsackdパッケージのインストール
- sackdのconfiglessモード設定（コントローラーから設定を自動取得）
- sackdサービスの起動と有効化

Ubuntu 24.04のSlurm関連パッケージは必要なディレクトリ（`/etc/slurm/`など）を自動作成するため、明示的なディレクトリ作成タスクは不要である。また、sackdはjournaldにログを出力するため、専用のログディレクトリも不要である。

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

| 変数名                  | 説明                                                |
| ----------------------- | --------------------------------------------------- |
| `slurm_controller_host` | コントローラーのホスト名（sackdのconfigless接続先） |
| `slurm_jwt_key`         | JWT認証鍵（Base64エンコード、Vault暗号化推奨）      |

#### 依存関係

- slurm_commonロール（meta/main.ymlで自動実行）
- slurm_ctrlロールが先に実行され、コントローラーが設定済みであること

#### 使用例

```yaml
- hosts: slurm_login_nodes
  roles:
    - role: infrastructure/slurm_login
      vars:
        slurm_controller_host: "slurm-ctrl-01.int.home.arpa"
```

### 方法2: 手動での設定手順

以下はUbuntu 24.04でSlurmログインノードを手動セットアップする手順である。configlessモードを使用するため、slurm.confのコピーは不要である。

#### ステップ1: パッケージのインストール

slurm-clientとsackdパッケージをインストールする。パッケージインストール時に必要なディレクトリ（`/etc/slurm/`など）は自動作成される。

```bash
sudo apt-get update
sudo apt-get install -y slurm-client sackd
```

#### ステップ2: sackdのconfiglessモード設定

sackdがコントローラーから設定を自動取得するようにsystemdのオーバーライド設定を作成する。

```bash
# コントローラーホスト名を設定
CONTROLLER_HOST="slurm-ctrl-01.int.home.arpa"

# systemdオーバーライドディレクトリを作成
sudo mkdir -p /etc/systemd/system/sackd.service.d

# configlessモードの設定
sudo tee /etc/systemd/system/sackd.service.d/configless.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/sackd --systemd --conf-server ${CONTROLLER_HOST}:6817
EOF

# systemdの設定をリロード
sudo systemctl daemon-reload
```

#### ステップ3: sackdサービスの起動

```bash
sudo systemctl enable sackd
sudo systemctl start sackd
```

## 運用管理

### 利用可能なコマンド

ログインノードでは以下のSlurmコマンドが利用可能である。

| コマンド   | 説明                                         |
| ---------- | -------------------------------------------- |
| `sbatch`   | バッチジョブの投入                           |
| `squeue`   | ジョブキューの表示                           |
| `scancel`  | ジョブのキャンセル                           |
| `sinfo`    | ノード情報の表示                             |
| `scontrol` | クラスタの制御（管理者権限が必要な場合あり） |
| `sacct`    | ジョブアカウンティング情報の表示             |
| `srun`     | インタラクティブジョブの実行                 |

### 基本操作

クラスタ状態の確認：

```bash
# ノード状態の確認
sinfo

# ジョブキューの確認
squeue

# 自分のジョブのみ表示
squeue -u $USER

# ノードの詳細情報
scontrol show nodes
```

ジョブの投入：

```bash
# バッチジョブの投入
sbatch job_script.sh

# インタラクティブジョブ
srun --pty bash

# ジョブのキャンセル
scancel <job_id>
```

### トラブルシューティング

#### 診断フロー

1. sackdサービスの確認

   ```bash
   sudo systemctl status sackd
   ```

2. sackdのログ確認（journald経由）

   ```bash
   sudo journalctl -u sackd
   ```

3. コントローラーへの接続確認

   ```bash
   sinfo
   # エラーが出る場合はコントローラーへの接続に問題がある
   ```

4. ネットワーク接続の確認

   ```bash
   # コントローラーのポートに接続できるか確認
   nc -zv <controller_host> 6817
   ```

5. sackdのconfigless設定確認

   ```bash
   cat /etc/systemd/system/sackd.service.d/configless.conf
   # --conf-serverのホスト名が正しいか確認
   ```

#### よくある問題と対処方法

- **問題**: "slurm_load_jobs error: Unable to contact slurm controller"
  - **対処**: コントローラーが起動しているか確認。ファイアウォールでポート6817がブロックされていないか確認

- **問題**: "Invalid user id"
  - **対処**: ログインノードとコントローラーでユーザーのUIDが一致しているか確認（FreeIPA等での統一が推奨）

- **問題**: sackdが起動しない
  - **対処**: systemdオーバーライド設定のコントローラーホスト名を確認。`sudo journalctl -u sackd`でログを確認

## 注意事項

- configlessモードにより、slurm.confはコントローラーから自動取得されるため手動での同期は不要である
- ユーザーアカウントはクラスタ全体で同一のUID/GIDを持つ必要がある（FreeIPA等の集中認証を推奨）
- ログインノードではsackdデーモンがconfigless設定の取得を担当し、slurmdデーモンは不要である
