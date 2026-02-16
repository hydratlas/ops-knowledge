# Ubuntu Server 24.04をBtrfs (RAID 1)でセットアップ
## ストレージをフォーマット
### GNU GRUB画面
![](server/01_grub.png)

「Try or Install Ubuntu Server」を選択して、Enterキーを押下する。

### Welcome!画面
![](server/02_welcome.png)

「English」を選択して、Enterキーを押下する。

### Installer update available画面
![](server/03_installer_update_available.png)

「Update to the new installer」を選択して、Enterキーを押下する。なお、インストーラーのアップデートが存在しない場合、この画面はスキップされる。

### Keyboard configuration画面
![](server/04_keyboard_configuration.png)

Layoutは「Japanese」、Variantは「Japanese」を選択したうえで、Doneにフォーカスを当ててEnterキーを押下する。

### Choose the type of installation画面
![](server/05_choose_the_type_of_installation.png)

なにもせずに、Ctrl + Alt + F2キーを押下して、コンソール画面に入る。

### コンソール画面
以下のようにスクリプトによってインストール先のストレージ2台をフォーマットする。

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

最後に、Ctrl + Alt + F1キーを押下して、インストーラー画面に戻る。

## インストール
### Choose the type of installation画面
![](server/05_choose_the_type_of_installation.png)

Ubuntu Serverを選択したうえで、Doneにフォーカスを当ててEnterキーを押下する。

### Network configuration画面
![](server/06_network_configuration.png)

自動的にDHCPによってIPアドレスが取得されるため、それを少し待ってからDoneにフォーカスを当ててEnterキーを押下する。

### Configure proxy画面
![](server/07_configure_proxy.png)

なにもせずに、Doneにフォーカスを当ててEnterキーを押下する。

### Configure Ubuntu archive mirror画面
![](server/08_configure_ubuntu_archive_mirror.png)

自動的にミラーが取得されるため、それを少し待ってからDoneにフォーカスを当ててEnterキーを押下する。

### Guided storage configuration画面
![](server/09_guided_storage_configuration.png)

Custom storage layoutを選択したうえで、Doneにフォーカスを当ててEnterキーを押下する。

### Storage configuration画面
![](server/10-01_storage_configuration.png)

1台目のストレージにフォーカスを当ててEnterキーを押下するとサブメニューが表示される。その中からUse As Boot Deviceにフォーカスを当ててEnterキーを押下する。

![](server/10-02_storage_configuration.png)

2台目のストレージにフォーカスを当ててEnterキーを押下するとサブメニューが表示される。その中からUse As Boot Deviceにフォーカスを当ててEnterキーを押下する。

![](server/10-03_storage_configuration.png)

1台目のストレージのpartition 2にフォーカスを当ててEnterキーを押下するとサブメニューが表示される。その中からEditにフォーカスを当ててEnterキーを押下する。

![](server/10-04_storage_configuration.png)

「Editing partition 2」というポップアップウィンドウが表示される。「Use as swap」にチェックを入れたうえで、Saveにフォーカスを当ててEnterキーを押下する。

![](server/10-05_storage_configuration.png)

2台目のストレージのpartition 2にフォーカスを当ててEnterキーを押下するとサブメニューが表示される。その中からEditにフォーカスを当ててEnterキーを押下する。

![](server/10-06_storage_configuration.png)

「Editing partition 2」というポップアップウィンドウが表示される。「Use as swap」にチェックを入れたうえで、Saveにフォーカスを当ててEnterキーを押下する。

![](server/10-07_storage_configuration.png)

1台目のストレージのpartition 3にフォーカスを当ててEnterキーを押下するとサブメニューが表示される。その中からEditにフォーカスを当ててEnterキーを押下する。

![](server/10-08_storage_configuration.png)

「Editing partition 3」というポップアップウィンドウが表示される。「Fremat」は「btrfs」、「Mount」は「/」を選択したうえで、Saveにフォーカスを当ててEnterキーを押下する。

![](server/10-09_storage_configuration.png)

「FILE SYSTEM SUMMARY」を確認する。今回の場合、/のbtrfsパーティションはこの場でフォーマットする。/boot/efiのvfatパーティション、および2つのswapパーティションはすでにフォーマット済みのためフォーマットせずに、既存の状態のまま使用する。確認したら、Doneにフォーカスを当ててEnterキーを押下する。

![](server/10-10_storage_configuration.png)
フォーマットによりデータが失われるという警告が表示される。Continueにフォーカスを当ててEnterキーを押下する。

### Profile configuration画面
![](server/11_profile_configuration.png)

任意の値を入力してから、Doneにフォーカスを当ててEnterキーを押下する。

### Upgrade to Ubuntu Pro画面
![](server/12_upgrade_to_ubuntu_pro.png)

continueにフォーカスを当ててEnterキーを押下する。

### SSH Setup画面
![](server/13-1_ssh_configuration.png)

「Install OpenSSH server」にチェックを入れ、「Import SSH Key」にフォーカスを当ててEnterキーを押下する。

![](server/13-2_ssh_configuration.png)

「from GitHub」を選択し、ユーザー名を入力してから、Doneにフォーカスを当ててEnterキーを押下する。

![](server/13-3_ssh_configuration.png)

インポートするSSHキーを確認して、Yesにフォーカスを当ててEnterキーを押下する。

![](server/13-4_ssh_configuration.png)

Doneにフォーカスを当ててEnterキーを押下する。

### Features Server Snaps画面
![](server/14_features_server_snaps.png)

必要なものがあればそれらにチェックを入れてから、Doneにフォーカスを当ててEnterキーを押下する。なお、ここでインストールできるのはSnap版のアプリケーションであるが、例えば一般的にDockerはSnap版ではないものをインストールする。

### Installing system画面
![](server/15_installing_system.png)

インストールが始まるため、待つ。

### Installation complete!画面
![](server/16_installation_complete.png)

インストールが終わったら、Ctrl + Alt + F2キーを押下して、コンソール画面に入る。

### コンソール画面
lsblkコマンドでインストール先のストレージの名前（sdX）を確認する。
```bash
lsblk -fe7
```

インストール先のストレージを、スクリプトによってBtrfsをRAID 1にするとともに、Snapperに対応したサブボリュームのレイアウトにし、さらにfstabとブートローダーをそれに合わせた構成に更新する。ただし、1台だけ指定した場合には、RAID 1ではなくシングル構成にする。第一引数のストレージから第二引数のストレージにコピーしてRAID 1構成にするため、引数の順番には注意すること。
```bash
sudo ./install.sh sdX sdX
```

終わったら再起動する。
```bash
sudo reboot
```
