# Path of Building 2 for macOS

[Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2) が開発している PoE2 ビルドプランナーを macOS でネイティブ動作させる非公式ポートです。

本家の開発者・コントリビューターの皆さんに感謝します。このプロジェクトは本家のコードをベースに、macOS (Metal/ARM64) 向けに移植したものです。

An unofficial macOS native port of the PoE2 build planner developed by [Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2). Huge thanks to the original developers and contributors. This project is based on their codebase, ported to run natively on macOS (Metal/ARM64).

---

## インストール / Installation

Releases ページから `.zip` をダウンロードして解凍し、`PathOfBuilding.app` を Applications フォルダに入れてください。

Download the `.zip` from the Releases page, extract it, and drag `PathOfBuilding.app` into your Applications folder.

### 初回起動について / First Launch

このアプリは Ad-hoc 署名済みですが、Apple の公証（Notarization）は受けていません。初回起動時に Gatekeeper がブロックする場合があります。

This app is ad-hoc signed but not notarized by Apple. Gatekeeper may block it on first launch.

1. `PathOfBuilding.app` を右クリック（またはControlキーを押しながらクリック）→「開く」
2. 「開発元を検証できません」ダイアログで「開く」をクリック

---

1. Right-click (or Control-click) `PathOfBuilding.app` → "Open"
2. Click "Open" in the "unverified developer" dialog

> **それでも開けない場合 / If it still won't open:**
> ターミナルで `xattr -cr PathOfBuilding.app` を実行してから再度開いてください。
>
> Run `xattr -cr PathOfBuilding.app` in Terminal, then try again.

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
