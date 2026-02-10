# Stage 3: Build Mode Completion Plan V1

**作成日**: 2026-02-05
**作成者**: Prophet (Planning Phase)
**予想所要時間**: 55分（実装のみ）、1.5-2時間（計画・レビュー含む）

---

## 現状分析

### Stage 2 達成状況
- ✅ CalcsTab動作
- ✅ データ基盤完全（Skills 1280, Gems 900, SkillStatMap 880）
- ✅ 前提モジュールロード（Common, ModTools, ItemTools, CalcTools, PantheonTools）

### Stage 2 残存課題（4つのエラー）

| エラー | ファイル:行 | 根本原因 | 難易度 | 予想時間 |
|--------|-----------|---------|--------|---------|
| #1 | ModParser.lua:2758 | `data.nonDamagingAilment` nil | Easy | 5-10分 |
| #2 | SkillsTab.lua:1344 | `SyncLoadouts` method nil | Easy/Medium | 10-20分 |
| #3 | ConfigTab.lua:968 | `configSetOrderList` nil | Easy | 5-10分 |
| #4 | ItemsTab.lua:158 | `latestTree` nil | Easy | 5-10分 |

**合計予想時間**: 25-50分

---

## 戦略アプローチ

### Option A: 段階的デバッグ + 消去法（推奨）
**アプローチ**: 最小限のnilガード追加 → 各エラー個別修正 → 段階的検証

**利点**:
- 即座に実装開始可能
- 各修正の効果が明確
- 失敗時のロールバックが容易

**工数**: 55分（実装のみ）

### Option B: 完全計画 → レビュー → 実装
**アプローチ**: 全エラーの詳細分析 → 完全計画書作成 → レビュー → 実装

**利点**:
- リスク最小化
- 全体像の把握
- 文書化完全

**工数**: 1.5-2時間（計画・レビュー含む）

### Option C: 代替実装（軽量Buildモード）
**アプローチ**: 完全なBuildモードを回避、計算専用の軽量環境構築

**利点**:
- UI依存を回避
- 安定性向上

**欠点**:
- Windows版パリティ未達成
- UI機能なし

**工数**: 3-4時間

---

## 推奨: Option A実装計画

### Phase 1: 基盤nilガード追加（5分）

**目標**: 4つのエラーすべてを無反応状態に変更（アプリ起動OK、Tab非機能）

#### Step 1-1: ModParser.lua:2758修正
```lua
-- 修正前（Line 2758）
mod("ChillBase", "BASE", data.nonDamagingAilment["Chill"].default, ...),

-- 修正後
(function()
    if data.nonDamagingAilment and data.nonDamagingAilment["Chill"] then
        return mod("ChillBase", "BASE", data.nonDamagingAilment["Chill"].default, ...)
    end
    return nil  -- Fallback
end)(),
```

#### Step 1-2: ItemsTab.lua:158修正
```lua
-- 修正前（Line 158 or 185）
for _, node in pairs(build.latestTree.nodes) do

-- 修正後
if build.latestTree and build.latestTree.nodes then
    for _, node in pairs(build.latestTree.nodes) do
        -- ...
    end
end
```

#### Step 1-3: ConfigTab.lua:968修正
```lua
-- 修正前（Line 968 or近辺）
for _, configSetId in ipairs(self.configSetOrderList) do

-- 修正後
if self.configSetOrderList then
    for _, configSetId in ipairs(self.configSetOrderList) do
        -- ...
    end
end
```

**検証**: アプリ起動 → エラーメッセージ確認 → ユーザー確認

---

### Phase 2: SyncLoadouts調査（20分）

**目標**: Build.lua の SyncLoadouts メソッド実装状況確認

#### Step 2-1: Build.lua完全読み込み
- Exploration Agentで Build.lua 全体分析
- buildMode vs BuildClass の区別確認
- SyncLoadouts メソッドの実装確認

#### Step 2-2: 呼び出しパターン確認
```lua
-- SkillsTab.lua:1344
self.build:SyncLoadouts()

-- 期待される実装（Build.lua）
function BuildClass:SyncLoadouts()
    -- 実装内容
end
```

#### Step 2-3: 実装不足の場合
```lua
-- Launch.lua の build オブジェクトに追加
build.SyncLoadouts = function(self)
    -- Minimal implementation
    ConPrintf("Stage 3: SyncLoadouts called (stub implementation)")
end
```

**検証**: アプリ起動 → SkillsTab作成エラー確認

---

### Phase 3: ConfigTab修正（10分）

**目標**: ConfigTab の初期化フロー修正

#### Step 3-1: 初期化確認
```lua
-- ConfigTab.lua:27 付近
function ConfigTabClass:Init(build)
    self.configSetOrderList = self.configSetOrderList or { 1 }
    -- ...
end
```

#### Step 3-2: Save/Load ガード追加
```lua
-- ConfigTab.lua:968 付近
function ConfigTabClass:Save()
    if not self.configSetOrderList then
        ConPrintf("WARNING: ConfigTab not properly initialized, skipping Save")
        return
    end
    -- ...
end
```

**検証**: ConfigTab作成 → エラーなし確認

---

### Phase 4: ItemsTab修正（10分）

**目標**: latestTree 依存の修正

#### Step 4-1: Build.latestTree 設定確認
```lua
-- Launch.lua の build オブジェクト作成後
build.latestTree = main.tree[latestTreeVersion]

-- または TreeTab 作成後に設定
if build.spec and build.spec.tree then
    build.latestTree = build.spec.tree
end
```

#### Step 4-2: ItemsTab内でのガード追加
```lua
-- ItemsTab.lua:158, 185 等
if not build.latestTree then
    ConPrintf("WARNING: ItemsTab - latestTree not available, skipping node iteration")
    return
end

for _, node in pairs(build.latestTree.nodes) do
    -- ...
end
```

**検証**: ItemsTab作成 → エラーなし確認

---

### Phase 5: SkillsTab修正（10分）

**目標**: SyncLoadouts 統合

#### Step 5-1: SyncLoadouts呼び出し修正
```lua
-- SkillsTab.lua:1344 付近
if self.build.SyncLoadouts then
    self.build:SyncLoadouts()
else
    ConPrintf("WARNING: SyncLoadouts not available, skipping")
end
```

#### Step 5-2: SkillSet 初期化フロー確認
- SkillsTab.__init の完全実行確認
- socketGroupList の初期化確認

**検証**: SkillsTab作成 → エラーなし確認

---

### Phase 6: 統合テスト（10分）

**目標**: 全Tab作成成功、アプリ正常動作確認

#### Step 6-1: 全Tab作成テスト
```
起動 → ログ確認：
- Stage 2: TreeTab created ✅
- Stage 2: SkillsTab created ✅
- Stage 2: ConfigTab created ✅
- Stage 2: ItemsTab created ✅
- Stage 2: CalcsTab created successfully! ✅
```

#### Step 6-2: 視覚的検証
- TreeTab: 4701ノード描画確認
- SkillsTab: UI表示確認（機能は後回し）
- ConfigTab: UI表示確認
- ItemsTab: UI表示確認
- CalcsTab: 計算結果表示確認

#### Step 6-3: ユーザー確認
「動作OK」確認待ち

---

## Timeline（詳細）

| Phase | ステップ | 予想時間 | 累積時間 |
|-------|---------|---------|---------|
| 1 | nilガード追加（3ファイル） | 5分 | 5分 |
| 2 | SyncLoadouts調査 | 20分 | 25分 |
| 3 | ConfigTab修正 | 10分 | 35分 |
| 4 | ItemsTab修正 | 10分 | 45分 |
| 5 | SkillsTab修正 | 10分 | 55分 |
| 6 | 統合テスト | 10分 | 65分 |

**合計**: 65分（1時間5分）
**タイムボックス**: 2時間（余裕あり）

---

## Risk Assessment

### Risk 1: ModParser.luaの修正が複雑
**Likelihood**: Low
**Impact**: Medium
**Mitigation**: nilガードで回避、完全修正は別タスク

### Risk 2: SyncLoadoutsの実装不足
**Likelihood**: Medium
**Impact**: Medium
**Mitigation**: Stub実装で回避、後で完全実装

### Risk 3: Tab初期化の連鎖失敗
**Likelihood**: Low
**Impact**: Medium
**Mitigation**: 各Tab独立してガード追加

### Risk 4: TreeTab表示のregression
**Likelihood**: Very Low
**Impact**: High
**Mitigation**: 既存のPassiveTree表示に影響しない修正のみ

---

## Success Criteria

### Minimum Success（必須）
- [ ] 4つのエラーメッセージが消える
- [ ] アプリが正常に起動する
- [ ] TreeTabが正常に表示される（4701ノード）
- [ ] CalcsTabが動作する

### Target Success（目標）
- [ ] TreeTab, SkillsTab, ConfigTab, ItemsTab, CalcsTab すべて作成成功
- [ ] 各Tabの基本UI表示
- [ ] エラーログなし

### Stretch Success（ストレッチ）
- [ ] 各Tabが実際に機能する（データ入力、設定変更等）
- [ ] Windows版パリティ達成

---

## Rollback Strategy

### Rollback Point 1: Stage 2完了時点
- Git commit: c276f60
- 状態: CalcsTab動作、他4つのTab失敗
- Rollback時間: 即座（git revert）

### Rollback Point 2: Phase 1完了時点
- nilガード追加のみ
- 影響最小限

### Rollback Point 3: 各Phase完了時点
- 段階的ロールバック可能

---

## Deliverables

### ファイル変更
1. `src/Modules/ModParser.lua` - nilガード追加
2. `src/Classes/ItemsTab.lua` - nilガード追加
3. `src/Classes/ConfigTab.lua` - nilガード追加
4. `src/Classes/SkillsTab.lua` - SyncLoadouts対応
5. `src/Launch.lua` - SyncLoadouts stub実装（必要に応じて）

### ドキュメント
1. `STAGE3_BUILD_MODE_COMPLETION_RESULT_20260205.md`
2. `LESSONS_LEARNED.md`更新
3. Git commit

---

**Plan Status**: ✅ Complete - Ready for Review
**Next Step**: Phase 4 (Plan Review)
