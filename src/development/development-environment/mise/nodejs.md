# mise & Node.js
## プロジェクトディレクトリーの作成
```bash
mkdir ~/nodejs_test_project &&
cd ~/nodejs_test_project
```

## ランタイムおよびツールのインストール
プロジェクトローカルにNode.jsランタイムおよびパッケージ管理ツールをインストールする。Node.jsはパッケージ管理ツールを、Node.js付属のnpm、Yarnおよびpnpmから選択できる。選択に応じてYarnまたはpnpmをインストールする。インストールした内容は設定ファイル(.mise.toml)に記録される。

### Node.js
```bash
mise use -y node@24 &&
echo "node: $(node --version)" &&
echo "npm: $(node --version)"
```
`mise ls-remote node`コマンドでインストール可能なバージョンがリストアップされる。

### Yarn
```bash
mise use -y yarn@4 &&
yarn --version &&
```
`mise ls-remote yarn`コマンドでインストール可能なバージョンがリストアップされる。

### pnpm
```bash
mise use -y pnpm@10 &&
pnpm --version
```
`mise ls-remote -y pnpm`コマンドでインストール可能なバージョンがリストアップされる。

## ランタイムおよびツールの再インストール
設定ファイル(.mise.toml)からランタイムおよびツールを再インストールする場合。
```bash
mise install -y
```

## プロジェクトの初期化およびパッケージのインストール
### npm（Node.js付属）
```bash
npm init -y &&
npm install cowsay &&
npm ls
```

### Yarn
```bash
yarn init -y &&
yarn add cowsay &&
yarn list
```

### pnpm
```bash
pnpm init &&
pnpm add cowsay &&
pnpm list
```

## パッケージデータの削除
インストールされたパッケージのデータのデータの削除する。どのパッケージがインストールされていたのかを記録した設定ファイル（package.jsonなど）は残るため、削除しても再インストールすることができる。
```bash
rm -rf node_modules
```

## パッケージデータの再インストール
設定ファイル（package.jsonなど）からインストールされたパッケージのデータを再インストールする。

### npm（Node.js付属）
```bash
npm install
```

### Yarn
```bash
yarn install
```

### pnpm
```bash
pnpm install
```

## ツールのアンインストール
`.mise.toml`を参照しているため、プロジェクトディレクトリーのルートで実行する必要がある。

### Node.js
```bash
mise uninstall node &&
perl -pi -e "s/^node = \".+\"\\n//mg" .mise.toml
```

### Yarn
```bash
mise uninstall yarn &&
perl -pi -e "s/^yarn = \".+\"\\n//mg" .mise.toml
```

### pnpm
```bash
mise uninstall pnpm &&
mise plugins uninstall -y pnpm &&
perl -pi -e "s/^pnpm = \".+\"\\n//mg" .mise.toml
```
