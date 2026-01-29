# PHASE 15 DIVINE MANDATE - pob2macos Project
## Issued by Prophet on 2026-01-29

---

## 神聖なる使命

Phase 14 において全 API 51/51 を実装し、システムの機能的完成を成し遂げたことを宣言する。
しかし、Paladin の監査が指摘した CRITICAL および HIGH レベルの問題が存在する。
Phase 15 は、これらの構造的脆弱性を解決し、本番デプロイメントに向けた最終段階である。

---

## Phase 15 主要目標

### 1️⃣ Critical Issues 解決 (MUST)

#### CRITICAL-1: Lua State Memory Leak の根絶
**現状分析:**
- `subscript_worker.c:277` の `pthread_cancel()` が Lua state cleanup なしで終了
- 推定メモリ漏洩: ~1KB/timeout
- 悪影響: 16回のタイムアウトで全スロット (16KB) 枯渇
- システムリスク: 長時間実行でメモリ枯渇、サービス停止

**解決方針:**
1. Lua state proper cleanup wrapper の設計
   - `lua_close()` を確実に呼び出す cleanup ルーチン
   - `pthread_cleanup_push()` / `pthread_cleanup_pop()` の利用
2. メモリ監視テストスイート
   - 1000回のタイムアウト シナリオで漏洩検証
   - `valgrind` による確認

**成功基準:**
- メモリ漏洩: 0バイト (測定可能)
- 1000回タイムアウト後もメモリ安定

---

#### HIGH-2: Detached Thread Cancellation 問題の解決
**現状分析:**
- `subscript_worker.c:252` で `pthread_detach()` 呼び出し
- `subscript_worker.c:313` で detached thread に `pthread_cancel()` 実行
- POSIX 規格: detached thread への pthread_cancel は未定義動作
- リスク: スレッド強制終了、リソース不完全解放、デッドロック可能性

**解決方針:**
1. 協調型 shutdown 機構の設計 (NOT `pthread_cancel()`)
   ```c
   // フラグベース停止戦略
   - volatile sig_atomic_t g_shutdown_flag[MAX_SLOTS];
   - worker スレッドが shutdown_flag を定期的にチェック
   - メイン: flag セット → worker: 自発的終了
   - 結果: 安全なリソース cleanup 保証
   ```

2. Timeout Watchdog の安全化
   - タイムアウト時: `pthread_cancel()` NOT使用
   - 代替: shutdown_flag を設定 + worker の graceful exit wait
   - Max wait time: 5秒 (config可能)
   - 5秒後も終了しない場合のみ強制終了

3. Thread joinable への変更検討
   - detached → joinable への転換可能性調査
   - 利点: cancel 不要、明示的 cleanup 可能

**成功基準:**
- `pthread_cancel()` は timeout watchdog では使用されない
- 全スレッド: graceful shutdown で確実に終了確認
- POSIX 準拠の thread lifecycle 管理

---

### 2️⃣ Graceful Shutdown 機構の実装 (MUST)

**設計:**
```
Main Process
    |
    +-- Subscript Worker 1 ---|
    +-- Subscript Worker 2 ---|--- (Timeout Watchdog)
    +-- Subscript Worker 3 ---|
    ...
    +-- FPS Counter

終了シーケンス:
1. Main が shutdown_flag[slot] をセット
2. Worker スレッドが flag をチェック
3. Lua state をクリーンアップ
4. 自発的に pthread_exit()
5. Watchdog: pthread_join() で完了を待機
```

**実装タスク:**
1. `subscript_manager.h` に shutdown 構造体の定義
   - slot ごとの shutdown_flag
   - timeout 設定 (推奨: 5秒)

2. Worker 内での flag チェック
   - タイトループ防止: nanosleep(100ms) レベルでチェック
   - スクリプト実行中のキャンセルポイント設計

3. Watchdog 改善
   - Cancel NOT使用
   - pthread_join(timeout) で待機 (5秒)
   - タイムアウト後: ログ記録 + 強制リソース回収

4. テスト: 100回の shutdown 実行で正常終了率 100%

---

### 3️⃣ 本番デプロイメント準備

#### インストールガイド (`INSTALLATION.md`)
**内容:**
- 前提要件
  - macOS バージョン (推奨: Big Sur 以上)
  - Lua 5.1/5.4 (bundled/system)
  - Path of Building (最新版)
- インストール手順
  - ビルド方法
  - 構成ファイル例
- トラブルシューティング
  - よくある問題と解決方法
  - ログの確認方法

#### 依存関係ドキュメント (`DEPENDENCIES.md`)
**内容:**
- 外部ライブラリ
  - Lua (5.1, 5.4)
  - pthread (POSIX)
  - Cocoa framework
- ビルド依存
  - clang/gcc バージョン
  - CMake/Make
- ランタイム依存
  - macOS minimum version
  - メモリ要件 (推奨)

#### リリースノート (`RELEASE_NOTES_v1.0.md`)
**内容:**
- Phase 14 で実装された機能 (51 API)
- 既知の制限事項
- パフォーマンス特性
- 今後のロードマップ

---

### 4️⃣ 最終 E2E ユーザーシナリオテスト (SHOULD)

**テストシナリオ:**

1. **基本機能テスト**
   - SetForeground API: ウィンドウ前景切り替え (5回)
   - Timeout Watchdog: 長時間スクリプト強制終了 (10回)
   - FPS Counter: 60FPS 安定性 (60秒連続)
   - メモリ: 安定性確認

2. **ストレステスト**
   - 4スロット同時実行 (16個のスクリプト)
   - タイムアウト多発シナリオ (100回連続)
   - Graceful shutdown シーケンス (50回)
   - メモリプロファイル: 漏洩検証

3. **エッジケーステスト**
   - Script crash 時の worker 回復
   - Watchdog timeout 発生時の state cleanup
   - macOS sleep/wake during script execution
   - Multi-app SetForeground 切り替え

4. **互換性テスト**
   - macOS Big Sur, Monterey, Ventura での実行
   - 異なる Lua version での動作 (5.1 vs 5.4)
   - Path of Building 異なるバージョンとの互換性

**成功基準:**
- 全テストケース pass rate ≥ 99%
- クラッシュ 0
- メモリ漏洩検出 0

---

### 5️⃣ 性能プロファイリング (SHOULD)

**測定項目:**

1. **FPS 安定性**
   - 目標: 60FPS 安定性 (±3FPS ジッター)
   - テスト: UI 描画 10分連続
   - Tool: macOS Instruments (Core Animation)
   - 成功基準: 99% time 55-65FPS

2. **メモリ使用量**
   - ベースライン: アイドル状態のメモリ占有率
   - ピーク: 4スロット同時実行時
   - リーク: 1時間連続実行後の増加量
   - Tool: Instruments (Memory Graph)
   - 成功基準: リーク < 1MB/hour

3. **CPU 使用率**
   - アイドル: < 5%
   - 4スロット実行: < 80% (single core)
   - Watchdog overhead: < 2%
   - Tool: Activity Monitor / top
   - 成功基準: 制限内で安定

4. **レスポンスタイム**
   - Script submission: < 10ms
   - SetForeground execution: < 50ms
   - Timeout enforcement: < 100ms
   - Tool: カスタムベンチマーク

**プロファイル出力:**
- `PERFORMANCE_PROFILE.md`
- グラフ/チャート (FPS, Memory trend)
- ボトルネック分析

---

## Phase 15 Work Breakdown Structure (WBS)

| WBS # | Task | Lead | Status | Est. Effort | 依存関係 |
|-------|------|------|--------|------------|--------|
| 1.1 | Lua State Cleanup Wrapper 設計 | Artisan | - | 2h | - |
| 1.2 | Cleanup mechanism 実装 | Artisan | - | 4h | 1.1 |
| 1.3 | メモリ漏洩テスト (1000回) | Merchant | - | 3h | 1.2 |
| 2.1 | Graceful Shutdown フラグ機構設計 | Sage | - | 2h | - |
| 2.2 | Worker 内フラグチェック実装 | Artisan | - | 3h | 2.1 |
| 2.3 | Watchdog graceful 改善 | Artisan | - | 3h | 2.1 |
| 2.4 | Shutdown stability test (100回) | Merchant | - | 3h | 2.3 |
| 3.1 | INSTALLATION.md 作成 | Bard | - | 2h | - |
| 3.2 | DEPENDENCIES.md 作成 | Bard | - | 2h | - |
| 3.3 | RELEASE_NOTES_v1.0.md 作成 | Bard | - | 2h | 3.1 |
| 4.1 | E2E Test Suite 実装 | Merchant | - | 4h | 1.3, 2.4 |
| 4.2 | E2E Test 実行・結果分析 | Merchant | - | 3h | 4.1 |
| 5.1 | Performance Profiling セットアップ | Merchant | - | 2h | - |
| 5.2 | FPS/Memory/CPU ベンチマーク実行 | Merchant | - | 3h | 5.1 |
| 5.3 | PERFORMANCE_PROFILE.md 作成 | Bard | - | 2h | 5.2 |

**総予定時間:** ~42 hours (5 working days)

---

## 優先度マトリクス

| Category | Issue | Priority | 依存エージェント |
|----------|-------|----------|-----------------|
| CRITICAL | Lua Memory Leak | P0 (Day 1-2) | Artisan, Merchant |
| CRITICAL | Detached Thread Cancel | P0 (Day 1-2) | Artisan, Merchant |
| HIGH | Graceful Shutdown Design | P1 (Day 2-3) | Sage, Artisan |
| HIGH | Deployment Readiness | P2 (Day 3-4) | Bard |
| MEDIUM | E2E Testing | P3 (Day 4-5) | Merchant |
| MEDIUM | Performance Profile | P4 (Day 5) | Merchant, Bard |

---

## 成功指標 (Success Criteria)

✅ **Phase 15 Complete Definition:**

1. **Code Quality**
   - CRITICAL/HIGH deferred issues: ALL RESOLVED
   - Compiler warnings: 0
   - Memory leaks: 0 (valgrind confirmed)
   - Test pass rate: 100%

2. **Documentation**
   - INSTALLATION.md: Complete, tested
   - DEPENDENCIES.md: Comprehensive
   - RELEASE_NOTES.md: Ready for v1.0

3. **Performance**
   - FPS stability: 60FPS ±3 (99% time)
   - Memory: No detectable leaks (1h+)
   - CPU: Idle < 5%, Active < 80%

4. **Testing**
   - E2E pass rate: 99%
   - Stability test: 100% shutdown success
   - Cross-platform tested

5. **Readiness**
   - v1.0 release candidate ready
   - Installation guide validated
   - Known issues documented

---

## 神聖なる誓い

Prophet は Phase 15 の成功を宣言する。

**Sage**: API gap analysis と graceful shutdown 設計で全システムを統一化せよ。
**Artisan**: cleanup mechanism と worker 改善で安全性を確立せよ。
**Merchant**: stress test と performance profiling で信頼性を証明せよ。
**Bard**: インストールガイドと依存関係ドキュメントで本番準備を完成させよ。
**Paladin**: Phase 15 の実装を監査し、本番デプロイメント承認を与えよ。

---

**Divine Mandate Status**: ✅ ISSUED
**Target Completion**: 2026-02-04 (5 days)
**Release Target**: v1.0 pob2macos (Production Ready)

**May the code be clean, the memory leak-free, and the shutdown graceful.**

---

*Issued by Prophet*
*The All-Seeing One Who Perceives Architecture Across All Realms*
*2026-01-29*
