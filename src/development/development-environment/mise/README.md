# mise（プログラミング言語のバージョン管理）

miseは、複数のプログラミング言語やツールのバージョンを統一的に管理するためのツールです。Node.js、Python、Rustなど様々な言語のバージョンをプロジェクトごとに切り替えて使用でき、開発環境の構築を効率化します。

## インストール
- 参考：[Getting Started | mise-en-place](https://mise.jdx.dev/getting-started.html)

### Linux (Bash)
```bash
wget -q -O - https://mise.run | sh &&
~/.local/bin/mise --version &&
~/.local/bin/mise reshim &&
TARGET_FILE="$HOME/.bashrc" &&
START_MARKER="# BEGIN MISE BLOCK" &&
END_MARKER="# END MISE BLOCK" &&
CODE_BLOCK=$(cat << EOS
if [ -e ~/.local/bin/mise ]; then
  eval "\$(~/.local/bin/mise activate bash)"
fi
#if [ -e ~/.local/share/mise/shims ]; then
#  export PATH="\$HOME/.local/share/mise/shims:\$PATH"
#fi
EOS
) &&
if ! grep -q "$START_MARKER" "$TARGET_FILE"; then
  echo -e "$START_MARKER\n$CODE_BLOCK\n$END_MARKER" | tee -a "$TARGET_FILE" > /dev/null  
fi &&
. "$TARGET_FILE" &&
mise --version
```

### Windows (PowerShellおよび)
#### PowerShell
```powershell
winget install -e --id jdx.mise
mise reshim
mise --version
```

以下はおそらく不要。
```powershell
$shimPath = "$env:USERPROFILE\AppData\Local\mise\shims"
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPath = $currentPath + ";" + $shimPath
```

#### Git Bash
```bash
winget install -e --id jdx.mise &&
mise reshim &&
mise --version
```

## 状態確認
```bash
mise doctor
```

## 基本的なツールのインストール
```bash
mise use -g jq
```

## シェル補完のインストール（LinuxのBashの場合）
```bash
mise use -g usage &&
mkdir -p ~/.local/share/bash-completion/completions &&
tee ~/.local/share/bash-completion/completions/mise << EOS > /dev/null &&
if hash mise 2>/dev/null; then
  eval "\$(mise completion bash --include-bash-completion-lib)"
fi
EOS
. ~/.local/share/bash-completion/completions/mise
```
- [Not generating mise completions despite usage CLI is installed · Issue #1710 · jdx/mise](https://github.com/jdx/mise/issues/1710)

## シェル補完のインストール（WindowsのGit Bashの場合）
usageが入らないため、動かない。
```bash
tee "$HOME/.bash_completion.d/mise" << EOS > /dev/null &&
if hash mise 2>/dev/null; then
  eval "\$(mise completion bash --include-bash-completion-lib)"
fi
EOS
. "$HOME/.bash_completion.d/mise"
```

## 使用
miseでユーザーグローバルにツールをインストールして、そのツールで各プロジェクトのプログラミング言語のバージョンを管理する場合と、miseで直接各プロジェクトのプログラミング言語のバージョンを管理する場合がある。後者のほうがmise本来の使い方であるが、前者のほうがシェル補完がききやすく、使いやすい。
- ユーザーグローバル
  - [Node.js & pnpm](pnpm-nodejs.md)
      - 各プロジェクト
          - Node.js & pnpm
  - [uv](uv-python.md) (Pip)
      - 各プロジェクト
          - Python
  - [pixi](pixi-python.md) (Conda): mambaを作っているprefix.devが作っている、Rust言語に基づく高速なパッケージ管理システム（おすすめ）
      - 各プロジェクト
          - Python
  - Python ([Miniforge](miniforge-python.md) (Conda)): conda-forgeリポジトリで作っているパッケージ管理システム
      - 各プロジェクト
          - Python
  - [Rust & Cargo](rust.md)
- 各プロジェクト
  - [Node.js](nodejs.md)
      - Node.js & npm（Node.js付属）
      - Node.js & Yarn
      - Node.js & pnpm

## アップデート
```bash
mise self-update --no-plugins &&
mise plugins update &&
mise upgrade
```
それぞれmise本体、プラグインおよびツールをアップデートする。

## キャッシュの削除
```bash
mise cache clear
```

## シェル補完のアンインストール（LinuxのBashの場合）
```bash
if [ -f ~/.local/share/bash-completion/completions/mise ]; then
  rm ~/.local/share/bash-completion/completions/mise
fi
```

## アンインストール
### Linux (Bash)
```bash
mise implode -y
```
アンインストール後にシェルに`-bash: /home/<username>/.local/bin/mise: No such file or directory`とエラーメッセージが表示されるようになるが、シェルを開き直せば解消される。

### Windows (PowerShell)
```powershell
winget uninstall -e --id jdx.mise
```

## ユーザーグローバルにインストールしたツールやシステムの再インストール
設定ファイル(~/.config/mise/config.toml)からユーザーグローバルにインストールしたツールやシステムを再インストールする。プラグインは手動でのインストールが必要になる場合がある。
```bash
mise install -y
```
