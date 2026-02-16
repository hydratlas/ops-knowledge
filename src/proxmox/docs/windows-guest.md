# Windowsゲストにドライバなどをインストール

Windows仮想マシンのゲストOSとしての最適化設定です。VirtIOドライバのインストールやパフォーマンス調整など、仮想化環境での最適な動作のための設定を説明します。

## 準仮想化ゲストドライバ
ゲストで準仮想化デバイスを使えるようになり、ホストで実デバイスをエミュレーションしなくてよくなる。実デバイスをエミュレーションするより準仮想化デバイスを使ったほうがパフォーマンスが高い。

[virtio-win-pkg-scripts/README.md](https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md)から[virtio-win-gt-x64.msi](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win-gt-x64.msi)をダウンロードしてインストール

参考：[Windows VirtIO Drivers - Proxmox VE](https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers)

## 準仮想化ゲストツール
ホストからゲストのIPアドレスを確認したり、シャットダウンコマンドが通じるようになったりする。

[virtio-win-pkg-scripts/README.md](https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md)から
[virtio-win-guest-tools.exe](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win-guest-tools.exe)をダウンロードしてインストール


## SPICEゲストツール
クリップボード共有ができるようになる。

[SPICE Download](https://www.spice-space.org/download.html)から[spice-guest-tools-latest.exe](https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe)をダウンロードしてインストール

## SPICE WebDAVデーモン
ファイル共有ができるようになる。

[Index of /download/windows/spice-webdavd](https://www.spice-space.org/download/windows/spice-webdavd/)から[spice-webdavd-x64-latest.msi](https://www.spice-space.org/download/windows/spice-webdavd/spice-webdavd-x64-latest.msi)をダウンロードしてインストール
