# Path of Building 2 for macOS

[Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2) が開発している PoE2 ビルドプランナーを macOS でネイティブ動作させる非公式ポートです。

本家の開発者・コントリビューターの皆さんに感謝します。このプロジェクトは本家のコードをベースに、macOS (Metal/ARM64) 向けに移植したものです。

An unofficial macOS native port of the PoE2 build planner developed by [Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2). Huge thanks to the original developers and contributors. This project is based on their codebase, ported to run natively on macOS (Metal/ARM64).

---

## インストール / Installation

1. Releases ページから `.zip` をダウンロードして解凍
2. `PathOfBuilding.app` を好きな場所に配置（Applications フォルダ推奨）
3. ターミナルを開き、`PathOfBuilding.app` を置いたフォルダに移動してから以下を実行：

```bash
cd /Applications  # アプリを置いた場所に合わせて変更
xattr -cr PathOfBuilding.app
```

4. `PathOfBuilding.app` をダブルクリックで起動

---

1. Download the `.zip` from the Releases page and extract it
2. Place `PathOfBuilding.app` wherever you like (Applications folder recommended)
3. Open Terminal, navigate to the folder containing `PathOfBuilding.app`, and run:

```bash
cd /Applications  # Change to wherever you placed the app
xattr -cr PathOfBuilding.app
```

4. Double-click `PathOfBuilding.app` to launch

---

## 注意事項 / Notes

現在 GGG に OAuth 認証の ID 取得を申請中のため、ご自身のキャラクター選択機能は未実装です。poe.ninja など外部サービスで PoB リンクがあれば、そちらからのインポートは可能です。

Character import from your own account is not yet available, as we are currently in the process of obtaining an OAuth client ID from GGG. In the meantime, you can import builds via PoB links from external services such as poe.ninja.

---

## バグ報告 / Bug Reports

動作がおかしい箇所やクラッシュを見つけたら、[Issues](https://github.com/kokagex/PoB2-for-macOS/issues) に報告してもらえると助かります。スクリーンショットや再現手順があるとより対応しやすいです。

If you find any bugs or crashes, please report them on [Issues](https://github.com/kokagex/PoB2-for-macOS/issues). Screenshots and steps to reproduce are very helpful.

---

## PoE2 0.5 アップデートについて / About the PoE2 0.5 Update

本家 PoB2 が 0.5 対応アップデートを出した際に、このmacOS版が追従できるかは現時点では未定です。データ構造やツリーの変更次第では対応に時間がかかる可能性があります。

Whether this macOS port can keep up with the PoE2 0.5 update from the upstream PoB2 is currently uncertain. Depending on changes to data structures and the passive tree, it may take some time to catch up.

---

## 既知の不具合 / Known Issues

- 一部のオイルアイテムのテクスチャが表示されない（DDS圧縮の互換性問題）
- ビルド計算の一部数値が本家と一致しない場合がある
- OAuth認証未実装のため、PoBサイトからの直接インポートは不可（リンク貼り付けは可能）
- 日本語翻訳はまだ一部未対応の箇所があります

---

- Some oil item textures may not display (DDS compression compatibility issue)
- Some build calculation values may differ from the Windows version
- OAuth authentication is not yet implemented; direct import from the PoB site is unavailable (link paste still works)
- Japanese translation is still incomplete in some areas

---

## バージョン履歴 / Version History

### v0.7.0 (2026-02-21)

- パッシブツリー翻訳をi18nシステムに統合（TreeTranslations/ja.lua廃止→i18n補助ファイル一本化）
- 1911件のノード名翻訳 + 1077件の新規stat行テンプレートを追加
- 複数行stat結合ロジック・ノード名末尾空白トリム・翻訳テンプレート品質修正

---

- Integrated passive tree translations into i18n system (removed standalone TreeTranslations/ja.lua)
- Added 1911 node name translations + 1077 new stat line templates
- Multi-line stat combining logic, node name whitespace trimming, template quality fixes

### v0.6.0 (2026-02-21)

- スキルジェムツールチップの日本語翻訳を大幅強化（効果分岐ラベル約360件追加）
- gem_stat_descriptions全テンプレートを網羅チェックし、未翻訳145件を追加（statテンプレートカバレッジ100%達成）
- ツールチップの改行時にカラーコードが消失する問題を修正
- calcFunc未取得時にジェムツールチップ全体が消失する問題を修正
- デバッグログ出力削除によるパフォーマンス改善

---

- Significantly enhanced Japanese translations for skill gem tooltips (added ~360 effect branch labels)
- Exhaustive check of all gem_stat_descriptions templates, added 145 missing entries (100% stat template coverage)
- Fixed color code loss when tooltip text wraps to next line
- Fixed gem tooltip disappearing entirely when calcFunc is unavailable
- Performance improvement by removing debug file I/O from translateModLine

### v0.5.0 (2026-02-20)

- 上流 PathOfBuilding-PoE2 dev ブランチから計算エンジン残り11モジュールを同期
- CalcSections/Calcs/CalcTools/BuildDisplayStats/CalcBreakdown/BuildSiteTools: 上流版に置換
- Data.lua/Common.lua/ModTools.lua/StatDescriber.lua/BuildList.lua: 手動マージ（ローカルパッチ保持）
- CalcSections: Spirit、Deflection、Freeze Buildup、Charm、Mark等のPoE2新stat表示追加
- BuildSiteTools: poe2db.tw対応、pob2:プロトコルハンドラ対応
- getGemStatRequirement引数順変更に伴うSkillsTab/GemSelectControlの呼び出し側修正
- 日本語翻訳: CalcSections 72項目追加、アイテムMod行・ジェムstat・パッシブツリーのtranslateModLine対応
- StatDescriber: undefined floor修正、i18n stat description lookup復元

---

- Synced remaining 11 calc engine modules from upstream PathOfBuilding-PoE2 dev branch
- CalcSections/Calcs/CalcTools/BuildDisplayStats/CalcBreakdown/BuildSiteTools: wholesale replaced with upstream
- Data.lua/Common.lua/ModTools.lua/StatDescriber.lua/BuildList.lua: manual merge preserving local patches
- CalcSections: added PoE2 new stat displays (Spirit, Deflection, Freeze Buildup, Charm, Mark, etc.)
- BuildSiteTools: added poe2db.tw support, pob2: protocol handler support
- Fixed getGemStatRequirement argument order change in SkillsTab/GemSelectControl callers
- Japanese translations: 72 new CalcSections labels, translateModLine support for item mods, gem stats, passive tree
- StatDescriber: fixed undefined floor, restored i18n stat description lookup

### v0.4.0 (2026-02-20)

- 上流 PathOfBuilding-PoE2 dev ブランチから24データファイルを同期
- StatDescriptions 5ファイル: Mod説明文・スキルstat・ジェムstat・モンスターstat更新
- ModCache: Modパース結果キャッシュ更新
- Bases 6ファイル: 剣・斧・メイス・ダガー・フレイル・スタッフの新ベース追加
- Uniques: 新ユニーク・レースユニーク追加
- TimelessJewel: レギオンパッシブ・ノードマッピング更新
- その他: Spectres、Minions、SkillStatMap、Global、Gems、Misc、ModScalability、ModItemExclusive更新
- ModTools.lua: 混合キー型ソートcomparator追加（Blackened Heart等の起動クラッシュ修正）
- Data.lua: metatableガード移設、PoE2武器タイプ・クラス対応

---

- Synced 24 data files from upstream PathOfBuilding-PoE2 dev branch
- StatDescriptions (5 files): updated mod descriptions, skill stats, gem stats, monster stats
- ModCache: updated mod parse result cache
- Bases (6 files): added new sword, axe, mace, dagger, flail, staff bases
- Uniques: added new uniques and race uniques
- TimelessJewel: updated legion passives and node index mapping
- Other: updated Spectres, Minions, SkillStatMap, Global, Gems, Misc, ModScalability, ModItemExclusive
- ModTools.lua: added mixed key type sort comparator (fixes launch crash on Blackened Heart etc.)
- Data.lua: relocated metatable guards, PoE2 weapon type and class support

### v0.3.0 (2026-02-19)

- 上流 PathOfBuilding-PoE2 dev ブランチから計算エンジンを同期（161コミット分のPoE2対応改善）
- CalcOffence: Firestorm/RoA等のDPS計算、ダメージ再帰構造を更新
- CalcDefence: PoE2のヒットチャンス/アーマー計算式、Deflection対応
- CalcPerform: Spirit計算、mergeKeystones対応
- CalcSetup: PoE2 characterConstants、statSets構造対応
- CalcActiveSkill: statSet構造、baseMods対応
- ModParser: PoE2 Conquerors（Vorana等）、Mod解析改善
- ItemTools: formatValue復活、PoE2 influence対応
- CalcTriggers: Unleashable→CanRapidFire リネーム
- CalcMirages: General's Cry改善
- Data.lua: PoE2対応の定数・テーブル追加（DeflectEffect、buildupTypes、ailmentDamageTypes等）
- ソケットグループの日本語表示ラベル修正

---

- Synced calculation engine from upstream PathOfBuilding-PoE2 dev branch (161 commits of PoE2 improvements)
- CalcOffence: Firestorm/RoA DPS calculations, damage recursive structure update
- CalcDefence: PoE2 hit chance/armour formulas, Deflection support
- CalcPerform: Spirit calculation, mergeKeystones support
- CalcSetup: PoE2 characterConstants, statSets structure support
- CalcActiveSkill: statSet structure, baseMods support
- ModParser: PoE2 Conquerors (Vorana etc), mod parsing improvements
- ItemTools: formatValue restoration, PoE2 influence support
- CalcTriggers: Unleashable→CanRapidFire rename
- CalcMirages: General's Cry improvements
- Data.lua: Added PoE2 constants and tables (DeflectEffect, buildupTypes, ailmentDamageTypes, etc.)
- Fixed Japanese display labels for socket groups

### v0.2.2 (2026-02-19)

- SGPAKアーカイブからのアセット読み込みシステムを追加（ディスク上の個別ファイルの代わりにアーカイブを使用）
- アーカイブのシャットダウン時クリーンアップ（ハンドルリーク防止）
- FFI nullポインタチェックの強化
- アーカイブ読み込み失敗時の警告ログ追加（サイレント失敗の防止）
- 未使用のMemory Budget API宣言を削除
- コード署名ディレクトリの.gitignore追加

---

- Added SGPAK archive loading system for bundled assets (loads from archives instead of loose files on disk)
- Archive cleanup on shutdown (prevents handle leaks)
- Improved FFI null pointer checks for robustness
- Added warning logs on archive load failure (prevents silent failures)
- Removed unused Memory Budget API declarations
- Added _CodeSignature directory to .gitignore

### v0.2.1 (2026-02-18)

- OAuth PKCE認証の暗号強度を改善（math.random → /dev/urandom、256bit エントロピー）
- TradeQuery通貨ファイルのパストラバーサル脆弱性を修正
- 外部ビルドリストのascendancy名によるパストラバーサルを修正
- ファイルパス検証の改行文字バイパスを修正
- base64urlパディング処理の修正
- io.open nilガード追加（通貨ファイル書き込み時のクラッシュ防止）

---

- Improved OAuth PKCE cryptographic strength (math.random → /dev/urandom, 256-bit entropy)
- Fixed path traversal vulnerability in TradeQuery currency file paths
- Fixed path traversal via ascendancy names from external build lists
- Fixed newline bypass in file path validation
- Fixed base64url padding strip for double-padded output
- Added io.open nil guard to prevent crash on currency file write failure

### v0.2.0 (2026-02-17)

- 日本語ローカライゼーション対応（UI全タブ、パッシブツリー、アイテム、スキル、Mod）
- パッシブツリーノード名 589件の日本語翻訳
- ユニークアイテム名・フレーバーテキスト 374件の日本語翻訳
- ジェム説明文・Mod統計行 3,298件の日本語翻訳
- SubScriptライフサイクル安全性の向上（コールバッククラッシュ防止）
- 大規模テーブル走査のyield改善（フレームスタッター軽減）
- ImageHandle安全性の向上（ダングリングポインタ修正）
- Bustedユニットテスト基盤（71テスト）+ GitHub Actions CI
- ビジュアルリグレッションテスト基盤

---

- Japanese localization (all UI tabs, passive tree, items, skills, mods)
- 589 passive tree node name translations
- 374 unique item name and flavour text translations
- 3,298 gem description and mod stat line translations
- Improved SubScript lifecycle safety (prevents callback crashes)
- Yield improvement for large table iteration (reduces frame stutter)
- ImageHandle safety improvements (dangling pointer fix)
- Busted unit test infrastructure (71 tests) + GitHub Actions CI
- Visual regression test infrastructure

### v0.1.2 (2026-02-11)

- ConfigOptionsをPoE2上流版に差し替え（Quest Rewards追加、Bandit/Pantheon削除）
- Warningsポップアップの表示順序修正（他のウィジェットの上に表示）
- 旧セーブデータ互換性のためのnil安全性修正
- Replaced ConfigOptions with PoE2 upstream (added Quest Rewards, removed Bandit/Pantheon)
- Fixed Warnings popup z-order (now renders above other widgets)
- Added nil-safety fixes for legacy save data compatibility

### v0.1.1 (2026-02-11)

- ビルドのセーブ/ロード機能を有効化（macOSパス設定修正）
- Save/Load builds now works (fixed macOS path settings)

### v0.1.0 (2026-02-11)

初回リリース / Initial release

- macOS ネイティブ動作（Metal / ARM64）
- パッシブツリーの表示・ノード割り当て・ステータス反映
- ビルド画面の全7タブ（Tree, Skills, Items, Calcs, Config, Notes, Import/Export）
- PoB リンクからのビルドインポート
- リアルタイムステータス再計算
- ツールチップ表示（アイテム・ノード・スキル）
- PoE2 武器タイプ対応（Spear, Flail, Crossbow, Talisman）

---

- Native macOS support (Metal / ARM64)
- Passive tree display, node allocation, and stat reflection
- All 7 build tabs (Tree, Skills, Items, Calcs, Config, Notes, Import/Export)
- Build import via PoB links
- Real-time stat recalculation
- Tooltips for items, nodes, and skills
- PoE2 weapon types supported (Spear, Flail, Crossbow, Talisman)

---

## このプロジェクトについて / About This Project

このプロジェクトはコーディング知識が一切ない作者が、Claude Code や Codex などの AI ツールを使い、バイブコーディングのみで移植作業を行いました。

This project was ported entirely through vibe coding by an author with zero coding knowledge, using AI tools such as Claude Code and Codex.

---

## License

This project is based on [Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2) and follows its licensing terms.
