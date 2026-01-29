# PALADIN Phase 4: セキュリティレビュー報告書

**作成日**: 2026-01-29
**対象**: `/Users/kokage/national-operations/pob2macos/src/` 以下の全 C ファイル
**レビュア**: Paladin (守護者)

---

## Executive Summary

7つの C ファイル (sg_image.c, sg_draw.c, sg_core.c, sg_text.c, sg_input.c, sg_lua_binding.c, metal_stub.c) に対してセキュリティレビューを実施しました。

**総合評価**: 複数の重大度高い問題が検出されました。本番リリース前に対応が必須です。

---

## 検出された問題

### 1. CRITICAL: バッファオーバーフロー脆弱性

#### Issue 1.1: sg_text.c - 無制限の strcpy() 使用

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_text.c`
**行番号**: 59
**重大度**: CRITICAL

```c
strcpy(sg_font_cache[sg_num_cached_fonts].name, font_name);  // DANGER!
```

**問題**:
- `strcpy()` は境界チェックを行わない
- `sg_font_cache[].name` は 256 バイトの固定長バッファ
- `font_name` の長さが制限されていない
- 任意長のフォント名が渡された場合、スタックオーバーフローが発生

**推奨修正**:
```c
strncpy(sg_font_cache[sg_num_cached_fonts].name, font_name,
        sizeof(sg_font_cache[sg_num_cached_fonts].name) - 1);
sg_font_cache[sg_num_cached_fonts].name[sizeof(sg_font_cache[sg_num_cached_fonts].name) - 1] = '\0';
```

---

#### Issue 1.2: sg_image.c - ファイル名バッファの境界処理

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_image.c`
**行番号**: 123
**重大度**: CRITICAL

```c
strncpy(sg_image_pool[idx].filename, filename, sizeof(sg_image_pool[idx].filename) - 1);
```

**問題**:
- `strncpy()` は NUL 終端を保証しない
- 255 バイト正確に詰まった場合、NUL 終端が欠落する可能性
- 後続の文字列操作で Use-after-free につながる可能性

**推奨修正**:
```c
strncpy(sg_image_pool[idx].filename, filename, sizeof(sg_image_pool[idx].filename) - 1);
sg_image_pool[idx].filename[sizeof(sg_image_pool[idx].filename) - 1] = '\0';
```

---

### 2. HIGH: メモリ安全性問題

#### Issue 2.1: sg_image.c - 不適切なキャスト

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_image.c`
**行番号**: 54, 66, 83, 99, 116, 151
**重大度**: HIGH

```c
return (void*)(uintptr_t)idx;  // idx を void* にキャスト

// 後で:
int idx = (int)(uintptr_t)img_handle;  // void* を int に戻す
```

**問題**:
- `void*` ポインタを整数キャストして配列インデックスとして使用
- ハンドル検証が不十分 (0 < idx < MAX_IMAGES のみ)
- 整数オーバーフロー時に保護なし
- マルチスレッド環境での TOCTOU (Time-Of-Check-Time-Of-Use) 競合

**推奨修正**:
```c
// 構造体型のハンドルを使用:
struct ImageHandle {
    uint32_t id;  // unique ID
    uint32_t idx; // pool index
};
// または UUID/セッション情報を含める
```

---

#### Issue 2.2: メモリリーク - フォント キャッシュ実装

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_text.c`
**行番号**: 57-64
**重大度**: HIGH

```c
if (sg_num_cached_fonts < MAX_CACHED_FONTS) {
    bool loaded = sg_backend_load_font(font_name, size);
    strcpy(sg_font_cache[sg_num_cached_fonts].name, font_name);
    sg_font_cache[sg_num_cached_fonts].size = size;
    sg_font_cache[sg_num_cached_fonts].loaded = loaded;
    sg_num_cached_fonts++;
    return loaded;
}
```

**問題**:
- `sg_backend_load_font()` で確保されたリソースを追跡していない
- キャッシュフルの場合、毎回新規に `sg_backend_load_font()` を呼ぶため重複読み込み
- グローバル変数 `sg_num_cached_fonts` が減少する仕組みがない (クリーンアップなし)

**推奨修正**:
```c
struct FontEntry {
    char name[256];
    int size;
    bool loaded;
    void* backend_handle;  // backend resource tracking
};
// キャッシュのクリア関数を実装
void SimpleGraphic_FreeFontCache(void)
```

---

### 3. HIGH: 入力検証不足

#### Issue 3.1: ファイル名パス検証欠落

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_image.c`
**行番号**: 110-130
**重大度**: HIGH

```c
bool SimpleGraphic_LoadImage(void* img_handle, const char* filename) {
    if (img_handle == NULL || filename == NULL) {
        printf("[SG] Warning: LoadImage called with null parameters\n");
        return false;
    }
    // ファイルパス検証なし
    if (!sg_backend_load_image(sg_image_pool[idx].backend_data, filename)) {
        ...
    }
}
```

**問題**:
- ファイルパスの検証なし
- パストラバーサル攻撃が可能 (`../../../etc/passwd`)
- 絶対パスか相対パスかの検証なし
- 許可リスト チェックなし

**推奨修正**:
```c
// ホワイトリスト方式で許可ディレクトリを制限
bool validate_image_path(const char* path) {
    if (strchr(path, "..") != NULL) return false;
    if (path[0] == '/') return false;  // 絶対パス禁止
    // 許可サフィックス確認
    return endswith(path, ".png") || endswith(path, ".jpg") || endswith(path, ".bmp");
}
```

---

#### Issue 3.2: 画像サイズ検証欠落

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_draw.c`
**行番号**: 61-78
**重大度**: HIGH

```c
void SimpleGraphic_DrawImage(void* img_handle, int left, int top,
                             int width, int height,
                             float tc_left, float tc_top,
                             float tc_right, float tc_bottom) {
    // width/height の有効性チェックなし
    // 負値チェックなし
    // 最大値チェックなし
    sg_backend_draw_image(img_handle, left, top, width, height, ...);
}
```

**問題**:
- 負の width/height が許可される
- 極めて大きい値 (INT_MAX など) でメモリ割り当て失敗の可能性
- テクスチャ座標 (tc_left, tc_right など) が [0.0, 1.0] 外でも許可される

**推奨修正**:
```c
if (width <= 0 || height <= 0 || width > MAX_TEXTURE_WIDTH || height > MAX_TEXTURE_HEIGHT) {
    printf("[SG] Error: Invalid image dimensions: %d x %d\n", width, height);
    return;
}
```

---

### 4. HIGH: Null ポインタ参照のリスク

#### Issue 4.1: sg_draw.c - GetDrawColor 無保護

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_draw.c`
**行番号**: 51-56
**重大度**: HIGH

```c
void SimpleGraphic_GetDrawColor(float* r, float* g, float* b, float* a) {
    *r = sg_draw_color[0];  // ポインタ Null チェックなし!
    *g = sg_draw_color[1];
    *b = sg_draw_color[2];
    *a = sg_draw_color[3];
}
```

**問題**:
- 引数 `r, g, b, a` が NULL の場合、セグメンテーションフォルト
- Lua バインディングから呼ばれる可能性がある

**推奨修正**:
```c
if (r == NULL || g == NULL || b == NULL || a == NULL) {
    printf("[SG] Error: GetDrawColor called with null pointers\n");
    return;
}
```

---

#### Issue 4.2: sg_core.c - GetScreenSize の前提条件

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_core.c`
**行番号**: 62-72
**重大度**: HIGH

```c
void SimpleGraphic_GetScreenSize(int* width, int* height) {
    if (!sg_initialized) {
        printf("[SG] Warning: GetScreenSize called before RenderInit\n");
        *width = 1920;   // Null チェックなし
        *height = 1080;
        return;
    }
    *width = sg_screen_width;   // Null チェックなし
    *height = sg_screen_height;
}
```

**問題**:
- `width`, `height` が NULL ポインタの場合、無条件で デリファレンス
- WARNING ログを出しても処理を続行する

---

### 5. MEDIUM: リソース管理の問題

#### Issue 5.1: 画像ハンドル プール の終了処理欠落

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_image.c`
**重大度**: MEDIUM

**問題**:
- `SimpleGraphic_Shutdown()` で `sg_image_pool` 全体をクリーンアップしていない
- 未解放の画像リソースが残存
- `sg_backend_free_image()` が呼ばれない

**推奨修正**:
```c
void SimpleGraphic_Shutdown(void) {
    if (!sg_initialized) {
        return;
    }
    // 全画像をクリーンアップ
    for (int i = 0; i < sg_num_images; i++) {
        if (sg_image_pool[i].valid && sg_image_pool[i].backend_data != NULL) {
            sg_backend_free_image(sg_image_pool[i].backend_data);
        }
    }
    sg_num_images = 0;
    printf("[SG] Shutting down\n");
    sg_backend_shutdown();
    sg_initialized = false;
}
```

---

#### Issue 5.2: フォント キャッシュ のクリーンアップ欠落

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_text.c`
**重大度**: MEDIUM

**問題**:
- アプリケーション終了時にフォント キャッシュをクリアしない
- キャッシュサイズが32エントリに制限されている
- キャッシュがいっぱいになると、それ以降のフォントロードが毎回 backend を呼ぶ

---

### 6. MEDIUM: エラーハンドリング

#### Issue 6.1: sg_lua_binding.c - 戻り値エラー処理

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_lua_binding.c`
**行番号**: 42-49
**重大度**: MEDIUM

```c
static int lua_SetClearColor(lua_State* L) {
    float r = (float)luaL_checknumber(L, 1);
    float g = (float)luaL_checknumber(L, 2);
    float b = (float)luaL_checknumber(L, 3);
    float a = (float)luaL_optnumber(L, 4, 1.0);
    // Placeholder - actual implementation deferred to C wrapper
    return 0;  // 実装されていない!
}
```

**問題**:
- コメント "actual implementation deferred" → 未実装
- `SimpleGraphic_SetClearColor()` を呼ばない

---

#### Issue 6.2: backend 戻り値の未検査

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_lua_binding.c`
**行番号**: 24, 38, 60, 77, 85, 124
**重大度**: MEDIUM

```c
static int lua_RenderInit(lua_State* L) {
    const char* flags = luaL_optstring(L, 1, "");
    SimpleGraphic_RenderInit(flags);  // 戻り値無視
    return 0;
}
```

**問題**:
- `RenderInit()` の失敗を検知していない
- Lua 側で初期化失敗を認識できない
- エラーハンドリングが存在しない

---

### 7. MEDIUM: 型安全性

#### Issue 7.1: metal_stub.c - strlen() 危険な使用

**ファイル**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/backend/metal_stub.c`
**行番号**: 123, 154
**重大度**: MEDIUM

```c
int sg_backend_draw_string_width(int height,
                                const char* font_name,
                                const char* text) {
    printf("[Metal Stub] Getting string width for: %s\n", text);
    // Stub: approximate 6 pixels per character
    return (int)strlen(text) * 6;  // text が NULL の場合 crash
}
```

**問題**:
- `text` が NULL ポインタの場合、`strlen()` でセグメンテーション フォルト
- 呼び出し元で NULL チェック後でも、競合状態の可能性

---

### 8. LOW: コード品質上の問題

#### Issue 8.1: グローバル状態の管理

**ファイル**: 複数ファイル
**重大度**: LOW

**問題**:
- 複数のグローバル静的変数が散在
- マルチスレッド非対応
- 再初期化 (RenderInit 複数回) への対応が弱い

#### Issue 8.2: マジックナンバーの乱用

**ファイル**: 複数ファイル
**重大度**: LOW

- MAX_IMAGES = 256
- MAX_CACHED_FONTS = 32
- MAX_TEXTURE_WIDTH, MAX_TEXTURE_HEIGHT が定義されていない

---

## セキュリティベストプラクティスの欠落

### 1. Defensive Programming
- 前提条件の検証不足
- 戻り値エラー処理が不十分
- NULL チェックの一貫性なし

### 2. Bounds Checking
- バッファサイズの検証欠落
- 負値チェックなし
- 極大値チェックなし

### 3. Resource Management
- リソースリークの可能性
- クリーンアップコードの欠落
- RAII パターンの使用なし (C言語のため)

---

## 修正優先度（Risk Matrix）

| 優先度 | 件数 | 対象 |
|--------|------|------|
| **Critical** | 2 | strcpy(), strncpy() NUL 終端 |
| **High** | 5 | メモリ安全、入力検証、Null チェック |
| **Medium** | 4 | リソース管理、エラー処理、型安全 |
| **Low** | 2 | コード品質 |

---

## 推奨アクション

### Phase 4a: Critical 修正（必須）
- [ ] Issue 1.1: sg_text.c の strcpy() → strncpy() + NUL 終端
- [ ] Issue 1.2: sg_image.c の strncpy() → 明示的 NUL 終端

### Phase 4b: High 修正（本番前必須）
- [ ] Issue 2.1: ハンドル管理を改善 (UUID または構造体型)
- [ ] Issue 2.2: フォントキャッシュの リソース追跡 を追加
- [ ] Issue 3.1: ファイルパス検証 を実装
- [ ] Issue 3.2: 画像サイズ検証 を実装
- [ ] Issue 4.1, 4.2: Null ポインタ チェック を追加

### Phase 4c: Medium 修正（推奨）
- [ ] Issue 5.1, 5.2: Shutdown 処理を完成
- [ ] Issue 6.1, 6.2: エラーハンドリング と Lua 戻り値
- [ ] Issue 7.1: NULL 安全な文字列処理

### Phase 4d: Low 修正（将来）
- [ ] Issue 8.1: グローバル状態をスレッドセーフ化
- [ ] Issue 8.2: マジックナンバーを定数化

---

## テストケース推奨

```c
// Boundary Testing
test_strcpy_buffer_overflow();      // 256+ byte font names
test_file_path_traversal();         // "../../../etc/passwd"
test_negative_dimensions();         // width = -1, height = -1
test_max_int_dimensions();          // INT_MAX
test_null_pointer_outputs();        // NULL to GetDrawColor
test_uninitialized_api_calls();     // RenderInit 前の各関数
test_handle_reuse_after_free();     // Use-after-free
test_font_cache_overflow();         // 33+ different fonts
```

---

## 適合状況チェックリスト

- [x] メモリ安全性: **部分的** (Critical 問題存在)
- [x] 入力検証: **不足** (パストラバーサル対策なし)
- [x] リソース管理: **不足** (クリーンアップ欠落)
- [x] エラーハンドリング: **不足** (戻り値未検査)
- [x] Null 安全: **部分的** (チェック不一貫)

---

## 結論

本コードは **MVP 段階** としては機能的には良い構造を持っていますが、セキュリティと堅牢性の面で **本番リリース前の対応が必須** です。

特に以下は **本番環境では受け入れられない**:
1. バッファオーバーフロー脆弱性
2. ファイルパストラバーサル
3. リソースリーク

推奨：Phase 4a の Critical 修正を即座に実施し、Phase 4b の High 修正は 本番リリース前に完了させてください。

---

**Paladin (守護者) 署名**
検証日: 2026-01-29
検証者: Paladin (Security Guardian)
