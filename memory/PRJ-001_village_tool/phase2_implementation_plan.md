# Phase 2 実装計画書
## Path of Building 2 macOS 移植プロジェクト

**作成日**: 2026-01-28
**作成者**: Mayor（村長）
**ステータス**: Phase 1 調査完了に基づく策定
**対象**: Sage の詳細分析結果の実装化

---

## Executive Summary

Phase 1 での Sage の詳細調査により、PoB2 macOS 移植の実現可能性が **HIGH（95%以上の確信）** と判定されました。

**Phase 2 の目的**: この調査結果を具体的な実装計画に変換し、Phase 3 の本格実装に向けた設計と準備を完結させること。

**期間**: 1 週間
**成果物**: 詳細設計書 3-4 個、タスク分解表、Artisan 向け実装指示書
**責任者**: Sage（知識人）+ Mayor（村長）

---

## Phase 2 の実施内容

### T2-1: SimpleGraphic代替ライブラリの設計

**目標**: Sage の推奨アーキテクチャに基づく詳細設計

#### 1.1 多層アーキテクチャの最終確定

Sage の推奨設計をもとに、以下を確定:

```
層1: Lua Application Layer (変更不要)
     ↓ SimpleGraphic API
層2: SimpleGraphic Wrapper (新規実装)
     ├─ Lua層: Image Handle, Callback System
     └─ C++層: State Management, Platform Dispatch
     ↓ Platform-specific API
層3: Platform Backend (新規実装)
     ├─ macOS Backend: Metal/OpenGL + GLFW + FreeType
     ├─ Windows Backend: 既存の D3D11/OpenGL
     └─ Linux Backend: 将来対応可能
     ↓
層4: OS Native Graphics
```

#### 1.2 SimpleGraphic API の完全実装仕様

**API 分類別実装優先順位**:

| グループ | 関数数 | 優先度 | 難度 | Phase | 予想工数 |
|---------|-------|--------|------|-------|---------|
| 描画基本（色・レイヤ・ビューポート） | 5 | P0 | 低 | 3 | 0.5日 |
| 画像描画（Draw Image/Quad） | 5 | P0 | 中 | 3 | 1.5日 |
| テキスト描画 | 4 | P0 | 高 | 3 | 2日 |
| 入力処理（キー・マウス） | 4 | P0 | 中 | 3 | 1日 |
| ファイル・パス管理 | 7 | P1 | 低 | 4 | 0.5日 |
| リソース管理（モジュール読込） | 6 | P1 | 中 | 4 | 1日 |
| クリップボード | 4 | P2 | 低 | 4 | 0.5日 |
| システム制御・デバッグ | 9 | P2 | 低 | 5 | 0.5日 |
| 圧縮・クラウド | 4 | P3 | 低 | 5 | 0.5日 |
| **合計** | **48** | - | - | - | **7日** |

**MVP（最小動作確認）対象**: P0 優先度の 18 関数

#### 1.3 C++ インターフェース設計

**SimpleGraphic Wrapper の C++ インターフェース**:

```cpp
// Header: SimpleGraphic.h
namespace SimpleGraphic {

// === Initialization ===
void RenderInit(const std::string& flags = "");
void SetWindowTitle(const std::string& title);

// === State Management ===
void SetDrawColor(float r, float g, float b, float a);
void GetDrawColor(float& r, float& g, float& b, float& a);
void SetClearColor(float r, float g, float b, float a);
void SetDrawLayer(int layer, int subLayer);
void SetViewport(int x, int y, int width, int height);

// === Image Rendering ===
struct ImageHandle { /* opaque */ };
ImageHandle* NewImageHandle();
void DrawImage(ImageHandle* img, int left, int top,
               int width, int height,
               float tcLeft, float tcTop,
               float tcRight, float tcBottom);
void DrawImageQuad(ImageHandle* img,
                   float x1, float y1, float x2, float y2,
                   float x3, float y3, float x4, float y4,
                   float s1, float t1, float s2, float t2,
                   float s3, float t3, float s4, float t4);
bool ImageHandle_Load(ImageHandle* handle,
                      const std::string& fileName);
bool ImageHandle_IsValid(ImageHandle* handle);
void ImageHandle_ImageSize(ImageHandle* handle,
                           int& width, int& height);

// === Text Rendering ===
void DrawString(int left, int top, int align, int height,
                const std::string& font,
                const std::string& text);
int DrawStringWidth(int height,
                    const std::string& font,
                    const std::string& text);
int DrawStringCursorIndex(int height,
                          const std::string& font,
                          const std::string& text,
                          int cursorX, int cursorY);
std::string StripEscapes(const std::string& text);

// === Input ===
bool IsKeyDown(const std::string& keyName);
void GetCursorPos(int& x, int& y);
void SetCursorPos(int x, int y);
void ShowCursor(bool doShow);

// === Utility ===
void GetScreenSize(int& width, int& height);
float GetScreenScale();
float GetDPIScaleOverridePercent();
void SetDPIScaleOverridePercent(float scale);
double GetTime();

// === More APIs ... ===
}
```

#### 1.4 バックエンド実装パターン

**macOS Backend の実装ガイドライン**:

```cpp
// metal_backend.mm
class MetalBackend : public GraphicsBackend {
private:
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLRenderPipelineState> pipelineState;
    MTKView* view;
    FT_Library ftLibrary;

public:
    MetalBackend();
    ~MetalBackend();

    // GraphicsBackend interface
    void RenderInit(const std::string& flags) override;
    void SetDrawColor(float r, float g, float b, float a) override;
    void DrawImage(ImageHandle* img, int x, int y,
                   int w, int h, float tcL, float tcT,
                   float tcR, float tcB) override;
    // ... more methods

private:
    void setupMetalPipeline();
    void renderFrame();
    void drawTextWithFreeType(const std::string& text, ...);
};
```

---

### T2-2: 段階的実装計画の策定

#### 2.1 MVP（最小動作確認）の仕様

**MVP の目標**:
- PoB2 が起動して、基本的な UI 描画ができること
- キーボード・マウス入力が反応すること
- テキスト・画像の基本描画が動作すること

**MVP に含まれる機能**:

| 機能 | 対象関数 | 実装方法 | 検証方法 |
|------|---------|--------|---------|
| ウィンドウ初期化 | RenderInit | GLFW + Metal | メインウィンドウが表示される |
| 画面サイズ取得 | GetScreenSize | GLFW API | 正しいサイズが返される |
| 描画色設定 | SetDrawColor | Metal state | 色が適用される |
| 矩形描画 | DrawImage（単色） | Metal triangle rendering | 矩形が表示される |
| テキスト描画 | DrawString（英数のみ） | FreeType + Metal | テキストが表示される |
| キー入力 | IsKeyDown | GLFW callbacks | キー状態が正確 |
| マウス入力 | GetCursorPos | GLFW callbacks | カーソル位置が正確 |
| フレームループ | OnFrame callback | Lua callback | フレームレート安定 |

**MVP チェックリスト**:

```lua
-- mvp_test.lua
RenderInit("DPI_AWARE")
print("✓ RenderInit called")

local w, h = GetScreenSize()
assert(w == 1920 and h == 1080, "GetScreenSize failed")
print("✓ GetScreenSize: " .. w .. "x" .. h)

SetDrawColor(1, 0, 0, 1)
print("✓ SetDrawColor succeeded")

local img = NewImageHandle()
img:Load("icon.png")
if img:IsValid() then
    DrawImage(img, 100, 100, 100, 100, 0, 0, 1, 1)
    print("✓ DrawImage succeeded")
end

DrawString(50, 50, 0, 20, "Arial", "Hello macOS MVP")
print("✓ DrawString succeeded")

if IsKeyDown("escape") then
    print("✓ IsKeyDown works")
end

local x, y = GetCursorPos()
print("✓ GetCursorPos: " .. x .. "," .. y)
```

#### 2.2 フェーズ分けされた実装ステップ

**Phase 3: MVP実装（2-3週）**

```
Week 1:
  ├─ Day 1-2: GLFW ウィンドウ管理
  │   ├─ GLFW 初期化・ウィンドウ作成
  │   ├─ イベントループ構築
  │   └─ 単体テスト作成
  │
  ├─ Day 3-4: Metal バックエンド基本
  │   ├─ Metal device/queue 初期化
  │   ├─ Render pipeline 構築
  │   └─ 単色矩形描画テスト
  │
  └─ Day 5: OpenGL fallback
      ├─ OpenGL ES 2.0 initialization
      └─ 同じ描画テスト

Week 2:
  ├─ Day 1-2: Lua-C++ バインディング
  │   ├─ LuaJIT FFI setup
  │   ├─ SimpleGraphic API wrapper
  │   └─ Image Handle 実装
  │
  ├─ Day 3-4: テキスト描画
  │   ├─ FreeType フォント読み込み
  │   ├─ グリフレンダリング
  │   └─ Metal/OpenGL で表示
  │
  └─ Day 5: 入力処理
      ├─ GLFW キーボード・マウス
      ├─ Lua callback 連携
      └─ 統合テスト

Week 3:
  ├─ Day 1-2: MVP テスト
  │   ├─ PoB2 基本起動確認
  │   ├─ UI 描画確認
  │   └─ 互換性テスト（Windows 版との比較）
  │
  └─ Day 3-5: 修正・最適化
      ├─ パフォーマンス測定
      ├─ クラッシュ修正
      └─ ドキュメント整備
```

**Phase 4: 本実装（2-3週）**

- 全 SimpleGraphic API 実装（P1-P3）
- フォント複数対応
- 複雑テキスト処理（Harfbuzz）
- クリップボード機能
- ファイルシステム機能
- 統合テスト・互換性確認

**Phase 5: 最適化・検証（1-2週）**

- パフォーマンスプロファイリング
- Metal 最適化
- Windows 版との詳細な互換性確認
- ドキュメント完成
- リリース準備

#### 2.3 各ステップの成果物と検証基準

| ステップ | 成果物 | 検証基準 |
|---------|--------|---------|
| GLFW初期化 | glfw_window.cpp | ウィンドウが表示・移動・リサイズ可能 |
| Metal基本 | metal_backend.mm | 赤い矩形が描画される |
| OpenGL互換 | opengl_backend.cpp | OpenGL版も赤い矩形が描画される |
| Lua bind | lua_bindings.cpp | Lua コードから RenderInit() 呼び出し可能 |
| テキスト描画 | freetype_renderer.cpp | "Hello" が画面に表示される |
| 入力処理 | input_handler.cpp | キー押下・マウス移動が反応 |
| MVP完成 | mvp_test.lua | PoB2 が起動してメインメニューが表示される |
| Phase 3完了 | integration_test.cpp | 全 MVP 機能が自動テストで確認される |

---

### T2-3: Artisan へのタスク割り当て準備

#### 3.1 Phase 3 の具体的なタスク分解

**T3-1: GLFW ウィンドウ管理の実装**

```yaml
Task: T3-1-A: GLFW ウィンドウ基本実装
Assignee: Artisan
Priority: P0
Duration: 2 days
Description: |
  GLFW を使用したクロスプラットフォーム ウィンドウ管理の実装

  Deliverables:
  - glfw_window.h: ウィンドウマネージャ基本クラス
  - glfw_window.cpp: GLFW API ラッパー実装
  - main_loop.cpp: イベントループ実装

  Acceptance Criteria:
  - コンパイル成功（macOS + Windows）
  - ウィンドウ表示 1920×1080
  - キーボード・マウスイベント取得可能
  - リサイズ対応

Task: T3-1-B: DPI スケーリング対応
Assignee: Artisan
Priority: P0
Duration: 1 day
Depends: T3-1-A
Description: |
  macOS の高 DPI ディスプレイ（Retina）対応

  Deliverables:
  - dpi_manager.h: DPI スケール管理
  - dpi_manager.cpp: GLFW 統合実装

  Acceptance Criteria:
  - Retina ディスプレイで 2x スケーリング
  - SetDPIScaleOverridePercent() が動作
```

**T3-2: Metal バックエンド実装**

```yaml
Task: T3-2-A: Metal デバイス初期化
Assignee: Artisan
Priority: P0
Duration: 2 days
Depends: T3-1-A
Description: |
  Metal グラフィックス API の初期化

  Deliverables:
  - metal_backend.h: Metal バックエンド基本クラス
  - metal_backend.mm: Metal device/queue/pipeline 初期化

  Acceptance Criteria:
  - Metal device 取得成功
  - Render pipeline 構築成功
  - コマンドバッファ生成可能
  - メモリ割り当て正常

Task: T3-2-B: 矩形描画パイプライン
Assignee: Artisan
Priority: P0
Duration: 2 days
Depends: T3-2-A
Description: |
  Metal による基本的な矩形描画の実装

  Deliverables:
  - metal_shaders.metal: 頂点・フラグメントシェーダ
  - mesh_renderer.mm: メッシュ生成・描画
  - color_state.mm: 描画色管理

  Acceptance Criteria:
  - SetDrawColor() で色が変わる
  - 矩形が正しい色で描画される
  - フレームレート 60fps 以上
```

**T3-3: OpenGL フォールバック実装**

```yaml
Task: T3-3-A: OpenGL ES 2.0 初期化
Assignee: Artisan
Priority: P1
Duration: 1 day
Depends: T3-2-B
Description: |
  OpenGL ES 2.0 互換バックエンド実装

  Deliverables:
  - opengl_backend.h: OpenGL バックエンド基本クラス
  - opengl_backend.cpp: OpenGL 初期化・パイプライン

  Acceptance Criteria:
  - OpenGL コンテキスト作成成功
  - 矩形描画が Metal と同様
  - コンパイラ警告なし
```

**T3-4: Lua-C++ バインディング実装**

```yaml
Task: T3-4-A: LuaJIT FFI セットアップ
Assignee: Artisan
Priority: P0
Duration: 1 day
Depends: T3-1-A, T3-2-B
Description: |
  LuaJIT FFI による C++ 関数の Lua 公開

  Deliverables:
  - lua_bindings.h: Lua FFI インターフェース定義
  - lua_bindings.cpp: FFI 登録実装
  - simplegraphic_ffi.lua: Lua 側 FFI ラッパー

  Acceptance Criteria:
  - Lua スクリプトから C++ 関数呼び出し可能
  - 戻り値が正しく返される
  - メモリリークなし

Task: T3-4-B: SimpleGraphic API Lua ラッパー
Assignee: Artisan
Priority: P0
Duration: 1 day
Depends: T3-4-A
Description: |
  SimpleGraphic API の Lua 層ラッパー実装

  Deliverables:
  - simplegraphic.lua: Lua API スタブ
  - image_handle.lua: ImageHandle メタテーブル

  Acceptance Criteria:
  - RenderInit("DPI_AWARE") 実行可能
  - GetScreenSize() が (1920, 1080) を返す
  - NewImageHandle() が有効なハンドルを返す
```

**T3-5: テキスト描画実装**

```yaml
Task: T3-5-A: FreeType 統合
Assignee: Artisan
Priority: P0
Duration: 2 days
Depends: T3-2-B
Description: |
  FreeType ライブラリによるフォントレンダリング

  Deliverables:
  - freetype_renderer.h: FreeType ラッパークラス
  - freetype_renderer.cpp: グリフレンダリング実装
  - font_cache.cpp: フォントキャッシュ

  Acceptance Criteria:
  - TrueType/OpenType フォント読み込み成功
  - グリフビットマップ生成成功
  - 複数フォント同時使用可能

Task: T3-5-B: Metal/OpenGL でのテキスト描画
Assignee: Artisan
Priority: P0
Duration: 1 day
Depends: T3-5-A, T3-2-B, T3-3-A
Description: |
  FreeType で生成したグリフを GPU で描画

  Deliverables:
  - text_renderer.mm: テキスト描画パイプライン
  - glyph_texture_atlas.cpp: グリフテクスチャアトラス

  Acceptance Criteria:
  - "Hello World" が画面に表示される
  - 複数のテキストサイズが対応
  - 描画速度 > 1000文字/フレーム
```

**T3-6: 入力処理実装**

```yaml
Task: T3-6-A: GLFW 入力ハンドリング
Assignee: Artisan
Priority: P0
Duration: 1 day
Depends: T3-1-A
Description: |
  キーボード・マウス入力の GLFW ラッピング

  Deliverables:
  - input_handler.h: 入力マネージャインターフェース
  - glfw_input.cpp: GLFW 入力ハンドラ実装

  Acceptance Criteria:
  - キー押下状態を記録・取得可能
  - マウス位置を取得可能
  - マウス位置を設定可能

Task: T3-6-B: Lua 入力関数実装
Assignee: Artisan
Priority: P0
Duration: 1 day
Depends: T3-6-A, T3-4-A
Description: |
  IsKeyDown(), GetCursorPos() 等の Lua API 実装

  Deliverables:
  - input_lua_bindings.cpp: 入力関数 FFI
  - input_wrapper.lua: Lua ラッパー

  Acceptance Criteria:
  - IsKeyDown("escape") が動作
  - GetCursorPos() で座標が返される
  - SetCursorPos() でカーソル移動可能
```

**T3-7: MVP 統合テスト**

```yaml
Task: T3-7-A: MVP テストスイート作成
Assignee: Artisan (Test Lead)
Priority: P0
Duration: 1 day
Depends: T3-1-A, T3-2-B, T3-5-B, T3-6-B
Description: |
  MVP の自動テストスイート実装

  Deliverables:
  - mvp_test.lua: Lua テストスクリプト
  - integration_test.cpp: C++ 統合テスト
  - test_runner.sh: テスト実行スクリプト

  Acceptance Criteria:
  - 全テストが合格
  - テストカバレッジ > 80%

Task: T3-7-B: PoB2 実動作確認
Assignee: Artisan + QA
Priority: P0
Duration: 1 day
Depends: T3-7-A
Description: |
  実際の PoB2 を起動してのテスト

  Deliverables:
  - compatibility_report.md: テスト報告書
  - benchmark_result.json: パフォーマンス結果

  Acceptance Criteria:
  - PoB2 が起動する
  - メインメニューが表示される
  - キャラクター作成画面が表示される
  - FPS が 60fps 以上
  - Windows 版と比較してパフォーマンス差異なし
```

#### 3.2 実装順序と依存関係

**タスク依存グラフ**:

```
T3-1-A (GLFW window)
    ↓ (depends)
T3-1-B (DPI scaling)
    ↓ (depends)
T3-2-A (Metal init)
    ↓ (depends)
T3-2-B (Rectangle rendering)
    ├─ T3-3-A (OpenGL fallback) 並列実行可
    ├─ T3-4-A (Lua FFI) 並列実行可
    │   └─ T3-4-B (SimpleGraphic wrapper)
    │       └─ T3-5-A (FreeType) 可開始
    │           └─ T3-5-B (Text rendering)
    │               └─ T3-6-A (Input handling)
    │                   └─ T3-6-B (Input Lua binding)
    │                       └─ T3-7-A (MVP test)
    │                           └─ T3-7-B (PoB2 integration)
```

**クリティカルパス** (最短実装期間):
- T3-1-A (2日) → T3-1-B (1日) → T3-2-A (2日) → T3-2-B (2日) → T3-4-A (1日) → T3-4-B (1日) → T3-5-A (2日) → T3-5-B (1日) → T3-6-A (1日) → T3-6-B (1日) → T3-7-A (1日) → T3-7-B (1日)
- **合計**: 16 営業日 (約 3.2 週)

---

## ビルドシステム・開発環境

### CMake 構成案

```cmake
# Root CMakeLists.txt

cmake_minimum_required(VERSION 3.16)
project(PathOfBuilding2-macOS)

# === Platform Detection ===
if(APPLE)
    set(GRAPHICS_BACKEND "metal" CACHE STRING "Graphics backend")
    set(TARGET_ARCH "arm64;x86_64")
elseif(WIN32)
    set(GRAPHICS_BACKEND "d3d11" CACHE STRING "Graphics backend")
else()
    set(GRAPHICS_BACKEND "opengl" CACHE STRING "Graphics backend")
endif()

# === Dependencies ===
find_package(Lua51 REQUIRED)
find_package(GLFW3 REQUIRED)
find_package(Freetype REQUIRED)
find_package(ZLIB REQUIRED)

if(APPLE)
    find_library(METAL_LIB Metal REQUIRED)
    find_library(METALKIT_LIB MetalKit REQUIRED)
    find_library(COCOA_LIB Cocoa REQUIRED)
endif()

# === Subdirectories ===
add_subdirectory(src/wrapper)      # SimpleGraphic Wrapper
add_subdirectory(src/backend)      # Platform backends
add_subdirectory(src/core)         # Shared code
add_subdirectory(tests)            # Test suite

# === Output ===
add_executable(PathOfBuilding2 ${POB_SOURCES})
```

### 開発環境セットアップ

**macOS**:
```bash
# 依存ライブラリインストール
brew install lua glfw3 freetype zlib

# ビルド
mkdir build && cd build
cmake -G Xcode -DCMAKE_BUILD_TYPE=Debug ..
cmake --build . --config Debug

# テスト実行
ctest
```

**Windows**:
```cmd
# Visual Studio 17 でビルド
mkdir build
cd build
cmake -G "Visual Studio 17 2022" ..
cmake --build . --config Debug

# テスト実行
ctest --build-config Debug
```

---

## リスク管理と対策

| リスク | 確率 | 影響 | 対策 |
|--------|------|------|------|
| Metal API 学習曲線 | 中 | 中 | Apple 公式ドキュメント・チュートリアル、段階的実装 |
| テキストレンダリング複雑性 | 中 | 中 | FreeType + Harfbuzz 採用、事前プロトタイプ |
| パフォーマンス低下 | 低 | 高 | Metal ネイティブ実装、Instruments でプロファイリング |
| クロスプラットフォーム互換性 | 低 | 高 | CI/CD で Windows 版との自動テスト |
| スケジュール遅延 | 中 | 高 | タスクの早期完了・バッファ確保、定期的なレビュー |

---

## 成功指標

### Phase 2 完了時の達成目標

1. **詳細設計書完成**
   - Sage による C++ インターフェース仕様書
   - アーキテクチャ設計書（更新版）
   - ビルドシステム設計書

2. **Artisan チーム準備完了**
   - 詳細なタスク分解表作成
   - 実装ロードマップ確定
   - 開発環境セットアップガイド

3. **Phase 3 実装準備完了**
   - GitHub リポジトリ・ブランチ作成
   - CMake 構成・ビルドシステム配置
   - CI/CD パイプライン構築

### Phase 3 開始時の チェックリスト

- [ ] Sage による詳細設計書が完成
- [ ] Artisan がタスク分解表を確認・同意
- [ ] CMake・ビルドシステムが動作確認
- [ ] GitHub Actions CI/CD が動作
- [ ] 開発環境が全メンバーで整備完了
- [ ] Mayor が Phase 3 実施を承認

---

## 参考資料

### 重要ドキュメント

| ドキュメント | パス | 用途 |
|------------|------|------|
| Sage 詳細分析 | memory/sage_pob2macos_analysis_20260128.md | 技術背景・詳細 |
| API リファレンス | memory/analysis/simplegraphic_api_reference.md | 実装仕様 |
| アーキテクチャ設計 | memory/analysis/architecture_recommendation.md | 設計方針 |

### 外部リソース

- [GLFW Documentation](https://www.glfw.org/documentation.html)
- [Apple Metal Programming Guide](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/)
- [FreeType Documentation](https://freetype.org/freetype2/docs/reference/)
- [LuaJIT FFI Tutorial](https://luajit.org/ext_ffi.html)

---

## 次のステップ（Phase 3 に向けて）

### 直近のマイルストーン

1. **Week 1-2 (Phase 2)**
   - Sage による詳細設計書作成
   - Artisan チームとの設計レビュー
   - リポジトリ・ビルドシステム整備

2. **Week 3-4 (Phase 3 開始)**
   - GLFW ウィンドウ管理実装開始
   - Metal バックエンド開発開始
   - 自動テスト基盤構築

3. **Week 5-7 (Phase 3 中盤)**
   - Lua バインディング・テキスト描画実装
   - MVP テストスイート開発

4. **Week 8-9 (Phase 3 完了)**
   - PoB2 実動作確認
   - MVP テスト合格

---

**Phase 2 計画書作成完了**

**作成者**: Mayor（村長）
**承認者**: （Sage の確認待ち）
**ステータス**: 実装準備完了、Phase 3 開始承認待ち

---

**End of Phase 2 Implementation Plan**
