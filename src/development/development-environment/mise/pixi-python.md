# mise & Pixi & Python
## ユーザーグローバルでの設定
### インストール
gitが必要。`sudo apt-get install -y git`などのコマンドでインストールしておく。
```bash
mise plugins install pixi https://github.com/pavelzw/asdf-pixi.git &&
mise use -g -y pixi &&
"$(mise which pixi)" --version
```

### シェル補完のインストール（bashの場合）
```bash
mkdir -p ~/.local/share/bash-completion/completions &&
tee ~/.local/share/bash-completion/completions/mise-pixi << EOS > /dev/null &&
if hash mise 2>/dev/null && mise which pixi 2>/dev/null; then
  eval "\$(pixi completion --shell bash)"
fi
EOS
. ~/.local/share/bash-completion/completions/mise-pixi
```

### シェル補完のアンインストール（bashの場合）
```bash
if [ -e ~/.local/share/bash-completion/completions/mise-pixi ]; then
  rm ~/.local/share/bash-completion/completions/mise-pixi
fi
```

### アンインストール
```bash
mise uninstall pixi &&
mise plugins uninstall pixi &&
perl -pi -e "s/^pixi = \".+\"\\n//mg" ~/.config/mise/config.toml
```
`mise use`を元に戻すサブコマンドは2024年11月現在、存在しない（参照：[`mise rm` · Issue #1465 · jdx/mise](https://github.com/jdx/mise/issues/1465)）。

## プロジェクトでの使用
### プロジェクトの作成
```bash
mkdir ~/pixi_test_project &&
cd ~/pixi_test_project &&
pixi init
```
Condaからエクスポートした依存関係は`pixi init --import environment.yml`でインポートできる。また、Conda形式で依存関係をエクスポートすることが`pixi project export conda-environment environment.yml`でできる。

### Pythonのインストール
```bash
pixi add python=3.13.0 &&
pixi run python3 --version
```
`pixi search python`コマンドでは最新バージョンの情報しか表示されず、インストール可能なバージョンの一覧を取得する方法は不明。

### チャンネルの追加
`conda-forge`以外のチャンネルを追加する。以下では`bioconda`を追加している。
```bash
pixi project channel add bioconda
```

### Pythonライブラリーのインストール
```bash
pixi add cowpy &&
pixi list &&
pixi run cowpy "Hello, world!"
```

### 環境の再構築
設定ファイルから環境を再構築する場合。
```bash
cd ~/pixi_test_project &&
pixi install
```
