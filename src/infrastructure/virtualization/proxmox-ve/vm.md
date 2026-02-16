
# VM作成
以下で、クラウドイメージとCloud-initを使い、QEMUゲストエージェント(qemu-guest-agent)が有効な状態で起動させる方法を示す。

## イメージのダウンロード
### 概要
Proxmox VEのストレージ（local）画面でイメージをダウンロードする。クラウドイメージが、仮想マシンに最適化されていて、なおかつ固有のすぐに起動できる状態で用意されているため便利である。

- Ubuntu
    - ダウンロード先：[Ubuntu Cloud Images - the official Ubuntu images for public clouds, Openstack, KVM and LXD](https://cloud-images.ubuntu.com/)
- Debian
    - ダウンロード先：[Debian Official Cloud Images](https://cloud.debian.org/images/cloud/)
- AlmaLinux OS
    - ダウンロード先：[https://repo.almalinux.org/almalinux/]()
- AlmaLinux OS Kitten
    - ダウンロード先：[https://kitten.repo.almalinux.org/]()

拡張子が.qcow2のものをダウンロードする場合には、Proxmox VEでは拡張子.imgしか受け付けないため、Proxmox VE上での保存ファイル名では拡張子を.imgにする。

以下の関数によってコマンドラインからもダウンロードできる。

### 関数によってコマンドラインからダウンロード
#### Ubuntu 24.04
```bash
eval "$(wget -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/proxmox-ve")" &&
image_downloader https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img
```

#### Debian 12
```bash
eval "$(wget -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/proxmox-ve")" &&
image_downloader https://cloud.debian.org/images/cloud/bookworm-backports/latest/debian-12-backports-genericcloud-amd64.qcow2
```

#### AlmaLinux OS 9
```bash
eval "$(wget -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/proxmox-ve")" &&
image_downloader https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
```

#### AlmaLinux OS Kitten 10
```bash
eval "$(wget -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/proxmox-ve")" &&
image_downloader https://kitten.repo.almalinux.org/10-kitten/cloud/x86_64_v2/images/AlmaLinux-Kitten-GenericCloud-10-latest.x86_64_v2.qcow2
```

## VMの作成
### スニペットの準備
#### スニペットの有効化
- Proxmox VEの画面から「データセンター」→「ストレージ」を選択
- リストから「local」を選択して「編集」ボタンを押す
- 複数選択の「内容」に「スニペット」が含まれるようにする

### スニペットの配置
```bash
tee "/var/lib/vz/snippets/qemu-guest-agent.yaml" << EOS > /dev/null
#cloud-config
timezone: $(timedatectl show --property=Timezone | cut -d= -f2)
packages: [qemu-guest-agent]
runcmd: 
  - "systemctl enable qemu-guest-agent"
  - "systemctl restart qemu-guest-agent"
EOS
```

### 関数の準備
- vm_create
  - 適当なマシン構成（あとから`qm set`コマンドで変更可能）
  - スニペット`qemu-guest-agent.yaml`を追加
- vm_start
  - GRUBをシリアルコンソールに出力
  - シリアルコンソール向けに`apt`コマンドのプログレスバーを無効化
```bash
eval "$(wget -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/proxmox-ve")"
```

### 固有値を決定
```bash
echo "VMID=\"$((RANDOM % 9900 + 100))\"" &&
for i in {0..9} ; do
  RANDOM_HEX=$(printf '%06X\n' $((RANDOM * 256 + RANDOM % 256))) &&
  echo "  --net${i} \"virtio=BC:24:11:$(echo "${RANDOM_HEX}" | sed 's/../&:/g; s/:$//'),bridge=***\" \\"
done
for i in {0..9} ; do
  echo "  --ipconfig${i} ip=dhcp,ip6=dhcp \\"
done
```

### 実行
固有値をはじめ、ストレージ容量やメモリー容量などを適宜変更して使用する。
```bash
eval "$(wget -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/proxmox-ve")" &&
VMID="2079" &&
NAME="ubuntu-2079" &&
vm_create "${VMID}" "local-zfs" "local" "/var/lib/vz/template/iso/ubuntu-24.04-minimal-cloudimg-amd64.img" "8G" &&
qm set "${VMID}" \
  --name "${NAME}" \
  --memory 8192 \
  --net0 "virtio=BC:24:11:03:67:FC,bridge=vmbr0" \
  --ipconfig0 ip=dhcp,ip6=dhcp \
  --ciuser "user" \
  --cipassword "$(openssl passwd -6 "p")" &&
vm_start "${VMID}" &&
vm_exec_apt "${VMID}" &&
vm_exec_grub "${VMID}" &&
qm guest exec "${VMID}" -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -yq \
  avahi-daemon libnss-mdns \
  less nano \
  bash-completion command-not-found \
  ' | jq -r '."out-data", ."err-data"' &&
qm guest exec "${VMID}" -- bash -c 'ip a && ip r' | jq -r '."out-data", ."err-data"' &&
qm terminal "${VMID}"
```
- `--cores`は設定しない場合、そのマシンの物理コア数となる
- `import-from`はイメージファイルによって規定された容量にしかできないため、`vm_create`コマンド内で後から容量を変更している
- Cloud-initは`vm_create`コマンド内で`local-zfs:cloudinit`として設定しているが、これを`--ide0`として設定すると、`--machine pc --bios seabios`でないと動かない。`--scsi0`で設定すれば、`--machine pc --bios seabios`でも`--machine q35 --bios ovmf --efidisk0 local-zfs:0`でも動く
- `vm_exec_grub`コマンド内で、GRUBの設定を変更して、GRUBをコンソールに出力させている
- `vm_exec_timezone`コマンド内で、タイムゾーンをホストと同じものに設定している

### 実行前にSSHを設定
`START`の前に次のように実行すると、Cloud-initによってSSHの`authorized_keys`を設定できる。起動中に実行した場合は再起動が必要。
```bash
KEY_URL="https://github.com/<name>.keys" &&
KEY_FILE="$(mktemp)" &&
IMAGE_DIR="/var/lib/vz/template/iso" &&
wget -O "$KEY_FILE" "$KEY_URL" &&
qm set "${VMID}" --sshkey "${KEY_FILE}" &&
rm "$KEY_FILE"
```

### 【デバッグ】すでに作成されているVMの設定を確認
```bash
qm config "${VMID}"
```
これを参考にして`qm create`コマンドのオプションを検討する。

### 【元に戻す】停止・削除
```bash
qm stop "${VMID}" &&
qm destroy "${VMID}"
```

## VMの使用
### ホストからコマンドを実行（QEMU guest agentが必要）
```bash
qm guest exec "${VMID}" -- bash -c "uname -r && uname -n" | jq -r '."out-data", ."err-data"'
```

### シリアルコンソールに接続
```bash
qm terminal "${VMID}"
```
シリアルコンソールは同時に一つしか使用できないため、ディスプレーをSerial terminal 0 (serial0)に設定すると接続できなくなることに注意。

### シリアルコンソールで文字の装飾を解除
シリアルコンソールで文字の装飾が続いてしまったときに解除する方法。
```bash
echo -e "\e[0m"
```

## 【遺産】イメージのカスタマイズ
イメージをカスタマイズすることもできるが、`qemu-guest-agent`さえ入っていれば通常の起動後に実行できる。
```bash
IMAGE_DIR="/var/lib/vz/template/iso" &&
BASE_FILE="ubuntu-24.04-minimal-cloudimg-amd64.img" &&
CUSTOM_FILE="${BASE_FILE%.*}" && # 拡張子なし
CUSTOM_FILE="${CUSTOM_FILE}-custom.img" &&
GRUBCONF=$(cat << EOS
GRUB_CMDLINE_LINUX="quiet console=tty0 console=ttyS0,115200"
GRUB_TERMINAL_INPUT="console serial"
GRUB_TERMINAL_OUTPUT="gfxterm serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
EOS
) &&
apt-get install --no-install-recommends -y guestfs-tools libguestfs-tools &&
cp "${IMAGE_DIR}/${BASE_FILE}" "${IMAGE_DIR}/${CUSTOM_FILE}" &&
virt-customize -a "${IMAGE_DIR}/${CUSTOM_FILE}" --install qemu-guest-agent \
  --timezone "$(timedatectl show --property=Timezone | cut -d= -f2)" \
  --mkdir /etc/ssh/sshd_config.d \
  --write '/etc/ssh/sshd_config.d/90-local.conf:
PasswordAuthentication no
PermitRootLogin no
' \
  --run-command "echo \"${GRUBCONF}\" >> /etc/default/grub" \
  --run-command "update-grub" &&
  virt-sysprep -a "${IMAGE_DIR}/${CUSTOM_FILE}" --enable machine-id,ssh-hostkeys
```
`virt-customize`コマンドがエラーで失敗するときには`-vx`オプションを加えてデバッグする。
