note.comの記事URLを受け取り、このブログ(myblog)に移植する。

## 手順

### 1. 記事の全文取得

WebFetchツールを**2回**使う。note.comはJavaScriptレンダリングが必要なため、1回目は概要しか取れないことが多い。

- 1回目のプロンプト: 「記事のタイトル、本文全文、画像URLをMarkdownで出力」
- うまく取れない場合はAgentツール(general-purpose)に委譲し、WebFetchを複数回試させる

取得すべき情報:

- タイトル、公開日
- 本文全文（見出し・段落・箇条書きの構造を保持）
- 画像URL（`https://assets.st-note.com` で始まる）と本文中の登場順

### 2. 既存投稿の構造確認

`posts/konoshima.md` などを参照してフロントマターとMarkdownのスタイルを合わせる。

### 3. 画像ディレクトリの作成・ダウンロード

```
mkdir -p posts/assets/<フォルダ名>/
```

フォルダ名は記事の内容から短い英数字で命名（例: `manai`, `konoshima`）。

画像は登場順に `01.jpg`, `02.png` ... と連番でリネームして保存:

```bash
curl -sO "<URL>" && mv "<元ファイル名>" 01.jpg
```

カバー画像（`/production/uploads/images/` パスのもの）は `cover.png` として保存。

### 4. Markdownファイルの作成

`posts/<フォルダ名>.md` に作成。

フロントマター:

```yaml
---
title: "記事タイトル"
date: YYYY-MM-DD   # noteの公開日
tags: travel, jinja, japan   # 内容に合わせて
---
```

画像の参照パス: `![](./assets/<フォルダ名>/01.jpg)`

注釈ブロックは `> [!NOTE]` 形式を使う:

```markdown
> [!NOTE]
> 補足説明テキスト
```

### 5. 確認

- 画像枚数が全て揃っているか: `ls posts/assets/<フォルダ名>/ | wc -l`
- Markdownの画像参照が全て正しいパスか確認

## 注意事項

- note.comはJavaScriptレンダリングのためWebFetchで本文が取れないことがある。その場合はAgentツールで複数回試す
- 画像URLは `assets.st-note.com/img/` と `assets.st-note.com/production/uploads/` の2種類ある
- 本文のキャプション（画像の下のテキスト）も保持する
