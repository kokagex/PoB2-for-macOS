# Stage 4: Main.lua Integration Plan V1

**作成日**: 2026-02-05
**作成者**: Prophet (Planning Phase)
**予想所要時間**: 3-4時間（タイムボックス: 4時間）

---

## 現状分析

### Stage 3 達成状況
- ✅ 5タブすべて作成成功（TreeTab、SkillsTab、ConfigTab、ItemsTab、CalcsTab）
- ✅ パッシブツリー表示が動作
- ✅ 基本的なビルドインフラが完成
- ⏸️ Main.lua 統合は延期（データ構造の競合）

### Stage 3 で発生したエラー（Main.lua ロード時）

| エラー | ファイル:行 | 根本原因 | 優先度 |
|--------|-----------|---------|--------|
| #1 | Data.lua:181 | `characterConstants['mana_regeneration_rate_per_minute_%']` が nil | HIGH |
| #2 | ModParser.lua:1906 | `data.gems` が nil で pairs() 失敗 | HIGH |
| #3 | Main.lua:319 | `data.setJewelRadiiGlobally` が関数ではない | MEDIUM |

---

## 戦略アプローチ

### Option A: データ構造の完全初期化（推奨）

**アプローチ**: Launch.lua でのデータ初期化を削除し、Main.lua に完全にデータロードを任せる

**利点**:
- Main.lua の標準フローに従う
- データ構造の一貫性が保証される
- 長期的にメンテナンスしやすい

**欠点**:
- Launch.lua での初期化コードを削除する必要がある
- Stage 3 の成果の一部を変更

**工数**: 2-3時間

### Option B: データ構造の選択的マージ

**アプローチ**: Launch.lua の初期化を保持し、Main.lua ロード時に競合を解決

**利点**:
- Stage 3 のコードを保持
- 段階的に修正可能

**欠点**:
- 複雑性が増す
- 長期的にメンテナンスが困難

**工数**: 3-4時間

### Option C: 2段階ロード戦略

**アプローチ**:
1. Phase 1: Launch.lua で最小限のデータ初期化（Stage 3 コード保持）
2. Phase 2: Main.lua ロード前に Launch.lua の初期化を「上書き可能」にマーク
3. Phase 3: Main.lua が完全なデータ構造をロード（上書き）

**利点**:
- Stage 3 の成果を保持
- Main.lua の標準フローを尊重
- 段階的移行が可能

**欠点**:
- やや複雑

**工数**: 2.5-3.5時間

---

## 推奨: Option A実装計画

### Phase 1: データ初期化の整理（30分）

**目標**: Launch.lua のデータ初期化を整理し、Main.lua との競合を防ぐ

#### Step 1-1: 現在のデータ初期化を確認
```lua
-- Launch.lua の Stage 3 初期化セクション（413-451行）を確認
-- どのデータ構造が Main.lua と競合するか特定
```

#### Step 1-2: 競合するデータ初期化をコメントアウト
```lua
-- 以下をコメントアウト（Main.lua が完全にロードする）
-- data.nonDamagingAilment
-- data.keystones
-- data.clusterJewels
-- data.jewelRadius
-- data.powerStatList
-- data.monsterConstants
```

#### Step 1-3: 必須の最小初期化のみ保持
```lua
-- 以下は保持（Main.lua ロード前に必要）
data = data or {}  -- 空のテーブル初期化のみ
```

**検証**: Launch.lua の data 初期化セクションが最小限になっている

---

### Phase 2: Main.lua ロードの準備（45分）

**目標**: Main.lua が正常にロードできる環境を整える

#### Step 2-1: 必須グローバル変数の確認
Main.lua が期待するグローバル変数:
- `launch` - Launch オブジェクト（既存）
- `latestTreeVersion` - ツリーバージョン（既存）
- `treeVersionList` - ツリーバージョン一覧（要確認）

#### Step 2-2: GameVersions モジュールのロード確認
```lua
-- Launch.lua で GameVersions がロードされているか確認
-- Main.lua が依存する latestTreeVersion などが定義されているか
```

#### Step 2-3: devMode フラグの設定
```lua
-- Main.lua が参照する launch.devMode を設定
launch.devMode = true  -- または false
```

**検証**: 必須グローバル変数がすべて定義されている

---

### Phase 3: Main.lua のロード（60分）

**目標**: Main.lua を正常にロードし、main オブジェクトを初期化

#### Step 3-1: Main.lua ロードの実装
```lua
-- Launch.lua の OnInit() 最後に追加
ConPrintf("Stage 4: Loading Main module...")
local ok, err = pcall(LoadModule, "Modules/Main", launch)
if not ok then
    ConPrintf("ERROR: Failed to load Main module: %s", tostring(err))
    return false
end
ConPrintf("Stage 4: Main module loaded successfully")
```

#### Step 3-2: Main:Init() の呼び出し
```lua
-- Main オブジェクトが設定されていることを確認
if main and main.Init then
    ConPrintf("Stage 4: Initializing Main...")
    local ok, err = pcall(function() main:Init() end)
    if not ok then
        ConPrintf("ERROR: Main:Init() failed: %s", tostring(err))
        return false
    end
    ConPrintf("Stage 4: Main initialized successfully")
end
```

#### Step 3-3: エラーハンドリング
各エラーに対して個別に対処:

**Error #1: Data.lua:181**
```lua
-- Data.lua で characterConstants が完全にロードされるまで待つ
-- または、Launch.lua で characterConstants の最小限の初期化
```

**Error #2: ModParser.lua:1906**
```lua
-- data.gems が Data.lua でロードされることを確認
-- Launch.lua では data.gems を初期化しない
```

**Error #3: Main.lua:319**
```lua
-- data.setJewelRadiiGlobally が関数として定義されることを確認
-- Launch.lua の stub 定義を削除
```

**検証**: Main.lua が正常にロードされ、main.Init() が成功する

---

### Phase 4: OnFrame() の統合（30分）

**目標**: Main.lua の OnFrame() を呼び出し、ビルドリスト画面を表示

#### Step 4-1: OnFrame() の切り替え
```lua
function launch:OnFrame()
    SetViewport(0, 0, self.screenWidth, self.screenHeight)
    SetClearColor(0.08, 0.08, 0.10, 1.0)

    -- Stage 4: Main module の OnFrame() を呼び出す
    if main and main.OnFrame then
        main:OnFrame()
    else
        -- Fallback: Passive tree viewer (Stage 3)
        if self.viewer then
            self.viewer:Draw(self.build, self.viewPort, self.inputEvents)
            self.inputEvents = { }
        end
    end

    self.frameCount = self.frameCount + 1
end
```

#### Step 4-2: 入力イベントの転送
```lua
function launch:OnKeyDown(key, doubleClick)
    if main and main.OnKeyDown then
        main:OnKeyDown(key, doubleClick)
    else
        table.insert(self.inputEvents, { type = "KeyDown", key = key, doubleClick = doubleClick })
    end
end

function launch:OnKeyUp(key)
    if main and main.OnKeyUp then
        main:OnKeyUp(key)
    else
        table.insert(self.inputEvents, { type = "KeyUp", key = key })
    end
end
```

**検証**: Main.lua の OnFrame() が呼ばれ、画面が描画される

---

### Phase 5: BuildList 画面の表示確認（30分）

**目標**: ビルドリスト画面が正常に表示されることを確認

#### Step 5-1: ビルドリスト画面の起動
- アプリを起動
- ログを確認: "Stage 4: Main initialized successfully"
- ビルドリスト画面が表示されるか確認

#### Step 5-2: 視覚的検証
- ビルドリスト画面の UI 要素が表示されるか
- "New Build" ボタンが表示されるか
- 既存のビルド一覧が表示されるか（空でも可）

#### Step 5-3: ビルド画面への遷移
- "New Build" をクリック
- ビルド画面が表示されるか
- 5つのタブ（Stage 3 で作成）が表示されるか

**検証**: ビルドリスト画面とビルド画面の両方が表示される

---

### Phase 6: Regression テスト（30分）

**目標**: Stage 3 で動作していた機能が引き続き動作することを確認

#### Step 6-1: 5タブの動作確認
- TreeTab: パッシブツリーが表示されるか
- SkillsTab: UI が表示されるか
- ConfigTab: UI が表示されるか
- ItemsTab: UI が表示されるか
- CalcsTab: 計算エンジンが動作するか

#### Step 6-2: エラーログの確認
- 新しいエラーが発生していないか
- Stage 3 のエラーが再発していないか

#### Step 6-3: パフォーマンス確認
- 起動時間が著しく遅くなっていないか
- 描画パフォーマンスが低下していないか

**検証**: すべての既存機能が正常に動作する

---

## Timeline（詳細）

| Phase | ステップ | 予想時間 | 累積時間 |
|-------|---------|---------|---------|
| 1 | データ初期化の整理 | 30分 | 30分 |
| 2 | Main.lua ロードの準備 | 45分 | 1時間15分 |
| 3 | Main.lua のロード | 60分 | 2時間15分 |
| 4 | OnFrame() の統合 | 30分 | 2時間45分 |
| 5 | BuildList 画面の表示確認 | 30分 | 3時間15分 |
| 6 | Regression テスト | 30分 | 3時間45分 |

**合計**: 3時間45分
**タイムボックス**: 4時間
**余裕**: 15分

---

## Risk Assessment

### Risk 1: Data.lua のロードエラーが解決できない
**Likelihood**: Medium
**Impact**: High
**Mitigation**:
- エラー発生時は、必要最小限のデータ構造を Launch.lua で初期化
- 完全なデータロードは段階的に実装

### Risk 2: Main.lua と Stage 3 コードの競合
**Likelihood**: Medium
**Impact**: Medium
**Mitigation**:
- Stage 3 コードをバックアップ
- 競合が解決できない場合は、Stage 3 の状態に rollback

### Risk 3: ビルドリスト画面の UI が表示されない
**Likelihood**: Low
**Impact**: High
**Mitigation**:
- Main.lua の OnFrame() が呼ばれているか確認
- 描画コマンドが正しく実行されているか確認

### Risk 4: Stage 3 機能の regression
**Likelihood**: Low
**Impact**: Medium
**Mitigation**:
- 各 Phase 後に既存機能をテスト
- Regression 発生時は即座に rollback

---

## Success Criteria

### Minimum Success（必須）
- [ ] Main.lua が正常にロードされる
- [ ] main.Init() が成功する
- [ ] アプリが正常に起動する（クラッシュしない）

### Target Success（目標）
- [ ] ビルドリスト画面が表示される
- [ ] "New Build" ボタンが動作する
- [ ] ビルド画面への遷移が成功する
- [ ] Stage 3 の5タブが引き続き動作する

### Stretch Success（ストレッチ）
- [ ] ビルドの保存・読み込みが動作する
- [ ] ビルドリストから既存ビルドを開ける
- [ ] 完全な Windows 版パリティ達成

---

## Rollback Strategy

### Rollback Point 1: Stage 3 完了時点
- Git commit: （最新の Stage 3 コミット）
- 状態: 5タブ作成成功、パッシブツリー表示
- Rollback時間: 即座（git revert）

### Rollback Point 2: Phase 1 完了時点
- データ初期化の整理のみ
- 影響最小限

### Rollback Point 3: 各 Phase 完了時点
- 段階的ロールバック可能
- ファイル同期を元に戻す

---

## Deliverables

### ファイル変更
1. `src/Launch.lua` - Main.lua ロード処理を追加、データ初期化を整理
2. （必要に応じて）`src/Modules/Data.lua` - 初期化順序の調整
3. （必要に応じて）`src/Modules/Main.lua` - 互換性修正

### ドキュメント
1. `STAGE4_MAIN_INTEGRATION_RESULT_20260205.md`
2. `LESSONS_LEARNED.md` 更新
3. Git commit

---

**Plan Status**: ✅ Complete - Ready for Review
**Next Step**: Phase 4 (Plan Review)
