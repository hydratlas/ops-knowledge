# SSHジャンプサーバーを構築する
## Kanidm Clientのセットアップ
Kanidm Clientのセットアップを行う（参照：[Kanidm Clientのセットアップ](client-setup.md)）。

## Kanidm Unix統合クライアントのセットアップ
```sh
sudo apt-get install -y kanidm-unixd &&
sudo tee "/etc/kanidm/unixd" > /dev/null << EOF &&
version = '2'
hsm_type = "soft"

[kanidm]
pam_allowed_login_groups = ["ssh-jamp"]
EOF
sudo systemctl status --no-pager --full kanidm-unixd &&
sudo systemctl status --no-pager --full kanidm-unixd-tasks &&
kanidm-unix status
kanidm_unixd_tasks
```

## テスト
```sh
kanidm_ssh_authorizedkeys --debug kishida230
```

## nsswitch.confのセットアップ
```sh
PERL_SCRIPT=$(cat << EOS
s/^(passwd:.+)$/\1 kanidm/g;
s/^(group:.+)$/\1 kanidm/g;
s/kanidm( kanidm)+/kanidm/g;
EOS
) &&
sudo perl -pi -e "${PERL_SCRIPT}" "/etc/nsswitch.conf"
```

## テスト
```sh
getent passwd kishida230
```

## SSHサーバーのセットアップ
```sh
sudo apt-get install --no-install-recommends -y openssh-server &&
sudo mkdir -p "/etc/ssh/sshd_config.d" &&
PERL_SCRIPT="s@^#Include /etc/ssh/sshd_config\.d/\*\.conf\$@Include /etc/ssh/sshd_config.d/*.conf@g" &&
sudo perl -p -i -e "$PERL_SCRIPT" "/etc/ssh/sshd_config" &&
REGEX='^Include /etc/ssh/sshd_config\.d/\*\.conf$' &&
if ! grep -qP "$REGEX" "/etc/ssh/sshd_config";then
  echo -e "Include /etc/ssh/sshd_config.d/*.conf" | sudo tee -a "/etc/ssh/sshd_config" > /dev/null
fi &&
sudo tee "/etc/ssh/sshd_config.d/90-local.conf" << EOS > /dev/null &&
PubkeyAuthentication yes
UsePAM yes
AuthorizedKeysCommand /usr/sbin/kanidm_ssh_authorizedkeys %u
AuthorizedKeysCommandUser nobody

PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
GSSAPIAuthentication no
KerberosAuthentication no

PermitTTY no
X11Forwarding no
ForceCommand /sbin/nologin
EOS
sudo systemctl restart ssh.service
```

## SSHサーバーのログの確認
```sh
sudo journalctl --no-pager --lines=30 -xeu ssh.service
```
必要に応じて`sudo nano /etc/ssh/sshd_config`コマンドからログレベルを変更する。