
# mise & Miniforge (Python)
## ユーザーグローバルでの設定
### Miniforgeのインストール（bashの場合）
```bash
mise use -g -y python@miniforge3-latest &&
"$(mise which conda)" --version &&
"$(mise which conda)" init bash &&
"$(mise which conda)" config --set auto_activate_base false &&
. ~/.bashrc
```
上記ではlatestバージョンを指定しており、通常これでよいが、特定のバージョンをインストールしたいときは、`mise ls-remote python miniforge`コマンドでインストール可能なMiniforgeのバージョンがリストアップされる。

### パッケージチャンネルの追加
`conda-forge`以外のチャンネルを追加する。以下では`bioconda`を追加している。
```bash
conda config --append channels bioconda &&
conda config --set channel_priority strict
```

### Miniforgeのアンインストール
```bash
conda init --reverse &&
mise uninstall python@miniforge3-latest &&
perl -pi -e "s/^python = \"miniforge.+\"\\n//mg" ~/.config/mise/config.toml &&
if [ -e ~/.condarc ]; then
  rm -f ~/.condarc
fi &&
if [ -e ~/.conda ]; then
  rm -fr ~/.conda
fi &&
. ~/.bashrc
```
`mise use`を元に戻すサブコマンドは2024年11月現在、存在しない（参照：[`mise rm` · Issue #1465 · jdx/mise](https://github.com/jdx/mise/issues/1465)）。

## プロジェクトでの使用
### 仮想環境の作成
```bash
mkdir ~/conda_test_project &&
cd ~/conda_test_project &&
conda create --name "$(basename "$(pwd)")" -y
```

### アクティブ化
Miniforge(conda)はディレクトリー移動とともに自動的に仮想環境を切り替えてくれないため、手動でアクティブ化およびデアクティブ化を行う必要がある。
```bash
conda activate "$(basename "$(pwd)")"
```

### Pythonのインストール
`conda search python`でインストール可能なバージョンを確認した上で、任意のバージョンを指定して、インストールする。
```bash
conda install -y python=3.13.0
conda run python3 --version
```
アクティブ化されていなくても、`conda install`コマンドは`--name`オプションで仮想環境名を与えることができる。

### Pythonライブラリーのインストール
```bash
conda install -y cowpy &&
cowpy "Hello, world!"
```

### 仮想環境のエクスポート
Miniforge(conda)はインストールコマンドの実行時に、ファイルへ仮想環境の状態を記録してくれないため、手動でエクスポートする必要がある。
```bash
conda env export | head -n -1 > environment.yml
```
アクティブ化されていなくても、`conda env`コマンドは`--name`オプションで仮想環境名を与えることができる。

prefixは意味がないため出力ファイルから削除している（参考：[Conda export environment contains local path in the prefix \`field\` · Issue #11114 · conda/conda](https://github.com/conda/conda/issues/11114)）。

### デアクティブ化
```bash
conda deactivate
```

### 仮想環境の削除
```bash
conda remove --name "$(basename "$(pwd)")" --all -y
```

### 環境の再構築
設定ファイルから環境を再構築する場合。事前にmiseのインストールが必要。
```bash
cd ~/conda_test_project
conda env create --name "$(basename "$(pwd)")" --file environment.yml -y
```
