# ops-knowledge サイト要件定義書

## 概要

本ドキュメントは、「ops-knowledge」サイトの要件定義を記載します。このサイトは、インフラストラクチャとオペレーションに関するナレッジベースとして機能します。

## 基本要件

### サイト情報
- **サイト名**: オペレーションナレッジ
- **説明**: インフラストラクチャとオペレーションに関するナレッジベース
- **URL**: https://hydratlas.github.io/ops-knowledge
- **言語**: 日本語

### ビルド環境
- **ツール管理**: mise
- **パッケージマネージャ**: Cargo
  - `mise use rust`でインストール
  - `mise exec -- cargo`で実行
- **静的サイトジェネレーター**: mdBook
  - `mise use aqua:rust-lang/mdBook`でインストール
  - `mise exec -- mdbook`で実行
  - **プラグイン**:
    - mdbook-auto-gen-summary
      - `mise exec -- cargo install mdbook-auto-gen-summary`でインストール
- **デプロイ先**: GitHub Pages
- **ベースURL**: /ops-knowledge

## 機能要件

### 1. コンテンツ管理

#### 1.1 ディレクトリ構造
- すべてのコンテンツは `src/` ディレクトリに配置
  - `src/` ディレクトリ内のファイルは修正せずに使う
- `src/` ディレクトリがサイトのルートとして機能
- README.mdファイルは各ディレクトリのindex.html的なデフォルト表示とする

#### 1.2 URL構造
- `src/` プレフィックスなしでアクセス可能
  - 例: `src/platforms/README.md` → `/ops-knowledge/platforms/`
- パーマリンク形式: pretty（末尾スラッシュ付き）

#### 1.3 Markdownサポート
- フロントマター不要（mdBookはフロントマターを使用しない）
- 相対リンクの自動処理

### 2. 自動処理機能

#### 2.1 ページタイトル自動生成
- 各ファイルの最初の `#` 見出しからタイトルを生成
- README.mdの場合も同様に最初の見出しを使用

#### 2.2 ナビゲーション自動生成
- mdBookプラグインを使用して `src/` ディレクトリ構造から自動的に `SUMMARY.md` を生成
- 全階層が展開された状態で表示（折りたたみ機能なし）
- タイトルは各ファイルの最初の見出しから取得
- 現在のページをハイライト表示

#### 2.3 パンくずリスト
- 全ページに自動的にパンくずリストを表示
- ホームからの階層パスを表示

### 3. GitHub Actions
- mainブランチへのプッシュ時に自動デプロイ
- 手動実行可能