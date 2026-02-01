# PRJ-003 pob2macos - External Resources

**プロジェクト**: PRJ-003 pob2macos
**作成日**: 2026-02-01
**責任者**: Merchant（外部リソースリサーチ）
**目的**: 有用な外部リソース（公式ドキュメント、技術記事、ツール、ライブラリ）を体系的に管理

このファイルは、Merchantエージェントが外部リサーチで発見した有用なリソースを記録し、プロジェクト全体で再利用できるようにするためのものです。

---

## 📚 使用方法

### Merchantの責任

- 外部リサーチ完了時に即座に更新
- Skill Validation Protocol（市場調査17秒+、文書分析255KB+）を満たすリソースのみ記録
- 重複を排除し、最新情報を優先

### 記録フォーマット

```markdown
### リソース名

**URL**: https://...
**タイプ**: 公式ドキュメント / 技術記事 / ツール / ライブラリ / 動画
**言語**: 英語 / 日本語 / その他
**発見日**: 2026-XX-XX
**重要度**: CRITICAL / HIGH / MEDIUM / LOW
**鮮度**: 2026年版 / 2025年版 / それ以前

**概要**: 何についてのリソースか
**有用性**: なぜこのプロジェクトに有用か
**適用**: どの場面で参照すべきか
```

---

## 🍎 Metal API

### Metal Shading Language Specification

**URL**: https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-12-01
**重要度**: CRITICAL
**鮮度**: 2024年版（Metal 3.1）

**概要**: Metal Shading Languageの完全仕様書。texture2d_array、sampler、シェーダー関数の詳細。

**有用性**:
- texture2d_array の正しい使用方法を理解
- シェーダーコンパイルエラーのデバッグ
- パフォーマンス最適化の指針

**適用**: Metal シェーダー実装時に必ず参照。

---

### Metal Best Practices Guide

**URL**: https://developer.apple.com/documentation/metal/metal_best_practices
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-12-05
**重要度**: HIGH
**鮮度**: 2025年版

**概要**: Metal APIの効率的な使用方法、パフォーマンス最適化、ベストプラクティス。

**有用性**:
- レンダリングパイプラインの最適化
- GPU使用率の改善
- バッチング戦略

**適用**: Metal バックエンド実装・最適化時。

---

### Metal Programming Guide

**URL**: https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-12-01
**重要度**: HIGH
**鮮度**: 2023年版（やや古い）

**概要**: Metalの基本概念、レンダリングパイプライン、コマンドエンコーディング。

**有用性**: Metal初学者向けの概念理解に有用。

**適用**: 新しいMetal機能実装前の概念確認。

---

## 🌙 Lua / LuaJIT

### LuaJIT 5.1 Reference Manual

**URL**: https://www.lua.org/manual/5.1/
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-11-20
**重要度**: CRITICAL
**鮮度**: 2006年版（LuaJIT 5.1準拠）

**概要**: Lua 5.1の公式マニュアル。このプロジェクトはLuaJIT 5.1を使用しているため、このバージョンが正式参照。

**有用性**:
- API互換性の確認（`table.move()`はLua 5.4なので使用不可）
- 標準ライブラリの正しい使用方法
- 言語仕様の理解

**適用**: Luaコード実装時に必ず参照。Lua 5.4マニュアルではない。

---

### LuaJIT FFI Tutorial

**URL**: https://luajit.org/ext_ffi_tutorial.html
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-11-25
**重要度**: HIGH
**鮮度**: 2023年版

**概要**: LuaJIT FFI（Foreign Function Interface）の使用方法、C関数の呼び出し、cdata操作。

**有用性**:
- SimpleGraphic C関数のLuaからの呼び出し
- FFI cdataのパフォーマンス最適化
- メモリ管理の理解

**適用**: pob2_launch.lua のFFI宣言、パフォーマンス最適化時。

---

### Programming in Lua (4th edition)

**URL**: https://www.lua.org/pil/
**タイプ**: 書籍（オンライン版）
**言語**: 英語
**発見日**: 2025-12-10
**重要度**: MEDIUM
**鮮度**: 2016年版（Lua 5.3対応だが参考になる）

**概要**: Luaプログラミングの包括的ガイド。パターン、イディオム、ベストプラクティス。

**有用性**: Lua中級者向けのプログラミングパターン学習。

**適用**: 複雑なLuaコード実装時の参考。

---

## 🖼️ グラフィックス

### FreeType 2 Documentation

**URL**: https://freetype.org/freetype2/docs/documentation.html
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-12-08
**重要度**: HIGH
**鮮度**: 2025年版

**概要**: FreeType 2テキストレンダリングライブラリの公式ドキュメント。

**有用性**:
- テキストレンダリング実装
- フォント読み込み
- グリフメトリクスの理解

**適用**: SimpleGraphic の text rendering 実装・デバッグ時。

---

### GLFW Documentation

**URL**: https://www.glfw.org/documentation.html
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-11-28
**重要度**: MEDIUM
**鮮度**: 2025年版

**概要**: GLFWウィンドウ管理ライブラリの公式ドキュメント。

**有用性**:
- ウィンドウ作成・管理
- 入力処理（キーボード、マウス）
- イベントループ

**適用**: SimpleGraphic の window 管理実装時。

---

## 🛠️ ビルド・開発ツール

### CMake Documentation

**URL**: https://cmake.org/cmake/help/latest/
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-11-22
**重要度**: MEDIUM
**鮮度**: 2026年版（最新）

**概要**: CMakeビルドシステムの公式ドキュメント。

**有用性**:
- SimpleGraphic のビルド設定
- クロスプラットフォームビルド
- 依存関係管理

**適用**: CMakeLists.txt 修正時、ビルド問題のデバッグ時。

---

### Busted - Lua Testing Framework

**URL**: https://lunarmodules.github.io/busted/
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-12-02
**重要度**: MEDIUM
**鮮度**: 2024年版

**概要**: Lua用のBDD（Behavior-Driven Development）テストフレームワーク。

**有用性**:
- Luaユニットテストの作成
- spec/ ディレクトリのテスト実装
- テストカバレッジの向上

**適用**: Luaコードのユニットテスト実装時。

---

## 🎮 Path of Exile 2

### Path of Exile 2 Official Wiki

**URL**: https://www.poewiki.net/wiki/Path_of_Exile_2
**タイプ**: コミュニティWiki
**言語**: 英語
**発見日**: 2025-11-20
**重要度**: HIGH
**鮮度**: 2026年版（継続更新中）

**概要**: Path of Exile 2のゲームデータ、スキル、アイテム、パッシブツリー情報。

**有用性**:
- ゲームデータの検証
- パッシブツリー構造の理解
- スキル・アイテム情報の参照

**適用**: Data.lua、PassiveTree.luaの実装・検証時。

---

### Path of Building Community Fork (Original)

**URL**: https://github.com/PathOfBuildingCommunity/PathOfBuilding
**タイプ**: GitHubリポジトリ
**言語**: Lua、英語
**発見日**: 2025-11-15
**重要度**: CRITICAL
**鮮度**: 2025年版（PoE1用、継続開発中）

**概要**: Path of Building の元となるオープンソースプロジェクト。

**有用性**:
- コードアーキテクチャの参考
- 計算ロジックの理解
- モジュール構造の学習

**適用**: 複雑な実装の参照、アルゴリズムの理解時。

---

## 🔧 macOS 開発

### macOS App Bundles

**URL**: https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/BundleTypes/BundleTypes.html
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-12-01
**重要度**: HIGH
**鮮度**: 2022年版（やや古いが有効）

**概要**: macOSアプリバンドルの構造、Info.plist、リソース管理。

**有用性**:
- PathOfBuilding.app の構造理解
- リソースファイルの配置
- アプリ署名・配布

**適用**: アプリバンドル構造の修正、デプロイ時。

---

### Code Signing and Notarization

**URL**: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
**タイプ**: 公式ドキュメント
**言語**: 英語
**発見日**: 2025-12-15
**重要度**: MEDIUM
**鮮度**: 2025年版

**概要**: macOSアプリのコード署名と公証プロセス。

**有用性**:
- "permission denied" 問題の理解
- アプリ配布時のセキュリティ要件
- Gatekeeper の理解

**適用**: アプリ配布準備時、セキュリティ問題のデバッグ時。

---

## 📊 リソース統計

**総リソース数**: 15件
- 公式ドキュメント: 13件
- コミュニティWiki: 1件
- GitHubリポジトリ: 1件

**重要度別**:
- CRITICAL: 4件
- HIGH: 8件
- MEDIUM: 3件

**言語別**:
- 英語: 15件
- 日本語: 0件

**カテゴリ別**:
- Metal API: 3件
- Lua/LuaJIT: 3件
- グラフィックス: 2件
- ビルド・開発ツール: 2件
- Path of Exile 2: 2件
- macOS開発: 2件

---

## 🔮 今後のリソース追加予定

### 優先度HIGH

- [ ] Metal Performance Best Practices (WWDC 2025)
- [ ] LuaJIT Performance Tips（公式）
- [ ] Path of Building 2 公式ドキュメント（リリース後）

### 優先度MEDIUM

- [ ] Objective-C++ 混在プロジェクトのベストプラクティス
- [ ] macOS Sandboxing ガイド
- [ ] FreeType アンチエイリアシング最適化

---

**最終更新**: 2026-02-01
**次回更新**: Merchant外部リサーチ実施時、即座に
**管理者**: Merchant
