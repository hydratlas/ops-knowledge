# Windows

Windows環境での運用に役立つ設定やカスタマイズ方法をまとめたドキュメントです。PowerShellスクリプトやシステム最適化の手順を記載しています。

## VSCodiumのインストール
```powershell
winget install -e --id VSCodium.VSCodium
```
サイドバーのExtensionsアイコンから、「Japanese Language Pack」をインストールする。

## nanoのインストール
```powershell
winget install -e --id GNU.Nano
```

## SSHクライアントキーの生成
```powershell
$FILE = "$HOME/.ssh/id_rsa"
ssh-keygen -t rsa   -b 4096 -N '""' -C '""' -f "$FILE"
Get-Content "$FILE.pub"
$FILE = "$HOME/.ssh/id_ecdsa"
ssh-keygen -t ecdsa  -b 521 -N '""' -C '""' -f "$FILE"
Get-Content "$FILE.pub"
$FILE = "$HOME/.ssh/id_ed25519"
ssh-keygen -t ed25519       -N '""' -C '""' -f "$FILE"
Get-Content "$FILE.pub"
```

## Git Bashのインストール
### 本体のインストール
「Git Bash」をインストールすることにより、Windows TerminalでBashが使えるようにします。また、テキストエディターのnanoをインストールします。

Windows TerminalのPowerShellを開き、次のコマンドを実行します。
```powershell
winget install -e --id Git.Git
```

終わったら、次の手順を実行します。

1. Windows Terminalを開きなおします
1. Windows Terminalのタブの右側にある「▼」ボタンをクリックし、「設定」を選択します
1. 「スタートアップ」設定の中の「既定のプロファイル」をクリックして変更します
1. 一覧の中から、「Git Bash」を探して、選択します
1. 下部の「保存」ボタンを押し、設定を保存します
1. 新しいタブを開きます
1. `bash --version`コマンドを実行して、シェルがBashであることを確認します

### Bashの補完などを有効にする
```bash
mkdir -p "$HOME/.bash_completion.d" &&
touch "$HOME/.bashrc" &&
tee -a "$HOME/.bashrc" << EOS > /dev/null &&
# Git補完を有効にする
if [ -f "/c/Program Files/Git/mingw64/share/git/completion/git-completion.bash" ]; then
    . "/c/Program Files/Git/mingw64/share/git/completion/git-completion.bash"
fi

# Gitプロンプトのカスタマイズを有効にする（任意）
if [ -f "/c/Program Files/Git/mingw64/share/git/completion/git-prompt.sh" ]; then
    . "/c/Program Files/Git/mingw64/share/git/completion/git-prompt.sh"
fi

# .bash_completion.dディレクトリーからファイルを読み込む
for file in ~/.bash_completion.d/*; do
    [ -f "\$file" ] && . "\$file"
done
EOS
source "$HOME/.bashrc"
```
