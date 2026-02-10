# テキスト入力パイプライン実装計画 V1

**Date**: 2026-02-10
**Task**: テキスト入力フィールド修正 — 文字入力パイプライン実装

## 原因分析

**症状**: 検索ボックス・ビルド名入力等、全テキスト入力フィールドが入力不可
**根本原因**: 2箇所の欠落

1. **C++層**: `glfwSetCharCallback`未登録 → 文字入力イベントがSimpleGraphicに到達しない
2. **Lua層**: `pob2_launch.lua`の`poll_input_events()`がchar入力をポーリングしていない

**下流チェーン**: `launch:OnChar()` → `Main:OnChar()` → `ControlHost` → `EditControl:OnChar()` は全て実装済み

## 修正案

### Step 0: simplegraphicソースをgit履歴(d4580cb)から復元

26ファイル全てを`git show`で復元。

### Step 1: sg_internal.h — SGContextにchar queue追加

```c
// Input state セクション (keys[512]の後に追加)
unsigned int char_queue[64];
int char_queue_head;
int char_queue_tail;
double wheel_delta;
```

### Step 2: sg_input.cpp — glfwSetCharCallback + GetCharInput() + GetMouseWheelDelta()

- `glfw_char_callback`: リングバッファにcodepoint追加
- `glfw_scroll_callback`: wheel_delta累積
- `sg_input_init()`: 2つのコールバック登録追加
- `sg_input_shutdown()`: 2つのコールバック解除追加
- `GetCharInput()`: キューからpop、0で終端
- `GetMouseWheelDelta()`: delta取得＆消費

### Step 3: simplegraphic.h — Public API宣言追加

```c
int GetCharInput(void);
int GetMouseWheelDelta(void);
```

### Step 4: ビルド＆デプロイ

```bash
cd pob2macos/simplegraphic
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build
cp build/libSimpleGraphic.dylib ../PathOfBuilding.app/Contents/Resources/runtime/SimpleGraphic.dylib
```

### Step 5: pob2_launch.lua — FFI宣言 + 文字ポーリング

- FFI cdef: `int GetCharInput(void);` (line 71付近)
- `poll_input_events()`末尾: codepoint → UTF-8変換 → `launch:OnChar(char_str)`

## 実装手順

| Step | ファイル | 変更内容 | 依存 |
|------|---------|---------|------|
| 0 | simplegraphic/* (26 files) | git d4580cbから復元 | - |
| 1 | sg_internal.h | char_queue + wheel_delta追加 | Step 0 |
| 2 | sg_input.cpp | callbacks + API関数 | Step 1 |
| 3 | simplegraphic.h | GetCharInput + GetMouseWheelDelta宣言 | Step 2 |
| 4 | cmake + make + deploy | ビルド＆デプロイ | Step 3 |
| 5 | pob2_launch.lua | FFI宣言 + ポーリング | Step 4 |

## リスク・ロールバック

**リスク**: Low
- charコールバックはkeyコールバックと独立。既存機能への影響なし
- GetMouseWheelDeltaの再実装が必要（現dylib有・ソース無）
- ビルドエラーの可能性（依存ライブラリのパス等）

**ロールバック**: 既存dylib(バックアップ)を戻すだけ
```bash
cp backup/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/runtime/
```

## 成功基準

1. アプリ起動、Build Listの検索フィールドクリック
2. キーボードで文字入力 → **文字が表示される**
3. Backspace → **文字が消える**
4. パッシブツリーの検索フィールドでも入力可能

## 6点レビュー

1. ✅ 原因が明確か？ — glfwSetCharCallback未登録 + Luaポーリング未実装
2. ✅ 技術的に妥当か？ — GLFW標準のchar callback + リングバッファは定番パターン
3. ✅ リスクが低い/管理可能か？ — 既存コールバックと独立、ロールバック容易
4. ✅ ロールバックが容易か？ — 既存dylib復元のみ
5. ✅ 視覚確認計画があるか？ — 検索フィールドでの文字入力テスト
6. ✅ タイムラインが現実的か？ — C++修正は最小限（〜50行追加）、Lua修正も〜20行

**Score: 6/6**
