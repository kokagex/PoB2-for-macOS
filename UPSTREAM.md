# 上流同期ステータス / Upstream Sync Status

上流: `PathOfBuildingCommunity/PathOfBuilding-PoE2` `dev` ブランチ
ローカル: `kokagex/PoB2-for-macOS` `pob2macos_stage2` ブランチ
最終同期: 2026-02-21 (v0.5.1)

---

## 同期済み / Synced

### ✅ Phase 1 — v0.3.0 (2026-02-19): 計算エンジン9ファイル

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

### ✅ Phase 2 — v0.4.0 (2026-02-20): データファイル24ファイル

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

### ✅ Phase 3 — v0.5.0 (2026-02-20): 計算エンジン残りモジュール11ファイル

丸ごと置換（6）:

| ファイル | 内容 |
|---|---|
| `src/Modules/CalcSections.lua` | Calcsタブ表示セクション定義 |
| `src/Modules/Calcs.lua` | 計算エンジンメインループ |
| `src/Modules/CalcTools.lua` | 計算ユーティリティ関数 |
| `src/Modules/BuildDisplayStats.lua` | ステータス表示定義 |
| `src/Modules/CalcBreakdown.lua` | 計算内訳 |
| `src/Modules/BuildSiteTools.lua` | ビルドサイト連携 |

手動マージ（5）:

| ファイル | ローカル保持 |
|---|---|
| `src/Modules/Data.lua` | metatableガード、weaponTypeエイリアス、rebuildItemListLabels |
| `src/Modules/Common.lua` | UTF-8バリデータ、nilガード2箇所 |
| `src/Modules/ModTools.lua` | formatTag混合キー型sort comparator |
| `src/Modules/StatDescriber.lua` | i18n stat翻訳lookup、io.openパス修正 |
| `src/Modules/BuildList.lua` | screenScale、i18n.t()、textInputActiveガード |

呼び出し側修正:
- `SkillsTab.lua`, `GemSelectControl.lua`: getGemStatRequirement引数順 `(level, multi, isSupport)`

i18n翻訳追加:
- `ItemTools.lua`: formatModLineにtranslateModLine適用
- `GemSelectControl.lua`: ジェムstat行にtranslateModLineフォールバック
- `PassiveTreeView.lua`: ツリーノードstat行にtranslateModLineフォールバック

---

### ✅ Phase 4 — v0.5.1 (2026-02-21): UI Classes cherry-pick + 確認

66ファイル調査の結果、大半はローカルPoE2カスタマイズ済みでsync不要。
upstreamの有用な変更のみcherry-pick。

#### cherry-pick実施

| ファイル | 変更内容 |
|---|---|
| `src/Classes/CalcBreakdownControl.lua` | damageTypes `Gain`カラム追加 |
| `src/Classes/TreeTab.lua` | FindTimelessJewelボタン再有効化、treeSubType汎用化、versionSelect幅修正 |
| `src/Classes/ModStore.lua` | `replace`パラメータ、`noFloor`/`limitStat`タグ、`Graft`除外、`nameCond` |

#### 確認済み — sync不要

| ファイル | 差分行数 | 理由 |
|---|---|---|
| `src/Classes/CalcsTab.lua` | 134 | ローカルが既にStatSet/BeastLibrary/MinionStatSet等を実装済み |
| `src/Classes/PassiveTreeView.lua` | 2,221 | ローカルPoE2描画+Metal対応。showStatDifferences=false は意図的（MINIMAL mode safety） |
| `src/Classes/GemSelectControl.lua` | 694 | ローカルi18nジェムツールチップ。reservationMapは将来検討 |
| `src/Classes/Tooltip.lua` | 417 | ローカルCJKフォント+Metal deferred描画。upstream追加はOil recipe（PoE1） |
| `src/Classes/PassiveTree.lua` | 1,240 | ローカルPoE2専用書き換え済み |
| `src/Classes/ItemsTab.lua` | 3,017 | ローカルPoE2アイテム対応済み |
| `src/Classes/PassiveSpec.lua` | 1,205 | ローカルPoE2パッシブ仕様済み |
| `src/Classes/Item.lua` | 1,135 | ローカルPoE2アイテムクラス済み |
| `src/Classes/ImportTab.lua` | 1,099 | ローカルPoE2インポート対応済み |
| `src/Classes/TradeQueryGenerator.lua` | 1,077 | ローカルPoE2 API対応済み |
| `src/Classes/SkillsTab.lua` | 816 | ローカルi18n+PoE2スキル対応済み |
| `src/Classes/TradeQueryRateLimiter.lua` | 486 | ローカルPoE2 API対応済み |
| `src/Classes/TradeQueryRequests.lua` | 426 | ローカルPoE2 API対応済み |
| `src/Classes/TradeQuery.lua` | 297 | ローカルPoE2 API対応済み |
| `src/Classes/ConfigTab.lua` | 262 | ローカルi18n+PoE2設定対応済み |
| `src/Classes/DropDownControl.lua` | 182 | ローカルmacOSカスタマイズ（screenScale, textInputActive） |
| `src/Classes/EditControl.lua` | 157 | ローカルmacOSカスタマイズ（IME, textInputActive） |
| `src/Classes/PartyTab.lua` | 140 | ローカルi18n対応済み |
| `src/Classes/ItemSlotControl.lua` | 138 | ローカルi18n対応済み |
| `src/Classes/ItemDBControl.lua` | 127 | ローカルi18n対応済み |
| `src/Classes/NotableDBControl.lua` | 113 | ローカルi18n対応済み |
| `src/Classes/MinionListControl.lua` | 108 | ローカルi18n対応済み |
| `src/Classes/MinionSearchListControl.lua` | 98 | ローカルi18n対応済み |
| `src/Classes/ControlHost.lua` | 97 | ローカルmacOSカスタマイズ |
| `src/Classes/ItemListControl.lua` | 93 | ローカルi18n対応済み |
| `src/Classes/PoEAPI.lua` | LOCAL_ONLY | macOS OAuth専用（upstream非対応） |
| 小差分22ファイル（diff < 50行） | — | ローカルi18n/macOSカスタマイズのみ |
| 同一23ファイル（diff = 0） | — | 変更なし |

将来検討:
- `GemSelectControl.lua`: reservationMap（PoE2リザベーション表示）をi18nツールチップに統合

---

## ✅ 完了 — i18n翻訳辞書 / Completed — i18n Dictionary Updates

Phase 2のStatDescriptionsデータ同期でdesc.textが変わったため更新を実施:

- [x] `ja_stat_descriptions.lua`: StatDescriptionsデータファイルの現在の`desc.text`キーに合わせて再生成済み
  - レンジ形式修正、キー再マッピング、PoE2新規翻訳追加
- [x] `ja_mod_stat_lines.lua`: PoE2固有stat 681件の日本語翻訳追加済み
  - Freeze Buildup, Bonded:, Spirit等のPoE2新規mod対応

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
