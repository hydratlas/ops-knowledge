# Intel AMT (Active Management Technology)

Intel AMT（Active Management Technology）の設定と管理方法です。インテルベースのシステムをリモートから管理し、電源制御やBIOS設定の変更を可能にします。

## 初期設定
HP EliteDesk 800 G4 DMで確認したもの。
- 「Startup Menu」画面から「ME Setup (F6)」を選択
- 「Intel(R) Management Engine BIOS Extension」の「MAIN MENU」画面から「MEBx Login」を選択
- 既定の初期パスワード「admin」と入力
- 新しいパスワードを入力
  - このときのパスワードは、「大文字・小文字」、「0～9」、および「!@#$%^&*()のいずれか」が全種類含まれた8文字以上の文字列が必要
  - また、英語キーボードとして入力されるため、日本語キーボードを接続している場合、想定とは異なる文字が入力される可能性がある
  - なお、この1回目のパスワード入力によって、2種類のパスワードが設定される
    - この画面でのログインに使われる「MEBxのログイン用」パスワードと、WebUIなどでのログインに使われる「ビルトイン管理アカウント（admin）用」パスワード
    - 2回目以降のパスワード変更では前者しか変更されないため注意
- 「Intel(R) AMT Configuration」、「Network Setup」、「TCP/IP Settings」および「Wired LAN IPV4 Configuration」を順に選択
  - 「DHCP Mode」を「Disabled」
  - 「IPV4 Address」、「Subnet Mask Address」、「Default Gateway Address」、「Preferred DNS Address」および「Alternate DNS Address」をそれぞれ入力
- 「MAIN MENU」画面に戻って「Activate Network Access」を選択し、「y」と入力
- 「MAIN MENU」画面に戻って「MEBx Exit」を選択

## 外部から接続
- [Intel Manageability Commander](https://www.intel.co.jp/content/www/jp/ja/download/18796/intel-manageability-commander.html)（Windows版のみ）
- 「System Status」の「Active Features」から「Redirection Port」、「IDE-Redirection」および「KVM Remote Desktop」を有効にする
- 「User Consent」から「Not Required」を選択してリモートデスクトップ接続時にクライアント側で操作してアクセスを許可する必要がないようにする
- 「Remote Desktop」から接続する
  - ポート5900によるVNCはサポートされなくなったらしく、Intel Manageability Commanderからでも、wsmanによる方法からでも設定できない
  - [VNC not supported anymore in newer Intel AMT versions. Giving Error "Error 400, unable to set values." · Issue #98 · Ylianst/MeshCommander](https://github.com/Ylianst/MeshCommander/issues/98)

wsmanによる方法を以下に示す。
```bash
sudo apt-get install -y wsmancli &&
tee kvm.sh << 'EOS' > /dev/null &&
#!/bin/bash
AMT_IP='192.168.1.<xxx>'
AMT_USER='admin'
AMT_PASSWORD='<password>'
VNC_PASSWORD="$(cat /dev/urandom | base64 | fold -w 8 | head -n 1)"
wsman put http://intel.com/wbem/wscim/1/ips-schema/1/IPS_KVMRedirectionSettingData -h "${AMT_IP}" -P 16992 -u "${AMT_USER}" -p "${AMT_PASSWORD}" -k RFBPassword="${VNC_PASSWORD}"
wsman put http://intel.com/wbem/wscim/1/ips-schema/1/IPS_KVMRedirectionSettingData -h "${AMT_IP}" -P 16992 -u "${AMT_USER}" -p "${AMT_PASSWORD}" -k Is5900PortEnabled=true
wsman put http://intel.com/wbem/wscim/1/ips-schema/1/IPS_KVMRedirectionSettingData -h "${AMT_IP}" -P 16992 -u "${AMT_USER}" -p "${AMT_PASSWORD}" -k OptInPolicy=false
wsman put http://intel.com/wbem/wscim/1/ips-schema/1/IPS_KVMRedirectionSettingData -h "${AMT_IP}" -P 16992 -u "${AMT_USER}" -p "${AMT_PASSWORD}" -k SessionTimeout=0
wsman invoke -a RequestStateChange http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_KVMRedirectionSAP -h "${AMT_IP}" -P 16992 -u "${AMT_USER}" -p "${AMT_PASSWORD}" -k RequestedState=2
echo "VNC Paswword: $VNC_PASSWORD"
EOS
chmod +x kvm.sh &&
./kvm.sh
```