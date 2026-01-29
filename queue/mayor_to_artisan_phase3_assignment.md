# Artisan へのフェーズ 3 タスク割り当て通知
## Path of Building 2 macOS 移植プロジェクト

**送信者**: Mayor（村長）
**受信者**: Artisan（職人）
**日時**: 2026-01-28 23:59:00Z
**優先度**: P0（最優先）
**状態**: 即時実行待ち

---

## 概要

Sage による Phase 1 詳細調査、Mayor による Phase 2 実装計画が完了しました。

**本日より、あなた（Artisan）は Phase 3 の MVP（最小動作確認）実装を担当してください。**

---

## 割り当てられたタスク

### 📋 タスク詳細書

**ファイル**: `/Users/kokage/national-operations/claudecode01/queue/tasks/artisan_pob2macos_phase3.yaml`

**タスク数**: 14個

**期間**: 2026-01-29 ~ 2026-02-16（16-18営業日）

### 🎯 成功基準

Phase 3 が成功したと判定する条件:

1. **14個のタスク全て完了**
2. **MVP テストスイート全合格**
3. **PoB2 が macOS で起動して動作**
4. **キー・マウス入力が反応**
5. **UI テキスト・画像が正しく描画される**
6. **FPS が 60fps 以上を維持**
7. **Windows 版との互換性確認完了**

---

## Phase 3 の構成

### Week 1: ウィンドウ管理 + グラフィックス基本（4タスク）

```
T3-1-A: GLFW ウィンドウ基本実装 (2日)
  ├─ ウィンドウ作成・管理
  ├─ イベントループ
  └─ リサイズ対応
  ↓
T3-1-B: DPI スケーリング対応 (1日)
  ├─ Retina 対応
  └─ SetDPIScaleOverridePercent()
  ↓
T3-2-A: Metal デバイス初期化 (2日)
  ├─ MTLDevice 取得
  ├─ MTLCommandQueue 作成
  └─ RenderPipeline 構築
  ↓
T3-2-B: Metal 矩形描画パイプライン (2日)
  ├─ 頂点・フラグメントシェーダ
  └─ SetDrawColor() 実装

並列可能:
T3-3-A: OpenGL ES 2.0 フォールバック (1日) ← T3-2-B の後
T3-4-A: LuaJIT FFI セットアップ (1日) ← T3-2-B の後
```

### Week 2: Lua バインディング + テキスト描画（5タスク）

```
T3-4-B: SimpleGraphic Lua API ラッパー (1日)
  ├─ RenderInit(), GetScreenSize()
  ├─ SetDrawColor(), NewImageHandle()
  └─ HeadlessWrapper.lua との互換性
  ↓
T3-5-A: FreeType フォントレンダリング (2日)
  ├─ TrueType/OpenType サポート
  ├─ グリフビットマップ生成
  └─ フォントキャッシュ
  ↓
T3-5-B: Metal/OpenGL テキスト描画 (1日)
  ├─ "Hello World" が表示される
  ├─ 複数テキストサイズ対応
  └─ パフォーマンス: 1000文字/フレーム

並列可能:
T3-6-A: GLFW 入力ハンドリング (1日)
T3-6-B: Lua 入力関数実装 (1日)
T3-6-C: DrawImage 基本実装 (1日)
```

### Week 3: テスト・検証（5タスク）

```
T3-7-A: MVP テストスイート作成 (1日)
  ├─ Lua テストスクリプト
  ├─ C++ 統合テスト
  └─ テストカバレッジ >= 80%
  ↓
T3-7-B: PoB2 実動作確認 (1日)
  ├─ アプリケーション起動
  ├─ メインメニュー表示確認
  ├─ UI レスポンス確認
  ├─ パフォーマンス測定
  └─ Windows 版との互換性確認
  ↓
T3-8-A: コード整理・ドキュメント作成 (1日)
  ├─ README.md
  ├─ BUILDING.md
  ├─ CODE_STYLE.md
  └─ コード整形 (fmt/clang-tidy)
```

---

## 重要なドキュメント

すべて `/Users/kokage/national-operations/claudecode01/memory/` に保管:

| ドキュメント | ファイル | 説明 |
|------------|---------|------|
| Phase 2 計画書 | `phase2_implementation_plan.md` | 詳細な実装設計 |
| API リファレンス | `analysis/simplegraphic_api_reference.md` | 48個の API 仕様 |
| アーキテクチャ設計 | `analysis/architecture_recommendation.md` | 多層設計・CMake 構成 |
| Sage 詳細分析 | `sage_pob2macos_analysis_20260128.md` | 技術背景・参考資料 |
| Sage 最終報告 | `SAGE_FINAL_REPORT_TO_MAYOR.md` | 実現可能性：HIGH |

---

## 開発環境セットアップ

### macOS でのセットアップ

```bash
# 1. 依存ライブラリインストール
brew install lua glfw3 freetype zlib cmake

# 2. リポジトリの準備（初回のみ）
cd /Users/kokage/national-operations/claudecode01
mkdir -p src/wrapper src/backend src/core
mkdir -p tests build

# 3. CMake ビルド
cd build
cmake -G Xcode -DCMAKE_BUILD_TYPE=Debug ..
cmake --build . --config Debug

# 4. テスト実行
ctest
```

### Windows でのセットアップ

```cmd
# Visual Studio 17 でビルド
mkdir build
cd build
cmake -G "Visual Studio 17 2022" ..
cmake --build . --config Debug
ctest --build-config Debug
```

---

## 実装フロー（重要）

### 1. 設計確認フェーズ（T3-1-A 開始前）

Sage の設計書を熟読してください:

- [ ] `phase2_implementation_plan.md` 読了（特に T2-2 と T2-3）
- [ ] `architecture_recommendation.md` 読了（CMake 構成・ファイル構成）
- [ ] `simplegraphic_api_reference.md` で 48 個の API を把握
- [ ] リポジトリの初期セットアップ完了

### 2. 実装フェーズ（T3-1-A ~ T3-7-A）

**重要**: 以下の順序を厳密に守ってください

1. **T3-1-A** を完了してから **T3-1-B** を開始
2. **T3-1-B** を完了してから **T3-2-A** を開始
3. **T3-2-A** を完了してから **T3-2-B** を開始
4. 以降、タスク依存グラフに従う

**並列実装可能な箇所**:
- T3-2-B 完了後、T3-3-A/T3-4-A/T3-6-C は並列実装可
- 効率化のため、チーム分割時は並列化推奨

### 3. テスト・検証フェーズ（T3-7-A, T3-7-B）

- [ ] MVP テストスイート開発（T3-7-A）
- [ ] PoB2 実動作確認（T3-7-B）
- [ ] Windows 版との互換性確認書作成

### 4. 最終化フェーズ（T3-8-A）

- [ ] コード整形・整理
- [ ] ドキュメント完成
- [ ] 村長への進捗報告

---

## タスク詳細への移動

詳細なタスク情報（Acceptance Criteria、Implementation Details等）は、以下の YAML ファイルで確認してください:

```
/Users/kokage/national-operations/claudecode01/queue/tasks/artisan_pob2macos_phase3.yaml
```

**各タスク内に以下が記載されています**:
- 詳細な実装説明
- ファイル一覧
- 受け入れ基準（Acceptance Criteria）
- 依存関係
- テスト方法

---

## ステータス更新・報告方法

### 日次報告

毎日の進捗を以下にまとめてください:

```markdown
## 日次報告 - 2026-01-29

### 完了タスク
- T3-1-A: GLFW ウィンドウ基本実装 ... 60% 完了

### 進行中
- src/backend/glfw_window.cpp 実装中
- GLFW コールバック登録中

### ブロッカー
- なし

### 予定
- 明日: T3-1-A 完成、テスト合格を目指す
```

### ドキュメント

進捗報告書を保存:

```
/Users/kokage/national-operations/claudecode01/memory/
  ├── artisan_phase3_progress_20260129.md
  ├── artisan_phase3_progress_20260130.md
  └── ... (毎日)
```

### 最終報告

Phase 3 完了時:

```
/Users/kokage/national-operations/claudecode01/memory/
  └── artisan_phase3_completion_report.md
```

**内容**:
- 全 14 タスクの完了確認
- MVP テスト結果（全合格）
- PoB2 実動作動画・スクリーンショット
- パフォーマンス測定結果
- Windows 版との互換性確認書

---

## FAQ

### Q: 依存関係が複雑で、すべての並列化ができない場合は？

**A**: クリティカルパスに従ってください（16営業日）。以下のように部分的な並列化が可能:

```
人員が複数いる場合:
- チーム A: T3-1-A/B, T3-2-A/B（Metal）
- チーム B: T3-3-A（OpenGL）+ T3-4-A/B（Lua）
  → T3-2-B 完了後に並列開始

チーム C: T3-5-A/B（テキスト）
  → T3-2-B 完了後に並列開始
```

### Q: Metal API がわからない場合は？

**A**: 以下の資料を参照:

1. **Apple 公式ガイド**: [Metal Programming Guide](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/)
2. **Sage の設計書**: `architecture_recommendation.md` の "Metal Graphics Abstraction" セクション
3. **参考実装**: LÖVE フレームワークの Metal バックエンド (GitHub より)

段階的に学習しながら実装してください。

### Q: CMake がわからない場合は？

**A**: `architecture_recommendation.md` の "CMake-based Build" セクションに詳細な構成が書かれています。

必要なら Sage に質問してください。

### Q: テストがどう書くのかわからない場合は？

**A**: T3-7-A のタスク詳細に example code があります。

また、Google Test (C++) と Lua のシンプルなテストランナーの例も記載されています。

---

## 連絡先・質問

疑問や技術的な問題が出たら:

1. **Sage（知識人）に相談**: 技術的な設計・アーキテクチャの質問
2. **Mayor（村長）に報告**: 進捗・スケジュール・意思決定が必要な内容

---

## 期待値

村長である私からの期待:

1. **品質**: コード品質を妥協しない（レビュー・テスト重視）
2. **スケジュール**: 16-18 営業日の期限を守る
3. **コミュニケーション**: 日々の進捗報告・問題の早期報告
4. **安定性**: PoB2 が安定して動作することを最優先

---

## 最後に

**あなたが Phase 3 を完了すれば、Path of Building 2 の macOS 移植はほぼ確実です。**

Sage の詳細調査と Mayor（僕）の計画に基づいて、確実な実装を進めてください。

**頑張って！**

---

## 文書情報

**作成者**: Mayor（村長）
**作成日時**: 2026-01-28 23:59:00Z
**ステータス**: Artisan への割り当て通知（即時実行）
**プロジェクト**: PRJ-003 PoB2macOS
**フェーズ**: Phase 3 MVP Implementation

---

**End of Assignment Letter**
