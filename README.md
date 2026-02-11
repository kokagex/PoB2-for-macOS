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

## バグ報告 / Bug Reports

動作がおかしい箇所やクラッシュを見つけたら、[Issues](https://github.com/kokagex/PoB2-for-macOS/issues) に報告してもらえると助かります。スクリーンショットや再現手順があるとより対応しやすいです。

If you find any bugs or crashes, please report them on [Issues](https://github.com/kokagex/PoB2-for-macOS/issues). Screenshots and steps to reproduce are very helpful.

---

## PoE2 0.5 アップデートについて / About the PoE2 0.5 Update

本家 PoB2 が 0.5 対応アップデートを出した際に、このmacOS版が追従できるかは現時点では未定です。データ構造やツリーの変更次第では対応に時間がかかる可能性があります。

Whether this macOS port can keep up with the PoE2 0.5 update from the upstream PoB2 is currently uncertain. Depending on changes to data structures and the passive tree, it may take some time to catch up.

---

## License

This project is based on [Path of Building Community](https://github.com/PathOfBuildingCommunity/PathOfBuilding-PoE2) and follows its licensing terms.
