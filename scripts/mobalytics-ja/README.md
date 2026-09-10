# mobalytics-ja — mobalytics.gg PoE2 ビルドガイドの日本語 UI クローン生成

mobalytics.gg のビルドガイド 1 ページを、元サイト風レイアウト + 日本語 (ゲーム用語は「日本語 + 英語小文字併記」) のローカル HTML に変換する手順と道具。
初回実績: `pages/varashta.json` → `tasks/2026-09-10-varashta-djinn-build-guide-ja-ui.html` (2026-09-10)。

全体像: **機械処理 (fetch → extract → assets → build → verify) は本ディレクトリのスクリプト、本文の翻訳だけが Claude の手作業**。
本文翻訳の出力形式 (下記「prose HTML の契約」) を守れば build.py がそのまま同じ見た目の成果物を出す。

## 0. 前提

- 作業 cwd は repo root (`/Users/kokage/national-operations`)。Bash の cwd は呼び出しごとに戻るので絶対パスで実行する
- 依存: python3 標準ライブラリ + curl のみ。ゲームデータは repo 内 (`src/Data/Gems.lua`, `src/TreeData/0_5/tree.lua`, `src/Locales/ja/*.lua`, `src/Locales/ja.lua`) を読む
- 成果物は `tasks/` 配下のローカルファイル。Artifact 化・commit はユーザーが求めたときだけ
- ブラウザ確認は `open -a Safari <file>` のみ。**Safari への osascript キー送信は禁止** (2026-09-10 にユーザー操作と衝突した)

## 1. ページ設定 JSON を書く

`pages/<slug>.json` を新規作成 (`pages/varashta.json` をコピーして書き換える)。

| key | 内容 |
|---|---|
| `slug` | 短い識別子。localStorage キー (`<slug>-variant`) に使う |
| `url` | 原文 URL |
| `prose_html` | 本文翻訳 HTML (repo 相対)。命名 `tasks/YYYY-MM-DD-<slug>-build-guide-ja.html` |
| `out_html` | 生成する UI クローン (repo 相対)。命名 `tasks/YYYY-MM-DD-<slug>-build-guide-ja-ui.html` |
| `asset_dir` | アイコン置き場 (repo 相対)。`out_html` と同じ basename のフォルダ。doc.json / dump.md もここに入る |
| `made_on` | 日本語版作成日 (ヒーローの byline に出る) |
| `page_title` | `<title>` |
| `title_ja` | ヒーローの `<h1>` (日本語タイトル) |
| `buttons` | 追加ボタン `[{label,url}]`。原文の動画リンク等。無ければ `[]` |
| `variant_titles_ja` | 原文バリアント名 → 日本語タブ名。原文名は fetch 後の出力で確認する |
| `gem_name_subst` | ジェム名のプレースホルダ置換 (例 Spectre の `{0}` → 実体名)。無ければ `{}` |
| `runes` | ルーン slug → 英語名。slug は dump.md の `runes:` 行に出る。`src/Data/ModRunes.lua` は slug を持たないため手書き |
| `anoints` | アノイント slug → パッシブ名。tree.lua の stringId で引けないものだけ書く |

`variant_titles_ja` / `runes` / `anoints` は fetch → extract の出力を見てから埋める (最初は空でよい)。

## 2. fetch — 原文 JSON の取得

```
python3 scripts/mobalytics-ja/fetch.py scripts/mobalytics-ja/pages/<slug>.json
```

- mobalytics は直接 curl だと Cloudflare に弾かれるので `https://r.jina.ai/<url>` に `X-Return-Format: html` を付けて取る (2026-09-10 時点で動作。恒久保証なし)
- `<asset_dir>/raw.html` → `window.__PRELOADED_STATE__` を抽出 → `state.json`、その中の `userGeneratedDocumentBySlug` を再帰探索して `doc.json`、コメント一覧を `comments.json` に保存
- raw.html が既にあれば再取得しない。取り直すときは raw.html を消す
- 出力にバリアント名とタグ名が出るので `variant_titles_ja` を埋める

## 3. extract — 翻訳用ダンプ

```
python3 scripts/mobalytics-ja/extract.py scripts/mobalytics-ja/pages/<slug>.json
```

`<asset_dir>/dump.md` に、原文本文 (Lexical rich text → Markdown 風)、強み弱み、クエスト報酬、各バリアントの装備 / ジェム / パッシブ (tree.lua で名前解決済み)、コメント JSON を書き出す。Claude はこれを Read して翻訳する。

## 4. 本文翻訳 (Claude の手作業) — prose HTML の契約

`prose_html` に **単独でも読める日本語訳ページ**を書く。build.py は以下の構造だけを頼りに本文を切り出すので必ず守る:

- `<h2 id="overview">` ビルド概要。配下の小見出しは `<h3 id="ov-xxx">1.1 見出し</h3>` (番号は build 時に除去、TOC のサブ項目になる)
- `<h2 id="sw">` 強みと弱み。**`<ul>` を 2 つ** (1 つ目 = 強み、2 つ目 = 弱み)
- `<h2 id="v1">` … `<h2 id="vN">` バリアント (doc の childrenVariants と同順・同数)。各セクション内に
  - 冒頭の導入文 (h3 より前) → 「ビルドバリアント」カードの本文
  - `<h3>装備</h3>` → 装備カードの本文
  - `<h3>スキルジェム</h3>` (または `<h3>スキルジェム (入手順)</h3>` 等、先頭一致) → ジェムカードの本文
  - `<h3>パッシブツリー</h3>` → パッシブカードの本文。この中の `<ul>` は捨てられる。ただし `<li>ジュエル…</li>` はジュエル欄、`<li>アセンダンシー: データ上は…</li>` はアセンダンシー注記として拾う
  - `<h4>掲載アイテム例</h4>`、`<div class="tbl">…</table></div>`、`<p class="m">装備優先順…</p>` / `<p class="m">必要ステータス…</p>` は build 時に削除される (データから再生成するため)。書いてもよいが重複させない
- `<h2 id="quest">` クエスト報酬の補足文 (表はデータから生成)
- `<h2 id="faq">` 著者コメント欄からの補足 (comments.json から拾った Q&A)
- `<h2 id="changelog">` 更新履歴
- `<h2 id="notes">` 訳注。最初の `<ul>` 先頭に build が定型の訳注 3 項目を差し込む
- 各 h2 の本文は次の `<h2 id=` または `</main>` / `</body>` まで

翻訳の約束:
- ゲーム用語 (スキル名 / ユニーク名 / パッシブ名 / ジェム名) は **英語のまま**書く。build がアイコン付きに置換する (`<code>` と `<a>` の中は置換しない)
- データ側 (装備 mod / ジェム説明 / パッシブ効果 / クエスト報酬) は build が `src/Locales/ja` で自動翻訳するので本文で繰り返さない
- `<strong>` や `<span class="uniq">` で用語を囲ってもよい (アイコン化時に外される)

## 5. assets — アイコン取得

```
python3 scripts/mobalytics-ja/assets.py scripts/mobalytics-ja/pages/<slug>.json
```

doc.json 内の `iconURL / iconUrl / icon / imageUrl` と、選択パッシブノードの tree.lua アイコン、クラス・アセンダンシーのヘッダー画像を `<asset_dir>/` に落とし `assetmap.json` を書く。

- ファイル名 = CDN パスの `/images/game/` 以降、英数字 `._-` 以外を `_`
- `.avif` は 403 なので `.webp` に読み替える。ルーンソケット画像 (`runesocketfilled` / `soulcoressocketfilled`) は 404 → build 側で「R」バッジ代替。この 2 件の失敗は正常 (2026-09-10 時点)
- **ページに登場するアイコンだけ**取る。全ノータブルを取ると本文中の一般語 (例 "Sniper") にパッシブアイコンが誤付与される (2026-09-10 に実証)

## 6. build — HTML 生成

```
python3 scripts/mobalytics-ja/build.py scripts/mobalytics-ja/pages/<slug>.json
```

出力末尾の `missing src []` / `placeholders 0` を確認。パッシブカードには `tree_svg.py` が `src/TreeData/0_5/tree.lua` の座標 (orbitAnglesByOrbit / orbitRadii、接続の弧は PassiveTree.lua と同じ 3 分岐) から描いた SVG ツリー (メイン + 武器セット 1/2 の割当、アセンダンシーは別 SVG) が入る。ベース層 (全ノード) は `<defs id="tb">` 1 個を `<use>` で共有し、バリアント毎には割当層だけを持つ (出力 ~1.2MB)。属性ノード間の長い直線はツリーデータ通りで誤りではない。`ja_locale.py` がロケール照合 (mod 行はテンプレート化して `{N}` 照合、単複・空白無視・複数行結合のフォールバックあり。ロケールに無い定型文は `ja_locale.py` の `MANUAL` に追記する)。

## 7. verify

```
python3 - <<'EOF'
from html.parser import HTMLParser
class P(HTMLParser):
    def __init__(s): super().__init__(); s.st=[]; s.bad=[]
    def handle_startendtag(s,t,a): pass
    def handle_starttag(s,t,a):
        if t not in ('img','br','meta','link','input','hr','use','circle','path','image'): s.st.append(t)
    def handle_endtag(s,t):
        if s.st and s.st[-1]==t: s.st.pop()
        else: s.bad.append(t)
p=P(); p.feed(open('tasks/<out>.html',encoding='utf-8').read()); print('unclosed',p.st,'bad',p.bad[:5])
EOF
```

- 英語残りの走査: `.tt-mod / .nstat / td.rw / .tt-name / .gname / .nname / .sup / .chip` の中身を正規表現で拾い、日本語を含まない行を列挙して `MANUAL` 追記かロケール確認
- 見た目: headless Chrome でスクリーンショット → `sips` で切り出して Read
  ```
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars --window-size=1300,16000 --screenshot=<png> "file://<abs out html>?v=<variantId>"
  sips -c 1400 1300 --cropOffset <Y> 0 <png> --out <crop.png>
  ```
- ツリー描画: パッシブカードのスクショで、弧が group 中心に沿っているか / 割当線が途切れていないか / アセンダンシー SVG が出ているかを見る (2026-09-10 に v=1 と v=6 で確認)
- 仕上げ: `open -a Safari <abs out html>`

## 8. 記録

- `tasks/YYMMDD-HHMM-<slug>-ui-clone.md` に checkpoint (context-keeper 形式)
- `brain_save(type: session)` で決定事項 (ロケールに無かった語、CDN の挙動変化など) を残す
- 新しい定型文を `MANUAL` に足したら次ページでも効くのでそのまま残す

## ファイル

| file | 役割 |
|---|---|
| `fetch.py` | r.jina.ai 経由で raw.html → state.json / doc.json / comments.json |
| `extract.py` | doc.json → dump.md (翻訳用) |
| `assets.py` | アイコン・ヘッダー画像を asset_dir へ |
| `build.py` | prose HTML + doc.json + ロケール → UI クローン HTML |
| `tree_svg.py` | tree.lua の座標・接続を解析してパッシブツリー SVG (ベース層 / 割当層 / アセンダンシー) と pan・zoom JS を生成 |
| `ja_locale.py` | `src/Locales/ja` の読み込みと mod / ステータス / 名前の翻訳 (`translate`, `translate_lines`, `stat_label`, `item_name`, `node_name`, `gem_name`, `MANUAL`) |
| `pages/*.json` | ページごとの設定 |
