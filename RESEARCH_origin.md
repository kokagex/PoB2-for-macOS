# RESEARCH_origin.md — PoB2 上流データ解析

**解析日**: 2026-02-18
**上流パス**: `/Users/kokage/national-operations/pob2macos/dev/pob2-original/`
**ローカルパス**: `/Users/kokage/national-operations/PathOfBuilding.app/Contents/Resources/`

---

## 1. 上流ディレクトリ構造概要

### 上流 `src/` 構造
```
Assets/ Classes/ Data/ Export/
GameVersions.lua HeadlessWrapper.lua Launch.lua LaunchInstall.lua
Locales/ Modules/ TreeData/
UpdateApply.lua UpdateCheck.lua
```

**ローカルと上流の主要差異**:
- 上流に `TreeData/` あり（ローカルは Resources/ 直下にバイナリ形式）
- ローカルに `BuildStub.lua`（Modules内）あり、上流にはなし
- ローカルに `PoEAPI.lua`（Classes内）あり、上流にはなし
- ローカルに `i18n.lua` の大幅拡張版あり（114行→228行）

---

## 2. Data/ ファイル差分マトリクス

### 2.1 ローカルにあって上流にないファイル（Data/直下）

| ファイル | 行数 | 内容 |
|---------|------|------|
| `ModCharm.lua` | 55 | チャーム修飾子データ |
| `ModCorrupted.lua` | 131 | 腐敗修飾子データ |
| `ModIncursionLimb.lua` | 16 | インカージョン・リム修飾子 |
| `ModItemExclusive.lua` | 4,867 | アイテム排他修飾子（大規模） |
| `ModRunes.lua` | 1,992 | ルーン修飾子データ |
| `ModScalability.lua` | 14,326 | スケーラビリティMod（最大規模） |
| `QuestRewards.lua` | 293 | クエスト報酬データ |
| `WorldAreas.lua` | 6,471 | ワールドエリアデータ |

### 2.2 共通ファイルの行数比較（主要差分）

| ファイル | 上流行数 | ローカル行数 | 競合リスク |
|---------|---------|------------|----------|
| `QueryMods.lua` | 76,974 | 25,556 | HIGH（上流PoE1データ大量） |
| `Gems.lua` | 14,786 | 18,843 | MEDIUM（ローカルPoE2ジェム追加） |
| `ModItem.lua` | 11,475 | 1,724 | HIGH（PoE1 vs PoE2） |
| `ModCache.lua` | 12,696 | 14,008 | MEDIUM |
| `Spectres.lua` | 7,000 | 16,812 | MEDIUM（ローカルPoE2スペクター大量） |
| `FlavourText.lua` | 11,032 | 3,235 | MEDIUM |
| `SkillStatMap.lua` | 2,275 | 2,911 | MEDIUM |
| `Global.lua` | 355 | 611 | HIGH（PoE2クラスカラー・OR64関数） |
| `Misc.lua` | 467 | 370 | HIGH（モンスターテーブル全面置換） |
| `Minions.lua` | 1,779 | 1,039 | MEDIUM |
| `Rares.lua` | 1,665 | 998 | MEDIUM |

### 2.3 完全同一ファイル（差分ゼロ）

```
ModMaster.lua, ModJewelAbyss.lua, ModJewelCluster.lua, ModGraft.lua,
ModMap.lua, ModFoulborn.lua, ModFoulbornMap.lua, ModTincture.lua,
ModNecropolis.lua, ModJewelCharm.lua, TattooPassives.lua,
BeastCraft.lua, Crucible.lua, EnchantmentHelmet.lua
```

---

## 3. Uniques/ 詳細分析

### 3.1 上流独自ファイル
なし。Uniques/直下の全ファイルはローカルにも存在する。

### 3.2 ローカル独自ファイル（PoE2新装備タイプ）

| ファイル | 行数 |
|---------|------|
| `crossbow.lua` | 52 |
| `flail.lua` | 6 |
| `focus.lua` | 84 |
| `incursionlimb.lua` | 6 |
| `sceptre.lua` | 112 |
| `soulcore.lua` | 6 |
| `spear.lua` | 107 |
| `traptool.lua` | 6 |

### 3.3 共通ファイルの差分概要

上流はPoE1ユニーク（Abyssus等）、ローカルはPoE2ユニーク（Black Sun Crest等）。**内容が完全に異なる**。

| ファイル | 上流行数 | ローカル行数 |
|---------|---------|------------|
| `jewel.lua` | 1,949 | 97 |
| `ring.lua` | 1,648 | 324 |
| `helmet.lua` | 1,670 | 544 |
| `amulet.lua` | 1,365 | 280 |
| `body.lua` | 1,475 | 773 |
| `sword.lua` | 1,014 | 10 |
| `axe.lua` | 473 | 8 |
| `claw.lua` | 374 | 6 |
| `dagger.lua` | 337 | 6 |

### 3.4 競合リスク: **HIGH** — PoE1/PoE2でユニーク定義が完全に異なる

---

## 4. Skills/ 詳細分析

### 4.1 行数・差分比較

| ファイル | 上流行数 | ローカル行数 | 競合リスク |
|---------|---------|------------|----------|
| `act_dex.lua` | 18,601 | 11,162 | HIGH |
| `act_int.lua` | 21,101 | 22,488 | HIGH |
| `act_str.lua` | 12,258 | 20,613 | HIGH |
| `other.lua` | 5,289 | 9,302 | HIGH |
| `spectre.lua` | 11,510 | 7,576 | HIGH |
| `sup_dex.lua` | 4,642 | 5,965 | MEDIUM |
| `sup_int.lua` | 6,012 | 8,115 | MEDIUM |
| `sup_str.lua` | 4,580 | 7,896 | MEDIUM |
| `glove.lua` | 2,247 | 2,247 | **LOW（同一）** |
| `minion.lua` | 2,154 | 2,310 | MEDIUM |

### 4.2 競合リスク
- **HIGH**: `act_dex/int/str.lua` — PoE1/PoE2でスキルが完全に異なる。統合不可。
- **LOW**: `glove.lua` — 同一。
- **MEDIUM**: `minion.lua`, `sup_*` — 部分的な共通構造。

---

## 5. StatDescriptions/ 詳細分析

### 5.1 ローカル独自ファイル（上流にない）

| ファイル | 行数 |
|---------|------|
| `advanced_mod_stat_descriptions.lua` | 1,154 |
| `meta_gem_stat_descriptions.lua` | 574 |
| `passive_skill_aura_stat_descriptions.lua` | 573 |
| `passive_skill_stat_descriptions.lua` | 4,302 |
| `utility_flask_buff_stat_descriptions.lua` | 141 |
| `Specific_Skill_Stat_Descriptions/` (ディレクトリ) | **664ファイル** |

### 5.2 共通ファイル（全22ファイル）: **完全同一**

stat_descriptions.lua (253,482行), gem_stat_descriptions.lua (20,063行),
skill_stat_descriptions.lua (49,731行), minion_skill_stat_descriptions.lua (9,703行),
および残り18ファイル — **全て上流・ローカルで完全同一**（363,604行）。

### 5.3 競合リスク: **LOW** — 共通ファイルは全て同一

---

## 6. Bases/ 詳細分析

### 6.1 行数比較（主要差分）

| ファイル | 上流行数 | ローカル行数 | 競合リスク |
|---------|---------|------------|----------|
| `amulet.lua` | 827 | 116 | HIGH |
| `body.lua` | 1,254 | 1,567 | HIGH |
| `sword.lua` | 873 | 461 | HIGH |
| `mace.lua` | 816 | 505 | HIGH |
| `axe.lua` | 496 | 391 | HIGH |
| `wand.lua` | 287 | 121 | HIGH |
| `claw.lua` | 284 | 123 | HIGH |
| `graft.lua` | 116 | 116 | **LOW（同一）** |
| `tincture.lua` | 84 | 84 | **LOW（同一）** |

### 6.2 ローカル独自（PoE2新装備）

crossbow(250), flail(196), focus(212), incursionlimb(101), sceptre(219),
soulcore(744), spear(284), talisman(218), traptool(97)

---

## 7. Mod系ファイル詳細分析

### 7.1 共通Modファイルの差分

| ファイル | 上流行数 | ローカル行数 | 競合リスク |
|---------|---------|------------|----------|
| `ModItem.lua` | 11,475 | 1,724 | HIGH |
| `QueryMods.lua` | 76,974 | 25,556 | HIGH |
| `ModCache.lua` | 12,696 | 14,008 | MEDIUM |
| `ModFlask.lua` | 250 | 82 | MEDIUM |
| `ModJewel.lua` | 428 | 365 | MEDIUM |
| `ModVeiled.lua` | 261 | 353 | LOW |

### 7.2 完全同一Modファイル

ModMaster, ModJewelAbyss, ModJewelCluster, ModGraft, ModMap,
ModFoulborn, ModFoulbornMap, ModTincture, ModNecropolis, ModJewelCharm

### 7.3 ローカル独自Modファイル（PoE2専用）

ModCharm(55), ModCorrupted(131), ModIncursionLimb(16),
ModItemExclusive(4,867), ModRunes(1,992), ModScalability(14,326)

---

## 8. Data.lua ローダー差分

### 8.1 主要差分

```
skillTypes: "glove" がコメントアウト（PoE1機能、SkillTypeエラー回避）

itemTypes（9種追加）:
  "sceptre", "focus", "crossbow", "flail", "spear", "soulcore",
  "talisman", "traptool", "incursionlimb"

data.itemMods（3種追加）:
  Runes, Exclusive, Corruption

追加ロード:
  data.questRewards = LoadModule("Data/QuestRewards")

Spectres遅延ロード化:
  data.getSpectres() 関数で初回アクセス時にロード

itemBaseTypeList構造変更（i18n対応）:
  上流: 文字列配列
  ローカル: {label, name}テーブル配列

data.misc.ManaRegenBase キー名差異:
  上流:    "mana_regeneration_rate_per_minute_%"
  ローカル: "character_inherent_mana_regeneration_rate_per_minute_%"

data.misc追加:
  normalEnemyDPSMult = 1 / 4.40

data.weaponTypeInfo追加:
  ["Spear"], ["Flail"], ["Crossbow"], ["Talisman"]

追加関数:
  data.rebuildItemListLabels()  -- i18n翻訳でリスト更新
```

---

## 9. Classes/Modules 表示関連差分

### 9.1 Classes/ 比較

| ファイル | 上流行数 | ローカル行数 | 競合リスク |
|---------|---------|------------|----------|
| `ItemsTab.lua` | 4,047 | 3,527 | **HIGH** |
| `PassiveTree.lua` | 988 | 1,087 | **HIGH** |
| `CalcsTab.lua` | 639 | 712 | MEDIUM |

**ItemsTab.lua 主要差分**:
- 上流: `baseSlots`にGraft 1/2、PoE1スロット
- ローカル: Charm 1/2/3、Arm 1/2、Leg 1/2（PoE2スロット）
- ローカル: ソケット色 S のみ（PoE2はソケット廃止）
- ローカル: 全ラベルを`i18n.t()`で翻訳

**PassiveTree.lua 主要差分**:
- 上流: `classArt`テーブルあり（PoE1クラスアート）
- ローカル: `classArt`なし（PoE2クラスアートは異なる）
- ローカル追加: チャンク読み込み、treeVersionバリデーション、math.atan2ローカル化

### 9.2 Modules/ 比較

| ファイル | 上流行数 | ローカル行数 | 競合リスク |
|---------|---------|------------|----------|
| `Main.lua` | 1,710 | 1,902 | **HIGH** |
| `Build.lua` | 1,947 | 2,794 | **HIGH** |
| `i18n.lua` | 114 | 228 | **HIGH** |
| `CalcPerform.lua` | 3,580 | 3,582 | LOW |
| `CalcSections.lua` | 2,507 | 2,507 | **LOW（同一）** |
| `ModParser.lua` | 6,591 | 6,591 | **LOW（同一）** |
| `CalcOffence.lua` | 5,871 | 5,871 | **LOW（同一）** |
| `CalcDefence.lua` | 3,785 | 3,785 | **LOW（同一）** |
| `CalcTriggers.lua` | 1,531 | 1,531 | **LOW（同一）** |
| `Calcs.lua` | 874 | 874 | **LOW（同一）** |
| `CalcBreakdown.lua` | 246 | 246 | **LOW（同一）** |
| `ModTools.lua` | 236 | 236 | **LOW（同一）** |
| `BuildSiteTools.lua` | 116 | 116 | **LOW（同一）** |
| `PantheonTools.lua` | 18 | 18 | **LOW（同一）** |

**ローカル独自**: `BuildStub.lua`（285行）

---

## 10. ローカライゼーション差分

### 10.1 ファイル構成比較

| ファイル | 上流行数 | ローカル行数 |
|---------|---------|------------|
| `en.lua` | 69 | 1,349 |
| `ja.lua` | 69 | 3,152 |
| `ja_base_names.lua` | **なし** | 1,420 |
| `ja_gem_descriptions.lua` | **なし** | 967 |
| `ja_gem_flavourtext.lua` | **なし** | 61 |
| `ja_mod_stat_lines.lua` | **なし** | 3,298 |
| `ja_stat_descriptions.lua` | **なし** | 1,337 |
| `ja_unique_flavourtext.lua` | **なし** | 1,348 |
| `ja_unique_names.lua` | **なし** | 394 |

**ローカル合計**: 13,326行（上流138行の**97倍**）

### 10.2 i18n.lua差分

- 上流（114行）: 基本的な `t()` 関数とドット記法ルックアップのみ
- ローカル（228行）: 補助ファイル7種の遅延ロード + `translateModLine()` + `rebuildItemListLabels()`
- **上流版に戻すと日本語化が全崩壊**

### 10.3 競合リスク: **HIGH** — ローカルの全拡張を保護必須

---

## 11. 競合リスクサマリー

### 11.1 HIGHリスク項目（統合禁止）

| 項目 | 理由 |
|-----|------|
| `Data/Uniques/` 全共通ファイル | PoE1とPoE2でユニーク定義が完全に異なる |
| `Data/Skills/act_*.lua` | PoE1とPoE2でスキルが完全に異なる |
| `Data/Bases/{amulet,ring,sword,axe,claw,dagger,wand,mace}` | PoE1ベースタイプで上書き禁止 |
| `Data/ModItem.lua` | 上流11,475行PoE1 vs ローカル1,724行PoE2 |
| `Data/QueryMods.lua` | 上流76,974行（PoE1大量データ） |
| `Data/Misc.lua` | モンスターテーブル全面置換（PoE2数値） |
| `Data/Global.lua` | PoE2クラスカラー・OR64関数喪失 |
| `Locales/en.lua`, `ja.lua` | 上流最小版で上書き禁止 |
| `Modules/Data.lua` | PoE2 itemTypes/i18n対応喪失 |
| `Modules/Main.lua` | macOS固有起動シーケンス喪失 |
| `Modules/i18n.lua` | 補助ファイルロード機能喪失→日本語化崩壊 |
| `Classes/ItemsTab.lua` | i18n対応・PoE2スロット定義 |
| `Classes/PassiveTree.lua` | macOS対応・PoE2クラスアート |

### 11.2 MEDIUMリスク項目（要精査後に部分統合可能）

ModCache, Gems, Spectres, FlavourText, SkillStatMap, Minions, Rares,
ModJewel, ModFlask, CalcsTab, CalcSetup, Common, sup_*.lua, minion.lua

### 11.3 LOWリスク項目（安全に統合可能）

**Data/StatDescriptions/ 共通22ファイル** — 全て完全同一（363,604行）
**Modules/Calc系** — CalcSections, CalcOffence, CalcDefence, CalcTriggers, CalcBreakdown, Calcs, ModTools, BuildSiteTools, PantheonTools（全て同一）
**Data/Mod系** — ModMaster, ModJewelAbyss, ModJewelCluster, ModGraft, ModMap, ModFoulborn, ModFoulbornMap, ModTincture, ModNecropolis, ModJewelCharm（全て同一）
**Data/Bases/** — graft.lua, tincture.lua（同一）
**Data/Skills/** — glove.lua（同一）

---

## 12. 30%統合推奨対象

### 12.1 即時統合可能（差分なし確認済み — 統合不要）

以下のファイルは既に上流と完全同一。統合作業は不要:
- StatDescriptions/ 共通22ファイル
- Mod系10ファイル（Master, JewelAbyss, JewelCluster等）
- Calc系モジュール9ファイル
- Bases/graft.lua, tincture.lua
- Skills/glove.lua

### 12.2 価値ある統合候補（30%ターゲット）

| 優先度 | ファイル/領域 | 統合内容 | リスク |
|--------|-------------|---------|--------|
| **P1** | `Data/Costs.lua` | 上流の新コストデータ追加 | LOW |
| **P1** | `Data/FlavourText.lua` | 上流の新フレーバーテキスト（PoE2共通部分） | LOW-MED |
| **P1** | `Modules/CalcPerform.lua` | 22行の差分（計算修正） | LOW |
| **P2** | `Data/Gems.lua` | 上流の新ジェムデータ（選択的マージ） | MEDIUM |
| **P2** | `Data/SkillStatMap.lua` | 上流の新スタットマッピング | MEDIUM |
| **P2** | `Data/ModCache.lua` | 上流の新キャッシュロジック | MEDIUM |
| **P3** | `Data/Skills/sup_*.lua` | サポートジェム更新（選択的マージ） | MEDIUM |
| **P3** | `Data/Skills/minion.lua` | ミニオンスキル更新 | MEDIUM |

### 12.3 統合禁止（破壊的変更）

Uniques全共通, Skills/act_*, Bases主要, ModItem, QueryMods,
Misc, Global, Locales, Data.lua, Main.lua, i18n.lua,
ItemsTab, PassiveTree, Build.lua

---

*本文書は実際のファイル解析（diff, wc -l, ファイル内容確認）に基づく。推測を含まない。*
