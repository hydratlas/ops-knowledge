# 自動インストール
## Debian
### 仕様
このリポジトリにある`preseed-bookworm-ja_JP.txt`ファイルの仕様を以下に示す。
- 日本・日本語仕様
- 「標準システムユーティリティー」および「SSHサーバ」をインストール（「Debianデスクトップ環境」はインストールしない）
- デフォルトユーザ名は「user」でパスワードは「p」

### 使い方（Proxmox VE）
1. netinst.isoから起動
1. 「Advanced options ...」にフォーカスを当てて、エンターキーを押す
1. 「Graphical automated install」または「Automated install」にフォーカスを当てて、「e」キーを押す
1. `linux /install.amd/vmlinuz`の直後に次を挿入
    - `hostname=<hostname> url=https://raw.githubusercontent.com/hydratlas/tips/refs/heads/main/debian-and-ubuntu-tips/auto-install/preseed-bookworm-ja_JP.txt`
    - 注意1：`<hostname>`部分は任意の値に書き換える
    - 注意2：前後にはスペースを入れる
1. 「F10」キーを押してインストーラーを起動させる
    - パーティショニング以外は自動的にインストールされる

### 使い方（Ventoy）
[Plugin.auto_install . Ventoy](https://www.ventoy.net/en/plugin_autoinstall.html)
