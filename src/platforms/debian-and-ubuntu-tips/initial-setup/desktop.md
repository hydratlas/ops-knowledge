# デスクトップ（Ubuntu）を設定
## HWEカーネルからGAカーネルへの切り替え（管理者）
```bash
sudo apt-get update &&
sudo apt-get install -y linux-generic &&
sudo apt-get remove -y linux-generic-hwe-* &&
sudo apt-get autoremove -y &&
sudo update-grub
```

## 各種アプリをインストール（管理者）
```bash
sudo apt-get install -y meld inkscape dconf-editor grsync nautilus-image-converter keepassxc transmission-gtk git gpg libreoffice libreoffice-l10n-ja &&
sudo snap install chromium gimp discord slack &&
```

## 各ディレクトリを英語化（各ユーザー）
```bash
LC_ALL=C xdg-user-dirs-gtk-update --force
```

## dash-to-dockの設定（各ユーザー）
```bash
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize-or-previews' # クリックしたとき、現在表示中であれば最小化、表示中でなければプレビュー
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'RIGHT' # ドックを右側に表示する
gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true # マルチモニターすべてにドックを表示する
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false # ドックにマウントドライブを表示しない
gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false # ドックにゴミ箱を表示しない
```

## desktopの設定（各ユーザー）
```bash
gsettings set org.gnome.desktop.screensaver lock-enabled false # スクリーンセーバー復帰後にロックしない
gsettings set org.gnome.desktop.interface clock-show-weekday true # 日付に曜日を表示
gsettings set org.gnome.desktop.input-sources mru-sources "[('ibus', 'mozc-jp'), ('xkb', 'jp')]" # mozcを優先
```

## nautilusの設定（各ユーザー）
```bash
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view' # リストビュー表示
gsettings set org.gnome.nautilus.list-view default-zoom-level 'small' # ファイルリストを小さく表示
gsettings org.gnome.nautilus.list-view default-visible-columns "['name', 'size', 'owner', 'group', 'permissions', 'date_modified']" # アクセス権などを表示
```

## Zoteroのインストール（管理者）
```bash
sudo apt-get update &&
sudo apt-get install bzip2 &&
wget -O Zotero_linux-x86_64.tar.bz2 "https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64" &&
sudo mkdir -p /opt/zotero &&
sudo tar -xjf Zotero_linux-x86_64.tar.bz2 -C /opt/zotero --strip-components=1 &&
sudo /opt/zotero/set_launcher_icon &&
ln -s /opt/zotero/zotero.desktop "$HOME/.local/share/applications/zotero.desktop"
```

## AppImage
### AppImageLauncherのインストール（管理者）
まず必要なパッケージをインストールする。
```bash
sudo apt-get install -y libfuse2t64
```

その上で[Releases · TheAssassin/AppImageLauncher](https://github.com/TheAssassin/AppImageLauncher/releases)からdebをダウンロードする（Ubuntu 24.04ではPPAが動かない）。そしてアプリセンターで開いてインストールする。

### AppImageリンク
- [https://standardnotes.com/download]()
- [https://obsidian.md/download]()
- [https://www.pcloud.com/ja/download-free-online-cloud-file-storage.html]()
- [https://photoqt.org/downpopupappimage]()

### Joplinの修正（各ユーザー）
JoplinのAppImageをAppImageLauncherからインストールして、アイコンファイルの指定が間違っている点を修正する。
```bash
find "$HOME/.local/share/applications" -name "*-Joplin.desktop" -exec perl -i -pe "s/^(Icon=.+)_joplin\$/\$1_\\@joplinapp-desktop/g" "{}" \;
```

### アイコン修正一般（各ユーザー）
AppImageLauncherが生成するdesktopファイルでStartupWMClassがないか、適切に設定されていないために、Dash to Dockでアイコンが表示されないことがある。

まずxpropコマンドでWM Classを調べる。
```bash
xprop WM_CLASS
```

その上で、desktopファイルを探す。
```bash
cd "$HOME/.local/share/applications" &&
ls -la
```

開いて、編集する（DB Browser for SQLiteの場合）。
```bash
nano appimagekit_dc17fe06dff3ad37a6b1ca1900ec4a18-DB_Browser_for_SQLite.desktop
```
```
[Desktop Entry]
...
StartupWMClass=DB Browser for SQLite
```

開いて、編集する（PhotoQtの場合）。
```bash
nano appimagekit_a804665a6765821784bd9f1084748dbf-PhotoQt.desktop
```
```
[Desktop Entry]
...
StartupWMClass=PhotoQt
```

## Firefox
```bash
wget -q -O - "https://packages.mozilla.org/apt/repo-signing-key.gpg" | \
  sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null &&
sudo tee "/etc/apt/sources.list.d/mozilla.sources" > /dev/null << EOF &&
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
sudo tee "/etc/apt/preferences.d/mozilla" > /dev/null << EOF &&
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
sudo apt-get update && sudo apt-get install -y firefox
```

## yt-dlp
```bash
sudo wget -O /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux &&
sudo chmod +x /usr/local/bin/yt-dlp
```

## Rcloneのインストール（管理者）
```bash
wget -O rclone.deb https://downloads.rclone.org/rclone-current-linux-amd64.deb &&
sudo dpkg -i rclone.deb &&
rm rclone.deb
```

## Remmina
「設定」→「RDP」→「キーボードレイアウト」に「00000411 – Japanese」を設定する。

## Zedのインストール（各ユーザー）
```bash
wget -q -O - https://zed.dev/install.sh | sh 
```

設定に以下の行を追加する。
```json
  "buffer_font_family": "Noto Sans Mono CJK JP",
  "autosave": {
    "after_delay": {
      "milliseconds": 1000
    }
  },
```

## Geanyのインストール（管理者）
```bash
sudo apt-get install -y geany
```

## Geanyの設定（各ユーザー）
```bash
mkdir "$HOME/.config/geany" &&
cat << EOF > "$HOME/.config/geany/geany.conf"
[geany]
pref_main_load_session=false
show_white_space=true
show_line_endings=true
sidebar_visible=false
msgwindow_visible=false

[search]
replace_regexp=true
EOF
```

## tesseractをインストール（管理者）
```bash
sudo apt-get install -y ocrmypdf tesseract-ocr &&
TESSDATA_DIR="/usr/share/tesseract-ocr/5/tessdata" &&
sudo wget -4 -P "$TESSDATA_DIR" "https://github.com/tesseract-ocr/tessdata_best/raw/refs/heads/main/jpn.traineddata" &&
sudo wget -4 -P "$TESSDATA_DIR" "https://github.com/tesseract-ocr/tessdata_best/raw/refs/heads/main/jpn_vert.traineddata" &&
tesseract --list-langs | grep jpn
```

```bash
INPUT="" &&
OUTPUT=""
ocrmypdf -l jpn_vert "$INPUT" "$OUTPUT"

find . -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.tiff" -o -iname "*.tif" \) -print0 | xargs -0 -P 16 -I {} tesseract -l jpn {} {}

find . -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.tiff" -o -iname "*.tif" \) -print0 | xargs -0 -P 16 -I {} tesseract -l jpn_vert {} {}

tesseract image.png output -l jpn
tesseract image.png output -l jpn_vert
```

```bash
sudo snap install tesseract &&
sudo snap remove tesseract
```

## 開発環境
```bash
wget -4 -q -O - "https://packages.microsoft.com/keys/microsoft.asc" | gpg --dearmor | \
  sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null &&
sudo tee "/etc/apt/sources.list.d/vscode.sources" > /dev/null << EOF &&
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /etc/apt/keyrings/packages.microsoft.gpg
EOF
sudo apt-get update && sudo apt-get install -y code
```
コマンドパレットに`ext install MS-CEINTL.vscode-language-pack-ja`と入力すると、日本語パッケージをインストールできる。その後、コマンドパレットに`Configure Display Language`と入力すると日本語に切り替えられる。
