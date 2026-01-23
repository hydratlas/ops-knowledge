# FreeIPAクライアントをインストール
## FreeIPAサーバーのWebUIでの準備
1. 「Identity」→「Hosts」画面を開く
1. 「add」ボタンを押すとダイアログボックスが開くので、「Host name」を入力して、「Add」ボタンでホストを追加する
1. 追加したホストを開いて、「Actions」ボタンから「Set One-Time Password」を開く
1. ダイアログボックスが開くので、任意のワンタイムパスワードを入力して、「Set OTP」ボタンでワンタイムパスワードを設定する

## インストール
```bash
ipahost="idm-01.int.home.arpa" &&
base_domain="home.arpa" &&
onetime_password="" &&
if hash apt-get 2>/dev/null; then
    sudo apt-get install --no-install-recommends -y freeipa-client
elif hash dnf 2>/dev/null; then
    sudo dnf install -y ipa-client
fi &&
eval "$(wget -q -O - "https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/freeipa")" &&
chosen_domain &&
sudo ipa-client-install \
  --unattended \
  --hostname="${domain}" \
  --server="${ipahost}" \
  --domain="${base_domain,,}" \
  --realm="${base_domain^^}" \
  --password="${onetime_password}" \
  --no-ntp \
  --mkhomedir
```

## サーバーへの接続を確認
adminアカウントのチケットを取得して、そのチケットを確認する。
```bash
kinit admin
klist
```

## アンインストール
```bash
sudo ipa-client-install --uninstall &&
if hash apt-get 2>/dev/null; then
    sudo apt-get purge -y freeipa-client
elif hash dnf 2>/dev/null; then
    sudo dnf remove -y ipa-client
fi
```
