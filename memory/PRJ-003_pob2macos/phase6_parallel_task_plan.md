# Phase 6 統合テスト並列タスク計画
**Mayor Assignment on On_Prophet_Revelation**

**Date**: 2026-01-29
**Project**: PRJ-003 PoB2macOS Phase 6
**Status**: 承認済み - 5人の村人へ並列割り振り実施
**Skill Validation Protocol**: 各村人の報告品質基準を定義済み

---

## 0. 現在の状況（Phase 5 完了）

### ビルド状況
```
✅ libsimplegraphic.a 完成
✅ MVP テスト: 12/12 PASS (100%)
✅ SimpleGraphic API 18個実装完成
✅ Lua バインディング登録完成
```

### セキュリティ状況
```
✅ CRITICAL 2件修正済
✅ HIGH 4件修正済
⚠️  MEDIUM 4件残存 (Paladin が担当)
```

### PoB2 統合分析完了
```
✅ Launch.lua 分析完了 (起動シーケンス確認)
✅ Main.lua 分析開始 (UI 初期化フロー確認)
✅ 不足 API リスト特定完了
✅ 4段階統合テスト計画書完成
```

---

## 1. Phase 6 目標

Sage の統合テスト計画に基づき、以下を並列実施:

1. **Launch.lua/Main.lua の詳細分析** → API 補完
2. **不足 API 実装** → ConExecute, ConClear, Copy, TakeScreenshot
3. **FreeType テキストレンダリング本実装**
4. **段階的統合テスト実施** (STAGE 1-4)
5. **セキュリティレビュー** + ドキュメント更新

---

## 2. 5人の村人タスク割り振り

### ========================================
### Sage (賢者) - 知識者・分析役
### ========================================

**役割**: PoB2 起動シーケンス分析、API 補完計画、テストスクリプト設計

#### 【T6-S1】PoB2 Launch.lua 詳細分析
**Status**: pending → in_progress → completed
**期限**: 2026-01-29
**成果物**: `/Users/kokage/national-operations/claudecode01/memory/sage_launch_analysis.md`

**実施内容**:
1. Launch.lua の実行フロー詳細解析
   - GetTime() → SetWindowTitle() → ConExecute() の依存関係
   - SetMainObject() と launch オブジェクトの接続確認
   - jit.opt と GC 設定の影響分析

2. 呼び出される SimpleGraphic API リスト確定
   ```
   ✅ RenderInit("DPI_AWARE")        [Line 68]
   ✅ SetWindowTitle(APP_NAME)       [Line 11]
   ✅ SetMainObject(launch)          [Line 16]
   ✅ GetScreenSize()                [Line 125 - main/launch:OnFrame]
   ✅ IsKeyDown()                    [Line 117, 154, 158, 360]
   ✅ GetTime()                      [Line 8, 26, 132]
   ✅ SetDrawLayer(), SetViewport()  [Line 118, 119]
   ✅ DrawString(), DrawImage()      [Line 129, 127, 392-404]
   ⚠️  ConExecute()                  [Line 12, 13] - スタブ確認
   ⚠️  ConClear(), ConPrintf()       [Line 35, 36] - スタブ確認
   ⚠️  Copy()                        [Line 362] - クリップボード実装確認
   ⚠️  TakeScreenshot()              [Line 159] - スクリーンショット確認
   ⚠️  Restart(), Exit()             [Line 130, 326] - 終了フロー確認
   ```

3. Main.lua の初期化フロー分析
   - ControlHost 作成メカニズム
   - Init() コールバックシーケンス
   - OnFrame(), OnKeyDown() などのイベントハンドラー

4. 統合ポイント特定
   - Launch.lua は **変更不要** (API 互換)
   - Main.lua は **変更不要** (API 互換)
   - スタブ実装が必要な 5 API を明確化

5. テストスクリプト基本設計書作成
   - STAGE 1-4 の詳細テストシナリオ
   - 予想される問題と対策

**成功基準**:
- [ ] Launch.lua の実行フロー図作成 (イベント駆動、OnInit→OnFrame→OnExit)
- [ ] API 呼び出し依存グラフ作成
- [ ] スタブ実装 5 API の仕様書完成
- [ ] STAGE 1-4 テストスクリプト基本骨子完成
- [ ] リスク分析と対策案を記載

**Skill Validation**:
- 報告文書の詳細度: 実装担当者が直接参照可能なレベル
- 図表品質: Artisan が実装時に参照できる精度
- 技術正確性: PoB2 公式コード との整合性確認済み

---

#### 【T6-S2】不足 API の仕様書作成
**Status**: pending → in_progress → completed
**期限**: 2026-01-29
**成果物**: `/Users/kokage/national-operations/claudecode01/memory/stub_api_specs.md`

**実施内容**:
1. ConExecute(cmd) の仕様確定
   ```
   用途: PoB2 コンソールコマンド実行（ビデオモード設定など）
   パラメータ: cmd (string)
   戻り値: なし
   実装: printf ログのみ（ビデオモード設定は無視）
   リスク: なし（ウィンドウ描画に直接影響なし）
   ```

2. ConClear(), ConPrintf() の仕様確定

3. Copy(text) の仕様確定
   ```
   用途: テキスト → クリップボード
   パラメータ: text (string)
   戻り値: なし
   実装: macOS の NSPasteboard または xclip (Linux) 使用
   優先度: MEDIUM (エラーメッセージコピーのみ)
   ```

4. TakeScreenshot() の仕様確定
   ```
   用途: スクリーンショット保存
   パラメータ: なし
   戻り値: なし
   実装: OpenGL バックバッファから PNG 保存
   優先度: LOW (オプション機能、スキップ可能)
   ```

5. Restart(), Exit() の仕様確定

**成功基準**:
- [ ] 各 API の完全仕様書完成 (パラメータ、戻り値、副作用、エラーハンドリング)
- [ ] 実装難易度と優先度の分類完成
- [ ] C/Lua バインディング実装ガイド完成

---

#### 【T6-S3】統合テスト Stage 1 テストスクリプト作成
**Status**: pending → in_progress → completed
**期限**: 2026-01-29
**成果物**: `/Users/kokage/national-operations/pob2macos/tests/stage1_window_test.lua`

**実施内容**:
1. ウィンドウ表示テストスクリプト実装
   ```lua
   -- tests/stage1_window_test.lua
   -- 目的: RenderInit + SetWindowTitle + GetScreenSize の動作確認
   -- 期待: ウィンドウ 5秒表示 → 正常終了
   ```

2. テスト実行手順書作成
   ```
   1. RenderInit("DPI_AWARE") 実行確認
   2. SetWindowTitle() でタイトル確認
   3. GetScreenSize() で寸法確認
   4. ウィンドウ表示 5秒
   5. 正常に終了できることを確認
   ```

3. 期待される出力値・ログ定義

**成功基準**:
- [ ] スクリプト実装完成、構文チェック合格
- [ ] 実行手順書完成
- [ ] 期待される出力例を含む

**Skill Validation Protocol**:
- コード品質: Artisan が直接実行可能
- ドキュメント品質: Merchant が実行・検証可能

---

### ========================================
### Artisan (職人) - 実装者
### ========================================

**役割**: API 実装、テストスクリプト実装、Lua バインディング追加

#### 【T6-A1】不足 API スタブ実装
**Status**: pending → in_progress → completed
**期限**: 2026-01-30
**成果物**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_stubs.c`

**実施内容**:
1. ConExecute() 実装
   ```c
   // sg_stubs.c
   static int lua_ConExecute(lua_State *L)
   {
       const char *cmd = luaL_optstring(L, 1, "");
       printf("[ConExecute] %s\n", cmd);
       // ビデオモード設定などは無視
       return 0;
   }
   ```

2. ConClear() 実装
3. Copy() 実装 (macOS NSPasteboard 使用)
4. TakeScreenshot() 実装 (簡易版: ログのみ)
5. Restart() 実装 (スタブ)

2. Lua グローバル登録
   ```c
   // sg_lua_binding.c に追加
   lua_register(L, "ConExecute", lua_ConExecute);
   lua_register(L, "ConClear", lua_ConClear);
   lua_register(L, "Copy", lua_Copy);
   lua_register(L, "TakeScreenshot", lua_TakeScreenshot);
   lua_register(L, "Restart", lua_Restart);
   ```

**成功基準**:
- [ ] 5 つの API が全て実装完成
- [ ] CMakeLists.txt に sg_stubs.c を追加
- [ ] ビルド成功 (libsimplegraphic.a 生成)
- [ ] Lua バインディング動作確認

**テスト方法**:
```lua
-- tests/test_stubs.lua
print(type(ConExecute))  -- function
print(type(ConClear))    -- function
print(type(Copy))        -- function
print(type(TakeScreenshot)) -- function
```

---

#### 【T6-A2】FreeType テキストレンダリング本実装
**Status**: pending → in_progress → completed
**期限**: 2026-01-31
**成果物**: `/Users/kokage/national-operations/pob2macos/src/simplegraphic/sg_text.c` (拡張)

**現在の状況**: Phase 5 で LoadFont, DrawString の基本実装は完成

**実施内容**:
1. フォントキャッシュの最適化
   ```c
   #define MAX_CACHED_FONTS 32
   #define MAX_FONT_SIZE 72

   // LRU キャッシュ実装（古いフォントから削除）
   typedef struct {
       char name[64];
       int size;
       FT_Face face;
       time_t last_used;
   } FontCacheEntry;
   ```

2. DrawStringWidth() の精度向上
   - アラインメント計算の修正
   - UTF-8 マルチバイト文字への対応

3. テキストテクスチャキャッシュの実装
   - 同じテキストの重複生成を回避
   - GPU メモリ管理

4. ドキュメント更新
   - FreeType 依存関係の明示
   - パフォーマンス特性 (フォント読み込み時間など)

**成功基準**:
- [ ] 32 フォントまでキャッシュ可能
- [ ] テキスト幅測定の誤差 < 1%
- [ ] 日本語テキスト (UTF-8) も正しく処理
- [ ] STAGE 3 テスト (text_test.lua) に合格

---

#### 【T6-A3】STAGE 2 基本描画テスト実装
**Status**: pending → in_progress → completed
**期限**: 2026-01-30
**成果物**: `/Users/kokage/national-operations/pob2macos/tests/stage2_draw_test.lua`

**実施内容**:
1. stage2_draw_test.lua 実装
   ```lua
   -- 確認項目:
   -- 1. SetClearColor が反映される
   -- 2. SetDrawColor が反映される
   -- 3. DrawImage(nil, x, y, w, h) で矩形描画できる
   -- 4. 複数色の矩形を重ねられる
   -- 5. アルファブレンディングが動作する
   ```

2. グリッド・カラーパレット描画テスト
3. 実行結果スクリーンショット (手動確認)

**成功基準**:
- [ ] スクリプト実装完成
- [ ] グリッド表示確認
- [ ] 4 色パレット表示確認
- [ ] アルファブレンディング確認

---

#### 【T6-A4】STAGE 3 テキスト描画テスト実装
**Status**: pending → in_progress → completed
**期限**: 2026-01-31
**成果物**: `/Users/kokage/national-operations/pob2macos/tests/stage3_text_test.lua`

**実施内容**:
1. stage3_text_test.lua 実装
   ```lua
   -- 確認項目:
   -- 1. LoadFont() でシステムフォント読み込み
   -- 2. DrawString() でテキスト表示
   -- 3. 配置 (LEFT/CENTER/RIGHT) が正しい
   -- 4. DrawStringWidth() で幅測定
   -- 5. 複数サイズのテキスト表示
   ```

2. フォント読み込みエラーハンドリング
3. テキスト配置の自動検証

**成功基準**:
- [ ] 3 種類のアラインメント (LEFT/CENTER/RIGHT) で表示
- [ ] 複数フォントサイズで表示 (12, 16, 20pt)
- [ ] テキスト幅測定が正確

---

#### 【T6-A5】STAGE 4 完全統合テスト実装
**Status**: pending → in_progress → completed
**期限**: 2026-02-02
**成果物**: `/Users/kokage/national-operations/pob2macos/tests/stage4_full_integration.lua`

**実施内容**:
1. Launch.lua + Main.lua 完全統合スクリプト実装
2. キー入力テスト
3. マウス入力テスト
4. UI レイアウト確認
5. 30分連続実行テスト

**成功基準**:
- [ ] Launch.lua が正常に実行される
- [ ] Main.lua が正常に初期化される
- [ ] UI 画面が表示される
- [ ] キー入力が反応する
- [ ] 30分実行後、メモリリークなし

---

#### 【T6-A6】テスト結果レポート作成
**Status**: pending → in_progress → completed
**期限**: 2026-02-02
**成果物**: `/Users/kokage/national-operations/pob2macos/tests/INTEGRATION_TEST_REPORT.md`

**実施内容**:
1. STAGE 1-4 各段階の実行結果記録
2. 検出されたバグ・問題点のリスト
3. パフォーマンス計測 (FPS, メモリ使用量)
4. スクリーンショット・ログの添付

**成功基準**:
- [ ] 全 4 段階の実行結果を記載
- [ ] 各テストアイテムの合格/不合格を明記
- [ ] 問題検出時は詳細なスタックトレース付き

---

### ========================================
### Paladin (聖騎士) - セキュリティ・品質保証
### ========================================

**役割**: セキュリティレビュー、メモリリーク検出、品質管理

#### 【T6-P1】残存 MEDIUM セキュリティ 4 件対応
**Status**: pending → in_progress → completed
**期限**: 2026-01-31
**成果物**: `/Users/kokage/national-operations/claudecode01/memory/security_fixes_phase6.md`

**実施内容**:
前フェーズから残存している MEDIUM レベルセキュリティ問題を特定・修正

1. 問題特定と現状分析
   ```
   - コード分析ツール (clang-analyzer など) で再スキャン
   - 前フェーズの報告から MEDIUM 4 件を抽出
   - 優先度を再評価（Critical > High > Medium）
   ```

2. 修正実装
   - バッファオーバーフロー対策
   - 不適切なポインタ操作の修正
   - リソース解放漏れの修正

3. テスト
   - 修正前後でビルド成功確認
   - MVP テスト 12/12 が引き続き合格することを確認

**成功基準**:
- [ ] MEDIUM 4 件全て修正完了
- [ ] ビルド成功 (警告なし)
- [ ] MVP テスト 12/12 PASS

**Skill Validation**:
- 報告品質: セキュリティ修正の理由と効果を明示
- 検証方法: コード分析ツール結果を添付

---

#### 【T6-P2】Phase 6 新規コードのセキュリティレビュー
**Status**: pending → in_progress → completed
**期限**: 2026-02-01
**成果物**: `/Users/kokage/national-operations/claudecode01/memory/phase6_security_review.md`

**実施内容**:
1. Artisan が実装した新規コード (sg_stubs.c, sg_text.c 拡張) のレビュー
   - メモリリーク検査
   - バッファオーバーフロー検査
   - 不正なメモリアクセス検査

2. Sage が作成したテストスクリプト (Lua) のレビュー
   - リソースリーク確認
   - 例外処理の安全性確認

3. 新規の高リスク API (Copy など) の安全性レビュー

**成功基準**:
- [ ] クリティカル問題: 0 件
- [ ] ハイレベル問題: 0 件
- [ ] 中程度問題: < 2 件（許容範囲）

---

#### 【T6-P3】メモリリーク検出テスト
**Status**: pending → in_progress → completed
**期限**: 2026-02-01
**成果物**: `/Users/kokage/national-operations/claudecode01/memory/memcheck_report_phase6.md`

**実施内容**:
1. valgrind (Linux) または Instruments (macOS) を使用したメモリチェック
2. 各統合テスト (STAGE 1-4) の実行時メモリ使用量監視
3. メモリリーク検出と原因分析

**テスト対象**:
- STAGE 1: ウィンドウ表示 (5秒)
- STAGE 2: 基本描画 (30フレーム)
- STAGE 3: テキスト描画 (30フレーム + フォント読み込み)
- STAGE 4: 完全統合 (30分連続)

**成功基準**:
- [ ] STAGE 1-3: メモリリークなし
- [ ] STAGE 4: 長時間実行でメモリ増加 < 100MB
- [ ] 報告書にメモリグラフ・統計情報を含む

---

### ========================================
### Merchant (商人) - テスト実行・最適化
### ========================================

**役割**: 統合テスト実行、パフォーマンス測定、ビルド最適化

#### 【T6-M1】STAGE 1 ウィンドウ表示テスト実行
**Status**: pending → in_progress → completed
**期限**: 2026-01-29
**成果物**: `/Users/kokage/national-operations/pob2macos/tests/STAGE1_RESULTS.md`

**実施内容**:
1. stage1_window_test.lua の実行
   ```bash
   cd /Users/kokage/national-operations/pob2macos
   lua tests/stage1_window_test.lua
   ```

2. 確認項目の検証
   - ウィンドウが表示されるか
   - タイトルが正しいか
   - GetScreenSize() が正しい値を返すか
   - 5秒後に正常に終了するか

3. スクリーンショット・ログ記録

**成功基準**:
- [ ] ウィンドウ表示成功
- [ ] タイトル確認: "Path of Building (PoE2)"
- [ ] 画面寸法確認: 1920x1080 (環境依存)
- [ ] 正常終了確認

**Skill Validation**:
- 報告品質: ユーザーが実行結果を一見で理解できるレベル
- スクリーンショット: ウィンドウタイトルと寸法が見える形で添付

---

#### 【T6-M2】STAGE 2-3 描画・テキストテスト実行
**Status**: pending → in_progress → completed
**期限**: 2026-01-31
**成果物**: `/Users/kokage/national-operations/pob2macos/tests/STAGE2_RESULTS.md` および `/Users/kokage/national-operations/pob2macos/tests/STAGE3_RESULTS.md`

**実施内容**:
1. stage2_draw_test.lua の実行と確認
   - グリッド表示
   - カラーパレット表示
   - アルファブレンディング表示
   - スクリーンショット記録

2. stage3_text_test.lua の実行と確認
   - テキスト表示確認 (3 アラインメント)
   - フォントサイズ確認
   - テキスト幅測定精度確認
   - スクリーンショット記録

**成功基準**:
- [ ] グリッド表示確認
- [ ] 4 色パレット正しく表示
- [ ] テキスト 3 アラインメント正しく表示
- [ ] フォントサイズの違いが目視確認可能

---

#### 【T6-M3】STAGE 4 完全統合テスト実行
**Status**: pending → in_progress → completed
**期限**: 2026-02-02
**成果物**: `/Users/kokage/national-operations/pob2macos/tests/STAGE4_RESULTS.md`

**実施内容**:
1. stage4_full_integration.lua の実行
   ```bash
   cd /Users/kokage/national-operations/pob2macos
   lua tests/stage4_full_integration.lua
   ```

2. 確認項目
   - Launch.lua 実行成功
   - Main.lua 初期化成功
   - UI 画面表示
   - キー入力反応テスト
   - マウス入力反応テスト
   - 30分連続実行（メモリリークなし）

3. パフォーマンス計測
   - FPS (目標: 60+ FPS)
   - GPU 使用率 (目標: < 50%)
   - メモリ使用量 (目標: < 500MB)

**成功基準**:
- [ ] ウィンドウ表示成功
- [ ] UI 画面表示確認
- [ ] キー入力反応確認
- [ ] FPS 60+ 維持
- [ ] メモリ使用量安定

---

#### 【T6-M4】パフォーマンスベースライン測定
**Status**: pending → in_progress → completed
**期限**: 2026-02-01
**成果物**: `/Users/kokage/national-operations/pob2macos/PERFORMANCE_BASELINE.md`

**実施内容**:
1. ベースラインテスト実施
   ```
   環境: macOS 25.2.0 (Darwin)
   CPU: [自動検出]
   GPU: [自動検出]
   メモリ: [自動検出]
   ```

2. 計測項目
   - アイドル時メモリ使用量
   - フレームレート (60 FPS 制御下)
   - GPU メモリ使用量
   - CPU 使用率

3. グラフ・表作成
   - 時間軸メモリ使用量グラフ
   - FPS 時系列グラフ

**成功基準**:
- [ ] ベースライン値を定義
- [ ] グラフを含むドキュメント作成
- [ ] 将来のパフォーマンス回帰テストの基準となる

---

#### 【T6-M5】ビルドシステム最適化
**Status**: pending → in_progress → completed
**期限**: 2026-02-01
**成果物**: `/Users/kokage/national-operations/pob2macos/build/CMAKE_OPTIMIZATION_REPORT.md`

**実施内容**:
1. CMakeLists.txt の最適化
   - インクリメンタルビルドの改善
   - リンク時間の短縮
   - キャッシュ活用

2. リリースビルド設定確認
   ```
   CMAKE_BUILD_TYPE=Release
   -O3 最適化フラグ
   LTO (Link Time Optimization) 有効化検討
   ```

3. ビルド時間計測
   - クリーンビルド時間
   - インクリメンタルビルド時間

**成功基準**:
- [ ] ビルド時間短縮 (目標: < 60秒)
- [ ] ビルド成功、警告なし
- [ ] 実行時パフォーマンス改善確認

---

### ========================================
### Bard (吟遊詩人) - ドキュメント・コミュニケーション
### ========================================

**役割**: ドキュメント作成、API マトリクス更新、ユーザーガイド拡充

#### 【T6-B1】Phase 6 進捗ドキュメント
**Status**: pending → in_progress → completed
**期限**: 2026-02-02
**成果物**: `/Users/kokage/national-operations/claudecode01/memory/phase6_progress.md`

**実施内容**:
1. 日次進捗記録テンプレート
   ```
   - 2026-01-29: Sage 分析開始、Artisan API 実装開始
   - 2026-01-30: STAGE 1 テスト実施、Artisan STAGE 2-3 テスト実装
   - 2026-01-31: STAGE 2-3 テスト実施、Paladin セキュリティレビュー
   - 2026-02-01: STAGE 4 テスト実施、Merchant パフォーマンス計測
   - 2026-02-02: 全テスト完了、最終レポート作成
   ```

2. マイルストーン達成状況記録
   - STAGE 1 ウィンドウ表示: [予定日]
   - STAGE 2 基本描画: [予定日]
   - STAGE 3 テキスト: [予定日]
   - STAGE 4 完全統合: [予定日]

3. リスク・課題の追跡

**成功基準**:
- [ ] 全マイルストーン記録完成
- [ ] 課題は自動で Paladin への記録に反映

---

#### 【T6-B2】API 互換性マトリクス更新
**Status**: pending → in_progress → completed
**期限**: 2026-02-02
**成果物**: `/Users/kokage/national-operations/claudecode01/memory/api_compatibility_matrix.md`

**実施内容**:
1. SimpleGraphic API カバレッジマトリクス
   ```
   | API | 実装状況 | Launch.lua | Main.lua | テスト | 備考 |
   |-----|--------|-----------|---------|--------|------|
   | RenderInit | ✅ 完成 | ✅ | N/A | STAGE 1 | Phase 4 完成 |
   | SetWindowTitle | ✅ 完成 | ✅ | N/A | STAGE 1 | Phase 4 完成 |
   | ... | ... | ... | ... | ... | ... |
   | ConExecute | ✅ スタブ | ✅ | N/A | STAGE 1 | Phase 6 実装 |
   | Copy | ✅ スタブ | N/A | ✅ | STAGE 4 | Phase 6 実装 |
   ```

2. PoB2 API 要件 vs SimpleGraphic API マッピング
   - 欠落 API なし確認
   - 代替実装の有無確認

3. プラットフォーム互換性マトリクス
   - macOS: [対応状況]
   - Linux: [対応状況]

**成功基準**:
- [ ] 全 API のカバレッジ確認
- [ ] テスト実施状況を反映

---

#### 【T6-B3】ユーザーガイド更新
**Status**: pending → in_progress → completed
**期限**: 2026-02-02
**成果物**: `/Users/kokage/national-operations/pob2macos/GETTING_STARTED.md` (新規/更新)

**実施内容**:
1. インストール・ビルド手順
   ```
   1. 前提条件: GLFW3, FreeType, CMake
   2. ビルド手順: cmake && cmake --build .
   3. 実行手順: lua tests/stage1_window_test.lua
   ```

2. トラブルシューティング
   - よくある問題と解決方法
   - GLFW ウィンドウ作成失敗時の対処
   - フォント読み込みエラー対応

3. API リファレンス要約
   - 主要 API 18 個の簡潔説明
   - 使用例

**成功基準**:
- [ ] ユーザーが完全に理解できるレベルのドキュメント
- [ ] スクリーンショット・図表を含む

---

#### 【T6-B4】セキュリティ・パフォーマンスレポート統合
**Status**: pending → in_progress → completed
**期限**: 2026-02-02
**成果物**: `/Users/kokage/national-operations/claudecode01/memory/phase6_final_report.md`

**実施内容**:
1. 全チームの報告を統合
   - Sage の分析報告
   - Artisan のテスト実装報告
   - Paladin のセキュリティ報告
   - Merchant のパフォーマンス報告

2. エグゼクティブサマリー作成
   ```
   Phase 6 統合テスト: [成功/失敗]
   主要な達成: ...
   残存する課題: ...
   推奨事項: ...
   ```

3. 次フェーズ (Phase 7) への推奨事項記載

**成功基準**:
- [ ] 全報告を統合したドキュメント完成
- [ ] エグゼクティブサマリー作成完了
- [ ] 全チームの意見が反映されている

---

## 3. 並列実行スケジュール

### Week 1 (2026-01-29)

**並列実行タスク**:
```
Sage:
  ├─ T6-S1: Launch.lua 詳細分析 (Start)
  ├─ T6-S2: 不足 API 仕様書 (Start)
  └─ T6-S3: STAGE 1 テストスクリプト (Start)

Artisan:
  ├─ T6-A1: 不足 API スタブ実装 (Start)
  └─ T6-A3: STAGE 2 テスト実装 (Start)

Merchant:
  └─ T6-M1: STAGE 1 テスト実行 (準備)

Paladin:
  ├─ T6-P1: MEDIUM セキュリティ対応 (Start)
  └─ T6-P2: Phase 6 コード レビュー準備

Bard:
  ├─ T6-B1: 進捗ドキュメント (Start)
  └─ T6-B3: ユーザーガイド (Start)
```

**マイルストーン** (2026-01-30):
- ✅ Sage: T6-S1, T6-S2, T6-S3 完成
- ✅ Artisan: T6-A1 完成 (ビルド成功)
- ✅ Merchant: T6-M1 実施 (STAGE 1 テスト実行)

### Week 2 (2026-01-31 - 2026-02-02)

**並列実行タスク**:
```
Artisan:
  ├─ T6-A2: FreeType テキストレンダリング (Continue)
  ├─ T6-A4: STAGE 3 テスト実装 (Start)
  └─ T6-A5: STAGE 4 テスト実装 (Start)

Merchant:
  ├─ T6-M2: STAGE 2-3 テスト実行
  ├─ T6-M3: STAGE 4 テスト実行
  ├─ T6-M4: パフォーマンスベースライン計測
  └─ T6-M5: ビルド最適化

Paladin:
  ├─ T6-P2: セキュリティレビュー
  └─ T6-P3: メモリリーク検出テスト

Bard:
  ├─ T6-B2: API マトリクス更新
  ├─ T6-B4: 最終レポート統合 (準備)
  └─ T6-B3: ユーザーガイド (Continue)

Artisan:
  └─ T6-A6: テスト結果レポート作成 (End)
```

**マイルストーン** (2026-02-02):
- ✅ STAGE 1-4 全テスト実施完了
- ✅ セキュリティレビュー完了
- ✅ パフォーマンスベースライン確立
- ✅ 全ドキュメント完成

---

## 4. 成功基準 (Skill Validation Protocol)

### 各村人の報告品質基準

#### Sage (知識者)
```
✅ 報告の完全性:
   - 技術的に正確で、実装者が直接参照可能
   - 図表・フロー図を含む
   - リスク分析と対策を記載

✅ 深さ:
   - Launch.lua 全 406 行の理解確認
   - API 呼び出し依存グラフ完成
   - スタブ仕様書は実装可能なレベル

✅ スキル検証:
   - PoB2 公式コードとの整合性チェック済み
   - テストスクリプト基本骨子は Artisan が直接使用可能
```

#### Artisan (職人)
```
✅ 実装の完全性:
   - ビルド成功（警告なし）
   - 全テストスクリプト動作確認
   - API スタブ 5 つ全て実装

✅ コード品質:
   - メモリリークなし
   - 例外処理完成
   - Lua バインディング登録確認

✅ スキル検証:
   - MVP テスト 12/12 引き続き PASS
   - 新規コードもセキュリティレビュー合格
```

#### Paladin (聖騎士)
```
✅ セキュリティ:
   - MEDIUM 4 件全て修正
   - 新規コード 0 件のクリティカル問題
   - メモリリーク検出テスト完成

✅ 報告品質:
   - セキュリティ修正の理由を明示
   - メモリグラフ・統計情報を含む
   - 将来の監視項目を定義

✅ スキル検証:
   - 分析ツール (clang-analyzer, valgrind) 使用確認
   - リスク再評価（初回からの進捗）
```

#### Merchant (商人)
```
✅ テスト実施:
   - 4 段階テスト全て実施
   - スクリーンショット・ログ記録
   - パフォーマンス計測完成

✅ 報告品質:
   - ユーザーが一見で理解可能
   - 問題発見時は詳細なスタックトレース
   - パフォーマンスグラフを含む

✅ スキル検証:
   - テスト実施手順書を正確に実行
   - パフォーマンス計測ツール使用確認
   - リスク検出時の報告体制確立
```

#### Bard (吟遊詩人)
```
✅ ドキュメント品質:
   - 日本語・英語の両言語対応検討
   - ユーザーが理解可能なレベル
   - スクリーンショット・図表を含む

✅ 統合性:
   - 全チームの報告を統合
   - エグゼクティブサマリーは経営層向け
   - 技術詳細は附属資料に記載

✅ スキル検証:
   - API マトリクスは実装者向け
   - ユーザーガイドはエンドユーザー向け
   - 2 つの視点で正確に記載
```

---

## 5. 成果物一覧

### Sage (賢者) 成果物
```
✅ sage_launch_analysis.md
   └─ Launch.lua フロー図、API 呼び出し依存グラフ

✅ stub_api_specs.md
   └─ 5 API の完全仕様書

✅ stage1_window_test.lua (template)
   └─ テストスクリプト基本骨子
```

### Artisan (職人) 成果物
```
✅ src/simplegraphic/sg_stubs.c
   └─ ConExecute, ConClear, Copy, TakeScreenshot, Restart

✅ src/simplegraphic/sg_text.c (拡張)
   └─ フォントキャッシュ最適化

✅ tests/stage1_window_test.lua (実装版)
✅ tests/stage2_draw_test.lua
✅ tests/stage3_text_test.lua
✅ tests/stage4_full_integration.lua

✅ tests/INTEGRATION_TEST_REPORT.md
   └─ 全段階のテスト結果
```

### Paladin (聖騎士) 成果物
```
✅ security_fixes_phase6.md
   └─ MEDIUM 4 件の修正詳細

✅ phase6_security_review.md
   └─ 新規コードセキュリティレビュー

✅ memcheck_report_phase6.md
   └─ メモリリーク検出レポート、グラフ付き
```

### Merchant (商人) 成果物
```
✅ tests/STAGE1_RESULTS.md
✅ tests/STAGE2_RESULTS.md
✅ tests/STAGE3_RESULTS.md
✅ tests/STAGE4_RESULTS.md

✅ PERFORMANCE_BASELINE.md
   └─ FPS, メモリ使用量グラフ

✅ build/CMAKE_OPTIMIZATION_REPORT.md
   └─ ビルド時間計測結果
```

### Bard (吟遊詩人) 成果物
```
✅ phase6_progress.md
   └─ 日次進捗記録

✅ api_compatibility_matrix.md
   └─ API カバレッジマトリクス

✅ GETTING_STARTED.md
   └─ ユーザーガイド

✅ phase6_final_report.md
   └─ 統合最終レポート、エグゼクティブサマリー
```

---

## 6. リスク管理

### 高リスク項目

| # | リスク | 影響 | 対策 | 監視者 |
|---|--------|------|------|--------|
| R1 | GLFW ウィンドウ作成失敗 | STAGE 1 失敗 | 事前環境確認 | Sage, Merchant |
| R2 | FreeType 初期化エラー | STAGE 3 失敗 | フォント読み込みエラー処理 | Artisan |
| R3 | Lua FFI バインディング未登録 | すべてのテスト失敗 | 動作確認スクリプト | Sage |
| R4 | メモリリーク (STAGE 4) | 長時間実行不可 | valgrind 検査 | Paladin |
| R5 | セキュリティ MEDIUM 修正ミス | MVP テスト失敗 | レビュー重視 | Paladin |

### 対応策

**リスク R1-R3**: Sage がテストスクリプト基本骨子で事前検証
**リスク R4**: Merchant が STAGE 4 実行時にリアルタイムメモリ監視
**リスク R5**: Paladin が MVP テスト 12/12 再実施で確認

---

## 7. コミュニケーション

### 日次ミーティング

```
時刻: 毎日 09:00 JST (30分)
参加: Mayor + 5人の村人

Agenda:
1. 前日の達成状況共有 (Bard が進捗ドキュメント報告)
2. 本日の予定確認
3. ブロッカーの即時解決 (Mayor が調整)
4. リスク情報共有 (Paladin が報告)
```

### 報告ルール

```
✅ 完了時: 成果物 + チェックリスト確認
⚠️  途中発見問題: 即日 Paladin に報告
🚨 ブロッカー: 即座に Mayor に escalate
```

---

## 8. 次フェーズ (Phase 7) への推奨事項

### Phase 6 終了時の状態

```
✅ PoB2 が macOS で完全に動作する基盤整備完了
✅ 統合テスト 4 段階全て合格
✅ セキュリティ: CRITICAL/HIGH 全て修正済み
⚠️  セキュリティ MEDIUM: [残存数] 件（許容範囲）
```

### Phase 7 推奨タスク

1. **UI 機能補完**
   - 設定画面実装
   - ビルド保存/読み込み機能

2. **パフォーマンス最適化**
   - GPU キャッシュ活用
   - フォント読み込み最適化

3. **ドキュメント完成**
   - API リファレンス (HTML)
   - チュートリアル作成

---

## まとめ

Phase 6 は **5人の村人による並列実行で、統合テスト計画を完全実施** します。

### 成功の鍵

```
✅ Sage: 詳細な分析とリスク事前把握
✅ Artisan: 堅牢な実装とテストスクリプト
✅ Paladin: 厳格なセキュリティ・品質管理
✅ Merchant: 実践的なテスト実施とパフォーマンス計測
✅ Bard: 統合ドキュメントでエグゼクティブ視点を提供
```

### 最終目標

**2026-02-02 までに**:
- ✅ PoB2 が macOS で完全に表示・動作することを確認
- ✅ セキュリティレビュー合格
- ✅ パフォーマンスベースライン確立
- ✅ ユーザーが利用可能なドキュメント完成

---

**Created by**: Mayor (村長)
**Execution Starts**: 2026-01-29
**Target Completion**: 2026-02-02
**Status**: 🚀 Ready for Parallel Execution

