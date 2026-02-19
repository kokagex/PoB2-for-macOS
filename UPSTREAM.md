# 上流同期ステータス / Upstream Sync Status

上流: `PathOfBuildingCommunity/PathOfBuilding-PoE2` `dev` ブランチ
ローカル: `kokagex/PoB2-for-macOS` `pob2macos_stage2` ブランチ
最終同期: 2026-02-20 (v0.3.1)

---

## 同期済み / Synced

### Phase 1 — v0.3.0 (2026-02-19): 計算エンジン9ファイル

| ファイル | 差分行数 | 内容 |
|---|---|---|
| `src/Modules/CalcOffence.lua` | 3,399 | DPS計算（Firestorm/RoA等） |
| `src/Modules/CalcDefence.lua` | 1,579 | 防御計算（Deflection、アーマー） |
| `src/Modules/CalcPerform.lua` | 1,566 | Spirit計算、mergeKeystones |
| `src/Modules/CalcSetup.lua` | 873 | characterConstants、statSets |
| `src/Modules/CalcActiveSkill.lua` | 439 | statSet構造、baseMods |
| `src/Modules/ModParser.lua` | 4,191 | Conquerors（Vorana等）、Mod解析 |
| `src/Modules/ItemTools.lua` | 351 | formatValue、PoE2 influence |
| `src/Modules/CalcTriggers.lua` | 190 | CanRapidFire |
| `src/Modules/CalcMirages.lua` | 72 | General's Cry |

互換性修正（ローカル追加）:
- `Data.lua`: statMap初期化、data.misc同期、buildupTypes、defaultAilmentDamageTypes、modScalability、additionalGrantedEffects
- `CalcActiveSkill.lua`: skillFlags後方互換性（Build.lua向け）
- `CalcSetup.lua`: i18n翻訳復元、srcInstance追加
- `SkillsTab.lua`: displaySkillList nilガード
- `Build.lua`: displaySkillList nilガード6箇所

### Phase 2 — v0.3.1 (2026-02-20): データファイル24ファイル

#### 自動生成系データ

| ファイル | 差分行数 | 内容 |
|---|---|---|
| `src/Data/StatDescriptions/stat_descriptions.lua` | 334,518 | Mod説明文マッピング |
| `src/Data/StatDescriptions/skill_stat_descriptions.lua` | 62,845 | スキルstat説明文 |
| `src/Data/StatDescriptions/gem_stat_descriptions.lua` | 21,477 | ジェムstat説明文 |
| `src/Data/StatDescriptions/active_skill_gem_stat_descriptions.lua` | 4,865 | アクティブジェム説明文 |
| `src/Data/StatDescriptions/monster_stat_descriptions.lua` | 95 | モンスターstat説明文 |
| `src/Data/ModCache.lua` | 15,865 | Modパース結果キャッシュ |

#### ゲームデータ

| ファイル | 差分行数 | 内容 |
|---|---|---|
| `src/Data/Uniques/Special/New.lua` | 315 | 新ユニークアイテム |
| `src/Data/Bases/sword.lua` | 212 | 剣ベース |
| `src/Data/Bases/axe.lua` | 196 | 斧ベース |
| `src/Data/Spectres.lua` | 164 | スペクターデータ |
| `src/Data/Bases/mace.lua` | 106 | メイスベース |
| `src/Data/Uniques/Special/race.lua` | 128 | レースユニーク（新規） |
| `src/Data/Bases/flail.lua` | 73 | フレイルベース（新規） |
| `src/Data/Bases/dagger.lua` | 72 | ダガーベース（新規） |
| `src/Data/ModScalability.lua` | 42 | Modスケーラビリティ |
| `src/Data/Minions.lua` | 13 | ミニオンデータ |
| `src/Data/SkillStatMap.lua` | 11 | スキルstatマッピング |
| `src/Data/Bases/staff.lua` | 9 | スタッフベース |
| `src/Data/Misc.lua` | 4 | 雑定数 |
| `src/Data/ModItemExclusive.lua` | 2 | アイテム専用Mod |
| `src/Data/Gems.lua` | 2 | ジェムデータ |
| `src/Data/Global.lua` | 1 | グローバル定数 |

#### TimelessJewel データ

| ファイル | 差分行数 | 内容 |
|---|---|---|
| `src/Data/TimelessJewelData/LegionPassives.lua` | 4,626 | レギオンパッシブ |
| `src/Data/TimelessJewelData/NodeIndexMapping.lua` | 3,478 | ノードマッピング |

互換性修正（ローカル追加）:
- `Data.lua`: metatableガードをMisc.luaから移設、weaponTypeInfoレガシーエイリアス保持、unarmedWeaponData PoE2クラス対応
- `ModTools.lua`: formatTag/formatValueの混合キー型ソートcomparator追加（上流はformatValueのみ。formatTagへの追加はローカル独自の防御的措置）

---

## 未同期 — 優先度 中 / Not Synced — Medium Priority

### 計算エンジン残り

同期済みCalcファイルと連携。Data.luaはさらに差分あり。

| ファイル | 差分行数 | 内容 |
|---|---|---|
| `src/Modules/CalcSections.lua` | 550 | Calcsタブ表示セクション定義 |
| `src/Modules/Data.lua` | 504 | データ読み込み（部分同期済み） |
| `src/Modules/StatDescriber.lua` | 181 | Mod説明文生成 |
| `src/Modules/Calcs.lua` | 132 | 計算エンジンメインループ |
| `src/Modules/CalcTools.lua` | 109 | 計算ユーティリティ関数 |
| `src/Modules/Common.lua` | 64 | 共通ユーティリティ |
| `src/Modules/ModTools.lua` | 55 | Modユーティリティ（部分同期済み: sort comparator） |
| `src/Modules/BuildDisplayStats.lua` | 71 | ステータス表示定義 |
| `src/Modules/CalcBreakdown.lua` | 16 | 計算内訳 |
| `src/Modules/BuildList.lua` | 72 | ビルドリスト |
| `src/Modules/BuildSiteTools.lua` | 27 | ビルドサイト連携 |

---

## 未同期 — 優先度 低 / Not Synced — Low Priority

### UI Classes

macOSカスタマイズとの衝突リスクが高い。手動マージが必要。

| ファイル | 差分行数 | 内容 | 注意点 |
|---|---|---|---|
| `src/Classes/PassiveTreeView.lua` | 1,010 | ツリー描画 | macOS Metal対応あり |
| `src/Classes/PassiveTree.lua` | 459 | ツリーデータ構造 | |
| `src/Classes/ItemsTab.lua` | 419 | アイテムタブ | |
| `src/Classes/PoEAPI.lua` | 403 | PoE API連携 | OAuth macOS対応 |
| `src/Classes/GemSelectControl.lua` | 387 | ジェム選択 | |
| `src/Classes/PassiveSpec.lua` | 335 | パッシブ仕様 | |
| `src/Classes/SkillsTab.lua` | 298 | スキルタブ | i18n対応済み |
| `src/Classes/ConfigTab.lua` | 148 | 設定タブ | |
| `src/Classes/TreeTab.lua` | 167 | ツリータブ | |
| `src/Classes/DropDownControl.lua` | 137 | ドロップダウン | |
| `src/Classes/Tooltip.lua` | 126 | ツールチップ | CJKフォント対応あり |
| `src/Classes/EditControl.lua` | 117 | テキスト入力 | IME対応あり? |
| その他 20+ ファイル | 〜600 | 各種UIコントロール | |

---

## 触らないファイル / Do Not Sync

macOS固有カスタマイズが入っているため上流版で置換しない。

| ファイル | 理由 |
|---|---|
| `src/Modules/Build.lua` | macOS固有 +515行カスタマイズ |
| `src/Modules/Main.lua` | macOS固有 +198行カスタマイズ |
| `pob2_launch.lua` | macOS起動スクリプト（ローカル専用） |
| `src/Modules/BuildStub.lua` | ローカル専用 |
| `src/Modules/i18n.lua` | 日本語ローカライゼーション（ローカル専用） |
| `src/Data/Skills/act_*.lua` | 既に同一 |
| `src/Data/ConfigOptions.lua` | 既に同一 |
| `src/Data/Uniques.lua` | 既に同一 |
| `src/Data/ModRunes.lua` | 既に同一 |
| ローカル独自ファイル全般 | Crucible, Enchantment, Tattoo, PantheonTools 等 |
