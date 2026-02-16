# ハードウェアの初期設定（すべて管理者）
## 次回起動時にUEFI設定画面を表示する
```bash
sudo systemctl reboot --firmware-setup
```

## ノートパソコンのふたをしめてもサスペンドしないようにする
```bash
sudo perl -pi -e 's/^#?HandleLidSwitch=.+$/HandleLidSwitch=ignore/g;' /etc/systemd/logind.conf &&
sudo systemctl restart systemd-logind.service
```

## NVMeの情報を表示
```bash
sudo apt-get install -y nvme-cli &&
sudo nvme smart-log /dev/nvme0
```
