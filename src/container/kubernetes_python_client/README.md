# pip_kubernetes

Kubernetes Pythonパッケージインストールロール

## 概要

### このドキュメントの目的
このロールは、Kubernetes APIとやり取りするために必要なPython用Kubernetesクライアントライブラリをインストールします。Ansible自動設定と手動設定の両方の方法について説明します。

### 実現される機能
- Kubernetes Python クライアントライブラリのインストール
- OSディストリビューションに応じた適切なインストール方法の選択
- Ansible Kubernetesモジュール使用のための前提条件の準備
- Python環境でのKubernetes API操作の有効化

## 要件と前提条件

### 共通要件
- Linux OS（Debian/Ubuntu/RHEL/CentOS/AlmaLinux/Rocky Linux）
- Python 3.x がインストール済み
- root権限またはsudo権限

### Ansible固有の要件
- Ansible 2.9以上
- プレイブックレベルで`become: true`の指定が必要

### 手動設定の要件
- bashシェル
- sudo権限を持つユーザー
- インターネット接続（パッケージダウンロード用）

## 設定方法

### 方法1: Ansible Roleを使用

#### ロール変数
このロールには設定可能な変数はありません。

#### 依存関係
なし

#### タグとハンドラー
- タグ: なし
- ハンドラー: なし

#### 使用例

基本的な使用例：
```yaml
- hosts: k8s_management
  become: true
  roles:
    - infrastructure/pip_kubernetes
```

Kubernetesモジュールと組み合わせた使用例：
```yaml
- hosts: k8s_controllers
  become: true
  roles:
    - infrastructure/pip_kubernetes
  
  tasks:
    - name: Get Kubernetes cluster info
      kubernetes.core.k8s_info:
        api_version: v1
        kind: Namespace
      register: namespace_list
    
    - name: Display namespaces
      debug:
        var: namespace_list
```

複数ロールとの組み合わせ例：
```yaml
- hosts: automation_servers
  become: true
  roles:
    - infrastructure/update_packages
    - infrastructure/pip_kubernetes
    - applications/kubectl_install
```

### 方法2: 手動での設定手順

#### ステップ1: 環境準備

```bash
# Pythonバージョンの確認
python3 --version

# pipの状態確認
which pip3 || which pip

# 現在インストール済みのPythonパッケージ確認
pip3 list | grep kubernetes || pip list | grep kubernetes
```

#### ステップ2: インストール（Debian/Ubuntu系）

```bash
# パッケージリストの更新
sudo apt-get update

# Python Kubernetesパッケージのインストール
sudo apt-get install -y python3-kubernetes

# インストールの確認
dpkg -l | grep python3-kubernetes
```

#### ステップ3: インストール（RHEL/CentOS/AlmaLinux/Rocky Linux系）

```bash
# Python pipのインストール（未インストールの場合）
sudo dnf install -y python3-pip
# または古いバージョンの場合
sudo yum install -y python3-pip

# Kubernetes Pythonパッケージのインストール
sudo pip3 install kubernetes

# インストールの確認
pip3 show kubernetes
```

#### ステップ4: インストールの検証

```bash
# Pythonインタープリタでインポートテスト
python3 -c "import kubernetes; print(kubernetes.__version__)"

# 詳細なパッケージ情報の確認
python3 -c "import kubernetes; help(kubernetes)"

# APIクライアントの基本的なテスト
python3 << 'EOF'
from kubernetes import client, config

try:
    # kubeconfigの読み込みを試行
    config.load_kube_config()
    v1 = client.CoreV1Api()
    print("Kubernetes client successfully initialized")
except Exception as e:
    print(f"Note: {e}")
    print("This is expected if kubectl is not configured")
EOF
```

## 運用管理

### 基本操作

パッケージ情報の確認：
```bash
# Debian/Ubuntu系
dpkg -l | grep kubernetes
apt-cache show python3-kubernetes

# RHEL系（pip経由）
pip3 show kubernetes
pip3 list | grep kubernetes
```

### ログとモニタリング

```bash
# インストールログの確認（apt）
sudo grep -i kubernetes /var/log/apt/history.log

# pipインストールログ
pip3 install --log /tmp/pip-kubernetes.log kubernetes
cat /tmp/pip-kubernetes.log
```

### トラブルシューティング

#### 診断フロー

1. Pythonバージョンの確認
   ```bash
   python3 --version
   python3 -m pip --version
   ```

2. インポートエラーの詳細確認
   ```bash
   python3 -c "import kubernetes" 2>&1
   ```

3. 依存関係の確認
   ```bash
   pip3 show kubernetes | grep Requires
   ```

#### よくある問題と対処方法

- **問題**: "ModuleNotFoundError: No module named 'kubernetes'"
  - **対処**: パッケージが正しくインストールされていることを確認

- **問題**: pipコマンドが見つからない
  - **対処**: `python3-pip`パッケージをインストール

- **問題**: 権限エラーでインストールできない
  - **対処**: `sudo`を使用するか、仮想環境を使用

### メンテナンス

パッケージのアップデート：
```bash
# Debian/Ubuntu系
sudo apt-get update
sudo apt-get upgrade python3-kubernetes

# pip経由
sudo pip3 install --upgrade kubernetes

# 特定バージョンへの固定
sudo pip3 install kubernetes==28.1.0
```

互換性の確認：
```bash
# 現在のバージョン確認
python3 -c "import kubernetes; print(kubernetes.__version__)"

# Kubernetes APIバージョンとの互換性確認
python3 -c "
from kubernetes import client
print('Supported API versions:')
for api in dir(client):
    if api.endswith('Api'):
        print(f'  - {api}')
"
```

## アンインストール（手動）

Kubernetes Pythonパッケージを削除する手順：

```bash
# Debian/Ubuntu系
# パッケージの削除
sudo apt-get remove --purge python3-kubernetes

# 不要な依存関係の削除
sudo apt-get autoremove

# RHEL/CentOS/AlmaLinux/Rocky Linux系（pip経由）
# pipでインストールした場合
sudo pip3 uninstall kubernetes

# 確認
pip3 list | grep kubernetes

# キャッシュのクリア（オプション）
pip3 cache purge
```

## 注意事項

- このロールはKubernetes Python クライアントライブラリのみをインストールします
- 実際にKubernetes APIに接続するには、適切なkubeconfigファイルが必要です
- システムワイドのインストールを行うため、Python仮想環境を使用する場合は手動インストールを推奨
- バージョンの互換性に注意：Kubernetes APIバージョンとクライアントライブラリバージョンの対応を確認してください
- プロダクション環境では特定のバージョンに固定することを推奨します