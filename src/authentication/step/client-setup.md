# step-cli（クライアント）
## 変数の準備
```bash
sudo install -m 755 -o "root" -g "root" /dev/stdin "/usr/local/etc/step-cli.env" << EOS > /dev/null
fingerprints=("abc" "abc")
hostnames=("ca-01.home.arpa" "ca-02.home.arpa")
ports=("8443" "8443")
federation_crt_file="private-ca.crt"
crt_dir="/etc/ssl/certs"
key_dir="/etc/ssl/private"
if test -e "/usr/local/share/ca-certificates"; then
  ca_certificates_dir="/usr/local/share/ca-certificates"
elif test -e "/usr/share/pki/ca-trust-source/anchors"; then
  ca_certificates_dir="/usr/share/pki/ca-trust-source/anchors"
fi
if hash update-ca-certificates 2>/dev/null; then
  ca_certificates_cmd="update-ca-certificates"
elif hash update-ca-trust 2>/dev/null; then
  ca_certificates_cmd="update-ca-trust"
fi
EOS
```

## インストール
[`step` CLI Install step](https://smallstep.com/docs/step-cli/installation/)

### Debian系
```bash
wget "https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb" &&
sudo dpkg -i step-cli_amd64.deb &&
rm step-cli_amd64.deb
```

### Red Hat系
```bash
curl -O -L "https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.rpm" &&
sudo rpm -i step-cli_amd64.rpm &&
rm step-cli_amd64.rpm
```
`warning: step-cli_amd64.rpm: Header V4 RSA/SHA256 Signature, key ID b855223c: NOKEY`という警告が表示されるが、インストールはできる。

## コマンドラインリファレンス
[step ca federation](https://smallstep.com/docs/step-cli/reference/)

## ルートCA証明書の取得
### 取得
```bash
source /usr/local/etc/step-cli.env &&
length=${#hostnames[@]} &&
for ((i=0; i<length; i++)); do
  fingerprint=${fingerprints[$i]} &&
  hostname=${hostnames[$i]} &&
  port=${ports[$i]} &&
  sudo step ca root "${ca_certificates_dir}/${hostname}.crt" \
    --ca-url "https://${hostname}:${port}" \
    --fingerprint "${fingerprint}" \
    --force &&
  sudo chmod 644 "${ca_certificates_dir}/${hostname}.crt"
done &&
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]} &&
  port=${ports[$i]} &&
  sudo step ca federation "${ca_certificates_dir}/${federation_crt_file}" \
    --ca-url "https://${hostname}:${port}" \
    --root "${ca_certificates_dir}/${hostname}.crt" \
    --force &&
  sudo chmod 644 "${ca_certificates_dir}/${federation_crt_file}"
done
sudo "${ca_certificates_cmd}"
```

### 【デバッグ】取得した証明書の概要の表示
```bash
source /usr/local/etc/step-cli.env &&
length=${#hostnames[@]} &&
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]} &&
  openssl x509 -text -noout -in "${ca_certificates_dir}/${hostname}.crt"
done &&
openssl crl2pkcs7 -nocrl -certfile "${ca_certificates_dir}/${federation_crt_file}" | openssl pkcs7 -print_certs -noout
```

### 【デバッグ】HTTPS通信の確認
```bash
source /usr/local/etc/step-cli.env &&
length=${#hostnames[@]} &&
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]} &&
  port=${ports[$i]} &&
  if hash wget 2>/dev/null; then
    wget -O - "https://${hostname}:${port}/health"
  elif hash update-ca-trust 2>/dev/null; then
    curl "https://${hostname}:${port}/health"
  fi
done
```

## サーバー証明書の作成（複数ドメイン対応）
### 作成
```bash
source /usr/local/etc/step-cli.env &&
hosts=($(hostname -A | tr ' ' '\n' | grep -Ff <(grep '^search' /etc/resolv.conf | awk '{$1=""; print $0}' | sed 's/^ *//' | tr -s ' ' | tr ' ' '\n') | grep -Fv ".vip.")) &&
length=${#hostnames[@]} &&
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]} &&
  port=${ports[$i]} &&
  sudo step ca certificate \
    "${hosts[0]}" "${crt_dir}/$(hostname)-${hostname}.crt" "${key_dir}/$(hostname)-${hostname}.key" \
    --ca-url "https://${hostname}:${port}" \
    --root "${ca_certificates_dir}/${federation_crt_file}" \
    --provisioner acme \
    --force \
    ${hosts[@]/#/--san } &&
  sudo chmod 644 "${crt_dir}/$(hostname)-${hostname}.crt" &&
  sudo chmod 600 "${key_dir}/$(hostname)-${hostname}.key" &&
  sudo install -m 644 "${crt_dir}/$(hostname)-${hostname}.crt" "${crt_dir}/$(hostname).crt" &&
  sudo install -m 600 "${key_dir}/$(hostname)-${hostname}.key" "${key_dir}/$(hostname).key"
done
```
ファイアウォールの無効化が必要。

`.vip.`を含むものは除外している（仮想IPアドレスに対応するドメインにはサブドメインとして「vip」を含むようにすることを想定）。

### 【デバッグ】証明書の概要の確認
```bash
source /usr/local/etc/step-cli.env &&
openssl x509 -text -noout -in "${crt_dir}/$(hostname).crt"
```

### 【デバッグ】証明書のチェーンの確認
```bash
source /usr/local/etc/step-cli.env &&
openssl crl2pkcs7 -nocrl -certfile "${crt_dir}/$(hostname).crt" | openssl pkcs7 -print_certs -noout
```

## 署名されたSSHホストキーの生成とSSHサーバーの設定
```bash
source /usr/local/etc/step-cli.env &&
sudo mkdir -p "/etc/ssh" "/etc/ssh/sshd_config.d" &&
hosts=($(hostname -A | tr ' ' '\n' | grep -Ff <(grep '^search' /etc/resolv.conf | awk '{$1=""; print $0}' | sed 's/^ *//' | tr -s ' ' | tr ' ' '\n') | grep -Fv ".vip.")) &&
conf_array=() &&
IFS=',' &&
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]} &&
  port=${ports[$i]} &&
  sudo step ssh certificate "${hosts[*]}" "/etc/ssh/${hostname}_id_ed25519" \
    --ca-url="https://${hostname}:${port}" \
    --root="${ca_certificates_dir}/${hostname}.crt" \
    --provisioner=x5c \
    --x5c-cert="${crt_dir}/$(hostname)-${hostname}.crt" \
    --x5c-key="${key_dir}/$(hostname)-${hostname}.key" \
    --host \
    --kty=OKP --curve=Ed25519 \
    --no-password \
    --insecure \
    --force &&
  if [ -f "/etc/ssh/${hostname}_id_ed25519" ]; then
    conf_array+=("HostKey /etc/ssh/${hostname}_id_ed25519")
  fi &&
  if [ -f "/etc/ssh/${hostname}_id_ed25519-cert.pub" ]; then
    conf_array+=("HostCertificate /etc/ssh/${hostname}_id_ed25519-cert.pub")
  fi
done
unset IFS &&
sudo install -m 644 -o "root" -g "root" /dev/stdin "/etc/ssh/sshd_config.d/signed_host_keys.conf" <<< "$(printf "%s\n" "${conf_array[@]}")" &&
sudo install -m 644 -o "root" -g "root" /dev/stdin "/etc/ssh/sshd_config.d/pubkey_auth.conf" << EOS > /dev/null &&
PubkeyAuthentication yes
PasswordAuthentication no
PermitRootLogin no
EOS
UNIT_NAME="ssh.service" &&
if systemctl list-unit-files | grep -q "^${UNIT_NAME}" && systemctl is-active --quiet "${UNIT_NAME}"; then
  sudo systemctl reload "${UNIT_NAME}"
fi
```
`step ssh certificate`コマンドの`--root`オプションには単一の証明書しか設定できない。

## 【デバッグ】SSHホストキーの確認
```bash
find /etc/ssh -iname "*-cert.pub" -exec ssh-keygen -L -f "{}" \;
```

## 【デバッグ】SSHサーバーの設定の確認
```bash
sudo sshd -T 
```

## 【デバッグ】SSHサーバーのログの確認
```bash
journalctl --no-pager --lines=20 --unit=ssh.service
```

## 証明書の更新
```bash
source /usr/local/etc/step-cli.env &&
length=${#hostnames[@]} &&
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]} &&
  port=${ports[$i]} &&
  sudo step ca renew \
    "${crt_dir}/$(hostname)-${hostname}.crt" "${key_dir}/$(hostname)-${hostname}.key" \
    --ca-url "https://${hostname}:${port}" \
    --root "${ca_certificates_dir}/${federation_crt_file}" \
    --force &&
  if test "${crt_dir}/$(hostname)-${hostname}.crt" -nt "${crt_dir}/$(hostname).crt"; then
    sudo install -m 644 "${crt_dir}/$(hostname)-${hostname}.crt" "${crt_dir}/$(hostname).crt"
  fi
  if test "${key_dir}/$(hostname)-${hostname}.key" -nt "${key_dir}/$(hostname).key"; then
    sudo install -m 600 "${key_dir}/$(hostname)-${hostname}.key" "${key_dir}/$(hostname).key"
  fi
done
```

## ルートCA証明書およびサーバー証明書の更新のサービス化
### スクリプトファイルの作成
```bash
sudo install -m 755 -o "root" -g "root" /dev/stdin "/usr/local/bin/step-cli-renew" << 'EOS' > /dev/null
#!/bin/bash
source /usr/local/etc/step-cli.env
length=${#hostnames[@]}

# フェデレーションCA証明書を取得
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]}
  port=${ports[$i]}
  step ca federation "${ca_certificates_dir}/${federation_crt_file}" \
    --ca-url "https://${hostname}:${port}" \
    --root "${ca_certificates_dir}/${federation_crt_file}" \
    --force
  chmod 644 "${ca_certificates_dir}/${federation_crt_file}"
done

# システムの証明書をアップデート
"${ca_certificates_cmd}"

# サーバー証明書を取得
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]}
  port=${ports[$i]}
  step ca renew \
    "${crt_dir}/$(hostname)-${hostname}.crt" "${key_dir}/$(hostname)-${hostname}.key" \
    --ca-url "https://${hostname}:${port}" \
    --root "${ca_certificates_dir}/${federation_crt_file}" \
    --force
  if test "${crt_dir}/$(hostname)-${hostname}.crt" -nt "${crt_dir}/$(hostname).crt"; then
    install -m 644 "${crt_dir}/$(hostname)-${hostname}.crt" "${crt_dir}/$(hostname).crt"
  fi
  if test "${key_dir}/$(hostname)-${hostname}.key" -nt "${key_dir}/$(hostname).key"; then
    install -m 600 "${key_dir}/$(hostname)-${hostname}.key" "${key_dir}/$(hostname).key"
  fi
done

# 署名付きSSHホストキーを取得
# 一時ディレクトリ作成
temp_dir="$(mktemp -d)"

# 証明書を一時ディレクトリに分割
csplit -z -f "${temp_dir}/cert-" "${ca_certificates_dir}/${federation_crt_file}" '/-----BEGIN CERTIFICATE-----/' '{*}' > /dev/null

# SSHホストキー取得
mkdir -p "/etc/ssh" "/etc/ssh/sshd_config.d"
hosts=($(hostname -A | tr ' ' '\n' | grep -Ff <(grep '^search' /etc/resolv.conf | awk '{$1=""; print $0}' | sed 's/^ *//' | tr -s ' ' | tr ' ' '\n') | grep -Fv ".vip."))
conf_array=()
IFS=','
for ((i=0; i<length; i++)); do
  hostname=${hostnames[$i]}
  port=${ports[$i]}
  for cert_file in "${temp_dir}"/cert-*; do
    step ssh certificate "${hosts[*]}" "/etc/ssh/${hostname}_id_ed25519" \
      --ca-url="https://${hostname}:${port}" \
      --root="${cert_file}" \
      --provisioner=x5c \
      --x5c-cert="${crt_dir}/$(hostname)-${hostname}.crt" \
      --x5c-key="${key_dir}/$(hostname)-${hostname}.key" \
      --host \
      --kty=OKP --curve=Ed25519 \
      --no-password \
      --insecure \
      --force
  done
  if [ -f "/etc/ssh/${hostname}_id_ed25519" ]; then
    conf_array+=("HostKey /etc/ssh/${hostname}_id_ed25519")
  fi
  if [ -f "/etc/ssh/${hostname}_id_ed25519-cert.pub" ]; then
    conf_array+=("HostCertificate /etc/ssh/${hostname}_id_ed25519-cert.pub")
  fi
done
unset IFS
install -m 644 -o "root" -g "root" /dev/stdin "/etc/ssh/sshd_config.d/signed_host_keys.conf" <<< "$(printf "%s\n" "${conf_array[@]}")"

# SSHサーバーが実行中の場合は、設定を再読込させることによりホストキーを更新する
UNIT_NAME="ssh.service"
if systemctl list-unit-files | grep -q "^${UNIT_NAME}" && systemctl is-active --quiet "${UNIT_NAME}"; then
  systemctl reload "${UNIT_NAME}"
fi

# 一時ディレクトリを削除
rm -rf "${temp_dir}"

# 後処理のスクリプトを実行
script_dir="/usr/local/etc/step-cli.d"
for script in "${script_dir}"/*; do
  if [ -x "${script}" ]; then
    "${script}" "${crt_dir}/$(hostname).crt" "${key_dir}/$(hostname).key"
  fi
done
EOS
```

### 【オプション】nginx用のスクリプト（例）
```bash
sudo mkdir -p "/usr/local/etc/step-cli.d" &&
sudo install -m 755 -o "root" -g "root" /dev/stdin "/usr/local/etc/step-cli.d/nginx" << EOS > /dev/null
#!/bin/bash
install -m 644 -o "root" -g "www-data" "\$1" "/etc/nginx/ssl/yourdomain.com.crt"
install -m 640 -o "root" -g "www-data" "\$2" "/etc/nginx/ssl/yourdomain.com.key"
EOS
```

### スクリプトファイルの動作確認
```bash
sudo bash /usr/local/bin/step-cli-renew
sudo bash -x /usr/local/bin/step-cli-renew
```

### サービスおよびタイマーファイルの作成
```bash
source /usr/local/etc/step-cli.env &&
sudo tee "/etc/systemd/system/step-cli-renew.service" << EOS > /dev/null &&
[Unit]
Description=Renew ACME certificate using Step CA renewal process
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/step-cli-renew
StandardOutput=journal
StandardError=journal
EOS
sudo tee "/etc/systemd/system/step-cli-renew.timer" << EOS > /dev/null &&
[Unit]
Description=Trigger Step CA certificate renewal periodically

[Timer]
OnCalendar=*-*-* 00,12:00:00
Persistent=true
RandomizedDelaySec=11h
Unit=step-cli-renew.service

[Install]
WantedBy=timers.target
EOS
sudo systemctl daemon-reload &&
sudo systemctl enable --now step-cli-renew.timer &&
sudo systemctl status --no-pager --full step-cli-renew.service &&
sudo systemctl status --no-pager --full step-cli-renew.timer
```

## 【デバッグ】サーバー証明書の更新のサービスのログを確認
```bash
journalctl --no-pager --lines=20 --unit=step-cli-renew.service
journalctl --no-pager --lines=20 --unit=step-cli-renew.timer
```

## 【元に戻す】サーバー証明書の更新のサービス化
```bash
sudo systemctl disable --now step-cli-renew.timer &&
sudo rm "/etc/systemd/system/step-cli-renew.timer" &&
sudo rm "/etc/systemd/system/step-cli-renew.service" &&
sudo systemctl daemon-reload
```
