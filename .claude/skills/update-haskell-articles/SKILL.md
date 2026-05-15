---
name: update-haskell-articles
description: qiita-article-archiveからHaskellタグ記事を収集し、Qiita APIで初回投稿日を取得して myblog/posts/2026-05-15-haskell-articles.md を最新状態に更新する
disable-model-invocation: true
allowed-tools: Bash Read Edit Write
---

myblogのHaskell記事まとめ (`posts/2026-05-15-haskell-articles.md`) を最新の状態に更新する。

## 手順

### 1. Haskellタグ記事のIDを収集する

`/home/sigma/qiita-article-archive/public/` 内のMarkdownファイルから、`tags:` に `Haskell` を含む記事のIDを列挙する。

```bash
cd /home/sigma/qiita-article-archive/public && for f in *.md; do
  if awk 'BEGIN{intag=0} /^tags:/{intag=1; next} intag && /^[a-z_]+:/{intag=0} intag {print}' "$f" | grep -qi "^\s*-\s*Haskell"; then
    basename "$f" .md
  fi
done
```

### 2. 既存記事の日付を再利用し、新規記事のみQiita APIで取得する

まず `posts/2026-05-15-haskell-articles.md` から既存のURL→日付マッピングを抽出する。
投稿日は変わらないので、既存記事はAPIを叩かずそのまま使う。

```bash
# 既存ファイルから "- YYYY-MM-DD [title](url)" の行を抽出してIDと日付をマッピング
python3 -c "
import re
existing = {}
with open('/home/sigma/myblog/posts/2026-05-15-haskell-articles.md') as f:
    for line in f:
        m = re.match(r'- (\d{4}-\d{2}-\d{2}) \[.*?\]\((https://qiita\.com/[^)]+/items/([^)]+))\)', line)
        if m:
            existing[m.group(3)] = (m.group(1), m.group(2))
print(existing)
"
```

次に、各IDについて既存マッピングにあればAPIを呼ばず再利用し、なければAPIで取得する。

```bash
for id in "${IDS[@]}"; do
  if [[ -v existing[$id] ]]; then
    echo "${existing[$id]}"  # YYYY-MM-DD<TAB>URL<TAB>title (キャッシュ済み)
  else
    curl -s "https://qiita.com/api/v2/items/$id" > /tmp/qiita_response.json
    python3 -c "
import json
with open('/tmp/qiita_response.json') as f:
    d = json.load(f)
print(d['created_at'][:10] + '\t' + d['url'] + '\t' + d['title'])
"
    sleep 0.3
  fi
done
```

実装上は、Bash連想配列ではなくPythonで一括処理する方が確実:

```python
import re, json, time
from urllib.request import urlopen

# 既存ファイルからID→(date, url, title)を抽出
existing = {}
with open('/home/sigma/myblog/posts/2026-05-15-haskell-articles.md') as f:
    for line in f:
        m = re.match(r'- (\d{4}-\d{2}-\d{2}) \[(.*?)\]\((https://qiita\.com/[^)]+/items/([^)]+))\)', line)
        if m:
            existing[m.group(4)] = (m.group(1), m.group(3), m.group(2))

results = []
for id in IDS:
    if id in existing:
        results.append(existing[id])  # (date, url, title)
    else:
        with urlopen(f'https://qiita.com/api/v2/items/{id}') as r:
            d = json.load(r)
        results.append((d['created_at'][:10], d['url'], d['title']))
        time.sleep(0.3)
```

`created_at` の先頭10文字 (YYYY-MM-DD) を初回投稿日として使う。`updated_at` ではないので注意。

### 3. ソートしてMarkdownを生成する

- 年ごとに `## YYYY` でグループ化
- 年は降順（新しい年が上）
- 各年内も投稿日の降順（新しい記事が上）
- 各行のフォーマット: `- YYYY-MM-DD [タイトル](URL)`

### 4. ファイルを更新する

`/home/sigma/myblog/posts/2026-05-15-haskell-articles.md` をEditツールで書き換える。

- frontmatterの `date:` を今日の日付 (YYYY-MM-DD) に変更する
- 本文のリスト部分を新しい内容で置き換える

最終的な構成:

```
---
title: 自分のHaskell記事まとめ
date: <今日の日付>
tags: haskell
---

Qiitaに投稿した自分のHaskell記事の一覧です。

## YYYY

- YYYY-MM-DD [タイトル](URL)
...
```
