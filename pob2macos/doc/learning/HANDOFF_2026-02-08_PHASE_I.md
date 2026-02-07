# 引き継ぎプロンプト - Phase I: Live Recalculation (2026-02-08)

## プロジェクト概要

**pob2macos**: Path of Building 2 の macOS ネイティブポート。Lua + C++/Objective-C (Metal backend) のハイブリッドアプリ。

**ブランチ**: `PoB2formacSO`
**作業ディレクトリ**: `/Users/kokage/national-operations/pob2macos/`
**アプリバンドル**: `PathOfBuilding.app/Contents/Resources/pob2macos/`

---

## 現在のステータス

### 完了済み ✅

| フェーズ | 内容 | 状態 |
|---------|------|------|
| Stage 4 | Build List画面 | ✅ 完了 |
| Phase 1 | Minimal Stub (Passive Tree表示) | ✅ 完了 |
| Phase 2 | Character Info Panel | ✅ 完了 |
| Phase A-H | 7タブ + Full OnFrame + サイドバー | ✅ 完了 |
| Phase I-1 | BuildOutput計算エンジン修正 | ✅ 完了 |
| Phase I-2 | ノード割当 (クリック→割当→Stats更新) | ✅ 完了 |

### Phase I 残作業 (進行中)

1. **診断ログクリーンアップ** ⚠️ 優先度高
   - 毎フレーム大量のDEBUGログが出力中（ログファイルが数分で2GB超に）
   - `PassiveTreeView.lua`: hover診断（120フレームごと）、背景描画ログ
   - `PassiveSpec.lua`: BuildPathFromNode詳細ログ
   - `Build.lua`: CallMode、autoStartBuildログ
   - `Main.lua`: DEBUG CallModeログ
   - **対策**: 不要なConPrintf削除 or コメントアウト

2. **Tree Tooltips** 未検証
   - ノードホバー時の情報表示（+X Life, +X% Damage等）
   - PassiveTreeView.lua の tooltip描画コードの動作確認

3. **Heatmap ("Show Node Power")** 未検証
   - 画面下部の "Show Node Power" ドロップダウン
   - fullDPS等の計算結果に基づくノードの色分け

---

## 今回のセッションで修正した内容

### Fix 1: ModDB.lua:104 - nil value guard
```lua
-- Before
result = result + mod.value
-- After
result = result + (mod.value or 0)
```

### Fix 2: ModStore.lua:305 - nil value guard
```lua
-- Before
local value = mod.value
-- After
local value = mod.value or 0
```

### Fix 3: Misc.lua - characterConstants/monsterConstants metatable
```lua
-- 行229 (characterConstants後)
setmetatable(data.characterConstants, { __index = function(t, k) return 0 end })
-- 行267 (monsterConstants後)
setmetatable(data.monsterConstants, { __index = function(t, k) return 0 end })
```

### Fix 4: PassiveTree.lua:440 - ClassStart接続フィルタ (最重要修正)
```lua
-- Before (ClassStartを全接続から除外 → linked=0、パス構築不可)
node.classesStart == nil and other.classesStart == nil
-- After (ClassStart↔通常ノード接続許可、ClassStart↔ClassStart除外)
node.classesStart == nil or other.classesStart == nil
```
**影響**: RANGER linked=0→2、パス3780ノード、ノード割当完全動作

---

## 重要な技術的知見

### ConPrintf %d 問題 (CRITICAL)
LuaJIT FFI経由のConPrintf(C関数)で`%d`フォーマットを使うと、Lua doubleの下位32ビットが読まれる。
IEEE 754のdouble表現では小さな整数の下位32ビットは常に`0x00000000`。

```lua
-- ❌ 常にゴミ値/0が表示される
ConPrintf("count=%d", someNumber)
-- ✅ 正しい値が表示される
ConPrintf("count=%s", tostring(someNumber))
```

### イベントフロー
```
Main:ProcessControlsInput (Main.lua:390)
  → Main のコントロール処理（Options, About等）
Build:OnFrame (Main.lua:393 → Build.lua:1812)
  → キーボードショートカット処理 (CTRL+S等)
  → buildFlag → BuildOutput再計算
  → treeTab:Draw (Build.lua:1976)
    → TreeTab:ProcessControlsInput (TreeTab.lua:341)
      → TreeTab のコントロール処理（Search, HeatMap等）
    → PassiveTreeView:Draw (TreeTab.lua:423)
      → クリック/ホバー処理
      → ノード割当/解除
  → DrawControls (Build.lua:2002)
```

### ファイル同期
ソースファイルは直接アプリバンドル内を編集中:
`PathOfBuilding.app/Contents/Resources/pob2macos/src/`

### ログ出力先
```
PathOfBuilding.app/Contents/Resources/pob2macos/codex/passive_tree_app.log
```
※ 起動スクリプト (`Contents/MacOS/PathOfBuilding`) が `exec luajit >> $LOG 2>&1` でリダイレクト

### 検証ワークフロー
1. ログをtruncate: `truncate -s 0 .../codex/passive_tree_app.log`
2. アプリ起動: `./PathOfBuilding.app/Contents/MacOS/PathOfBuilding &`
3. ユーザーがスクリーンショット
4. アプリ終了: `pkill -f PathOfBuilding`
5. ログ確認: `grep "KEYWORD" .../codex/passive_tree_app.log | tail -N`

---

## 未コミットの変更 (31ファイル)

主要な変更ファイル:
- `src/Classes/PassiveTree.lua` - ClassStart接続修正
- `src/Classes/PassiveTreeView.lua` - 診断ログ追加 (+225行)
- `src/Classes/PassiveSpec.lua` - パス構築ログ修正
- `src/Classes/ModDB.lua` - nil guard
- `src/Classes/ModStore.lua` - nil guard
- `src/Data/Misc.lua` - metatable追加
- `src/Modules/Build.lua` - Full OnFrame + 診断ログ (+959行)
- `src/Classes/TreeTab.lua` - 診断ログ追加

---

## 推奨される次のステップ

### 1. 診断ログクリーンアップ (30分)
以下のファイルから不要なConPrintf削除:
- `PassiveTreeView.lua`: "DEBUG: Starting background artwork rendering" 等の毎フレームログ
- `PassiveSpec.lua`: BuildPathFromNode詳細ログ（正常動作確認済み）
- `Build.lua`: "DEBUG CallMode", "autoStartBuild" ログ
- `Main.lua`: "DEBUG CallMode" ログ
- `TreeTab.lua`: TREETAB-SEL/PCI 診断（正常動作確認済み）

### 2. Tooltip検証 (15分)
PassiveTreeView.lua内のtooltip描画コードの動作確認

### 3. Heatmap検証 (15分)
"Show Node Power" 機能の動作確認

### 4. Phase J: Save/Load (数時間)
XML永続化 - ビルドの保存・読み込み

### 5. コミット
Phase I完了後にコミット推奨

---

## 参照ドキュメント
- `CLAUDE.md` - プロジェクト全体のガイドライン
- `doc/learning/LESSONS_LEARNED.md` - 39の学習記録
- `doc/learning/CRITICAL_FAILURE_ANALYSIS.md` - 重大失敗パターン
- `MEMORY.md` - プロジェクト記憶（自動読み込み）
