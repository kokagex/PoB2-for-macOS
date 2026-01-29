# macOS 移植推奨アーキテクチャ設計書
## Path of Building 2 - ネイティブ移植技術仕様

**作成日**: 2026-01-28
**作成者**: Sage（知識人）
**バージョン**: 1.0 - Final Recommendation

---

## Executive Summary

Path of Building 2 の macOS ネイティブ移植には、**多層ハイブリッドアーキテクチャ** の採用を推奨します。

このアーキテクチャにより:
- ✅ 既存 Lua コード変更ゼロ（互換性完全維持）
- ✅ Windows/macOS 統一ビルド（コード共用）
- ✅ パフォーマンス最適化（Metal ネイティブ）
- ✅ 将来の拡張性確保（Linux 対応等）

---

## 階層設計

### Tier 1: Lua Application Layer

```
┌─────────────────────────────────────┐
│  Path of Building 2                 │
│  (Main, Launch, Modules, etc)       │
│                                     │
│  ⚠️ NO CHANGES REQUIRED             │
│     (既存 Lua コード継続使用)        │
└─────────────────────────────────────┘
              │
              │ Lua API calls
              ↓
```

**特性**:
- 既存コード完全互換
- SimpleGraphic API に完全依存
- プラットフォーム抽象度：最高

### Tier 2: SimpleGraphic Compatibility Wrapper

```
┌─────────────────────────────────────┐
│  SimpleGraphic Wrapper (NEW)        │
│  Location: Lua + C++ Mixed          │
│                                     │
│  ├─ Image Handle Management        │
│  │   (Lua: metatables)             │
│  │                                 │
│  ├─ Callback System                │
│  │   (Lua: global callbackTable)   │
│  │                                 │
│  ├─ State Management               │
│  │   (C++: DrawColor, Layer, etc)  │
│  │                                 │
│  └─ Platform Dispatch Layer        │
│      (C++: backend selection)      │
└─────────────────────────────────────┘
              │
              │ C++ Function Calls
              ↓
```

**責務**:
- Lua → C++ インターフェース
- SimpleGraphic API スタブの実装
- 状態管理（描画色・レイヤ等）
- Image Handle オブジェクト管理

**実装言語**:
- Lua (Image Handle, Callback System)
- C++ (State Management, Dispatch)

### Tier 3: Platform-Specific Backend

```
┌──────────────────────────────────────────────┐
│  Platform Backend Layer                      │
│  Location: C++ Pure                          │
│                                              │
│  ┌────────────────┐  ┌────────────────────┐│
│  │ macOS Backend  │  │ Windows Backend    ││
│  │ (Recommended)  │  │ (Existing)         ││
│  │                │  │                    ││
│  │ ├─ Graphics    │  │ ├─ Graphics       ││
│  │ │  ├─ Metal    │  │ │  ├─ D3D11       ││
│  │ │  └─ OpenGL   │  │ │  └─ OpenGL      ││
│  │ │              │  │ │                  ││
│  │ ├─ Window Mgmt │  │ ├─ Window Mgmt    ││
│  │ │  (GLFW)      │  │ │  (GLFW)         ││
│  │ │              │  │ ├─ Input (SDL2)   ││
│  │ ├─ Input       │  │ │                  ││
│  │ │  ├─ GLFW     │  │ └─ System         ││
│  │ │  └─ Cocoa    │  │    (Windows API)  ││
│  │ │              │  │                    ││
│  │ ├─ Text Render │  │ ├─ Font Render    ││
│  │ │  ├─FreeType  │  │ │  (GDI/DirectX)  ││
│  │ │  └─Harfbuzz  │  │ │                  ││
│  │ │              │  │ └─ Clipboard      ││
│  │ ├─ System      │  │    (Windows API)  ││
│  │ │  ├─Cocoa     │  │                    ││
│  │ │  └─CoreText  │  │ ┌────────────────┐││
│  │ │              │  │ │ Linux Backend  │││
│  │ ├─ Clipboard   │  │ │ (Future)       │││
│  │ │  (Pasteboard)│  │ │                │││
│  │ │              │  │ │ ├─ Vulkan      │││
│  │ └─ Path Mgmt   │  │ │ ├─ OpenGL      │││
│  │    (POSIX)     │  │ │ ├─ GLFW        │││
│  │                │  │ │ └─ FreeType    │││
│  └────────────────┘  └┴────────────────┘||
│                                          │
│  Common Components:                      │
│  ├─ GLFW (Window, Input)                │
│  ├─ FreeType (Font)                     │
│  ├─ Harfbuzz (Complex Text)             │
│  ├─ stb_image (Image Loading)           │
│  └─ zlib (Compression)                  │
└──────────────────────────────────────────┘
              │
              ↓
```

**主要技術スタック** (macOS):

| 機能 | ライブラリ | バージョン | 参考 |
|------|-----------|-----------|------|
| 窓・イベント | GLFW | 3.4+ | クロスプラットフォーム |
| グラフィックス（推奨） | Metal | 2.4+ | Apple 公式、最高性能 |
| グラフィックス（互換） | OpenGL | 4.1+ | 互換性、クロスプラット |
| テキスト | FreeType | 2.13+ | TrueType/OpenType サポート |
| 複雑テキスト | Harfbuzz | 7.x | 複言語テキスト処理 |
| 画像読み込み | stb_image | 2.28 | PNG/JPG/BMP サポート |
| 圧縮 | zlib | 1.3+ | deflate/inflate |
| 入力・システム | Cocoa API | macOS 標準 | ネイティブ統合 |

### Tier 4: OS Native Graphics APIs

```
┌──────────────────────────────────┐
│  OS Native Graphics Rendering    │
│                                  │
│  macOS:                          │
│  ├─ Metal Framework              │
│  └─ OpenGL (Deprecated but OK)   │
│                                  │
│  Windows:                        │
│  ├─ Direct3D 11                  │
│  └─ OpenGL                       │
│                                  │
│  Linux (Future):                 │
│  ├─ Vulkan                       │
│  └─ OpenGL                       │
└──────────────────────────────────┘
              │
              ↓
       Hardware GPU
```

---

## 詳細設計: macOS Backend

### Graphics Abstraction

```cpp
// C++ Core: Graphics Abstraction Layer

class GraphicsBackend {
public:
    virtual void RenderInit(const std::string& flags) = 0;
    virtual void SetDrawColor(float r, float g, float b, float a) = 0;
    virtual void DrawImage(ImageHandle* img, int x, int y,
                          int w, int h, float tcL, float tcT,
                          float tcR, float tcB) = 0;
    virtual void DrawString(int x, int y, int align, int height,
                           const std::string& font,
                           const std::string& text) = 0;
    // ... other functions
};

// macOS Implementation
class MetalBackend : public GraphicsBackend {
private:
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLRenderPipelineState> pipelineState;

public:
    void RenderInit(const std::string& flags) override;
    void DrawImage(...) override;
    // ... implementation
};

// Fallback OpenGL Implementation
class OpenGLBackend : public GraphicsBackend {
    // OpenGL ES 2.0 compatible implementation
};
```

### Lua-C++ Interface

```cpp
// Lua binding layer

// Image Handle Registration
static int lua_NewImageHandle(lua_State* L) {
    ImageHandle* img = new ImageHandle();
    lua_pushlightuserdata(L, img);
    luaL_getmetatable(L, "ImageHandle");
    lua_setmetatable(L, -2);
    return 1;
}

// DrawImage Wrapper
static int lua_DrawImage(lua_State* L) {
    ImageHandle* img = (ImageHandle*)lua_touserdata(L, 1);
    int left = luaL_checkint(L, 2);
    int top = luaL_checkint(L, 3);
    // ... parameter extraction

    g_backend->DrawImage(img, left, top, ...);
    return 0;
}
```

---

## ビルドシステム構成

### CMake-based Build

```cmake
# Root CMakeLists.txt

cmake_minimum_required(VERSION 3.16)
project(PathOfBuilding2-macOS)

# Platform detection
if(APPLE)
    set(PLATFORM_NAME "macOS")
    set(TARGET_ARCH "arm64;x86_64")  # Universal Binary
    set(GRAPHICS_BACKEND "metal")
elseif(WIN32)
    set(PLATFORM_NAME "Windows")
    set(GRAPHICS_BACKEND "d3d11")
elseif(UNIX)
    set(PLATFORM_NAME "Linux")
    set(GRAPHICS_BACKEND "vulkan")
endif()

# Dependencies
find_package(Lua51 REQUIRED)
find_package(GLFW3 REQUIRED)
find_package(Freetype REQUIRED)
find_package(ZLIB REQUIRED)

# Platform-specific
if(APPLE)
    find_library(METAL_LIB Metal)
    find_library(METALKIT_LIB MetalKit)
    find_library(COCOA_LIB Cocoa)
endif()

# Source organization
add_subdirectory(src/wrapper)      # SimpleGraphic wrapper
add_subdirectory(src/backend)      # Platform backends
add_subdirectory(src/core)         # Shared components

# Output
add_executable(PathOfBuilding2 ${POB_SOURCES})

if(APPLE)
    # Create macOS app bundle
    set_target_properties(PathOfBuilding2 PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Info.plist"
    )
endif()
```

---

## ファイル構成

```
PathOfBuilding-PoE2/
├── CMakeLists.txt                  (新規: ビルドシステム)
├── src/
│   ├── HeadlessWrapper.lua          (既存: Lua layer)
│   ├── Launch.lua                   (既存: Lua layer)
│   ├── Modules/                     (既存: Lua modules)
│   │
│   ├── wrapper/                     (新規: C++ wrapper)
│   │   ├── CMakeLists.txt
│   │   ├── simplegraphic_wrapper.h
│   │   ├── simplegraphic_wrapper.cpp
│   │   ├── image_handle.h
│   │   └── lua_bindings.cpp
│   │
│   ├── backend/                     (新規: Platform backends)
│   │   ├── CMakeLists.txt
│   │   ├── graphics_backend.h
│   │   ├── metal_backend.mm         (macOS Metal)
│   │   ├── opengl_backend.cpp       (OpenGL fallback)
│   │   ├── window_manager.h
│   │   ├── glfw_window.cpp          (GLFW wrapper)
│   │   ├── input_handler.h
│   │   ├── cocoa_input.mm           (macOS native input)
│   │   ├── font_renderer.h
│   │   ├── freetype_renderer.cpp
│   │   ├── clipboard_manager.h
│   │   └── cocoa_clipboard.mm
│   │
│   └── core/                        (新規: Shared code)
│       ├── CMakeLists.txt
│       ├── types.h                  (Common types)
│       ├── logger.h                 (Logging)
│       └── platform_utils.h         (OS abstractions)
│
├── build/                           (ビルド出力)
├── dist/                            (配布物)
│   ├── macos/
│   │   └── PathOfBuilding2.app/
│   └── windows/
│       └── PathOfBuilding2.exe
│
└── tests/
    ├── lua_tests/
    └── integration_tests/
```

---

## Development Timeline

### Phase 2: 設計・計画（1週間）
- [ ] 詳細アーキテクチャ設計
- [ ] API インターフェース仕様書
- [ ] CMake ビルドシステム設計
- [ ] テスト計画策定

### Phase 3: MVP実装（2-3週間）
**目標**: 基本的な描画・入力が動作すること

- [ ] GLFW ウィンドウ初期化
- [ ] Metal/OpenGL バックエンド最小実装
- [ ] 矩形・画像描画（色付き）
- [ ] キーボード・マウス入力
- [ ] FreeType テキスト（英数字のみ）
- [ ] 単体テスト

**MVP チェックリスト**:
```lua
-- MVP で動作確認するスクリプト
RenderInit("DPI_AWARE")
GetScreenSize()  -- OK

SetDrawColor(1, 0, 0, 1)
DrawImage(img, 100, 100, 100, 100, 0, 0, 1, 1)  -- OK

DrawString(50, 50, 0, 20, "Arial", "Hello macOS")  -- OK

while not IsKeyDown("escape") do
    runCallback("OnFrame")
end
```

### Phase 4: 本格実装（2-3週間）
- [ ] 全 SimpleGraphic API 実装
- [ ] フォント複数対応（Cocoa フォント列挙）
- [ ] 複雑テキスト処理（Harfbuzz）
- [ ] Deflate/Inflate 実装
- [ ] クラウドストレージ検出
- [ ] マルチプラットフォーム統一ビルド
- [ ] 統合テスト

### Phase 5: 最適化・検証（1-2週間）
- [ ] パフォーマンスプロファイリング
- [ ] Metal 最適化
- [ ] Windows 版との互換性確認
- [ ] ドキュメント作成
- [ ] リリース準備

---

## パフォーマンス目標

| メトリック | 目標値 | 測定方法 |
|-----------|-------|---------|
| FPS | 60+ | フレームレート測定 |
| 起動時間 | < 3秒 | 冷起動・温起動 |
| メモリ使用量 | < 500MB | Activity Monitor |
| CPU 使用率 | < 30% | アイドル時 |
| テキスト描画速度 | > 1000文字/フレーム | ベンチマーク |

**Metal が OpenGL より 30-50% 高速化** という事例に基づく。

---

## 品質保証戦略

### テストレベル

```
Unit Tests (C++ backend functions)
    ↓
Integration Tests (Lua ↔ C++ boundary)
    ↓
System Tests (Full Path of Building)
    ↓
Performance Tests (Metal vs OpenGL)
    ↓
Compatibility Tests (Windows version comparison)
```

### CI/CD Pipeline

```yaml
name: Build & Test
on: [push, pull_request]

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build (Metal)
        run: cmake -B build -G Xcode && cmake --build build
      - name: Build (OpenGL fallback)
        run: cmake -B build-gl -DGRAPHICS_BACKEND=opengl && cmake --build build-gl
      - name: Run tests
        run: ctest --build build
      - name: Performance benchmark
        run: ./build/benchmark_suite

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build (D3D11)
        run: cmake -B build -G "Visual Studio 17" && cmake --build build
      - name: Run tests
        run: ctest --build build
```

---

## 将来の拡張性

このアーキテクチャは以下の拡張に対応可能:

### Linux サポート

```cpp
#elif defined(__linux__)
class VulkanBackend : public GraphicsBackend { ... };
class OpenGLBackend : public GraphicsBackend { ... };
```

### iOS/iPad OS サポート

```cpp
#elif TARGET_OS_IOS
class MetalIOSBackend : public GraphicsBackend { ... };
```

### Vulkan (Windows/Linux 高性能版)

```cpp
class VulkanBackend : public GraphicsBackend { ... };
```

---

## 推奨ツール・IDE

| ツール | 用途 | 推奨version |
|--------|------|-----------|
| Xcode | macOS 開発・ビルド | 14.3+ |
| Visual Studio | Windows 開発 | 2022+ |
| CMake | ビルドシステム | 3.25+ |
| Clang | C++コンパイラ | 15+ |
| LLDB | デバッガ (macOS) | 付属 |
| Metal Profiler | Metal 最適化 | Xcode 付属 |
| Instruments | パフォーマンス | Xcode 付属 |

---

## リスク管理

| リスク | 確率 | 影響 | 対策 |
|--------|------|------|------|
| Metal API 学習曲線 | 中 | 中 | Apple 公式ドキュメント・チュートリアル参照 |
| テキストレンダリング複雑性 | 中 | 中 | FreeType + Harfbuzz で複言語対応 |
| パフォーマンス低下 | 低 | 高 | Metal ネイティブ実装・ベンチマーク |
| クロスプラットフォーム保守負担 | 低 | 中 | CI/CD で自動テスト実施 |

---

## 成功指標

移植が成功したと判定する基準:

1. **機能完全性**: 全 SimpleGraphic API が実装される
2. **互換性**: 既存 PoB2 Lua コード変更不要
3. **パフォーマンス**: Windows 版と同等以上（金属 30%高速化）
4. **安定性**: クラッシュ・バグ < 1件/100時間使用
5. **保守性**: Windows/macOS/Linux 共通コード率 > 80%

---

**Architecture Design Complete**

**Approved by**: Sage（知識人）
**Date**: 2026-01-28
**Status**: Ready for Phase 2 Implementation Planning

