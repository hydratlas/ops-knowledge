# Ubuntu 24.04をBtrfs (RAID 1)でセットアップ
## ステップ1
### GNU GRUB画面
![](desktop/001_grub.png)

「Try or Install Ubuntu」にフォーカスを当てて、Enterキーを押下する。

### Ubuntuへ、ようこそ（Welcome to Ubuntu）画面
![](desktop/002_welcome_to_ubuntu.png)

「日本語」を選択して、「次」ボタンをクリックする。

### アクセシビリティ（Accessobility）画面
![](desktop/003_accessobility.png)

「次」ボタンをクリックする。

### キーボードレイアウト（Keyboard layout）画面
![](desktop/004_keyboard_layout.png)

「日本語」とキーボードバリアント「日本語」を選択して、「次」ボタンをクリックする。

### ネットワークに接続（Internet connection）画面
![](desktop/005_internet_connection.png)

「有線接続を使用」を選択して、「次」ボタンをクリックする。

### Ubuntuを試用またはインストール（Try or install Ubuntu）画面
![](desktop/006_try_or_install_ubuntu.png)

「Ubuntuをインストール」を選択して、「次」ボタンをクリックする。

### インストール方法を選択（Type of installation）画面
![](desktop/007_type_of_installation.png)

「次」ボタンをクリックする。

### アプリケーション（Applications）画面
![](desktop/008_applications.png)

「既定の選択」を選択して、「次」ボタンをクリックする。

### ディスクのセットアップ（Disk setup）画面
![](desktop/010-1_disk_setup.png)
![](desktop/010-2_disk_setup.png)
![](desktop/010-3_disk_setup.png)

1. 左上の「アクティビティ」ボタンをクリック
1. 左下の「アプリケーションを表示する」ボタンをクリック
1. 「Taminal」をクリック

### ターミナル画面
![](desktop/010-4_disk_setup.png)

スクリプトによってインストール先のストレージ2台をフォーマットする。

まず、スクリプトをダウンロードして、そのディレクトリーに移動する。
```bash
sudo apt-get install -y git
git clone --depth=1 https://github.com/hydratlas/tips
cd tips/debian-and-ubuntu-tips/install-ubuntu-with-btrfs
```

lsblkコマンドでインストール先のストレージの名前（sdX）を確認する。
```bash
lsblk -fe7
```

インストール先のストレージを、スクリプトによってフォーマットする。
```bash
sudo ./parted.sh sdX
sudo ./parted.sh sdX
```

終わったら、ターミナル画面を閉じる。

## ステップ2
### ディスクのセットアップ（Disk setup）画面
![](desktop/010-1_disk_setup.png)

「手動パーティショニング」を選択して、「次」ボタンをクリックする。

### 手動パーティショニング（Manual partitioning）画面
![](desktop/101-1_manual_partitioning.png)
![](desktop/101-2_manual_partitioning.png)
![](desktop/101-3_manual_partitioning.png)

1. ブートローダーをインストールするデバイスとして、一台目のストレージを選択する
1. 一台目のストレージの第三パーティション（この場合は「vda3」）を選択
1. 「変更」ボタンをクリック
1. 「パーティションを編集する」画面が表示されるので、Btrfsと/を選択して、「OK」ボタンをクリックする
1. 「次」ボタンをクリックする

### アカウントの設定（Create your account）画面
![](desktop/102_create_your_account.png)

任意の値を入力して、「次」ボタンをクリックする。

### タイムゾーンを選択してください（Select your timezone）画面
![](desktop/103_select_your_timezone.png)

「Tokyo」と「Asia/Tokyo」を選択して、「次」ボタンをクリックする。

### インストールの準備完了（Ready to install）画面
![](desktop/104_ready_to_install.png)

確認して、「インストール」ボタンをクリックする。

### インストールが完了しました（Installation complete）画面
![](desktop/105-1_installation_complete.png)
![](desktop/105-2_installation_complete.png)
![](desktop/105-3_installation_complete.png)

1. 左上の「アクティビティ」ボタンをクリック
1. 左下の「アプリケーションを表示する」ボタンをクリック
1. 「Taminal」をクリック

### ターミナル画面
![](desktop/105-4_installation_complete.png)

スクリプトのディレクトリーに移動する。
```bash
cd tips/debian-and-ubuntu-tips/install-ubuntu-with-btrfs
```

lsblkコマンドでインストール先のストレージの名前（sdX）を確認する。
```bash
lsblk -fe7
```

インストール先のストレージを、スクリプトによってBtrfsをRAID 1にするとともに、Snapperに対応したサブボリュームのレイアウトにし、さらにfstabとブートローダーをそれに合わせた構成に更新する。ただし、1台だけ指定した場合には、RAID 1ではなくシングル構成にする。第一引数のストレージから第二引数のストレージにコピーしてRAID 1構成にするため、引数の順番には注意すること。
```bash
sudo ./install.sh sdX sdX
```

終わったら、ターミナル画面を閉じる。

## ステップ3
### インストールが完了しました（Installation complete）画面
![](desktop/105-1_installation_complete.png)

「今すぐ再起動する」ボタンをクリックする。
