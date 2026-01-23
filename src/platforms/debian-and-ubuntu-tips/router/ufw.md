# ufwでIPマスカレードおよびファイアウォール設定をする
nftablesを直接使うほうが簡単。

## IPマスカレードおよびファイアウォール設定（ufw）
nftablesと同じことをしており、併用不可。また、ufwはnftablesに依存しているため、nftablesは簡単にはアンインストールできない。
### 設定
`ufw allow`のサービス名のリストは`/etc/services`のものが使われる。
```bash
sudo apt-get install -y ufw &&
sudo tee /etc/sysctl.d/20-ip-forward.conf << EOS > /dev/null &&
net/ipv4/ip_forward=1
EOS
sudo sysctl -p /etc/sysctl.d/20-ip-forward.conf &&
sysctl -a 2>/dev/null | grep ip_forward &&
sudo perl -pi -e "s/^#?DEFAULT_FORWARD_POLICY=.*\$/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/g" /etc/default/ufw &&
sudo perl -pi -e "s|^#?net/ipv4/ip_forward=.*\$|net/ipv4/ip_forward=1|g" /etc/ufw/sysctl.conf &&
sudo ufw allow domain &&
sudo ufw allow bootps &&
sudo ufw logging medium &&
sudo apt-get install -y ipcalc moreutils &&
URL="https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/scripts/update_or_add_textblock" &&
wget --spider "${URL}" &&
wget -O - "${URL}" | sudo tee /usr/local/bin/update_or_add_textblock > /dev/null &&
sudo chmod a+x /usr/local/bin/update_or_add_textblock &&
CODE_BLOCK1=$(cat << EOS
*nat
-F
:POSTROUTING ACCEPT [0:0]
EOS
) &&
host_index="" &&
while read -r index element; do
  if [ "${element}" = "${HOSTNAME}" ]; then
    host_index=${index}
  fi
done <<< "$(echo "${JSON}" | jq -c -r ".router_host[]" | nl -v 0)" &&
outside_interface="$(echo "${JSON}" | jq -c -r ".outside.interface[${host_index}]")" &&
CODE_BLOCK2="" &&
while read -r index element; do
  interface="$(echo "${element}" | jq -c -r ".interface[${host_index}]")" &&
  ip_address="$(echo "${element}" | jq -c -r ".ip_address[${host_index}]")" &&
  cidr="$(echo "${element}" | jq -c -r ".cidr")" &&
  network_address="$(ipcalc "${ip_address}/${cidr}" | grep -oP "(?<=^Network:) *[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")" &&
  network_address="${network_address#"${network_address%%[![:space:]]*}"}" &&
  CODE_BLOCK2="${CODE_BLOCK2}"$'\n'"$(cat << EOS
-A POSTROUTING -s ${network_address}/${cidr} -o ${outside_interface} -j MASQUERADE
EOS
  )"
done <<< "$(echo "${JSON}" | jq -c -r ".inside[]" | nl -v 0)" &&
CODE_BLOCK3=$(cat << EOS
COMMIT
EOS
) &&
CODE_BLOCK="${CODE_BLOCK1}"$'\n'"${CODE_BLOCK2}"$'\n'"${CODE_BLOCK3}" &&
TARGET_FILE="/etc/ufw/before.rules" &&
sudo cat "${TARGET_FILE}" | update_or_add_textblock "MASQUERADE" "${CODE_BLOCK}" | sudo sponge "${TARGET_FILE}" &&
while read -r index element; do
  sudo ufw allow in on "${interface}" from "${network_address}/${cidr}" to any &&
  sudo ufw route allow in on "${interface}" from "${network_address}/${cidr}" to any &&
  sudo ufw allow in on "${interface}" from "${network_address}/${cidr}" to 224.0.0.18 comment 'keepalived multicast'
done <<< "$(echo "${JSON}" | jq -c -r ".inside[]" | nl -v 0)" &&
sudo systemctl restart ufw.service &&
sudo systemctl enable ufw.service &&
sudo ufw enable
```

### 確認
```bash
sudo ufw status verbose

sudo systemctl status ufw.service
```

### 【やりなおすとき】無効化・削除
```bash
sudo ufw disable &&
sudo apt-get purge -y ufw
```

### ログの確認
```bash
journalctl | grep "\[UFW "
```
