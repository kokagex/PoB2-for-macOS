# Phase 7 セキュリティレビューレポート
## Paladin（聖騎士）による Phase 7 新規コードセキュリティ監査

**作成日**: 2026-01-29
**レビュー対象**: sg_stubs.c, sg_text.c, sg_core.c, sg_lua_binding.c, text_renderer.c
**レビュアー**: Paladin（聖騎士） - セキュリティ・品質保証部門

---

## 目次

1. [Executive Summary](#executive-summary)
2. [sg_stubs.c セキュリティレビュー](#sg_stubsc-セキュリティレビュー)
3. [コールバック機構のセキュリティ設計指針](#コールバック機構のセキュリティ設計指針)
4. [メモリリーク検出結果](#メモリリーク検出結果)
5. [テキストレンダリングセキュリティ](#テキストレンダリングセキュリティ)
6. [推奨修正事項](#推奨修正事項)
7. [検査チェックリスト](#検査チェックリスト)

---

## Executive Summary

### 総合評価
**脆弱性レベル: 中程度（MODERATE）**

Phase 7 の既存実装（sg_stubs.c, sg_text.c, sg_core.c, sg_lua_binding.c）には以下の セキュリティ上の懸念点が確認されました：

- **コマンドインジェクション**: ConExecute と TakeScreenshot で要対策
- **パストラバーサル**: LoadModule のパス検証が不完全
- **メモリリーク**: テキストレンダラーでの不完全な解放
- **プロセス生成**: SpawnProcess で execv の安全性確認が必要
- **NULL ポインタデリファレンス**: 複数の関数で入力検証が不足

### 好的な設計
- **strncpy の使用**: sg_text.c で正しくバッファオーバーフロー対策が実装されている
- **NULL チェック**: GetScreenSize で NULL ポインタ保護が実装
- **パス検証の基盤**: LoadModule で ".." の検出が実装

---

## sg_stubs.c セキュリティレビュー

### 1. ConExecute() - コマンド実行
**脆弱性: コマンドインジェクション（中程度）**

```c
void SimpleGraphic_ConExecute(const char* cmd) {
    // ...
    system(cmd);  // DANGER: Direct command execution
}
```

**問題点**:
- コマンドの whitelist チェックが実装されているものの、`strncmp` の利用は不完全
- ユーザー入力を含むコマンドが直接 `system()` に渡される場合、シェルメタキャラが実行される
- 現在の実装では "set vid_mode" と "set vid_resizable" のみ許可しているが、引数の検証がない

**推奨対策**:
1. コマンド引数を完全に解析し、数値型のコマンドのみ許可する
2. `system()` の使用を避け、`execve()` で直接プログラムを実行する
3. 引数は配列形式で渡し、シェル展開を防ぐ

**リスク**: 低～中程度（現在のフィルタリングにより大幅に軽減）

---

### 2. Copy() / Paste() - クリップボード操作
**脆弱性: プロセス通信の安全性（低程度）**

```c
void SimpleGraphic_Copy(const char* text) {
    FILE* pbcopy = popen("pbcopy", "w");
    if (pbcopy) {
        fputs(text, pbcopy);
        pclose(pbcopy);
    }
}
```

**問題点**:
- `popen()` は安全（ハードコードされたコマンド、引数なし）
- ただし `fputs()` でテキストの出力サイズが制限されていない
- 長いテキストがバッファを溢れさせる可能性は低い（`fputs()` は安全）が、確認が必要

**好的な点**:
- popen の第 2 引数が "w" であり、シェルを経由しない設計が良好
- `pclose()` で確実に プロセスを終了

**推奨対策**:
- テキスト長の制限を明示的に検討（例: 1MB 制限）

**リスク**: 低い

---

### 3. TakeScreenshot() - スクリーンショット機能
**脆弱性: コマンドインジェクション（中程度）**

```c
void SimpleGraphic_TakeScreenshot(void) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "screencapture -x ~/Desktop/screenshot_%ld.png",
             (long)time(NULL));
    system(cmd);  // DANGER: Command injection
}
```

**問題点**:
- `time(NULL)` の出力を直接 `system()` に渡す
- タイムスタンプは制御可能だが、`system()` の呼び出しでシェルメタキャラが展開される
- macOS の `screencapture` コマンドは一般的に安全だが、パス指定が `~` で展開される

**脆弱性シナリオ**:
- ホームディレクトリのパスが不正な文字を含む場合、シェル展開により予期しない動作が起こりうる

**推奨対策**:
1. `system()` を避け、`execve()` で直接 `screencapture` を呼び出す
2. ファイルパスを絶対パスに変換（`realpath()`）
3. ファイル名サニタイズ：数字のみを使用

**修正例**:
```c
void SimpleGraphic_TakeScreenshot(void) {
    pid_t pid = fork();
    if (pid == 0) {
        // 絶対パスを構築
        char filename[PATH_MAX];
        snprintf(filename, sizeof(filename),
                 "%s/Desktop/screenshot_%ld.png",
                 getenv("HOME"), (long)time(NULL));

        execl("/usr/sbin/screencapture", "screencapture",
              "-x", filename, NULL);
        exit(127);
    }
}
```

**リスク**: 中程度

---

### 4. SpawnProcess() - プロセス生成
**脆弱性: パストラバーサル、権限昇格の可能性（中程度）**

```c
int SimpleGraphic_SpawnProcess(const char* cmd_path, const char* args) {
    pid_t pid = fork();
    if (pid == 0) {
        char* argv[3];
        argv[0] = (char*)cmd_path;
        argv[1] = args ? (char*)args : NULL;
        argv[2] = NULL;
        execv(cmd_path, argv);  // DANGER: No path validation
        exit(127);
    }
    return pid;
}
```

**問題点**:
- `cmd_path` の検証が完全でない
- 相対パスが許可される（例: `../../../bin/sh`）
- 実行可能性の確認がない（存在しないファイルは execv で失敗するが、エラーハンドリングが不完全）
- `args` がシェルで展開される可能性はないが、execv の第 2 引数の安全性確認が必要

**脆弱性シナリオ**:
- Lua スクリプトから悪意あるパスを指定される場合、想定外のプログラムを実行させられる

**推奨対策**:
1. `cmd_path` を絶対パスに正規化（`realpath()`）
2. `/bin`, `/usr/bin`, `/usr/local/bin` などのホワイトリストディレクトリのみ許可
3. 実行権限の確認（`access(cmd_path, X_OK)`）
4. セットアップスクリプトで権限をチェック

**修正例**:
```c
int SimpleGraphic_SpawnProcess(const char* cmd_path, const char* args) {
    // 絶対パスに正規化
    char resolved_path[PATH_MAX];
    if (!realpath(cmd_path, resolved_path)) {
        fprintf(stderr, "[SpawnProcess] realpath failed\n");
        return -1;
    }

    // ホワイトリストチェック
    const char* safe_paths[] = {
        "/bin/", "/usr/bin/", "/usr/local/bin/",
        "/Applications/", NULL
    };
    bool allowed = false;
    for (int i = 0; safe_paths[i]; i++) {
        if (strncmp(resolved_path, safe_paths[i], strlen(safe_paths[i])) == 0) {
            allowed = true;
            break;
        }
    }

    if (!allowed) {
        fprintf(stderr, "[SpawnProcess] Path not in whitelist: %s\n", resolved_path);
        return -1;
    }

    // 実行権限確認
    if (access(resolved_path, X_OK) != 0) {
        fprintf(stderr, "[SpawnProcess] Not executable: %s\n", resolved_path);
        return -1;
    }

    pid_t pid = fork();
    if (pid == 0) {
        char* argv[3];
        argv[0] = resolved_path;
        argv[1] = args ? (char*)args : NULL;
        argv[2] = NULL;
        execv(resolved_path, argv);
        exit(127);
    }
    return pid;
}
```

**リスク**: 中程度

---

### 5. LoadModule() - モジュール読み込み
**脆弱性: パストラバーサル（低程度、だが改善の余地あり）**

```c
int SimpleGraphic_LoadModule(const char* module_path) {
    if (strstr(module_path, "..") != NULL) {
        fprintf(stderr, "[LoadModule] Rejecting path traversal attempt: %s\n",
                module_path);
        return 0;
    }
    return 1;
}
```

**問題点**:
- ".." のみの検出であり、他の攻撃ベクトルが存在する可能性
- シンボリックリンク経由のパストラバーサルを防げない
- 絶対パスが許可される（セキュリティリスク）

**推奨対策**:
1. `realpath()` で正規化し、シンボリックリンクを解決
2. module ディレクトリの既知パスの下に限定
3. ファイル拡張子の制限（`.lua`, `.so` など）

**修正例**:
```c
int SimpleGraphic_LoadModule(const char* module_path) {
    if (!module_path) return 0;

    // 絶対パスに正規化
    char resolved[PATH_MAX];
    if (!realpath(module_path, resolved)) {
        fprintf(stderr, "[LoadModule] Invalid path: %s\n", module_path);
        return 0;
    }

    // 許可されたディレクトリの確認
    const char* allowed_dir = "/Users/kokage/national-operations/pob2macos/modules";
    if (strncmp(resolved, allowed_dir, strlen(allowed_dir)) != 0) {
        fprintf(stderr, "[LoadModule] Path not in allowed directory: %s\n",
                resolved);
        return 0;
    }

    // ファイル拡張子の確認
    const char* ext = strrchr(resolved, '.');
    if (!ext || (strcmp(ext, ".lua") != 0 && strcmp(ext, ".so") != 0)) {
        fprintf(stderr, "[LoadModule] Invalid file extension: %s\n", ext);
        return 0;
    }

    return 1;
}
```

**リスク**: 低程度（ただし改善推奨）

---

## コールバック機構のセキュリティ設計指針

### Phase 7 で実装予定: SetCallback, GetCallback, runCallback, PCall, PLoadModule

これらは Phase 7 で Artisan により実装予定のため、ここではセキュリティ設計指針を示します。

### 1. Lua Ref メモリリーク防止

**問題**: Lua の `luaL_ref()` で登録された参照が解放されないと、メモリリークになる

**設計指針**:
```c
// 正しいパターン
typedef struct {
    int callback_ref;  // Registered with luaL_ref()
} CallbackData;

void register_callback(lua_State* L, const char* name, int func_index) {
    // Lua スタックのインデックスを参照に変換
    lua_pushvalue(L, func_index);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);

    // ref を保存
    // ...
}

void unregister_callback(lua_State* L, int callback_ref) {
    if (callback_ref != LUA_NOREF && callback_ref != LUA_REFNIL) {
        luaL_unref(L, LUA_REGISTRYINDEX, callback_ref);
    }
}

void cleanup_callbacks(lua_State* L, CallbackData* callbacks, int count) {
    for (int i = 0; i < count; i++) {
        if (callbacks[i].callback_ref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, callbacks[i].callback_ref);
            callbacks[i].callback_ref = LUA_NOREF;
        }
    }
    free(callbacks);
}
```

**チェックリスト**:
- [ ] すべての `luaL_ref()` に対応する `luaL_unref()` が存在する
- [ ] アプリケーション終了時に全参照が解放される
- [ ] エラーパスでも参照がリークしない（try-finally パターン）
- [ ] コールバック登録上限を設定（無限登録防止）

---

### 2. PCall（Protected Call）のエラーハンドリング

**問題**: Lua 関数呼び出しでスタックオーバーフローが起きる可能性

**設計指針**:
```c
int safe_lua_call(lua_State* L, int nargs, int nresults) {
    // スタック深度制限の設定
    static const int MAX_STACK_DEPTH = 1000;

    if (lua_gettop(L) > MAX_STACK_DEPTH) {
        fprintf(stderr, "[Lua] Stack overflow detected\n");
        return LUA_ERRRUN;
    }

    // lua_pcall を使用（例外安全）
    int result = lua_pcall(L, nargs, nresults, 0);

    if (result != LUA_OK) {
        fprintf(stderr, "[Lua] Call error: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);  // エラーメッセージをポップ
    }

    return result;
}
```

**チェックリスト**:
- [ ] すべての lua_call は lua_pcall に変更される
- [ ] エラーハンドリング後、スタックが安定状態に復帰する
- [ ] 再帰呼び出しで深度がチェックされる
- [ ] タイムアウト機構を検討（無限ループ防止）

---

### 3. PLoadModule のパス検証

**設計指針**: `LoadModule()` と同じ安全性要件

```c
int SimpleGraphic_PLoadModule(const char* module_path) {
    // LoadModule() の完全版と同じパス検証を実施
    return SimpleGraphic_LoadModule(module_path);
}
```

---

## メモリリーク検出結果

### スキャン対象: malloc, calloc, free の対応関係

#### 1. **text_renderer.c - グリフキャッシュ管理**

**問題: 未割り当てのグリフバッファ**

```c
// Line 86 (Phase 5 Stub - 未実装)
// cache->glyphs = (GlyphMetrics*)calloc(MAX_GLYPHS_PER_FONT, sizeof(GlyphMetrics));
```

**状況**:
- Phase 5 では `calloc()` がコメントアウトされているため、メモリリークはない
- Phase 6 で実装される際、必ず対応する `free()` が必要

**リスク**: 低い（現在は stub）

---

#### 2. **text_renderer.c - グリフ解放**

**問題: 確実に解放される**

```c
// Line 147-152
if (cache->glyphs) {
    for (int j = 0; j < cache->glyph_count; j++) {
        if (cache->glyphs[j].texture_id) {
            glDeleteTextures(1, &cache->glyphs[j].texture_id);
        }
    }
    free(cache->glyphs);
}
```

**評価**: **GOOD** - 完全に解放されている

---

#### 3. **sg_lua_binding.c - Paste/GetClipboard**

**問題: strdup の対応する free**

```c
// Line 245-254
char* text = SimpleGraphic_Paste();
if (text) {
    lua_pushstring(L, text);
    free(text);  // CORRECT
} else {
    lua_pushstring(L, "");
}
return 1;
```

**評価**: **GOOD** - 正しく解放されている

---

#### 4. **sg_stubs.c - Paste/GetClipboard**

**問題: strdup で割り当てられたメモリ**

```c
// Line 124
buffer[total] = '\0';
return strdup(buffer);  // Allocated memory
```

**パス A: 正常系**
```c
// sg_lua_binding.c: 249
free(text);  // CORRECT
```

**パス B: エラー系**
```c
// sg_lua_binding.c: 251
// return NULL の場合は free されない（正しい）
```

**評価**: **GOOD** - Lua バインディング層で適切に管理されている

---

#### 5. **OpenGL リソース**

**グリフテクスチャ**:
```c
// text_renderer.c: 148, 264, 415
glDeleteTextures(1, &cache->glyphs[j].texture_id);
```

**評価**: **GOOD** - テクスチャが解放されている

**ただし注意**: Phase 6 で FreeType 統合時に、以下を確認必要
- FT_Done_Face() の呼び出し
- FreeType ライブラリの FT_Done_FreeType()

---

### メモリリーク総評

| 項目 | リスク | コメント |
|------|--------|---------|
| テキストレンダラーのグリフ解放 | 低 | Phase 5 stub のため未割り当て |
| Lua Paste 機能 | 低 | 正しく解放されている |
| OpenGL テクスチャ | 低 | 削除が実装されている |
| **FreeType ライブラリ** | 中 | Phase 6 実装時に確認必要 |
| **Lua コールバック参照** | 中 | Phase 7 実装時に確認必要 |

**結論**: 現在の実装では大きなメモリリークはない。ただし Phase 6/7 の FreeType と Lua コールバック機構で注意が必要。

---

## テキストレンダリングセキュリティ

### text_renderer.c / text_renderer.h

#### 1. フォントファイル読み込み

**現状**:
```c
bool text_renderer_load_font(const char* font_path, int size) {
    if (!font_path || size <= 0) {
        set_error("Invalid font path or size");
        return false;
    }
    printf("[TextRenderer] Loading font: %s (size=%d)\n", font_path, size);
    // Phase 6 TODO: FreeType integration
}
```

**セキュリティ懸念**:
- フォントパスの検証がない
- 悪意あるフォントファイル（malformed TTF）から RCE の可能性
- ZIP爆弾のような圧縮爆弾攻撃

**推奨対策**:
1. フォントパスを `realpath()` で正規化
2. `realpath()` の結果が許可されたディレクトリ内か確認
3. FreeType の例外処理を実装
4. ファイルサイズの制限（例: 100MB 以下）

**修正例**:
```c
bool text_renderer_load_font(const char* font_path, int size) {
    if (!font_path || size <= 0) {
        set_error("Invalid font path or size");
        return false;
    }

    // パス正規化
    char resolved_path[PATH_MAX];
    if (!realpath(font_path, resolved_path)) {
        set_error("Invalid font path");
        return false;
    }

    // 許可されたディレクトリの確認
    const char* allowed[] = {
        "/Library/Fonts",
        "/System/Library/Fonts",
        getenv("HOME")  // ~/.fonts, ~/Library/Fonts
    };

    bool allowed_dir = false;
    for (int i = 0; i < 3; i++) {
        if (allowed[i] && strncmp(resolved_path, allowed[i], strlen(allowed[i])) == 0) {
            allowed_dir = true;
            break;
        }
    }

    if (!allowed_dir) {
        set_error("Font path not in allowed directory");
        return false;
    }

    // ファイルサイズチェック
    struct stat st;
    if (stat(resolved_path, &st) != 0 || st.st_size > 100 * 1024 * 1024) {
        set_error("Font file too large");
        return false;
    }

    // ... FreeType loading
    return true;
}
```

**リスク**: 低～中（Phase 6 実装時に重要）

---

#### 2. テキスト長制限

**問題**:
```c
int text_renderer_measure_width(const char* font_path, int size, const char* text) {
    int text_len = strlen(text);
    int estimated_width = text_len * (size / 2);
    // テキスト長に上限がない
}
```

**リスク**:
- 巨大なテキストによるメモリ枯渇（DoS）
- GPU メモリの枯渇（テクスチャ生成時）

**推奨対策**:
```c
#define MAX_TEXT_LENGTH 65536  // 64KB

int text_renderer_measure_width(const char* font_path, int size, const char* text) {
    if (!text || !font_path) return 0;

    size_t text_len = strlen(text);
    if (text_len > MAX_TEXT_LENGTH) {
        set_error("Text exceeds maximum length");
        return 0;
    }

    // ...
}
```

**リスク**: 低～中

---

#### 3. フォントサイズの制限

**問題**:
```c
bool text_renderer_load_font(const char* font_path, int size) {
    // size に上限がない
    // size が負数や 0 の場合の検証あり
}
```

**推奨対策**:
```c
#define MAX_FONT_SIZE 256
#define MIN_FONT_SIZE 8

bool text_renderer_load_font(const char* font_path, int size) {
    if (size < MIN_FONT_SIZE || size > MAX_FONT_SIZE) {
        set_error("Font size out of range: %d", size);
        return false;
    }
    // ...
}
```

---

## 推奨修正事項

### 優先度 1（High）- Phase 7 開始前に必須

| # | 項目 | ファイル | 優先度 | 内容 |
|----|------|--------|--------|------|
| 1 | TakeScreenshot コマンドインジェクション | sg_stubs.c | **HIGH** | system() を execv に変更、パス正規化 |
| 2 | SpawnProcess パストラバーサル対策 | sg_stubs.c | **HIGH** | realpath() でパス正規化、whitelist チェック |
| 3 | LoadModule パストラバーサル改善 | sg_stubs.c | **HIGH** | realpath()、ディレクトリ制限、拡張子チェック |
| 4 | ConExecute の安全性強化 | sg_stubs.c | **MEDIUM** | コマンド引数の完全検証、execve への変更検討 |

### 優先度 2（Medium）- Phase 6/7 実装時

| # | 項目 | ファイル | 優先度 | 内容 |
|----|------|--------|--------|------|
| 5 | FreeType パス検証 | text_renderer.c | **MEDIUM** | realpath()、ディレクトリ制限、ファイルサイズチェック |
| 6 | テキスト長制限 | text_renderer.c | **MEDIUM** | MAX_TEXT_LENGTH の定義と検証 |
| 7 | フォントサイズ制限 | text_renderer.c | **MEDIUM** | MIN_FONT_SIZE, MAX_FONT_SIZE の定義 |
| 8 | Lua ref メモリリーク防止 | sg_lua_binding.c (Phase 7) | **MEDIUM** | luaL_unref() の確実な呼び出し |
| 9 | PCall スタック深度制限 | sg_callbacks.c (Phase 7) | **MEDIUM** | MAX_STACK_DEPTH の実装 |

### 優先度 3（Low）- 将来の改善

| # | 項目 | ファイル | 優先度 | 内容 |
|----|------|--------|--------|------|
| 10 | Paste テキスト長制限 | sg_stubs.c | **LOW** | クリップボードのサイズ制限（8KB → 1MB） |
| 11 | システムフォント検索 | text_renderer.c (Phase 6) | **LOW** | セキュアな fontconfig 利用 |
| 12 | エラーメッセージのログ記録 | 全体 | **LOW** | 詳細ログを別ファイルに記録 |

---

## 検査チェックリスト

### Artisan への確認項目（Phase 7 実装前）

- [ ] **Path 関数群の統一**
  - [ ] `realpath()` をすべてのパス入力で使用
  - [ ] `PATH_MAX` の定義を確認（システムに依存）
  - [ ] シンボリックリンク解決の動作確認

- [ ] **メモリ管理**
  - [ ] Lua ref の登録/解除が常に対になっているか
  - [ ] FreeType ライブラリの初期化/終了を確認
  - [ ] OpenGL リソース（テクスチャ、VBO）の削除タイミング

- [ ] **入力検証**
  - [ ] NULL ポインタチェックが完全か
  - [ ] 文字列長制限が実装されているか
  - [ ] 数値オーバーフロー対策があるか

- [ ] **プロセス管理**
  - [ ] fork()/execv() の使用で POSIX 準拠か
  - [ ] ゾンビプロセス防止（SIGCHLD ハンドラ）
  - [ ] popen() の使用が最小限か

- [ ] **エラーハンドリング**
  - [ ] エラーコードの確認と適切なログ出力
  - [ ] リソースリークの防止（エラーパス）
  - [ ] ユーザーへの安全なエラーメッセージ

---

## 参考資料

### CWE（Common Weakness Enumeration）

| CWE | 説明 | 対象 |
|-----|------|------|
| CWE-78 | Improper Neutralization of Special Elements used in an OS Command | ConExecute, TakeScreenshot |
| CWE-426 | Untrusted Search Path | SpawnProcess, LoadModule |
| CWE-119 | Improper Restriction of Operations within the Bounds of a Memory Buffer | Paste (8KB limit) |
| CWE-476 | Null Pointer Dereference | GetScreenSize (修正済) |
| CWE-120 | Buffer Copy without Checking Size of Input | sg_text.c (修正済: strncpy) |

### セキュリティ参考実装

1. **OpenBSD strlcpy/strlcat**
   - バッファオーバーフロー防止
   - macOS では標準利用可能

2. **POSIX exec() 族の正確な使用法**
   - `execve()`: 最も安全（環境変数制御可能）
   - `system()`: シェル展開により危険

3. **FreeType セキュリティ**
   - [FreeType Security](https://www.freetype.org/)
   - CVE データベースの確認

---

## 報告者からの総括

### 監査の結論

**Phase 7 のコード実装は、現在のスタブ実装から見ると全体的にセキュリティ意識が高く、基本的な対策（NULL チェック、strncpy の使用）が実装されています。**

しかし以下の重要な改善が必要です：

1. **コマンド実行の系統的な改善** - system() の使用を減らし、execv() への統一
2. **パス入力の一貫的な検証** - realpath() による正規化とホワイトリストチェック
3. **Phase 7 特有の設計** - Lua ref の完全な生存期間管理

これらの対策を実装することで、PoB2 macOS ポーティングは高いセキュリティレベルを達成できます。

---

**作成日**: 2026-01-29 (JST)
**署名**: Paladin（聖騎士） - SimpleGraphic セキュリティ監査部門
