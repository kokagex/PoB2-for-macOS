# mcp/worker/probes/

pob2-advisor worker (mcp/worker/) に対する単発診断・検証スクリプト置き場。
`cd src && ../runtime/lua ../mcp/worker/probes/<name>.lua` で実行する
(probe 内の `dofile("../mcp/worker/boot.lua")` は cwd=src 相対)。

一過性の探索スクリプトはここに置いて使い捨てる (キャンペーン終了後に棚卸しで削除)。
恒久 probe は以下の 9 件 (2026-07-05 棚卸し):

| probe | 用途 |
|---|---|
| roundtrip_verify | export した .code の decode→再 calc round-trip 検証 (リリース検証用 BLOCKING チェック) |
| iso_test | calc facade (loadBuild/applyPatch) の isolation テスト |
| diagnose_current | ビルド現状の baseline 診断ダンプ (最適化着手前のオリエンテーション) |
| dump_config | configTab.input (保存済み戦闘 config) のダンプ |
| dump_items | 全装備アイテムのダンプ (slot → title + rarity + mod 行) |
| dump_skill | メインスキルの gem 構成ダンプ (active + supports) |
| dump_moditem | data.itemMods のエントリスキーマ確認 (category → modName → entry) |
| enum_supports | engine 由来の support gem 候補列挙 (sample-free) |
| probe_dims | どの最適化次元が対象ビルドの DPS を動かすかの事前診断 |
