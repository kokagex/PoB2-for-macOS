# 引き継ぎプロンプト - 2026-02-08 Session 2

## このプロンプトの使い方
新しいセッションにコピペして続行してください。

---

## 引き継ぎプロンプト (コピー用)

```
pob2macos BUILD画面の継続開発。以下の状態から再開してください。

## 現在の状態 (2026-02-08 20:05)

### ブランチ: PoB2macos
未コミットの変更あり（13ファイル）。前回コミット: c6f55e6 "表示関係のfix"

### 完了済み（Phase I: Live Recalculation）

1. **BuildOutput計算成功** ✅
   - ModDB.lua:104, ModStore.lua:305: `mod.value or 0` ガード
   - Misc.lua: characterConstants/monsterConstants にメタテーブル追加
   - 結果: Life:53, Mana:41, Evasion:7, 属性値, レジスト等が正しく計算

2. **ノード割り当て動作** ✅
   - PassiveTree.lua:440: classesStart接続条件 `and`→`or` 修正
   - 結果: ノードクリック→割り当て→ステータス更新が機能

3. **ツールチップZ-order** ✅
   - PassiveTreeView.lua: ツールチップ描画をノードループ外に遅延
   - 結果: ツールチップがノードアイコンの上に表示

4. **ノータブルツールチップ** 一部復旧 ⚠️
   - PassiveTree.lua:321: node.statSets[1].stats フォールバック追加
   - 結果: 一部のノータブルでスタット表示復旧。ただし全ノードではない可能性あり

5. **S/Aフィルタボタン** ✅
   - GemSelectControl.lua: pcall保護でAddGemTooltipエラー回避
   - SkillsTab.lua: S/Aボタン描画保護

6. **Calcs 0 DPS** → 仕様通り（修正不要）
   - Lightning Arrow = bow攻撃スキル。武器未装備時は0 DPS正常
   - Itemsタブでbow装備すればDPS表示される

### 未コミット変更ファイル一覧
- `.claude/CLAUDE.md` - Error Handling改訂
- `doc/learning/LESSONS_LEARNED.md` - 学習データ更新
- `src/Classes/CalcsTab.lua` - Calcsタブ修正
- `src/Classes/GemSelectControl.lua` - S/Aフィルタ修正
- `src/Classes/PassiveTree.lua` - statSetsフォールバック
- `src/Classes/PassiveTreeView.lua` - ツールチップZ-order遅延
- `src/Classes/SkillsTab.lua` - スキルタブ修正
- `src/Data/Skills/act_int.lua` - スキルデータ修正
- `src/Modules/Build.lua` - Build画面修正
- `src/Modules/CalcOffence.lua` - 計算修正

### 次のステップ候補

#### Phase J: Save/Load (XML persistence)
- ビルドのセーブ/ロード機能
- XML形式でのパッシブツリー状態保存

#### Phase K: Items タブ
- 装備アイテムの追加/編集UI
- bowを装備すればCalcs DPSが表示される
- これが0 DPS問題の根本解決

#### Phase L: Skill Gem機能
- AddGemTooltip完全修正
- スキルジェムの選択/設定UI

#### その他残タスク
- ノータブルツールチップの完全修復（一部まだ空の可能性）
- Heatmap表示
- 診断ログのクリーンアップ

### 重要な技術的注意事項

1. **ConPrintf %d禁止**: FFI経由のConPrintfでは%dがIEEE 754下位32ビットを表示。必ず`%s` + `tostring()`を使う
2. **ファイル同期必須**: src/ → app bundle両方に反映必要
3. **SetDrawLayerはno-op**: Metal MVPでは描画順序=Z-order
4. **LuaJIT 5.1**: Lua 5.2+機能は使用不可
5. **Lua修正はサブエージェント必須**: CLAUDE.md規約
```

---

## スクリーンショット参照

最新スクリーンショット: `~/Desktop/スクリーンショット 2026-02-08 20.05.45.png`
- Calcsタブ表示: セクション正常表示、Life/Mana/属性値計算済み
- DPS 0.0: 武器未装備のため正常（バグではない）

## アーキテクチャメモ

### ファイルパス (app bundle内)
```
pob2macos/PathOfBuilding.app/Contents/Resources/pob2macos/
├── src/
│   ├── Classes/     ← UI コンポーネント
│   ├── Modules/     ← コアロジック (Build.lua, Main.lua, Calcs.lua)
│   └── Data/        ← ゲームデータ
├── runtime/         ← SimpleGraphic.dylib
└── pob2_launch.lua  ← FFIブリッジ
```
