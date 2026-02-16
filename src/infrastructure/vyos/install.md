# VyOSのインストール
## インストール
まずライブ実行する。ログイン時のデフォルト名とパスワードはともに`vyos`である。ログインしたら`install image`コマンドを実行する。

1. **Welcome to VyOS installation!**  
   This command will install VyOS to your permanent storage.  
   Would you like to continue? [y/N]  
   ↳「y」と入力してエンター

2. **What would you like to name this image?** (Default: 1.5-rolling-202411270007)  
   ↳無入力でエンター

3. **Please enter a password for the "vyos" user:**  
   ↳パスワードを入力してエンター

4. **Please confirm password for the "vyos" user:**  
   ↳パスワードを入力してエンター

5. **What console should be used by default?** (K: KVM, S: Serial)? (Default: S)  
   ↳無入力でエンター

6. **Probing disks**  
   1 disk(s) found  
   The following disks were found:  
   Drive: /dev/sda (16.0 GB)  
   Which one should be used for installation? (Default: /dev/sda)  
   ↳無入力でエンター

7. **Installation will delete all data on the drive. Continue?** [y/N]  
   ↳「y」と入力してエンター

8. **No previous installation found**  
   Would you like to use all the free space on the drive? [Y/n]  
   ↳「y」と入力してエンター

9. **Creating partition table...**  
   The following config files are available for boot:  
   1: /opt/vyatta/etc/config/config.boot  
   2: /opt/vyatta/etc/config.boot.default  
   Which file would you like as boot config? (Default: 1)  
   ↳無入力でエンター

10. **The image installed successfully; please reboot now.**  
    ↳「poweroff now」と入力してエンター

シャットダウンしたら、ISOイメージを取り外す。

なお、`qemu-guest-agent`は2024年12月にデフォルトでは入っていないようになった。 [⚓ T6942 Remove VM guest agents from the generic flavor for the rolling release](https://vyos.dev/T6942)

## 初期設定

### シリアルコンソールが太字になってしまうのを解除
```bash
sudo tee "/config/scripts/setup_unbold_the_console.sh" << EOS > /dev/null &&
#!/bin/bash
cp /config/scripts/unbold_the_console.sh /etc/profile.d/unbold_the_console.sh
EOS
sudo chmod 755 "/config/scripts/setup_unbold_the_console.sh" &&
sudo tee "/config/scripts/unbold_the_console.sh" << EOS > /dev/null &&
#!/bin/bash
echo -e "\e[0m"
EOS
sudo chmod 644 /config/scripts/unbold_the_console.sh &&
sudo tee -a "/config/scripts/vyos-postconfig-bootup.script" \
  <<< "/config/scripts/setup_unbold_the_console.sh" > /dev/null
```

### ホスト名とタイムゾーンの設定
```bash
/bin/vbash << EOS
source /opt/vyatta/etc/functions/script-template
configure
set system host-name 'router-01'
set system time-zone 'Asia/Tokyo'
commit && save && exit
EOS
```

## 基本的な設定

### eth0にIPv4のDHCPを設定
```bash
/bin/vbash << EOS
source /opt/vyatta/etc/functions/script-template
configure
set interfaces ethernet eth0 address dhcp
set system name-server eth0
run show interfaces
commit && save && exit
EOS
```

### eth0にIPv6のRAを設定
```bash
/bin/vbash << EOS
source /opt/vyatta/etc/functions/script-template
configure
set interfaces ethernet eth0 ipv6 address autoconf
commit && save && exit
EOS
```
