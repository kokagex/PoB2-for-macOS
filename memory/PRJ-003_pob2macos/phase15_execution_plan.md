# Phase 15 Execution Plan - Architectural Refinement

**Date**: 2026-01-29 21:08 JST
**Author**: Mayor (Claude Sonnet 4.5)
**Phase**: 15 - Deferred Issues Resolution + Production Readiness
**Duration**: 5営業日 (2026-01-30 → 2026-02-04)

---

## 📋 Executive Summary

Phase 14 完了により API 51/51 (100%) 達成。Phase 15 では Paladin が DEFERRED した CRITICAL/HIGH issues を解決し、本番デプロイ準備を完了させる。

### Phase 14 → Phase 15 移行状況

| 項目 | Phase 14 終了時 | Phase 15 目標 |
|------|----------------|--------------|
| API Coverage | 51/51 (100%) | 51/51 (維持) |
| CRITICAL Issues | 2 DEFERRED | 0 (全解決) |
| HIGH Issues | 1 DEFERRED | 0 (全解決) |
| Memory Leaks | Unknown | 0 (verified) |
| Deployment Docs | なし | 完備 |
| Production Ready | No | **Yes** ✅ |

---

## 🎯 Phase 15 目標

### 1. CRITICAL Issues 解決

**CRITICAL-1: Lua State Memory Leak**
- **場所**: `subscript_worker.c:277`
- **問題**: `pthread_cancel()` 時に `lua_close()` 未実行 → ~1KB/timeout リーク
- **解決策**: `pthread_cleanup_push/pop()` で確実な cleanup
- **検証**: valgrind で 1000回タイムアウト後にリーク 0 確認

### 2. HIGH Issues 解決

**HIGH-2: Detached Thread Cancellation (POSIX Violation)**
- **場所**: `subscript_worker.c:252, :313`
- **問題**: detached thread への `pthread_cancel()` は未定義動作
- **解決策**: フラグベース協調型 shutdown (`volatile sig_atomic_t` flags)
- **効果**: Graceful termination で確実なリソース解放

### 3. Production Deployment 準備

- **Installation Guide**: macOS Ventura+ 向け完全手順書
- **Dependencies Documentation**: 全依存ライブラリの取得・ビルド方法
- **Release Notes**: v1.0 の機能一覧・既知の制限事項
- **Troubleshooting Guide**: よくある問題と解決策

### 4. 最終品質保証

- **E2E User Scenario Test**: ビルド作成→保存→読込→編集の完全フロー
- **Performance Profiling**: 60FPS 安定性、メモリ使用量、起動時間
- **Stress Testing**: 連続1時間実行、複数タイムアウト耐性、メモリリーク検証

---

## 👥 Agent Assignments

### Task Breakdown

| # | Task | Agent | Duration | Dependencies |
|---|------|-------|----------|--------------|
| **S1** | Graceful Shutdown 設計統一 | Sage | 4h | Prophet mandate |
| **A1** | pthread_cleanup_push/pop 実装 | Artisan | 4h | S1 |
| **A2** | Cooperative shutdown flags 実装 | Artisan | 4h | S1 |
| **M1** | Memory leak test (valgrind) | Merchant | 3h | A1, A2 |
| **M2** | Stress test (1000 timeouts) | Merchant | 3h | A1, A2 |
| **P1** | Phase 15 Security Audit | Paladin | 6h | A1, A2 |
| **P2** | Production Approval | Paladin | 2h | M1, M2, P1 |
| **B1** | INSTALLATION.md | Bard | 3h | - |
| **B2** | DEPENDENCIES.md | Bard | 2h | - |
| **B3** | RELEASE_NOTES.md v1.0 | Bard | 2h | P2 |
| **B4** | Dashboard final update | Bard | 1h | P2 |

**Total Effort**: ~36 agent-hours
**Wall Time**: 5営業日 (並列実行)

---

## 📅 Phase 15 Schedule

### Day 1 (2026-01-30): 設計 + 準備

**Morning**
- Prophet mandate 全員共有
- Sage: S1 (Graceful Shutdown 設計) 開始
- Bard: B1, B2 (ドキュメント) 並列開始

**Afternoon**
- Sage: S1 完成 → Artisan へ引き継ぎ
- Artisan: A1 (pthread_cleanup) 開始

### Day 2 (2026-01-31): 実装

**Morning**
- Artisan: A1 完成、A2 (shutdown flags) 開始

**Afternoon**
- Artisan: A2 完成
- Merchant: M1 (memory leak test) 準備開始

### Day 3 (2026-02-01): テスト + 監査

**Morning**
- Merchant: M1 実行、M2 (stress test) 開始
- Paladin: P1 (Security Audit) 開始

**Afternoon**
- Merchant: M2 完成
- Paladin: P1 継続

### Day 4 (2026-02-03): 最終検証

**Morning**
- Paladin: P1 完成、P2 (Production Approval) 判定

**Afternoon**
- Bard: B3 (RELEASE_NOTES) 作成
- Mayor: 統合ビルド最終確認

### Day 5 (2026-02-04): リリース準備

**Morning**
- Bard: B4 (Dashboard update)
- Mayor: Phase 15 完了宣言

**Afternoon**
- 🎉 **v1.0 Production Release Candidate 完成** 🎉

---

## 🔧 Technical Specifications

### A1: pthread_cleanup_push/pop 実装

**変更ファイル**: `subscript_worker.c`

```c
static void lua_state_cleanup(void* arg) {
    lua_State* L = (lua_State*)arg;
    if (L) {
        lua_close(L);
        printf("[subscript] Cleanup: lua_close() called\n");
    }
}

static void* subscript_worker(void* arg) {
    SubScript* ss = (SubScript*)arg;
    lua_State* L = luaL_newstate();

    // Register cleanup handler
    pthread_cleanup_push(lua_state_cleanup, L);

    // ... existing implementation ...

    pthread_cleanup_pop(1);  // Execute cleanup
    return NULL;
}
```

**効果**:
- `pthread_cancel()` 時に自動的に `lua_close()` 実行
- メモリリーク完全防止

### A2: Cooperative Shutdown Flags 実装

**変更ファイル**: `subscript_worker.c`, `subscript.h`

```c
// subscript.h
typedef struct {
    // ... existing fields ...
    volatile sig_atomic_t shutdown_requested;
} SubScript;

// subscript_worker.c
static void* subscript_worker(void* arg) {
    SubScript* ss = (SubScript*)arg;

    // Polling loop で shutdown チェック
    while (!ss->shutdown_requested) {
        // Script execution with periodic checks
        if (luaL_loadstring(L, ss->script_code) == 0) {
            // Execute with timeout checking
        }
    }

    // Graceful cleanup
    lua_close(L);
    return NULL;
}

// Main thread からの shutdown request
void SimpleGraphic_AbortSubScript(int id) {
    // ...
    ss->shutdown_requested = 1;  // Set flag
    pthread_join(ss->thread, NULL);  // Wait for graceful exit
}
```

**効果**:
- POSIX 準拠の安全な thread 終了
- 確実なリソース解放

---

## ✅ Definition of Done (DoD)

### Code Quality
- [ ] CRITICAL-1 解決: Memory leak 0 (valgrind verified)
- [ ] HIGH-2 解決: POSIX-compliant graceful shutdown
- [ ] All tests PASS: mvp_test + leak test + stress test
- [ ] Build: 0 errors, 0 warnings (except pre-existing -Wunused-parameter)
- [ ] Paladin: Production approval (Grade A or A+)

### Performance
- [ ] FPS stability: 60FPS ±3FPS (1分間測定)
- [ ] Memory: No leaks after 1000 timeout scenarios
- [ ] Graceful shutdown: 100% success rate (100回テスト)
- [ ] Startup time: <2秒 (cold start)

### Documentation
- [ ] INSTALLATION.md: Complete step-by-step guide
- [ ] DEPENDENCIES.md: All libraries with versions
- [ ] RELEASE_NOTES.md: v1.0 feature list + known issues
- [ ] TROUBLESHOOTING.md: Common problems + solutions
- [ ] Dashboard: Phase 15 completion recorded

### Production Readiness
- [ ] Version tag: v1.0.0
- [ ] All API: 51/51 (100%) functional
- [ ] Security score: A or A+
- [ ] Ready for public release: YES ✅

---

## 📊 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Memory leak | 0 bytes | valgrind --leak-check=full |
| Crash rate | 0% | 1000 iteration stress test |
| Shutdown success | 100% | 100 graceful shutdown tests |
| FPS stability | 60 ±3 | SimpleGraphic_GetFPS() 1分間 |
| Build time | <30s | cmake build (incremental) |
| Test coverage | 95%+ | All critical paths tested |

---

## 🚨 Risk Management

### Risk 1: pthread_cleanup 複雑性
- **リスク**: cleanup handler が予期せぬ副作用を起こす可能性
- **対策**: 単純な実装に留める (lua_close のみ)
- **Fallback**: cleanup handler なしで explicit cleanup 実装

### Risk 2: Cooperative shutdown の応答性
- **リスク**: Lua script が長時間実行で shutdown flag をチェックしない
- **対策**: luaL_dostring() ではなく chunk 単位実行 + 定期チェック
- **Fallback**: ハイブリッド (timeout + cooperative)

### Risk 3: 性能劣化
- **リスク**: shutdown flag チェックで性能低下
- **対策**: ベンチマーク比較 (Phase 14 vs Phase 15)
- **Acceptable**: <5% 性能低下まで許容

---

## 📝 Deliverables

### Code Artifacts
1. `subscript_worker.c` (修正版) - pthread_cleanup + cooperative shutdown
2. `subscript.h` (修正版) - shutdown_requested field 追加
3. `test_leak.c` (新規) - Memory leak verification test
4. `test_stress.c` (新規) - 1000 timeout stress test

### Documentation
1. `INSTALLATION.md` - macOS インストール完全ガイド
2. `DEPENDENCIES.md` - 依存ライブラリ一覧 + ビルド手順
3. `RELEASE_NOTES.md` - v1.0 リリースノート
4. `TROUBLESHOOTING.md` - トラブルシューティングガイド

### Reports
1. `paladin_phase15_security_report.md` - 最終セキュリティ監査
2. `merchant_phase15_test_report.md` - 性能 + リークテスト結果
3. `sage_phase15_shutdown_design.md` - Graceful shutdown 設計書
4. `PHASE15_COMPLETION_REPORT.md` - Phase 15 完了サマリー

---

## 🎯 Phase 15 Execution Command

**Mayor から全エージェントへ**:

```
PHASE 15 AUTHORIZATION ISSUED

Prophet Divine Mandate 受領完了。
全エージェントは Phase 15 execution plan に従い、
各担当タスクを 2026-01-30 より開始せよ。

Definition of Done 全項目達成を以って、
pob2macos v1.0 Production Release とする。

村長 (Mayor) より承認
Date: 2026-01-29 21:08 JST
```

---

**Status**: ✅ Ready for Execution
**Next Action**: Prophet mandate 確認後、Sage S1 タスク開始
**Target Completion**: 2026-02-04 17:00 JST
