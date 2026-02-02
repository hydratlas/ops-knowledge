# Proxmox VE Roles

Proxmox VE関連のAnsibleロール集

## 概要

このディレクトリには、Proxmox VE（Virtual Environment）の設定と管理を自動化するための複数のAnsibleロールが含まれています。

## 含まれるロール

- **pve_auto_updates**: Proxmox VEホストの自動アップデート設定
- **pve_free_repo**: 無料リポジトリへの切り替え
- **pve_remove_subscription_notice**: サブスクリプション通知の削除
- **pve_vm_ssh_host_keys**: VMのSSHホストキー管理

## 追加ドキュメント

- **ct.md**: LXCコンテナ（CT）に関する情報
- **vm.md**: 仮想マシン（VM）に関する情報
- **install/**: インストール手順のスクリーンショット

## 手動での設定手順

### インストール
1. Target harddisk
2. Advanced optiosから、ZFS (RAID 1)（1台だけの場合はRAID 0）
3. compressはzstd
4. ARC max sizeは、ストレージの1TBあたり1GiBが目安。上限は搭載している物理メモリの3/4もしくは、1GBを残した全部
5. CountryはJapan
6. TimezoneはAsia/Tokyo
7. Keyboard layoutはJapanese
8. Root passwordは任意の値
9. Administrator emailはroot@home.arpa
10. Management interfaceは任意のものを選択
11. Hostname (FQDN)は\<hostname\>.home.arpa
12. IP address (CIDR)は任意の値
13. Gateway addressは任意の値
14. DNS server addressは任意の値

### リポジトリを無料のものにする
```bash
mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak &&
mv /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list.bak &&
VERSION_CODENAME="$(grep -oP '(?<=^VERSION_CODENAME=).+' /etc/os-release | tr -d '\"')" &&
tee "/etc/apt/sources.list.d/pve-no-subscription.sources" <<- EOS > /dev/null &&
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $VERSION_CODENAME
Components: pve-no-subscription
EOS
tee "/etc/apt/sources.list.d/ceph.sources" <<- EOS > /dev/null
Types: deb
URIs: http://download.proxmox.com/debian/ceph-reef
Suites: $VERSION_CODENAME
Components: no-subscription
EOS
```

### サブスクリプションの広告を削除
```bash
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
```

### 自動アップデート
#### パッケージをインストール
```bash
apt-get update -y &&
apt-get install -y unattended-upgrades apt-listchanges
```

#### 設定ファイルを作成
```bash
tee /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF' > /dev/null
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};

Unattended-Upgrade::Automatic-Reboot "false";
EOF
```

#### 自動アップデートを有効化
```bash
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | debconf-set-selections
```

### VM/CTの名前を後から変更
```bash
qm set <vmid> --name <name>
```

### ノード削除
Proxmox VE Administration Guide
https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_remove_a_cluster_node

加えてcorosync.confから、削除したノードの情報を削除する。
```bash
nano /etc/pve/corosync.conf
```

### クリップボードからテキストを貼り付け
1. ブラウザに[Tampermonkey](https://www.tampermonkey.net/)拡張機能をインストール
2. [Copy/Paste for noVNC Proxmox](https://gist.github.com/amunchet/4cfaf0274f3d238946f9f8f94fa9ee02)を開く
3. `noVNCCopyPasteProxmox.user.js`の「Raw」ボタンを押す
4. Tampermonkeyのスクリプトインスロール画面が表示されるためインストールする
5. Proxmox VEで仮想マシンのコンソールをnoVNCで開く
6. 右クリックから「貼り付け」を押す

### Ansible実行用の準備
#### APIトークンの取得とアクセス権限の設定
1. WebUIの「データセンター」→「アクセス権限」→「ユーザ」→「追加」からユーザーを作る
   - ユーザ名：`ansible-runner`
   - レルム：`Proxmox VE authentication server`
   - パスワード：（任意の値）
   - グループ：（なし）
2. WebUIの「データセンター」→「アクセス権限」→「API トークン」→「追加」からAPIトークンを作る
   - ユーザ：`ansible-runner@pve`
   - トークンID：`ansible-runner-202501`
   - →APIトークンのIDとシークレットを記録
3. WebUIの「データセンター」→「アクセス権限」→「追加」→「API トークンのアクセス権限」からAPIトークンのアクセス権限を作る
   - パス：`/`
   - API トークン：`ansible-runner@pve!ansible-runner-202501`
   - ロール：Administrator
   - 継承：チェック

#### Python環境の構築
`uv`を使っている場合
```bash
uv add ansible proxmoxer requests
```

#### Ansible Galaxyにおけるコレクションのインストール（不要？）
```bash
uv run ansible-galaxy collection install community.general
```

#### Ansible Vaultの使用（インストール不要）
```bash
uvx --from ansible-core ansible-vault encrypt_string '<token_secret>' --name 'pve_token_secret'
```

#### Ansible Playbookの実行
```bash
uv run ansible-playbook -vvvv playbooks/aaa.yml
```

### その他
追加のユーザーはRealm「Proxmox VE authentication server」で作る。Proxmox VEの基盤となるLinuxマシンに対してログインすることはできないが、Proxmox VEのウェブUIにはログインすることができ、それはProxmox VEのクラスター全体に波及する。

noVNCが開かないとき
```bash
/usr/bin/ssh -e none -o 'HostKeyAlias=<hostname>' root@<IP address> /bin/true
```

LinuxではディスプレーをVirtIO-GPUにする。

Proxmox VEのroot@pamをLDAPで管理することはできない。緊急用アカウントとして使うとよい。