---
name: mobalytics-ja
description: >-
  mobalytics.gg の PoE2 ビルドガイドを日本語 UI クローン HTML (tasks/ 配下のローカル成果物) にする。
  Use when the user asks to translate / clone / 日本語化 a mobalytics.gg build guide page,
  or references 「mobalytics のビルドガイド」「前と同じやり方で翻訳」.
  Repo 固有 (src/Locales/ja と scripts/mobalytics-ja に依存) のため sync 対象外。
---

# mobalytics-ja

手順の正本は `scripts/mobalytics-ja/README.md`。**最初に必ず Read してから始める** (本スキルは入口と要点のみ)。

## 流れ

1. `scripts/mobalytics-ja/pages/<slug>.json` を `pages/varashta.json` から複製して書く (url / 出力名 / 作成日 / タイトル)
2. `python3 scripts/mobalytics-ja/fetch.py pages/<slug>.json` → 出力のバリアント名を `variant_titles_ja` に写す
3. `python3 scripts/mobalytics-ja/extract.py pages/<slug>.json` → `<asset_dir>/dump.md` を Read
4. 本文を翻訳して `prose_html` を書く。README「prose HTML の契約」(h2 id = overview / sw / v1..vN / quest / faq / changelog / notes、バリアント内 h3 = 装備 / スキルジェム / パッシブツリー) を厳守。ゲーム用語は英語のまま
5. `assets.py` → `build.py` → README §7 の verify (HTML 整合 / 英語残り走査 / headless Chrome スクショ)。パッシブカードには `tree_svg.py` が `src/TreeData/0_5/tree.lua` から描く SVG ツリー (メイン + 武器セット 1/2 + アセンダンシー別 SVG、pan・zoom・hover tooltip) が入るので、スクショでツリー領域も見る (弧が group に沿う / 割当線が開始点から途切れない / アセンダンシーが出る)
6. `open -a Safari <abs path>` で開く。osascript でのキー送信は禁止
7. checkpoint md + `brain_save(type: session)`

## 判断軸

- 機械化できる部分 (データ由来のアイテム / ジェム / パッシブ / クエスト報酬) はスクリプトに任せ、本文だけ訳す。データの表を本文に手書きしない
- 翻訳が落ちた行 (英語のまま残る mod / 効果) は `ja_locale.py` の `MANUAL` に追記して再ビルド。ページ固有の置換は `pages/<slug>.json` 側
- 成果物は commit しない (ユーザーが求めたときだけ)。Artifact 化もしない
- 前回成果物との比較で回帰を見る: 同じ設定で再ビルドし `diff <(tr '>' '>\n' < old) <(tr '>' '>\n' < new)`
- ツリーはノード一覧で代替しない (2026-09-10 ユーザー指摘)。描画データは tree.lua に揃っており、接続の弧は PoB `PassiveTree.lua` の 3 分岐を `tree_svg.py` に移植済み。見た目が本家と違うのは仕様で、notes にその旨を書く
- ツリーの既知の未対応: 武器セット側キーストーン専用のリング色なし / 未割当の属性ノードは「?」表示。該当ページで問題になったら `tree_svg.py` の CSS と build.py の `attr_of` を直す
