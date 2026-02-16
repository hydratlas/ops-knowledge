# step-ca（サーバー）
step-ca本体で`step ca init`コマンド実行時に自動的にルートCA証明書が作成されるが、step-caを簡単に再インストールできるように、事前に別途、ルートCA証明書を作り、それを`step ca init`コマンド実行時に利用するようにする。

しかし、SSH用のルートCA証明書については、事前に別途、作ることが面倒なため、

## ルートCA証明書の作成
### 変数の準備
```bash
sudo install -D -m 755 -o "root" -g "root" /dev/stdin "/opt/root-ca/root-ca.env" << EOS > /dev/null
root_ca_user_name="root-ca"
root_ca_dir="/opt/root-ca"
EOS
```

### ユーザーおよびディレクトリーの作成
```bash
source "/opt/root-ca/root-ca.env" &&
if ! id "${root_ca_user_name}" &>/dev/null; then
  sudo useradd --system --no-create-home --user-group --shell /usr/usr/sbin/nologin "${root_ca_user_name}"
fi &&
sudo install -o "root" -g "${root_ca_user_name}" -m 775 -d "${root_ca_dir}/root" "${root_ca_dir}/federated-roots" "${root_ca_dir}/ssh"
```

### 秘密鍵の作成
```bash
source "/opt/root-ca/root-ca.env" &&
OUT_FILEPATH="${root_ca_dir}/root/root_ca_key" &&
sudo -u "${root_ca_user_name}" openssl genpkey -algorithm ED25519 -out "${OUT_FILEPATH}" &&
sudo chmod 640 "${OUT_FILEPATH}" &&
sudo chown "root:${root_ca_user_name}" "${OUT_FILEPATH}"
```

### 【デバッグ】秘密鍵の確認
```bash
source "/opt/root-ca/root-ca.env" &&
sudo -u "${root_ca_user_name}" cat "${root_ca_dir}/root/root_ca_key"
```

### 設定ファイルの作成
```bash
source "/opt/root-ca/root-ca.env" &&
sudo install -m 644 -o "root" -g "${root_ca_user_name}" /dev/stdin "${root_ca_dir}/root/openssl.cnf" << EOS > /dev/null
[ req ]
default_md              = sha512
prompt                  = no
x509_extensions         = v3_ca

[ v3_ca ]
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always, issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, keyCertSign, cRLSign
EOS
```

### 証明書の作成
```bash
source "/opt/root-ca/root-ca.env" &&
OUT_FILEPATH="${root_ca_dir}/root/root_ca.crt" &&
sudo -u "${root_ca_user_name}" openssl req -x509 -new \
  -key "${root_ca_dir}/root/root_ca_key" -nodes \
  -out "${OUT_FILEPATH}" \
  -subj "/O=Private $(hostname)/CN=Private $(hostname) Root CA" \
  -days 7300 \
  -config "${root_ca_dir}/root/openssl.cnf" &&
sudo chmod 644 "${OUT_FILEPATH}" &&
sudo chown "root:${root_ca_user_name}" "${OUT_FILEPATH}" &&
sudo cp "${OUT_FILEPATH}" /usr/local/share/ca-certificates/root_ca.crt &&
sudo update-ca-certificates
```

### 【デバッグ】証明書の確認
```bash
openssl x509 -text -noout -in "/usr/local/share/ca-certificates/root_ca.crt"
```

### 【デバッグ】証明書の表示
```bash
cat "/usr/local/share/ca-certificates/root_ca.crt"
```

### 【オプション】ほかのプライベート認証局サーバーのルート証明書の追加
#### 証明書ファイルの作成
```bash
source "/opt/root-ca/root-ca.env" &&
OUT_FILEPATH="${root_ca_dir}/federated-roots/peer_root_ca.crt" &&
sudo -u "${root_ca_user_name}" touch "${OUT_FILEPATH}" &&
sudo chmod 644 "${OUT_FILEPATH}" &&
sudo chown "root:${root_ca_user_name}" "${OUT_FILEPATH}"
```

#### 証明書ファイルの編集
```bash
sudo nano "${OUT_FILEPATH}"
```
ほかのサーバーで`cat /opt/root-ca/root/root_ca.crt`コマンドを実行し表示された内容を入力する。

#### 【デバッグ】証明書ファイルの確認
```bash
source "/opt/root-ca/root-ca.env" &&
openssl x509 -text -noout -in "${root_ca_dir}/federated-roots/peer_root_ca.crt"
```

#### 【デバッグ】証明書ファイルの表示
```bash
source "/opt/root-ca/root-ca.env" &&
cat "${root_ca_dir}/federated-roots/peer_root_ca.crt"
```

### 【元に戻す】削除
```bash
source "/opt/root-ca/root-ca.env" &&
sudo rm -dr "${root_ca_dir}" &&
sudo userdel "${root_ca_user_name}"
```

## step-caのインストール
### 変数の準備
```bash
sudo install -D -m 755 -o "root" -g "root" /dev/stdin "/opt/step-ca/step-ca.env" << EOS > /dev/null
step_ca_user_name="step-ca"
step_ca_dir="/opt/step-ca"
root_ca_container_dir="/home/root-ca"
step_ca_container_dir="/home/step"
provisioner_password_filename="provisioner-password"
password_filename="password"
EOS
```

### ユーザーおよびディレクトリーの作成
```bash
source "/opt/root-ca/root-ca.env" &&
source "/opt/step-ca/step-ca.env" &&
if ! id "${step_ca_user_name}" &>/dev/null; then
  sudo useradd --system --no-create-home --user-group --shell /usr/usr/sbin/nologin "${step_ca_user_name}" &&
  sudo usermod -aG "${root_ca_user_name}" "${step_ca_user_name}"
fi &&
sudo install -o "root" -g "${step_ca_user_name}" -m 775 -d "${step_ca_dir}" &&
sudo install -o "${step_ca_user_name}" -g "${step_ca_user_name}" -m 700 -d "${step_ca_dir}/secrets"
OUT_FILEPATH="${step_ca_dir}/secrets/${provisioner_password_filename}" &&
sudo -u "${step_ca_user_name}" openssl rand -base64 -out "${OUT_FILEPATH}" 32 &&
sudo chmod 600 "${OUT_FILEPATH}" &&
sudo chown "${step_ca_user_name}:${step_ca_user_name}" "${OUT_FILEPATH}" &&
OUT_FILEPATH="${step_ca_dir}/secrets/${password_filename}" &&
sudo -u "${step_ca_user_name}" openssl rand -base64 -out "${OUT_FILEPATH}" 32 &&
sudo chmod 600 "${OUT_FILEPATH}" &&
sudo chown "${step_ca_user_name}:${step_ca_user_name}" "${OUT_FILEPATH}"
```

### インストール
```bash
source "/opt/root-ca/root-ca.env" &&
source "/opt/step-ca/step-ca.env" &&
sudo chown "root:${step_ca_user_name}" "${root_ca_dir}/root/root_ca_key" &&
sudo apt-get install -y podman &&
sudo podman run \
  --user "$(id -u "${step_ca_user_name}"):$(id -g "${step_ca_user_name}")" \
  --interactive --tty \
  --volume "${step_ca_dir}:${step_ca_container_dir}:Z" \
  --volume "${root_ca_dir}:${root_ca_container_dir}:ro,z" \
  docker.io/smallstep/step-ca \
    step ca init \
    --deployment-type="standalone" \
    --name="Private $(hostname)" \
    --dns="$(hostname -A | tr ' ' '\n' | grep -F '.' | paste -sd ',' -),localhost" \
    --address=":8443" \
    --root="${root_ca_container_dir}/root/root_ca.crt" \
    --key="${root_ca_container_dir}/root/root_ca_key" \
    --password-file="${step_ca_container_dir}/secrets/${password_filename}" \
    --provisioner="admin" \
    --provisioner-password-file="${step_ca_container_dir}/secrets/${provisioner_password_filename}" \
    --acme \
    --ssh &&
sudo chown "root:${root_ca_user_name}" "${root_ca_dir}/root/root_ca_key"
```

### 【オプション】ほかのプライベート認証局サーバーのルート証明書の追加
```bash
source "/opt/root-ca/root-ca.env" &&
source "/opt/step-ca/step-ca.env" &&
if [ -f "${root_ca_dir}/federated-roots/peer_root_ca.crt" ]; then
  sudo install -m 755 -o "${step_ca_user_name}" -g "${step_ca_user_name}" "${root_ca_dir}/federated-roots/peer_root_ca.crt" "${step_ca_dir}/certs/peer_root_ca.crt" &&
  sudo apt-get install -y jq &&
  TARGET_FILEPATH="${step_ca_dir}/config/ca.json" &&
  sudo -u "${step_ca_user_name}" cat "${TARGET_FILEPATH}" | \
    jq ". + {\"federatedRoots\": [\"${step_ca_container_dir}/certs/peer_root_ca.crt\"]}" | \
    sudo -u "${step_ca_user_name}" tee "${TARGET_FILEPATH}.tmp" > /dev/null &&
  sudo -u "${step_ca_user_name}" mv "${TARGET_FILEPATH}.tmp" "${TARGET_FILEPATH}" &&
  sudo -u "${step_ca_user_name}" chmod 644 "${TARGET_FILEPATH}"
fi
```
- [Step v0.8.3: Federation and Root Rotation for step Certificates](https://smallstep.com/blog/step-v0.8.3-federation-root-rotation/)

### SSH用にX5Cプロビジョナーの追加
```bash
source "/opt/step-ca/step-ca.env" &&
sudo find "${step_ca_dir}/certs" -type f -name "*root_ca*.crt" -exec cat {} + | \
  sudo tee "${step_ca_dir}/certs/federation.crt" > /dev/null &&
sudo podman run \
  --user "$(id -u "${step_ca_user_name}"):$(id -g "${step_ca_user_name}")" \
  --interactive --tty \
  --volume "${step_ca_dir}:${step_ca_container_dir}:Z" \
  docker.io/smallstep/step-ca \
    step ca provisioner add x5c \
      --type=X5C \
      --x5c-roots "${step_ca_container_dir}/certs/federation.crt"
      # "${step_ca_container_dir}/certs/root_ca.crt"
```

### 【デバッグ】状態の確認
#### ファイルリスト
```bash
source "/opt/step-ca/step-ca.env" &&
cd / &&
sudo -u "${step_ca_user_name}" find "${step_ca_dir}" -exec ls -ld {} +
```
`find`コマンドは、カレントディレクトリーに実行権限がないと、カレントディレクトリーに対して「Permission denied」エラーとなるため、カレントディレクトリーを`/`にしている。

#### 設定
```bash
source "/opt/step-ca/step-ca.env" &&
sudo -u "${step_ca_user_name}" cat "${step_ca_dir}/config/ca.json" &&
sudo -u "${step_ca_user_name}" cat "${step_ca_dir}/config/defaults.json"
```

#### 秘密鍵
```bash
source "/opt/step-ca/step-ca.env" &&
sudo -u "${step_ca_user_name}" cat "${step_ca_dir}/secrets/intermediate_ca_key"
```

#### 証明書
```bash
source "/opt/step-ca/step-ca.env" &&
sudo -u "${step_ca_user_name}" openssl x509 -text -noout -in "${step_ca_dir}/certs/root_ca.crt" &&
sudo -u "${step_ca_user_name}" openssl x509 -text -noout -in "${step_ca_dir}/certs/intermediate_ca.crt"
```

#### SSHホスト秘密鍵
```bash
source "/opt/step-ca/step-ca.env" &&
sudo -u "${step_ca_user_name}" cat "${step_ca_dir}/secrets/ssh_host_ca_key"
```

### 【元に戻す】削除
```bash
source "/opt/step-ca/step-ca.env" &&
sudo rm -dr "${step_ca_dir}" &&
sudo userdel "${step_ca_user_name}"
```

### SSH用のルートCAキーおよび証明書の退避
step-caを簡単に再インストールできるように、SSH用のルートCAキーおよび証明書を退避させておく。
```bash
source "/opt/root-ca/root-ca.env" &&
source "/opt/step-ca/step-ca.env" &&
sudo install -m 644 -o "root" -g "${root_ca_user_name}" "${step_ca_dir}/certs/ssh_host_ca_key.pub" "${root_ca_dir}/ssh/ssh_host_ca_key.pub" &&
sudo install -m 644 -o "root" -g "${root_ca_user_name}" "${step_ca_dir}/certs/ssh_user_ca_key.pub" "${root_ca_dir}/ssh/ssh_user_ca_key.pub" &&
sudo install -m 640 -o "root" -g "${root_ca_user_name}" "${step_ca_dir}/secrets/ssh_host_ca_key" "${root_ca_dir}/ssh/ssh_host_ca_key" &&
sudo install -m 640 -o "root" -g "${root_ca_user_name}" "${step_ca_dir}/secrets/ssh_user_ca_key" "${root_ca_dir}/ssh/ssh_user_ca_key" &&
sudo ls -la "${root_ca_dir}/ssh"
```

### 【オプション】退避させたSSH用のルートCAキーおよび証明書の書き戻し
退避させておいたSSH用のルートCAキーおよび証明書を、書き戻す。
```bash
source "/opt/root-ca/root-ca.env" &&
source "/opt/step-ca/step-ca.env" &&
sudo -u "${step_ca_user_name}" install -m 600 "${root_ca_dir}/ssh/ssh_host_ca_key.pub" "${step_ca_dir}/certs/ssh_host_ca_key.pub" &&
sudo -u "${step_ca_user_name}" install -m 600 "${root_ca_dir}/ssh/ssh_user_ca_key.pub" "${step_ca_dir}/certs/ssh_user_ca_key.pub" &&
sudo -u "${step_ca_user_name}" install -m 600 "${root_ca_dir}/ssh/ssh_host_ca_key" "${step_ca_dir}/secrets/ssh_host_ca_key" &&
sudo -u "${step_ca_user_name}" install -m 600 "${root_ca_dir}/ssh/ssh_user_ca_key" "${step_ca_dir}/secrets/ssh_user_ca_key" &&
sudo -u "${step_ca_user_name}" ls -la "${step_ca_dir}/certs" &&
sudo -u "${step_ca_user_name}" ls -la "${step_ca_dir}/secrets"
```

### サービス化
#### サービスの作成・起動
```bash
source "/opt/root-ca/root-ca.env" &&
sudo tee "/etc/containers/systemd/step-ca.container" << EOS > /dev/null &&
[Container]
Image=docker.io/smallstep/step-ca
ContainerName=step-ca
AutoUpdate=registry
LogDriver=journald

PublishPort=8443:8443
Volume=${step_ca_dir}:${step_ca_container_dir}:Z
User=$(id -u "${step_ca_user_name}")
Group=$(id -g "${step_ca_user_name}")

[Service]
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOS
sudo systemctl daemon-reload &&
sudo systemctl start step-ca.service &&
sudo systemctl status --no-pager --full step-ca.service
```

#### 【デバッグ】ログの確認
```bash
journalctl --no-pager --lines=20 --unit=step-ca.service
```

#### 【デバッグ】再起動
```bash
sudo systemctl restart step-ca.service
```

### 【元に戻す】停止・削除
```bash
sudo systemctl stop step-ca.service &&
sudo rm /etc/containers/systemd/step-ca.container &&
sudo systemctl daemon-reload
```

### 【デバッグ】さまざまな確認
#### HTTPSの確認
```bash
wget -O - https://localhost:8443/health
```

#### プロビジョナーの確認
```bash
wget -O - https://localhost:8443/provisioners
```

### step-cli（クライアント）で使うルートCA証明書のフィンガープリントを表示
```bash
openssl x509 -noout -fingerprint -sha256 -in "/usr/local/share/ca-certificates/root_ca.crt" | cut -d '=' -f 2 | tr -d ':'
```

### step-cli（クライアント）でSSHホストキーを署名した際に、SSHクライアントで使うSSH認証局の公開鍵を表示
```bash
sudo cat /opt/step-ca/certs/ssh_host_ca_key.pub
```

以下のように使用する。
```bash
tee -a "$HOME/.ssh/known_hosts" << EOS > /dev/null
@cert-authority * ecdsa-sha2-nistp256 AAAA
@cert-authority * ecdsa-sha2-nistp256 AAAA
EOS
```