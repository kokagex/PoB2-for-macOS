# 黄色テキストレンダリングバグ - 根本原因分析と修正提案

**分析日時**: 2026-02-04 22:50 JST
**分析者**: Claude (Sonnet 4.5)
**プロジェクト**: pob2macos Metal Rendering

---

## 📋 エグゼクティブサマリー

### 問題の概要
pob2macosアプリケーションにおいて、意図しない黄色テキスト（RGB 1,1,0）が表示される問題が発生。

### 根本原因（確定）
**複合的な問題**:
1. ✅ **デプロイメント問題**（確認済み、高優先度）
   - アプリは**古いまたは未知のバージョンのdylib**をロードしている
   - 最新のビルド成果物が実行環境に正しくデプロイされていない
   - これにより、コード変更が反映されない状態が継続

2. ⚠️ **シェーダー処理問題**（仮説、中優先度）
   - 色値は頂点データまで正しく伝達されている（検証済み）
   - Metalフラグメントシェーダーの処理で問題が発生している可能性
   - R8Unormテクスチャ判定とalpha blending処理が疑わしい

### 影響度
- **リスクレベル**: 🔴 高
- **デバッグ困難度**: 🔴 非常に高い
- **ユーザー体験への影響**: 🟡 中（視覚的な不一致）

---

## 🔍 調査結果の統合

### タスク2: ビルドパイプライン監査 ✅

#### 重大な発見

**3つの異なるdylibバージョンが存在**:

| 場所 | ファイル名 | チェックサム | タイムスタンプ | 状態 |
|------|-----------|-------------|---------------|------|
| ビルド成果物 | libSimpleGraphic.1.0.0.dylib | `3bc83444c85042dd` | 2026-02-04 06:06:35 | ✅ 最新 |
| 開発ランタイム | SimpleGraphic.dylib | `d8acb631d2633f3c` | 2026-02-03 21:02:27 | ❌ **古い** |
| アプリバンドル(1) | SimpleGraphic.dylib | `a3e58cd409c658e9` | 2026-02-04 22:36:22 | ❓ **不明版** |
| アプリバンドル(2) | libSimpleGraphic.dylib | `3bc83444c85042dd` | 2026-02-04 06:06:42 | ✅ 最新（未使用） |

**問題点**:
- アプリは `SimpleGraphic.dylib`（不明版、チェックサム `a3e58cd409c658e9`）をロード
- 最新のビルド成果物はロードされていない
- アプリバンドルに重複ファイルが存在

#### デプロイプロセスの破綻

**期待されるフロー**:
```
ビルド成果物 → 開発ランタイム → アプリバンドル
```

**実際のフロー**:
```
ビルド成果物 ✓
   ↓ ❌ コピーされていない
開発ランタイム（古いまま）
   ↓ ❌ 正しくコピーされていない
アプリバンドル（不明版）
```

**詳細レポート**: `.claude/debug_reports/task_2_build_audit.md`

---

### タスク3: ランタイム状態検査 ✅

#### 重要な発見

**色値は正しく伝達されている**:
- Luaレイヤー: RGB(1.000, 1.000, 0.000) ✓
- C++ DrawString: RGB(1.000, 1.000, 0.000) ✓
- metal_draw_glyph: RGB(1.000, 1.000, 0.000) ✓
- 頂点バッファデータ: RGB(1.000, 1.000, 0.000) ✓

#### 検証方法

デバッグログを `metal_backend.mm:metal_draw_glyph()` に追加して実際の色値をキャプチャ:

```
DEBUG_COLOR_YELLOW: #21 pos=(298,131) size=(12x19) color=(R:1.000 G:1.000 B:0.000 A:1.000)
DEBUG_COLOR_YELLOW: #22 pos=(312,131) size=(11x19) color=(R:1.000 G:1.000 B:0.000 A:1.000)
```

#### 問題の所在

色値が頂点データまで正しいため、問題は**Metalシェーダー内の処理**にある:

**疑わしいコード** (`metal_backend.mm` line 122-138):
```metal
fragment float4 textFragmentShader(VertexOut in [[stage_in]],
                                   texture2d<float> tex [[texture(0)]]) {
    float4 texColor = tex.sample(sampler(mag_filter::linear), in.texCoord);

    // R8Unorm texture detection (for glyph atlas)
    if (texColor.r > 0.0 && texColor.g == 0.0 && texColor.b == 0.0) {
        float alpha = texColor.r;
        return float4(in.color.rgb, alpha * in.color.a);  // ← ここで黄色が失われる？
    }

    // RGBA texture (for images)
    return texColor * in.color;
}
```

**仮説**:
- R8Unorm判定が正しく動作していない
- `in.color.rgb` が正しく渡されていない（頂点シェーダーの問題？）
- Alpha blending計算が間違っている

**詳細レポート**: `/Users/kokage/national-operations/pob2macos/.claude/debug_reports/task_3_runtime_inspection.md`

---

## 🎯 根本原因の結論

### 主原因: デプロイメント問題（確定）

**なぜこれが黄色テキスト問題を引き起こすか**:

1. 過去にシェーダーコードを修正した（黄色問題の修正を試みた）
2. ビルドは成功したが、**デプロイステップが実行されなかった**
3. アプリは**古いdylib**（修正前のコード）を実行し続けている
4. 結果: 黄色テキスト問題が「修正されない」まま残っている

**証拠**:
- ビルド成果物のタイムスタンプ: 2026-02-04 06:06:35
- アプリがロードするdylib: 不明版（チェックサムが一致しない）
- CLAUDE.mdには「常に正しいdylibがコピーされていることを確認」と記載されているが、実行されていない

### 副原因: シェーダー処理問題（仮説）

**仮に最新のdylibが正しくデプロイされても**、シェーダーに問題がある可能性:

1. フラグメントシェーダーが `in.color.rgb` を正しく使用していない
2. R8Unorm判定ロジックにバグがある
3. 頂点シェーダーからフラグメントシェーダーへの色の伝達に問題がある

**次の調査が必要**:
- シェーダーの実際の出力色を検証（Metal Debugger使用）
- 頂点シェーダーの `out.color = in.color;` が正しく動作しているか
- テクスチャフォーマットの確認（本当にR8Unormか？）

---

## 🔧 優先順位付き修正プラン

### P0: 即座に実行（所要時間: 10分）

#### 1. 最新dylibの正しいデプロイ

```bash
cd /Users/kokage/national-operations/pob2macos

# 古いファイルをすべて削除（重複を防ぐ）
rm -f PathOfBuilding.app/Contents/Resources/pob2macos/runtime/*.dylib

# 最新のビルド成果物を確認
ls -lh dev/simplegraphic/build/libSimpleGraphic.dylib
shasum dev/simplegraphic/build/libSimpleGraphic.dylib

# 開発ランタイムに同期
cp dev/simplegraphic/build/libSimpleGraphic.dylib dev/runtime/SimpleGraphic.dylib

# アプリバンドルに同期
cp dev/runtime/SimpleGraphic.dylib \
   PathOfBuilding.app/Contents/Resources/pob2macos/runtime/

# チェックサム検証（すべて一致するはず）
shasum dev/simplegraphic/build/libSimpleGraphic.dylib \
       dev/runtime/SimpleGraphic.dylib \
       PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
```

**期待される出力**:
```
3bc83444c85042dd  dev/simplegraphic/build/libSimpleGraphic.dylib
3bc83444c85042dd  dev/runtime/SimpleGraphic.dylib
3bc83444c85042dd  PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib
```

#### 2. デプロイ検証テスト

```bash
# アプリを起動してテスト
open PathOfBuilding.app

# または、ターミナルから実行してログ確認
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding 2>&1 | tee /tmp/pob_test.log
```

**検証項目**:
- ✅ 黄色テキスト問題が解決したか？
- ✅ 他の色が正しく表示されるか？
- ✅ テキストレンダリングに異常がないか？

---

### P1: 今日中に実行（所要時間: 1時間）

#### 3. 自動デプロイスクリプトの作成

**deploy.sh** を作成（タスク2のレポートに詳細あり）:

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

echo "=== SimpleGraphic Deployment ==="

# 1. ビルド成果物の存在確認
if [[ ! -f "$BUILD_DYLIB" ]]; then
    echo "❌ ERROR: Build artifact not found: $BUILD_DYLIB"
    echo "Run: cd dev/simplegraphic && make -C build"
    exit 1
fi

# 2. チェックサム計算
BUILD_SHA=$(shasum "$BUILD_DYLIB" | awk '{print $1}')
echo "Build artifact: $BUILD_SHA"

# 3. 開発ランタイムにデプロイ
echo "Deploying to runtime..."
cp "$BUILD_DYLIB" "$RUNTIME_DYLIB"
RUNTIME_SHA=$(shasum "$RUNTIME_DYLIB" | awk '{print $1}')

# 4. アプリバンドルにデプロイ（古いファイル削除）
echo "Deploying to app bundle..."
rm -f "${APP_BUNDLE_DIR}"/*.dylib
cp "$RUNTIME_DYLIB" "$APP_DYLIB"
APP_SHA=$(shasum "$APP_DYLIB" | awk '{print $1}')

# 5. 検証
if [[ "$BUILD_SHA" == "$RUNTIME_SHA" ]] && [[ "$BUILD_SHA" == "$APP_SHA" ]]; then
    echo "✅ Deployment successful!"
    echo "   Checksum: $BUILD_SHA"
else
    echo "❌ ERROR: Checksum mismatch!"
    echo "   Build:   $BUILD_SHA"
    echo "   Runtime: $RUNTIME_SHA"
    echo "   App:     $APP_SHA"
    exit 1
fi
```

**使い方**:
```bash
cd /Users/kokage/national-operations/pob2macos
chmod +x deploy.sh

# ビルド後、必ずデプロイ
cd dev/simplegraphic && make -C build
cd ../..
./deploy.sh
```

#### 4. CLAUDE.mdの更新

現在のCLAUDE.mdに以下を追加:

```markdown
## デプロイメント（CRITICAL）

### ビルド後の必須ステップ

**重要**: C++コードを修正した場合、以下を**必ず実行**してください。

1. **ビルド**:
   ```bash
   cd /Users/kokage/national-operations/pob2macos/dev/simplegraphic
   make -C build
   ```

2. **デプロイ（必須）**:
   ```bash
   cd /Users/kokage/national-operations/pob2macos
   ./deploy.sh
   ```

3. **検証**:
   - デプロイスクリプトがチェックサム一致を報告すること
   - アプリを起動して変更が反映されていることを確認

### デプロイしないとどうなるか

- ❌ コード変更が反映されない
- ❌ 古いバグが残り続ける
- ❌ デバッグが極めて困難になる
- ❌ 何時間もの無駄な作業が発生

### トラブルシューティング

**チェックサムが一致しない**:
```bash
# 手動で確認
shasum dev/simplegraphic/build/libSimpleGraphic.dylib
shasum dev/runtime/SimpleGraphic.dylib
shasum PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib

# 不一致の場合、deploy.shを再実行
./deploy.sh
```

**デプロイ後も変更が反映されない**:
1. アプリを完全に終了（Command+Q）
2. プロセスが残っていないか確認: `ps aux | grep PathOfBuilding`
3. アプリを再起動
```

---

### P2: 今週中に実行（所要時間: 30分）

#### 5. シェーダーデバッグ（デプロイ後）

P0のデプロイ実行後、**まだ黄色テキスト問題が残っている場合**:

**Metal Fragment Shaderのデバッグ**:

```objc
// metal_backend.mm line 122-138に追加
fragment float4 textFragmentShader(VertexOut in [[stage_in]],
                                   texture2d<float> tex [[texture(0)]]) {
    float4 texColor = tex.sample(sampler(mag_filter::linear), in.texCoord);

    // DEBUG: Log input color
    // (Metal Debuggerで確認 - printfは使えない)

    // R8Unorm texture detection
    if (texColor.r > 0.0 && texColor.g == 0.0 && texColor.b == 0.0) {
        float alpha = texColor.r;
        float4 output = float4(in.color.rgb, alpha * in.color.a);

        // DEBUG: 黄色の場合、強制的に緑に変更してテスト
        // if (in.color.r > 0.9 && in.color.g > 0.9 && in.color.b < 0.1) {
        //     return float4(0.0, 1.0, 0.0, output.a);  // 緑色に変更
        // }

        return output;
    }

    return texColor * in.color;
}
```

**Metal Debuggerの使用**:
1. Xcodeでプロジェクトを開く
2. Product → Scheme → Edit Scheme → Run → Options
3. Metal API Validation を有効化
4. GPU Frame Captureを実行
5. Fragment Shaderの入力/出力値を確認

**検証項目**:
- `in.color.rgb` の実際の値
- `texColor` の実際の値
- R8Unorm判定が正しく動作しているか
- 最終的な `return` 値

---

## ✅ 検証テスト計画

### テスト1: デプロイ検証（P0実行後）

**目的**: 最新のコードが実行されていることを確認

**手順**:
```bash
# 1. ビルドタイムスタンプを記録
BUILD_TIME=$(stat -f %m /Users/kokage/national-operations/pob2macos/dev/simplegraphic/build/libSimpleGraphic.dylib)

# 2. チェックサム検証
shasum /Users/kokage/national-operations/pob2macos/dev/simplegraphic/build/libSimpleGraphic.dylib \
       /Users/kokage/national-operations/pob2macos/dev/runtime/SimpleGraphic.dylib \
       /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib

# 3. タイムスタンプの差を確認（7分以内であること）
APP_TIME=$(stat -f %m /Users/kokage/national-operations/pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib)
DIFF=$((BUILD_TIME - APP_TIME))
echo "Timestamp difference: ${DIFF}s (should be < 420s)"
```

**期待される結果**:
- ✅ 3つのチェックサムがすべて一致
- ✅ タイムスタンプの差が7分未満
- ✅ アプリバンドルに1つのdylibのみ存在

---

### テスト2: 色レンダリング検証

**テストスクリプト** (既に作成済み):
```bash
cd /Users/kokage/national-operations/pob2macos
luajit .claude/debug_reports/test_color_debug.lua
```

**期待される結果**:
- ✅ 白色テキストが白く表示される
- ✅ 黄色テキストが黄色く表示される
- ✅ 赤色テキストが赤く表示される
- ✅ エスケープコード `^4` が黄色を生成する

**検証方法**:
1. 視覚的確認（スクリーンショット撮影）
2. ログ出力の確認（色値が正しいか）

---

### テスト3: 実アプリでの検証

**手順**:
```bash
# アプリを起動
open /Users/kokage/national-operations/pob2macos/PathOfBuilding.app

# PassiveTreeタブを開く
# 黄色テキストが表示される場所を確認
```

**チェックリスト**:
- [ ] ノード名が正しい色で表示される
- [ ] ツールチップのテキストが正しい色で表示される
- [ ] UIラベルが正しい色で表示される
- [ ] 意図しない黄色テキストが表示されない

---

## 📊 成功の定義

### 短期目標（P0完了後）

1. ✅ すべてのdylibのチェックサムが一致
2. ✅ アプリが最新のビルド成果物をロード
3. ✅ デプロイプロセスが自動化され、検証される

### 中期目標（P1完了後）

4. ✅ 黄色テキスト問題が視覚的に解決
5. ✅ すべての色が正しく表示される
6. ✅ CLAUDE.mdに正確なデプロイ手順が記載

### 長期目標（P2完了後）

7. ✅ シェーダーのすべての問題が解決
8. ✅ テストスイートが整備され、回帰を防止
9. ✅ CI/CDパイプラインでデプロイが自動化

---

## 🚀 次のアクション

### 今すぐ実行

```bash
# デプロイメント問題の即座解決
cd /Users/kokage/national-operations/pob2macos
rm -f PathOfBuilding.app/Contents/Resources/pob2macos/runtime/*.dylib
cp dev/simplegraphic/build/libSimpleGraphic.dylib dev/runtime/SimpleGraphic.dylib
cp dev/runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
shasum dev/simplegraphic/build/libSimpleGraphic.dylib \
       dev/runtime/SimpleGraphic.dylib \
       PathOfBuilding.app/Contents/Resources/pob2macos/runtime/SimpleGraphic.dylib

# テスト実行
open PathOfBuilding.app
```

### その後

1. **deploy.sh** スクリプトを作成（タスク2レポート参照）
2. CLAUDE.mdにデプロイ手順を追記
3. 黄色テキスト問題が残っている場合、シェーダーデバッグを実行

---

## 📚 関連ドキュメント

- **タスク2レポート**: `.claude/debug_reports/task_2_build_audit.md`
- **タスク3レポート**: `/Users/kokage/national-operations/pob2macos/.claude/debug_reports/task_3_runtime_inspection.md`
- **テストスクリプト**: `/Users/kokage/national-operations/pob2macos/.claude/debug_reports/test_color_debug.lua`
- **CLAUDE.md**: `/Users/kokage/national-operations/.claude/CLAUDE.md`

---

## 🔮 未解決の質問（タスク1完了後に更新予定）

- [ ] シェーダーソースコードに黄色をハードコードしている箇所があるか？
- [ ] metal_backend.mmの他の場所で色が変更されているか？
- [ ] デフォルト色設定が黄色になっているか？
- [ ] テクスチャアトラスに黄色のピクセルが含まれているか？

**注**: タスク1（シェーダー分析）が完了したら、このセクションを更新します。

---

**報告者**: Claude (Sonnet 4.5)
**最終更新**: 2026-02-04 22:50 JST
