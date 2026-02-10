# タスク2: ビルドパイプライン監査結果

**監査日時**: 2026-02-04 22:40
**監査者**: Claude (Sonnet 4.5)

---

## エグゼクティブサマリー

### 重大な問題点 (CRITICAL)

**3つの異なるバージョンのdylibが検出されました**:

1. **ビルド成果物** (`dev/simplegraphic/build/`) - **最新** (2026-02-04 06:06:35)
2. **開発ランタイム** (`dev/runtime/`) - **古い** (2026-02-03 21:02:27) ← ❌ 同期されていない
3. **アプリバンドル** (`PathOfBuilding.app/.../runtime/`) - **混在** (2種類のdylibが存在)

### 影響度

- **リスクレベル**: 高
- **影響範囲**: ビルド後のテストで古いコードが実行される可能性
- **デバッグ困難度**: 非常に高い (ソースコード変更が反映されない原因になる)

---

## ビルドプロセス

### 1. CMakeベースのビルドシステム

**ビルド場所**: `/Users/kokage/national-operations/pob2macos/dev/simplegraphic/`

**ビルドコマンド** (CLAUDE.mdより):
```bash
cd simplegraphic
cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
make -C build
```

**ビルド設定**:
- CMake 3.16+
- Backend: Metal (default), OpenGL (fallback)
- Output: `libSimpleGraphic.1.0.0.dylib` (+ symlinks)
- 言語: C++17, Objective-C++ (Metal backend)

### 2. ビルド成果物

**出力ディレクトリ**: `dev/simplegraphic/build/`

**ファイル構造**:
```
libSimpleGraphic.1.0.0.dylib  (actual binary)
libSimpleGraphic.1.dylib      (symlink → 1.0.0)
libSimpleGraphic.dylib        (symlink → 1.dylib)
```

---

## 成果物の追跡

### デプロイフロー

```
[1] ビルド成果物
    └─ dev/simplegraphic/build/libSimpleGraphic.1.0.0.dylib
         ↓ 手動コピー (CLAUDE.mdに記載)
[2] 開発ランタイム
    └─ dev/runtime/SimpleGraphic.dylib
         ↓ 手動コピー (CLAUDE.mdに記載)
[3] アプリバンドル (実行時)
    └─ PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
```

### 実行時ロードパス

**エントリーポイント**: `PathOfBuilding.app/Contents/MacOS/PathOfBuilding` (zsh script)
```zsh
#!/bin/zsh
cd "$(dirname "$0")/../Resources/pob2macos"
exec /usr/local/bin/luajit "./pob2_launch.lua"
```

**FFIロード** (pob2_launch.lua:81-82):
```lua
local lib_path = "runtime/SimpleGraphic.dylib"
local sg = ffi.load(lib_path)
```

**実際のロード先**: `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib`

---

## チェックサム検証

### 完全チェックサム比較表

| 場所 | ファイル名 | チェックサム (SHA1) | サイズ (bytes) | タイムスタンプ | 状態 |
|------|------------|---------------------|----------------|---------------|------|
| **ビルド成果物** | libSimpleGraphic.1.0.0.dylib | `3bc83444c85042dd` | 216,224 | 2026-02-04 06:06:35 | ✓ 最新 |
| **開発ランタイム** | SimpleGraphic.dylib | `d8acb631d2633f3c` | 216,224 | 2026-02-03 21:02:27 | ✗ **古い** |
| **アプリバンドル (1)** | SimpleGraphic.dylib | `a3e58cd409c658e9` | 216,272 | 2026-02-04 22:36:22 | ? **不明版** |
| **アプリバンドル (2)** | libSimpleGraphic.dylib | `3bc83444c85042dd` | 216,224 | 2026-02-04 06:06:42 | ✓ 最新 |

### 重大な発見

#### 1. 開発ランタイムが古い

- **dev/runtime/SimpleGraphic.dylib** は2026-02-03版
- 最新ビルド (2026-02-04) が反映されていない
- チェックサムが完全に異なる

#### 2. アプリバンドルに2つのdylibが存在

**libSimpleGraphic.dylib**:
- チェックサム: `3bc83444c85042dd` (ビルド成果物と同一) ✓
- タイムスタンプ: 2026-02-04 06:06:42
- サイズ: 216,224 bytes

**SimpleGraphic.dylib**:
- チェックサム: `a3e58cd409c658e9` (どのバージョンとも一致しない) ✗
- タイムスタンプ: 2026-02-04 22:36:22 (最新)
- サイズ: 216,272 bytes (48 bytes 大きい)

#### 3. ロード対象は不明版

pob2_launch.lua が実際にロードするのは **SimpleGraphic.dylib** (不明版) であり、最新のビルド成果物ではない可能性が高い。

---

## 問題点の詳細分析

### 問題1: 手動デプロイプロセスの脆弱性

**現状のプロセス** (CLAUDE.mdより):
```bash
# 1. ビルド
cd simplegraphic && make -C build

# 2. ランタイムにコピー
cp simplegraphic/build/libSimpleGraphic.dylib runtime/

# 3. アプリバンドルにコピー
cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
```

**問題点**:
- ステップ2が実行されていない形跡 (開発ランタイムが古い)
- ステップ3が実行されていない、または異なるソースからコピーされた
- 3ステップの手動プロセスは人的ミスが発生しやすい
- ビルド後の検証ステップがない

### 問題2: 複数のバイナリファイルの混在

**アプリバンドル内**:
```
runtime/
  ├─ SimpleGraphic.dylib       (ロード対象、不明版)
  └─ libSimpleGraphic.dylib    (未使用、最新版)
```

**なぜこうなったか**:
- 異なるソースから異なるタイミングでコピーされた
- CLAUDE.mdのデプロイ手順が実際の運用と乖離している
- どちらがロードされるか明示的に制御されていない

### 問題3: チェックサム検証の欠如

**CLAUDE.mdの記載**:
> テスト前に常に正しいdylibがランタイムディレクトリにコピーされていることを確認してください。チェックサムまたはファイルタイムスタンプの比較を実行して、デプロイされたバイナリが最新のビルドと一致することを確認してください。

**実態**:
- チェックサム検証が実行された形跡なし
- タイムスタンプ比較も実行されていない
- デプロイ後の検証プロセスが存在しない

---

## デバッグへの影響

### シナリオ: Metal backendのコード修正

1. **開発者がmetal_backend.mmを修正**
2. **ビルド実行**: `make -C build` → `dev/simplegraphic/build/libSimpleGraphic.dylib` が更新される
3. **テスト実行**: `open PathOfBuilding.app`
4. **問題**: アプリは `runtime/SimpleGraphic.dylib` (古いまたは不明版) をロードする
5. **結果**: コード修正が反映されない → **デバッグ困難**

### 過去の失敗事例 (推測)

**2026-02-04の履歴**:
- commit `5ffeebc`: "codexでツリー表示正常化"
- PassiveTreeView.luaなどのLuaファイルは更新されている
- dylib関連の変更は含まれていない

**可能性**:
- Luaファイルの変更は即座に反映される (インタープリタ言語)
- dylibの変更は反映されない (ビルド成果物のデプロイミス)
- 結果として、Luaレベルでの問題は修正できても、C++レベルの問題は解決できない

---

## 推奨される修正

### 即時対応 (HIGH PRIORITY)

#### 1. 現在の状態を確認

```bash
# 現在ロードされているdylibを特定
cd /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos
/usr/local/bin/luajit -e 'ffi=require("ffi"); ffi.cdef[[void* dlopen(const char*,int); char* dlerror(); ]]; h=ffi.C.dlopen("runtime/SimpleGraphic.dylib",1); print(h~=nil and "Loaded" or ffi.string(ffi.C.dlerror()))'
```

#### 2. 最新ビルドを正しくデプロイ

```bash
# ビルド成果物を確認
ls -lh /Users/kokage/national-operations/pob2macos/dev/simplegraphic/build/libSimpleGraphic.dylib
shasum /Users/kokage/national-operations/pob2macos/dev/simplegraphic/build/libSimpleGraphic.dylib

# 開発ランタイムに同期
cp /Users/kokage/national-operations/pob2macos/dev/simplegraphic/build/libSimpleGraphic.dylib \
   /Users/kokage/national-operations/pob2macos/dev/runtime/SimpleGraphic.dylib

# アプリバンドルに同期 (古いファイルを削除してから)
rm /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
rm /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/libSimpleGraphic.dylib
cp /Users/kokage/national-operations/pob2macos/dev/runtime/SimpleGraphic.dylib \
   /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/

# チェックサム検証
shasum /Users/kokage/national-operations/pob2macos/dev/simplegraphic/build/libSimpleGraphic.dylib \
       /Users/kokage/national-operations/pob2macos/dev/runtime/SimpleGraphic.dylib \
       /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
```

### 中期対応 (RECOMMENDED)

#### 3. デプロイスクリプトの作成

**deploy.sh**:
```bash
#!/bin/bash
set -euo pipefail

PROJECT_ROOT="/Users/kokage/national-operations/pob2macos"
BUILD_DIR="${PROJECT_ROOT}/dev/simplegraphic/build"
RUNTIME_DIR="${PROJECT_ROOT}/dev/runtime"
APP_BUNDLE_DIR="${PROJECT_ROOT}/PathOfBuilding.app/Contents/Resources/pob2macos/runtime"

DYLIB_NAME="SimpleGraphic.dylib"
BUILD_DYLIB="${BUILD_DIR}/libSimpleGraphic.dylib"
RUNTIME_DYLIB="${RUNTIME_DIR}/${DYLIB_NAME}"
APP_DYLIB="${APP_BUNDLE_DIR}/${DYLIB_NAME}"

# 1. ビルド成果物の存在確認
if [[ ! -f "$BUILD_DYLIB" ]]; then
    echo "ERROR: Build artifact not found: $BUILD_DYLIB"
    exit 1
fi

# 2. ビルド成果物のチェックサム
BUILD_SHA=$(shasum "$BUILD_DYLIB" | awk '{print $1}')
echo "Build artifact: $BUILD_SHA"

# 3. 開発ランタイムにコピー
echo "Deploying to runtime..."
cp "$BUILD_DYLIB" "$RUNTIME_DYLIB"
RUNTIME_SHA=$(shasum "$RUNTIME_DYLIB" | awk '{print $1}')
echo "Runtime dylib: $RUNTIME_SHA"

# 4. アプリバンドルにコピー (古いファイルを削除)
echo "Deploying to app bundle..."
rm -f "${APP_BUNDLE_DIR}"/*.dylib
cp "$RUNTIME_DYLIB" "$APP_DYLIB"
APP_SHA=$(shasum "$APP_DYLIB" | awk '{print $1}')
echo "App bundle dylib: $APP_SHA"

# 5. チェックサム検証
if [[ "$BUILD_SHA" == "$RUNTIME_SHA" ]] && [[ "$BUILD_SHA" == "$APP_SHA" ]]; then
    echo "✓ Deployment successful! All checksums match."
    echo "  Checksum: $BUILD_SHA"
else
    echo "✗ ERROR: Checksum mismatch!"
    echo "  Build:   $BUILD_SHA"
    echo "  Runtime: $RUNTIME_SHA"
    echo "  App:     $APP_SHA"
    exit 1
fi
```

**使い方**:
```bash
# ビルド → デプロイ → 検証
cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
make -C build
cd /Users/kokage/national-operations/pob2macos
./deploy.sh
```

#### 4. Makefileへの統合

**dev/simplegraphic/build/Makefile** (カスタムターゲット追加):
```makefile
.PHONY: deploy
deploy: simplegraphic
	@echo "Deploying SimpleGraphic.dylib..."
	@bash ../../deploy.sh
```

**使い方**:
```bash
cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
make -C build deploy
```

### 長期対応 (BEST PRACTICE)

#### 5. CI/CDパイプラインの構築

**GitHub Actions** または **local pre-commit hook**:
```yaml
name: Build and Deploy
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: brew install cmake glfw freetype luajit zlib zstd
      - name: Build
        run: |
          cd dev/simplegraphic
          cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal
          make -C build
      - name: Deploy
        run: ./deploy.sh
      - name: Verify
        run: |
          CHECKSUMS=$(shasum dev/simplegraphic/build/libSimpleGraphic.dylib \
                             dev/runtime/SimpleGraphic.dylib \
                             PathOfBuilding.app/.../runtime/SimpleGraphic.dylib | awk '{print $1}')
          [[ $(echo "$CHECKSUMS" | uniq | wc -l) -eq 1 ]] || exit 1
```

#### 6. CLAUDE.mdの更新

**現在の記載を具体化**:
```markdown
## Build and Deploy

### Standard Workflow

1. **Build SimpleGraphic library**:
   ```bash
   cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
   make -C build
   ```

2. **Deploy (REQUIRED after every build)**:
   ```bash
   cd /Users/kokage/national-operations/pob2macos
   ./deploy.sh
   ```
   This script:
   - Copies `build/libSimpleGraphic.dylib` → `dev/runtime/SimpleGraphic.dylib`
   - Copies to `PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib`
   - Verifies checksums match across all locations

3. **Verify deployment**:
   ```bash
   shasum dev/simplegraphic/build/libSimpleGraphic.dylib \
          dev/runtime/SimpleGraphic.dylib \
          PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
   ```
   All three checksums MUST be identical.

### One-Command Build + Deploy

```bash
cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
make -C build deploy
```

### CRITICAL: Never Skip Deployment

**DO NOT**:
- Build and test immediately without deploying
- Manually copy files without checksum verification
- Assume the latest code is running

**ALWAYS**:
- Run `deploy.sh` after every build
- Verify checksums match
- Check app bundle has the correct dylib
```

---

## 検証方法

### デプロイ後の必須チェック

```bash
# 1. チェックサム一致確認
cd /Users/kokage/national-operations/pob2macos
CHECKSUMS=$(shasum dev/simplegraphic/build/libSimpleGraphic.dylib \
                   dev/runtime/SimpleGraphic.dylib \
                   PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib \
           | awk '{print $1}')
UNIQUE_COUNT=$(echo "$CHECKSUMS" | sort -u | wc -l)
if [[ $UNIQUE_COUNT -eq 1 ]]; then
    echo "✓ All checksums match"
else
    echo "✗ ERROR: Checksums do not match"
    exit 1
fi

# 2. タイムスタンプ確認 (ビルド後7分以内であること)
NEWEST=$(stat -f %m dev/simplegraphic/build/libSimpleGraphic.dylib)
OLDEST=$(stat -f %m PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib)
DIFF=$((NEWEST - OLDEST))
if [[ $DIFF -lt 420 ]]; then  # 7 minutes
    echo "✓ Timestamps are recent (${DIFF}s difference)"
else
    echo "✗ WARNING: Large timestamp gap (${DIFF}s)"
fi

# 3. アプリバンドル内に重複ファイルがないか確認
DYLIB_COUNT=$(ls -1 PathOfBuilding.app/Contents/Resources/pob2macos/runtime/*.dylib | wc -l)
if [[ $DYLIB_COUNT -eq 1 ]]; then
    echo "✓ Only one dylib in app bundle"
else
    echo "✗ WARNING: Multiple dylibs found ($DYLIB_COUNT)"
    ls -lh PathOfBuilding.app/Contents/Resources/pob2macos/runtime/*.dylib
fi
```

### 実行時検証

```bash
# アプリを起動してログを確認
open PathOfBuilding.app
sleep 5
tail -50 /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/passive_tree_app.log
```

**期待されるログ出力**:
```
Loading SimpleGraphic library...
✓ SimpleGraphic loaded from: runtime/SimpleGraphic.dylib
```

---

## 結論

### 現状の評価

- **ビルドシステム**: 正常に動作 (CMake + Make)
- **デプロイプロセス**: **破綻** (手動コピー、検証なし)
- **品質保証**: **不在** (チェックサム検証なし)

### 優先度付きアクションプラン

| 優先度 | アクション | 所要時間 | 影響度 |
|--------|-----------|---------|-------|
| P0 (即時) | 最新dylibを正しくデプロイ | 5分 | 高 |
| P0 (即時) | 古いlibSimpleGraphic.dylibを削除 | 1分 | 高 |
| P1 (今日) | deploy.shスクリプトを作成 | 30分 | 高 |
| P1 (今日) | CLAUDE.mdのデプロイ手順を更新 | 15分 | 中 |
| P2 (今週) | Makefileにdeployターゲットを追加 | 15分 | 中 |
| P3 (来週) | CI/CDパイプラインを構築 | 2時間 | 低 |

### 次のステップ

1. **即座に実行**: 「即時対応」セクションのコマンドを実行
2. **検証**: チェックサムが一致することを確認
3. **スクリプト化**: deploy.shを作成して今後のビルドで使用
4. **ドキュメント更新**: CLAUDE.mdに正確なデプロイ手順を追記

---

## 付録: ファイル構造

### 完全なディレクトリマップ

```
/Users/kokage/national-operations/pob2macos/
├── dev/
│   ├── simplegraphic/
│   │   ├── CMakeLists.txt
│   │   ├── src/
│   │   ├── include/
│   │   └── build/
│   │       ├── libSimpleGraphic.1.0.0.dylib  ← ビルド成果物 (最新)
│   │       ├── libSimpleGraphic.1.dylib      (symlink)
│   │       └── libSimpleGraphic.dylib        (symlink)
│   ├── runtime/
│   │   ├── SimpleGraphic.dylib               ← 開発ランタイム (古い)
│   │   └── lua/                              (symlink)
│   └── pob2_launch.lua                       ← FFI loader script
└── PathOfBuilding.app/
    └── Contents/
        ├── MacOS/
        │   └── PathOfBuilding                ← Launch script (zsh)
        └── Resources/
            └── pob2macos/
                ├── pob2_launch.lua           ← Deployed launcher
                ├── src/                      ← Lua source code
                └── runtime/
                    ├── SimpleGraphic.dylib   ← 実行時ロード対象 (不明版)
                    └── libSimpleGraphic.dylib ← 未使用 (最新版)
```

### 実行フロー

```
[User clicks app]
  → PathOfBuilding (zsh)
    → cd Contents/Resources/pob2macos
    → luajit ./pob2_launch.lua
      → ffi.load("runtime/SimpleGraphic.dylib")  ← ここで古いまたは不明版がロード
        → [Application runs with old code]
```

---

**END OF REPORT**
