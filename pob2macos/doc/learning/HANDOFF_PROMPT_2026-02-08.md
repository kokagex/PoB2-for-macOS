# pob2macos 引き継ぎプロンプト (2026-02-08)

## プロジェクト概要

pob2macosはPath of Building 2のmacOSネイティブポート。Lua + C++/Objective-Cハイブリッドアプリ。
Metal APIグラフィックスバックエンド + LuaJIT 5.1 + GLFW3 + FreeType2。

**リポジトリ**: `/Users/kokage/national-operations/pob2macos/`
**アプリバンドル**: `PathOfBuilding.app/Contents/Resources/pob2macos/`

---

## 現在の状態（Phase A-H完了、Phase I作業中）

### 動作しているもの
- **Build List画面**: 完全動作（Stage 4完了）
- **BUILD画面レイアウト**: トップバー、サイドバー、タブナビゲーション、パッシブツリー表示
- **全8タブ**: Tree, Skills, Items, Calcs, Config, Notes, Import/Export, Party のインスタンス化完了
- **サイドバーStats表示**: Life:78, Mana:68, Str/Dex/Int:14, 耐性値等が表示
- **トップバーコントロール**: Back, Save, Save As, Level, Auto/Manual, Class/Ascendancy ドロップダウン
- **パッシブツリー**: ビューポート(x=312, y=32)で正しく描画
- **フォント**: VAR→Helvetica, 垂直オフセット+スケール(0.85f)修正済み
- **安定性**: FULL ERRORクラッシュ 0件

### 動作していないもの（最重要課題）
- **BuildOutput失敗**: `ModDB.lua:104: attempt to perform arithmetic on field 'value' (a nil value)`
  - PoE2のmod dataに`value`フィールドがnilのmodが存在する
  - フォールバック`mainEnv`で基本ステータスのみ表示中
  - **修正場所**: `src/Classes/ModDB.lua:104` → `result = result + mod.value`でmod.valueがnil
  - これが解決すれば、リアルタイム再計算、ツリーTooltip、ヒートマップが全て有効化

---

## 主要修正履歴（このセッションで実施）

### 1. CalcActiveSkill.lua - nil guard (行242-247)
```lua
local activeGrantedEffect = activeEffect.grantedEffect
if not activeGrantedEffect then
    activeSkill.skillCfg = { flags = 0, keywordFlags = 0, skillName = "Unknown", skillTypes = {}, skillCond = {} }
    activeSkill.skillModList = new("ModList", activeSkill.actor.modDB)
    activeSkill.baseSkillModList = activeSkill.skillModList
    return
end
```

### 2. CalcSetup.lua - PoE2デフォルトスキル (行1734-1758)
PoE2には`env.data.skills.Melee`が存在しない（PoE1のみ）。
`MeleeUnarmedPlayer`にフォールバック、それもなければインラインで最小定義を作成。

### 3. CalcTools.lua - statSetsフォールバック (行192)
```lua
local grantedStats = grantedEffect.stats or (grantedEffect.statSets and grantedEffect.statSets[1] and grantedEffect.statSets[1].stats) or {}
```
PoE2ではstatsがトップレベルではなく`statSets[1].stats`に格納。

### 4. Build.lua - フォールバックmainEnv (行313-348)
BuildOutput失敗時に最小限のmainEnvを作成。`setmetatable`で未知キーを0にデフォルト。

### 5. Build.lua - childStat型チェック (行2342-2346)
```lua
if statVal and statData.childStat and type(statVal) == "table" then
    statVal = statVal[statData.childStat]
elseif statData.childStat then
    statVal = nil
end
```
フォールバックmetatable が0を返すため、`output.MainHand`等がnumber(0)になりテーブルインデックス不可。

### 6. Build.lua - pcallラッピング (行2518-2522)
`AddDisplayStatList`と`InsertItemWarnings`をpcallで保護。

### 7. PassiveTreeView.lua - grantedPassives nil guard (行971)
```lua
or (build.calcsTab and build.calcsTab.mainEnv and build.calcsTab.mainEnv.grantedPassives and build.calcsTab.mainEnv.grantedPassives[nodeId])
```

### 8. Build.lua - 重複タブバー削除
Phase AのカスタムタブバーとPhase HのButtonControlタブが同時描画されていた問題を修正。
OnFrameMinimalからカスタム描画コードを削除、ButtonControlのみに統一。

---

## 次のタスク: ModDB.lua:104 エラー修正

### 根本原因
`ModDB.lua:104`: `result = result + mod.value` で `mod.value` が nil。
PoE2のmod dataの一部にvalueフィールドがないmodが混入している。

### 調査方針
1. **どのmodがvalue=nilか特定**: ModDB.lua:104にデバッグ出力追加
   ```lua
   if mod.value == nil then
       ConPrintf("WARNING: mod with nil value: name=%s source=%s type=%s",
           tostring(mod.name), tostring(mod.source), tostring(mod.type))
       -- skip this mod or default to 0
   end
   ```
2. **修正オプション**:
   - A) ModDB.lua:104で`mod.value or 0`にガード（簡単だが根本解決でない）
   - B) modを生成している箇所でvalue設定を保証（根本解決だが範囲広い）
   - C) Aを適用してBuildOutputを通し、次のエラーを順次修正（推奨）

### BuildOutput成功後に有効化されるもの
- パッシブノード割当 → ステータス自動更新
- ツリーTooltip（"+X Life, +Y DPS"表示）
- ヒートマップ（パワービルダー）
- Calcsタブの計算結果表示

---

## ファイル配置と同期ルール

**重要**: ソースコード修正後、必ずアプリバンドルにコピーすること。

```bash
# Luaファイル同期
cp src/Modules/Build.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/
cp src/Modules/CalcSetup.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/
cp src/Classes/ModDB.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/

# C++ライブラリ同期
cp simplegraphic/build/libSimpleGraphic.dylib runtime/SimpleGraphic.dylib
cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/
```

**現在の作業ファイルはアプリバンドル内のものが最新**:
- `PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/Build.lua`
- `PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/CalcSetup.lua`
- `PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/CalcActiveSkill.lua`
- `PathOfBuilding.app/Contents/Resources/pob2macos/src/Modules/CalcTools.lua`
- `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/PassiveTreeView.lua`
- `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/ModDB.lua`

---

## 技術的注意事項

### PCall仕様
- **成功時**: `nil`を返す（Luaの`pcall`と逆）
- **失敗時**: エラー文字列を返す
- チェック: `if buildErr then` = 失敗

### ConPrintf (C FFI)
- `%d`フォーマットはLua doubleでゴミ値になる → 常に`%s`+`tostring()`を使用
- 大量のDEBUGログ出力あり（sg_text.cppのDRAWSTRINGデバッグ含む）→ ログ1050万行

### PoE2 vs PoE1 データ構造差異
| 項目 | PoE1 | PoE2 |
|------|------|------|
| デフォルトスキル | `data.skills.Melee` | `data.skills.MeleeUnarmedPlayer` |
| スキルStats | `grantedEffect.stats` | `grantedEffect.statSets[1].stats` |
| クラス数 | 7 | 8 |
| mod.value | 常にあり | nilの場合あり ← **今の問題** |

### ビルドテスト手順
```bash
# アプリ起動（ターミナルからログ確認）
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding &
# ユーザーがスクリーンショット撮影後
pkill -f PathOfBuilding
# ログ確認
grep "FULL ERROR\|WARNING" PathOfBuilding.app/Contents/Resources/pob2macos/codex/passive_tree_app.log | head -30
```

---

## 全体計画（残フェーズ）

| Phase | 状態 | 内容 |
|-------|------|------|
| A-H | ✅完了 | タブナビ、全タブ、サイドバー、OnFrame |
| I | **作業中** | ライブ再計算（ModDB.lua:104修正が鍵） |
| J | 未着手 | セーブ/ロード（XML永続化） |
| K | 未着手 | アイテム機能（装備→計算） |
| L | 未着手 | スキルジェム機能（ジェム→DPS） |

詳細計画: `.claude/plans/playful-swimming-rain.md`

---

## 削除すべきデバッグコード（優先度低）

1. **sg_text.cpp**: DrawString内のDRAWSTRINGデバッグprintf → ログ肥大化の原因
2. **Build.lua**: InitMinimal内の大量のConPrintf DEBUG出力
3. **PassiveTreeView.lua**: Draw内のDEBUGログ出力
