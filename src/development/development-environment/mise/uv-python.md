# mise & uv & Python
## ユーザーグローバルでの設定
### インストール
#### LinuxのBash
```bash
mise use -g -y uv &&
mise settings set pipx_uvx true &&
"$(mise which uv)" --version
```

#### WindowsのPowerShell
```powershell
mise use -g -y uv
mise settings set pipx_uvx true
& (Get-Command uv).Source --version
```

補足：`mise ls-remote -y uv`コマンドでインストール可能なバージョンがリストアップされ、`mise use -g -y uv@0.4.29`などと指定することができる。

説明：uvのインストールとともに、uvxが存在する場合にはpipxの代わりにuvxを使うようにしている。pipxはPythonでできているコマンドラインツールを個別の環境に分離してインストールするもの。pipでは環境を分離しないため依存関係が破壊される可能性があるが、環境の分離によってそれを防ぐ。pipおよびuvは主に実行したいPythonコードから依存するライブラリーのインストールに使用するが、pipxおよびuvxはコマンドラインツールのインストールに使用する。

### シェル補完のインストール
#### LinuxのBash
```bash
mkdir -p ~/.local/share/bash-completion/completions &&
tee ~/.local/share/bash-completion/completions/uv << EOS > /dev/null &&
if hash mise 2>/dev/null && mise which uv 2>/dev/null; then
  eval "\$(uv generate-shell-completion bash)"
fi
EOS
. ~/.local/share/bash-completion/completions/uv &&
tee ~/.local/share/bash-completion/completions/uvx << EOS > /dev/null &&
if hash mise 2>/dev/null && mise which uvx 2>/dev/null; then
  eval "\$(uvx --generate-shell-completion bash)"
fi
EOS
. ~/.local/share/bash-completion/completions/uvx
```

#### WindowsのPowerShell
```powershell
$profileDir = Split-Path -Path $PROFILE
New-Item -ItemType Directory -Path $profileDir -Force
if (-not (Test-Path -Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force
}
Add-Content -Path $PROFILE -Value '(& uv generate-shell-completion powershell) | Out-String | Invoke-Expression'
Add-Content -Path $PROFILE -Value '(& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression'
. $PROFILE
```
- [Installing and managing Python | uv](https://docs.astral.sh/uv/getting-started/installation/#upgrading-uv)

### シェル補完のアンインストール（bashの場合）
```bash
if [ -e ~/.local/share/bash-completion/completions/uv ]; then
  rm ~/.local/share/bash-completion/completions/uv
fi &&
if [ -e ~/.local/share/bash-completion/completions/uvx ]; then
  rm ~/.local/share/bash-completion/completions/uvx
fi
```

### アンインストール（bashの場合）
```bash
mise settings unset pipx_uvx &&
mise uninstall uv &&
perl -pi -e "s/^uv = \".+\"\\n//mg" ~/.config/mise/config.toml
```
`mise use`を元に戻すサブコマンドは2024年11月現在、存在しない（参照：[`mise rm` · Issue #1465 · jdx/mise](https://github.com/jdx/mise/issues/1465)）。

## プロジェクトでの使用
### プロジェクトの作成
#### Bash
```bash
mkdir ~/uv_test_project &&
cd ~/uv_test_project &&
uv init
```

#### PowerShell
```powershell
New-Item -Path "$HOME\uv_test_project" -ItemType Directory -Force
Set-Location -Path "$HOME\uv_test_project"
uv init
```

### Pythonのインストール
#### Bash
```bash
uv python pin 3.13 &&
uv run python3 --version
```

#### PowerShell
```powershell
uv python pin 3.13
uv run python3 --version
```
`uv python list`コマンドでインストール可能なバージョンがリストアップされる。

### Pythonライブラリーのインストール
```bash
uv add cowsay &&
uv pip list &&
uv run cowsay -t "Hello, world!"
```

### Pythonライブラリーのアンインストール
```bash
uv remove cowsay
```

### pipxの実行（インストール不要）
```bash
uvx pycowsay hello from uv
```

### 環境の再構築
設定ファイルから環境を再構築する場合。
```bash
cd ~/uv_test_project &&
uv sync
```
