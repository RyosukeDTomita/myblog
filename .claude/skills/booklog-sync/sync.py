#!/usr/bin/env python3
"""posts/book.md をブクログ(booklog.jp)の本棚に同期する。

処理の流れ:
  1. posts/book.md を解析して 題名 / URL / WIPマーク / 見出し階層 を取り出す
  2. 題名 -> アイテムID(ASIN / ISBN-10) を ids.json から引く。未知のものだけ解決する
  3. 解決したIDがブクログに実在するか /item/1/{id} で確認する
  4. 現在の本棚をエクスポートして差分を取る
  5. 未登録の本を CSV まとめて登録で追加し、読書状況/タグが変わった本を個別に更新する

ブクログの操作はログイン済みの Chrome に playwright-cli でアタッチして行う。
"""

import argparse
import base64
import csv
import datetime
import io
import json
import os
import re
import subprocess
import sys
import time
import unicodedata

SKILL_DIR = os.path.dirname(os.path.abspath(__file__))
IDS_PATH = os.path.join(SKILL_DIR, 'ids.json')
PW = ['npx', '-y', '@playwright/cli@latest', '--s=chrome']
UA = ('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/140.0 Safari/537.36')

# ブクログの読書状況ラジオボタンの値
STATUS_VALUE = {'読みたい': '1', 'いま読んでる': '2', '読み終わった': '3', '積読': '4'}


# --------------------------------------------------------------------------
# ISBN
# --------------------------------------------------------------------------

def valid10(s: str) -> bool:
    if not re.fullmatch(r'\d{9}[\dX]', s):
        return False
    t = sum((10 - k) * (10 if c == 'X' else int(c)) for k, c in enumerate(s))
    return t % 11 == 0


def valid13(s: str) -> bool:
    if not re.fullmatch(r'97[89]\d{10}', s):
        return False
    t = sum(int(c) * (1 if k % 2 == 0 else 3) for k, c in enumerate(s))
    return t % 10 == 0


def isbn13_to_10(i13: str):
    if not (i13 and len(i13) == 13 and i13.startswith('978')):
        return None
    core = i13[3:12]
    cd = (11 - sum((10 - k) * int(c) for k, c in enumerate(core)) % 11) % 11
    return core + ('X' if cd == 10 else str(cd))


def isbn10_to_13(i10: str):
    if not (i10 and len(i10) == 10):
        return None
    core = '978' + i10[:9]
    s = sum(int(c) * (1 if k % 2 == 0 else 3) for k, c in enumerate(core))
    return core + str((10 - s % 10) % 10)


def find_isbn10(text: str):
    """任意のテキストから ISBN を拾って ISBN-10 で返す。ISBN-13 を優先する。"""
    for m in re.finditer(r'97[89][-‐‑ ]?(?:\d[-‐‑ ]?){9}\d', text):
        c = re.sub(r'[-‐‑ ]', '', m.group(0))
        if valid13(c):
            return isbn13_to_10(c)
    for m in re.finditer(r'(?<![\dA-Za-z])((?:\d[-‐‑ ]?){9}[\dX])(?![\dA-Za-z])', text):
        c = re.sub(r'[-‐‑ ]', '', m.group(1))
        if valid10(c):
            return c
    return None


# --------------------------------------------------------------------------
# book.md の解析
# --------------------------------------------------------------------------

def norm_tag(s: str) -> str:
    """見出しをタグに変換する。タグはスペース区切りなので内部の空白は詰める。"""
    return re.sub(r'\s+', '', re.sub(r'[(（]一部[)）]', '', s))


def parse_book_md(path: str):
    h2 = h3 = h4 = None
    books = []
    for ln in open(path, encoding='utf-8'):
        ln = ln.rstrip('\n')
        if ln.startswith('#### '):
            h4 = ln[5:].strip()
        elif ln.startswith('### '):
            h3, h4 = ln[4:].strip(), None
        elif ln.startswith('## '):
            h2, h3, h4 = ln[3:].strip(), None, None
        m = re.match(r'^- \[(.+?)\]\((\S+?)\)(.*)$', ln)
        if not m:
            continue
        title, url, rest = m.group(1), m.group(2), m.group(3)
        sections = [s for s in (h2, h3, h4) if s]
        books.append({
            'title': title,
            'url': url,
            'status': 'いま読んでる' if 'WIP' in rest else '読み終わった',
            'tags': ' '.join(dict.fromkeys(norm_tag(s) for s in sections)),
        })
    return books


# --------------------------------------------------------------------------
# ブラウザ操作 (playwright-cli 経由)
# --------------------------------------------------------------------------

def pw(*args, timeout=300):
    p = subprocess.run(PW + list(args), capture_output=True, text=True, timeout=timeout)
    return p.stdout


def require_session():
    out = pw('tab-list', timeout=120)
    if 'booklog' not in out and 'Open tabs' not in out:
        sys.exit('chrome セッションにアタッチできていない。\n'
                 '  npx -y @playwright/cli@latest attach --cdp=chrome\n'
                 'を実行し、Chrome 側の接続許可プロンプトを承認してから再実行すること。')


def goto_booklog():
    """eval は現在のページ上で走る。相対 fetch を booklog に向けるため必ず遷移させる。"""
    pw('goto', 'https://booklog.jp/home')


def js(expr: str, timeout=600):
    out = pw('--raw', 'eval', expr, timeout=timeout).strip()
    st = min([i for i in (out.find('{'), out.find('[')) if i >= 0], default=-1)
    if st < 0:
        raise RuntimeError('eval の戻り値を解釈できない: ' + out[:400])
    en = max(out.rfind('}'), out.rfind(']'))
    return json.loads(out[st:en + 1])


# --------------------------------------------------------------------------
# ID の解決
# --------------------------------------------------------------------------

def resolve_amazon_short(url: str):
    """amzn.asia の短縮URLは1ホップのリダイレクト先に ASIN が入っている。"""
    p = subprocess.run(['curl', '-s', '-o', '/dev/null', '--max-time', '25',
                        '-A', UA, '-w', '%{redirect_url}', url],
                       capture_output=True, text=True, timeout=45)
    m = re.search(r'/(?:dp|gp/product)/([A-Z0-9]{10})', p.stdout)
    return m.group(1) if m else None


def resolve_publisher(url: str):
    """出版社ページ本文から ISBN を拾う。URL 内の数字は製品コードのことがあるので本文優先。"""
    try:
        p = subprocess.run(['curl', '-sL', '--max-time', '30', '--compressed', '-A', UA, url],
                           capture_output=True, timeout=45)
        html = p.stdout.decode('utf-8', 'replace')
        if html.count('�') > len(html) / 50:
            html = p.stdout.decode('cp932', 'replace')
        text = re.sub(r'<(script|style)[^>]*>.*?</\1>', ' ', html, flags=re.S | re.I)
        got = find_isbn10(text)
        if got:
            return got
    except Exception:
        pass
    return find_isbn10(url)   # ページ取得に失敗しても URL に ISBN が埋まっていることがある


def verify_on_booklog(ids):
    """/item/1/{id} を引いて実在確認する。{id: 題名} を返す(存在しないものは含めない)。"""
    found = {}
    for i in range(0, len(ids), 20):
        chunk = ids[i:i + 20]
        expr = '''async () => {
          const out = [];
          for (const id of %s) {
            const r = await fetch('/item/1/' + id, {credentials:'include'});
            const t = await r.text();
            const m = t.match(/<title>(.*?)<\\/title>/s);
            out.push([id, r.status, m ? m[1].trim() : '']);
            await new Promise(s => setTimeout(s, 250));
          }
          return out;
        }''' % json.dumps(chunk)
        for id_, status, title in js(expr):
            if status == 200:
                found[id_] = re.sub(r'のあらすじ・感想 - ブクログ$', '', title)
    return found


def search_booklog(title: str, limit=6):
    expr = '''async () => {
      const r = await fetch('/search?service_id=1&keyword=' + encodeURIComponent(%s),
                            {credentials:'include'});
      const doc = new DOMParser().parseFromString(await r.text(), 'text/html');
      const seen = new Map();
      for (const a of doc.querySelectorAll('a[href*="/item/1/"]')) {
        const id = a.getAttribute('href').match(/\\/item\\/1\\/([0-9A-Z]{10})/)[1];
        const img = a.querySelector('img');
        const t = (img && img.alt) || (a.textContent || '').trim();
        if (t && t.length > 3 && !seen.has(id)) seen.set(id, t);
      }
      return [...seen].slice(0, %d);
    }''' % (json.dumps(title), limit)
    return js(expr)


# --------------------------------------------------------------------------
# 本棚の読み書き
# --------------------------------------------------------------------------

def export_shelf():
    """本棚をエクスポートして {アイテムID: 行} を返す。列は下の SHELF_COLS を参照。"""
    pw('goto', 'https://booklog.jp/export')
    href = js("() => { const a = [...document.querySelectorAll('a')]"
              ".find(x => /download\\.booklog\\.jp/.test(x.href)); return {u: a ? a.href : ''}; }")['u']
    if not href:
        raise RuntimeError('エクスポートのダウンロードリンクが見つからない')
    raw = subprocess.run(['curl', '-s', href], capture_output=True, timeout=180).stdout
    if not raw:
        return {}
    rows = list(csv.reader(io.StringIO(raw.decode('cp932', 'replace'))))
    return {r[1]: r for r in rows if len(r) > 7}


# エクスポートCSVの列: サービスID, アイテムID, 13桁ISBN, カテゴリ, 評価, 読書状況,
#                      レビュー, タグ, 読書メモ, 登録日時, 読了日, 題名, 著者, 出版社, 発行年, 種別, ページ数
SHELF_STATUS, SHELF_TAGS, SHELF_TITLE = 5, 7, 11


def import_csv(rows):
    """まとめて登録(CSV)。既存アイテムは重複も更新もされず単に無視される。"""
    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    def q(v):
        return '"' + str(v).replace('"', '""') + '"'
    added = 0
    for i in range(0, len(rows), 100):          # 一度に登録できるのは100件まで
        chunk = rows[i:i + 100]
        body = '\r\n'.join(
            ','.join(q(c) for c in
                     ['1', b['id'], isbn10_to_13(b['id']) if valid10(b['id']) else '',
                      '-', '', b['status'], '', b['tags'], '', now, ''])
            for b in chunk) + '\r\n'
        b64 = base64.b64encode(body.encode('cp932', 'replace')).decode()
        pw('goto', 'https://booklog.jp/input/file')
        js('''async () => {
          const bin = atob("%s"); const buf = new Uint8Array(bin.length);
          for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
          const fd = new FormData();
          fd.append('input_file', new File([buf], 'import.csv', {type: 'text/csv'}));
          fd.append('_method', 'default');
          const r = await fetch('/input/file', {method: 'POST', body: fd, credentials: 'include'});
          return {status: r.status};
        }''' % b64)
        added += len(chunk)
        time.sleep(2)                            # サーバ負荷への配慮
    return added


def update_item(item_id, status, tags):
    """既存アイテムの読書状況とタグを更新する。CSVインポートでは更新できないため個別に投げる。"""
    expr = '''async () => {
      const id = %s, status = %s, tags = %s;
      const page = await (await fetch('/edit/1/' + id, {credentials:'include'})).text();
      const doc = new DOMParser().parseFromString(page, 'text/html');
      const form = [...doc.querySelectorAll('form')]
        .find(f => [...f.elements].some(e => e.name === 'create_on_d'));
      if (!form) return {ok: false, why: 'edit form not found'};
      const fd = new FormData();
      for (const e of form.elements) {
        if (!e.name) continue;
        if (e.type === 'checkbox' || e.type === 'radio') { if (e.checked) fd.append(e.name, e.value); }
        else fd.append(e.name, e.value);
      }
      fd.set('status_1_' + id, status);
      fd.set('tags', tags);
      const r = await fetch('/edit/1/' + id, {method:'POST', body: fd, credentials:'include'});
      return {ok: r.status === 200, status: r.status};
    }''' % (json.dumps(item_id), json.dumps(STATUS_VALUE[status]), json.dumps(tags))
    return js(expr)


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description='posts/book.md をブクログの本棚に同期する')
    ap.add_argument('--book-md', default='posts/book.md')
    ap.add_argument('--dry-run', action='store_true', help='差分を表示するだけで書き込まない')
    ap.add_argument('--no-update', action='store_true',
                    help='新規追加のみ行い、既存本の読書状況/タグは更新しない')
    args = ap.parse_args()

    books = parse_book_md(args.book_md)
    ids = json.load(open(IDS_PATH, encoding='utf-8'))
    resolved, skipped = ids['resolved'], ids['skipped']
    print(f'book.md: {len(books)}冊')

    require_session()
    goto_booklog()

    # 1. 未知の本の ID を解決する
    unknown = [b for b in books if b['title'] not in resolved and b['title'] not in skipped]
    newly, unresolved = {}, []
    for b in unknown:
        got = (resolve_amazon_short(b['url']) if 'amzn.asia' in b['url']
               else resolve_publisher(b['url']))
        (newly.__setitem__(b['title'], got) if got else unresolved.append(b))
        time.sleep(1)
    if newly:
        goto_booklog()
        ok = verify_on_booklog(sorted(set(newly.values())))
        for t, i in list(newly.items()):
            if i in ok:
                print(f'  解決: {t} -> {i} ({ok[i]})')
            else:
                del newly[t]
                unresolved.append(next(b for b in books if b['title'] == t))
        resolved.update(newly)

    if unresolved:
        print(f'\n★ 自動解決できなかった本 {len(unresolved)}件 '
              '(ブクログの書名検索候補を出す。正しいIDを ids.json の resolved に、'
              'ブクログに無い同人誌等は skipped に手で追記すること):')
        for b in unresolved:
            print(f'  ## {b["title"]}  <{b["url"]}>')
            try:
                for i, t in search_booklog(b['title']):
                    print(f'       {i}  {t[:70]}')
            except Exception as e:
                print(f'       (検索失敗: {e})')

    # 2. 本棚と突き合わせる
    shelf = export_shelf()
    print(f'\n本棚: {len(shelf)}冊')
    to_add, to_update = [], []
    for b in books:
        item_id = resolved.get(b['title'])
        if not item_id:
            continue
        row = shelf.get(item_id)
        if row is None:
            to_add.append({'id': item_id, **b})
        elif row[SHELF_STATUS] != b['status'] or row[SHELF_TAGS] != b['tags']:
            to_update.append({'id': item_id, 'row': row, **b})

    print(f'追加 {len(to_add)}件 / 更新 {len(to_update)}件')
    for b in to_add:
        print(f'  + {b["id"]}  {b["title"][:50]}  [{b["status"]}]')
    for b in to_update:
        r = b['row']
        print(f'  ~ {b["id"]}  {r[SHELF_TITLE][:40]}')
        if r[SHELF_STATUS] != b['status']:
            print(f'      読書状況: {r[SHELF_STATUS]} -> {b["status"]}')
        if r[SHELF_TAGS] != b['tags']:
            print(f'      タグ    : {r[SHELF_TAGS]} -> {b["tags"]}')

    if args.dry_run:
        print('\n--dry-run のため書き込みはしていない。')
        return

    if to_add:
        goto_booklog()
        print(f'\n{import_csv(to_add)}件を CSV まとめて登録で追加した。')
    if to_update and not args.no_update:
        goto_booklog()
        ng = [b for b in to_update if not update_item(b['id'], b['status'], b['tags']).get('ok')]
        print(f'{len(to_update) - len(ng)}件を更新した。' + (f' 失敗 {len(ng)}件。' if ng else ''))

    # 3. 解決結果を書き戻して次回以降の再取得を省く
    ids['resolved'] = dict(sorted(resolved.items()))
    json.dump(ids, open(IDS_PATH, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

    # 4. 反映確認
    shelf = export_shelf()
    missing = [b['title'] for b in books
               if resolved.get(b['title']) and resolved[b['title']] not in shelf]
    print(f'\n最終: 本棚 {len(shelf)}冊 / 未反映 {len(missing)}件'
          + (': ' + ', '.join(missing) if missing else ''))


if __name__ == '__main__':
    main()
