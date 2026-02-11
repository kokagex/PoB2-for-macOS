# Path of Building 2 for macOS

[Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2) が開発している PoE2 ビルドプランナーを macOS でネイティブ動作させる非公式ポートです。

本家の開発者・コントリビューターの皆さんに感謝します。このプロジェクトは本家のコードをベースに、macOS (Metal/ARM64) 向けに移植したものです。

An unofficial macOS native port of the PoE2 build planner developed by [Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2). Huge thanks to the original developers and contributors. This project is based on their codebase, ported to run natively on macOS (Metal/ARM64).

---

## インストール / Installation

Releases ページから `.zip` をダウンロードして解凍し、`PathOfBuilding.app` を Applications フォルダに入れてください。

Download the `.zip` from the Releases page, extract it, and drag `PathOfBuilding.app` into your Applications folder.

### 署名なしアプリについて / Unsigned App Notice

このアプリは Apple Developer ID による署名を行っていません。初回起動時に macOS の Gatekeeper がブロックします。以下の手順で開いてください:

This app is not signed with an Apple Developer ID. macOS Gatekeeper will block it on first launch. To open it:

1. `PathOfBuilding.app` を右クリック（またはControlキーを押しながらクリック）
2. 「開く」を選択
3. 警告ダイアログが出るので、もう一度「開く」をクリック

---

1. Right-click (or Control-click) `PathOfBuilding.app`
2. Select "Open"
3. Click "Open" again in the warning dialog

2回目以降は普通にダブルクリックで起動できます。

After the first time, it will open normally with a double-click.

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
- ジュエルソケットのサムネイルプレビューで、ツリーの描画が枠外にはみ出すことがある
- ビルド計算の一部数値が本家と一致しない場合がある
- Save/Load の XML 保存は未実装（インポートは動作します）

---

- Some oil item textures may not display (DDS compression compatibility issue)
- Jewel socket thumbnail previews may overflow outside the frame
- Some build calculation values may differ from the Windows version
- OAuth認証未実装のため、PoBサイトからの直接インポートは不可（リンク貼り付けは可能）

---

## バージョン履歴 / Version History

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
