# mise & ( Node.js & pnpm ) & Node.js
## ユーザーグローバルでの設定
### インストール
```bash
mise use -g -y node pnpm &&
echo "Node.js: $("$(mise which node)" --version)" &&
echo "pnpm: $("$(mise which pnpm)" --version)"
```
pnpmはNode.jsがないと動かないためNode.jsも入れている。

### シェル補完のインストール（bashの場合）
```bash
mkdir -p ~/.local/share/bash-completion/completions &&
tee ~/.local/share/bash-completion/completions/pnpm << EOS > /dev/null &&
if hash mise 2>/dev/null && mise which pnpm 2>/dev/null; then
  eval "\$(pnpm completion bash)"
fi
EOS
. ~/.local/share/bash-completion/completions/pnpm
```

### シェル補完のアンインストール（bashの場合）
```bash
if [ -e ~/.local/share/bash-completion/completions/pnpm ]; then
  rm ~/.local/share/bash-completion/completions/pnpm
fi
```

### アンインストール
```bash
mise uninstall node pnpm &&
perl -pi -e "s/^node = \".+\"\\n//mg;s/^pnpm = \".+\"\\n//mg" ~/.config/mise/config.toml
```
`mise use`を元に戻すサブコマンドは2024年11月現在、存在しない（参照：[`mise rm` · Issue #1465 · jdx/mise](https://github.com/jdx/mise/issues/1465)）。

## プロジェクトでの使用
### プロジェクトの作成
```bash
mkdir ~/pnpm_test_project &&
cd ~/pnpm_test_project &&
pnpm init
```

### 指定したバージョンのNode.jsのインストール、およびその使用の強制
jqが必要。`sudo apt-get install -y jq`または`mise use -g jq`などのコマンドでインストールしておく。
```bash
mv package.json package.json.bak &&
cat package.json.bak | jq '.pnpm.executionEnv.nodeVersion|="22.11.0"' > package.json &&
rm package.json.bak &&
tee -a .npmrc << EOS > /dev/null &&
engine-strict=true
EOS
pnpm node --version
```
`pnpm env list --remote`コマンドでインストール可能なバージョンがリストアップされる。バージョン指定は`X.Y.Z`とする必要があり、下位の桁を省略できない。`engine-strict=true`によってこの場合、指定したバージョンのNode.jsの使用を強制している。
- [Settings (.npmrc) | pnpm](https://pnpm.io/ja/npmrc#use-node-version)

### pnpmのバージョンの固定、およびその使用の強制
```bash
tee -a .npmrc << EOS > /dev/null &&
package-manager-strict=true
package-manager-strict-version=true
manage-package-manager-versions=true
EOS
mv package.json package.json.bak &&
cat package.json.bak | jq ".packageManager|=\"pnpm@$(pnpm --version)\"" > package.json &&
rm package.json.bak &&
pnpm --version
```
- [Settings (.npmrc) | pnpm](https://pnpm.io/ja/npmrc#package-manager-strict)
- [Settings (.npmrc) | pnpm](https://pnpm.io/ja/npmrc#package-manager-strict-version)
- [Settings (.npmrc) | pnpm](https://pnpm.io/ja/npmrc#manage-package-manager-versions)

### Node.jsライブラリーのインストール
```bash
pnpm add cowsay &&
pnpm list
```

### 環境の再構築
設定ファイルから環境を再構築する場合。
```bash
pnpm install
```
