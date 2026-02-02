# Ubuntu 24.04にGNOME Boxesを介してWindows 11を入れる（要管理者権限）

GNOME Boxesは、シンプルで使いやすい仮想化フロントエンドです。QEMUとlibvirtを基盤として、デスクトップ環境での仮想マシン管理を簡単に行えます。

## 準備
### Btrfs使用時にディスクイメージ保存先を分離する
GNOME Boxesはユーザーのホームディレクトリ配下の`~/.local/share/gnome-boxes/images`にディスクイメージを保存する。ユーザーのホームディレクトリにBtrfsを使用しているときは、このディレクトリーをサブボリュームに分離する。そうすることで、ホームディレクトリのスナップショットを保存した際に、ディスクイメージがそのスナップショットの対象外になる。ディスクイメージは容量が大きいため、スナップショットに含めないほうが使い勝手がよい。

```bash
BTRFS_OPTIONS="noatime,compress=zstd:1,degraded" &&
FS_UUID="$(findmnt --noheadings --output UUID /)" &&
sudo mount -o "noatime,subvol=/" "/dev/disk/by-uuid/${FS_UUID}" /mnt &&
cd /mnt &&
sudo btrfs subvolume create "@${USER}_images" &&
cd "@${USER}_images" &&
mkdir -p "${HOME}/.local/share/gnome-boxes/images" &&
sudo rsync -av "${HOME}/.local/share/gnome-boxes/images/" ./ &&
find "${HOME}/.local/share/gnome-boxes/images" -mindepth 1 -maxdepth 1 -exec rm -dr "{}" + &&
cd / &&
sudo umount -R /mnt &&
FSTAB_STR="/dev/disk/by-uuid/${FS_UUID} ${HOME}/.local/share/gnome-boxes/images btrfs defaults,subvol=@${USER}_images,${BTRFS_OPTIONS} 0 0" &&
sudo tee -a /etc/fstab <<< "${FSTAB_STR}" > /dev/null &&
sudo systemctl daemon-reload &&
sudo mount "${HOME}/.local/share/gnome-boxes/images"
```

### パッケージをインストール
```bash
sudo apt-get install -y gnome-boxes swtpm-tools
```

## 仮想マシンをセットアップ
### TPMを追加
仮想マシンを作成した上で、仮想マシンの設定画面の「設定を編集」からXMLファイルを編集する。

\<devices>タグと\</devices>タグの内側に以下の要素を追加する。
```xml
    <tpm model="tpm-tis">
      <backend type="emulator" version="2.0" />
    </tpm>
```

## 仮想マシン起動後の後処理
### Windowsゲストにドライバなどをインストール
[windows-guest.md](./windows-guest.md)を参照。

### Trimを有効化
仮想マシンをシャットダウンしてから、仮想マシンの設定画面の「設定を編集」からXMLファイルを編集する。\<devices>タグと\</devices>タグの内側にSCSIコントローラーの要素を追加する。
```xml
    <controller type='scsi' model='virtio-scsi' index='0'/>
```

\<devices>タグと\</devices>タグの内側にある、既存のディスクの要素に`cache="writeback" discard="unmap"`を追加し、`bus`属性を`scsi`に変更する。
```xml
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2" cache="writeback" discard="unmap"/>
      <source file="/home/<user>/.local/share/gnome-boxes/images/<imagename>"/>
      <target dev="sda" bus="scsi"/>
      <!--addressは削除-->
    </disk>
```
参考：[KVM のゲストで fstrim する #Linux - Qiita](https://qiita.com/ngyuki/items/9a7373da17e8d8733ad7)

### ネットワークデバイスを準仮想化
\<devices>タグと\</devices>タグの内側にある、既存のネットワークインターフェースの要素の`type`属性を`rtl8139`から`virtio`に変える。
```xml
    <interface type="user">
      <mac address="..."/>
      <model type="virtio"/>
      <address .../>
    </interface>
```

### ディスクイメージをTrimによって縮小する
まず、仮想マシン上でTrimを実行する。次に仮想マシンをシャットダウンしてから、ホスト上でディスクイメージのファイル名を確認する。
```bash
cd "$HOME/.local/share/gnome-boxes/images" &&
ls -la
```

ファイル名を指定して、ディスクイメージを縮小する。
```bash
FILENAME="<filename>" &&
mv "${FILENAME}" "${FILENAME}_backup" &&
qemu-img convert -O qcow2 "${FILENAME}_backup" "${FILENAME}"
```

バックアップファイルを削除する。
```bash
rm "${FILENAME}_backup"
```
