# ops-knowledge

インフラストラクチャとオペレーションに関するナレッジベースサイトです。

詳細な仕様については[SPEC.md](SPEC.md)を参照してください。

## クイックスタート

### 必要なもの
- [mise](https://mise.jdx.dev/)

### ローカルでの実行
```bash
# mdBookのインストール（初回のみ）
mise install

# サイトをビルドして起動
mise exec -- mdbook serve

# http://localhost:3000/ でアクセス可能
```

### ビルドのみ
```bash
mise exec -- mdbook build
```

## ディレクトリ構造
```
ops-knowledge/
├── book.toml           # mdBook設定ファイル
├── src/                # すべてのコンテンツ
│   ├── SUMMARY.md      # 自動生成されるナビゲーション
│   └── ...             # Markdownファイル
├── _site/              # ビルド出力
├── scripts/            # ユーティリティスクリプト
└── custom.css          # カスタムスタイル
```

## 主な特徴

### 自動ナビゲーション生成
`mdbook-auto-gen-summary`により、`src/`ディレクトリ構造から自動的にSUMMARY.mdが生成されます。

### 日本語対応
日本語に最適化されたフォントとレイアウトで快適に閲覧できます。

### GitHub Pages自動デプロイ
mainブランチへのプッシュで自動的にサイトがデプロイされます。

## コンテンツの追加・編集

1. `src/`ディレクトリ内の適切な場所にMarkdownファイルを作成・編集
2. 各ファイルの最初の`#`見出しがナビゲーションのタイトルになります
3. `README.md`は各ディレクトリのインデックスページとして機能します

## トラブルシューティング

### SUMMARY.mdの再生成
SUMMARY.mdは`mdbook build`時に自動的に再生成されます。

### ビルドエラーの確認
```bash
mise exec -- mdbook build --verbose
```

### mdbook-auto-gen-summaryのインストール
```bash
mise exec -- cargo install mdbook-auto-gen-summary
```
