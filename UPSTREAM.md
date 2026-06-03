# 上流同期ステータス / Upstream Sync Status

上流: `PathOfBuildingCommunity/PathOfBuilding-PoE2` `dev` ブランチ
ローカル: `kokagex/PoB2-for-macOS` `main` ブランチ
最終同期: 2026-06-03 (Phase 10, 上流 commit `adda26750` / Release 0.17.1)

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

### ✅ Phase 5 — (2026-03-17): upstream/dev 6ebe367 まで同期

上流 `75f06dc..6ebe367` の差分は**1コミット・1ファイルのみ**:

| ファイル | 変更内容 |
|---|---|
| `src/Classes/TradeQueryGenerator.lua` | modWeightsソート改善: meanStatDiff同値時にabs(weight)でタイブレイク、重複ソート削除 (#1779) |

Data/, Modules/ の変更なし。翻訳辞書更新不要。

---

### ✅ Phase 6 — (2026-05-03): upstream/dev 31dabfaa1 まで同期

上流 `6ebe367..31dabfaa1` の 18 commits / 25 files / +241/-122 行を機能別に取り込み。
worktree `.worktrees/upstream-sync-phase6` (branch `sync/upstream-phase6`) で 4 commit に分割。

#### Modules (commit `2f25905`)

| ファイル | 変更内容 |
|---|---|
| `src/Modules/CalcDefence.lua` | pob1-port: negative eHP / NaN Max hit fix (#1799) |
| `src/Modules/CalcOffence.lua` | pob1-port: skill repeat 計算修正 + trap/mine 二重カウント fix (#1791) |
| `src/Modules/BuildSiteTools.lua` | URL spoofing fix: `matchURL` に `^https:/` 強制 (#1792, security) |
| `src/Modules/CalcSetup.lua` | alternate quality 廃止: `qualityId` 参照削除 (#1794) |
| `src/Modules/ModParser.lua` | `magnitude of ailments` mod 追加 (#1793) + Molten One's Gift fix (#1803) + Duelist mod 移設 |

ローカル衝突: BuildSiteTools.lua と CalcSetup.lua は変更箇所が離れていて自動マージ可。ModParser.lua はローカル変更ゼロで完全 fast-forward。

#### Data (commit `e792a38`) — 完全 fast-forward (ローカル変更ゼロ)

| ファイル | 変更内容 |
|---|---|
| `src/Data/StatDescriptions/stat_descriptions.lua` | `canonical_stat` / `canonical_line` キー順序入れ替えのメタ変更のみ (`desc.text` 本文変更なし → `ja_stat_descriptions.lua` 追従不要) |
| `src/Data/ModCache.lua` | 自動再生成 |
| `src/Data/SkillStatMap.lua` | mod マッピング追加 6 行 |
| `src/Data/Uniques/body.lua` | Keeper of the Arc legacy mod 修正 (#1784) |
| `src/Data/Uniques/{helmet,jewel,amulet}.lua` | variant text ordering fix: The Adorned, Yoke of Suffering 等 (#1783) |

#### Classes (commit `7063014`)

| ファイル | 変更内容 |
|---|---|
| `src/Classes/Tooltip.lua` | spell-checker directives 追加のみ (#1771) |
| `src/Classes/SkillsTab.lua` | `alternateGemQualityList` 削除 (#1794) — ローカル i18n 化リストは温存、未使用関数のみ削除 |
| `src/Classes/GemSelectControl.lua` | `GetQualityType` メソッド削除 + `UpdateGem` 引数調整 (#1794) |
| `src/Classes/ImportTab.lua` | Remember league for imported characters (#1795) — `lastLeague` の Save/Load + `DownloadCharacterList` 復元ロジック |

3-way merge: SkillsTab.lua のみ衝突、ローカル i18n を維持しつつ alternate quality 関連のみ削除で手動解決。

#### その他 (commit `14df3f0`)

| ファイル | 変更内容 |
|---|---|
| `src/HeadlessWrapper.lua` | `GetVirtualScreenSize` stub 追加 (#1789) |
| `src/UpdateCheck.lua` | 絶対パス対応 (PoB1 PR #9777 移植 #1802) |

#### スキップ判定 (Phase 6 で取り込まないファイル)

| ファイル | 理由 |
|---|---|
| `CONTRIBUTING.md` | ローカル独自化 372 行差、上流 doc 変更 (spell-checker directives 追加) は取り込み価値低 |
| `src/Export/*` (6 ファイル) | ローカル PoE2 export 大幅改造、上流変更との 3-way merge は影響範囲不明 → 別 sprint で扱う |

#### 検証

- 全 18 ファイル LuaJIT syntax check PASS (`luajit -bl <file> /dev/null`)
- busted 単体テスト: 環境に未インストールのため未実施 (要 `luarocks install busted` for LuaJIT)
- `scripts/build-app.sh --dev` 起動確認: ユーザー側で実施推奨

---

### ✅ Phase 7 — (2026-05-23): upstream/dev f0ed15fd4 まで同期

上流 `31dabfaa1..f0ed15fd4` の 64 commits / 84 files / +17890/-8628 行の差分。
worktree `.worktrees/upstream-sync-phase7` (branch `sync/upstream-phase7`) で 3 commit に分割。
**Build comparison tab (#1830, 30 files / +14998/-7838) は Phase 8 へ分離**。

#### Modules (commit `493ddf38d`) — 10 files

| ファイル | 内容 |
|---|---|
| `src/Modules/BuildSiteTools.lua` | 末尾改行修正 (fast-forward) |
| `src/Modules/CalcDefence.lua` | バグ修正各種 (fast-forward, ローカル変更ゼロ) |
| `src/Modules/CalcOffence.lua` | バグ修正各種 (fast-forward, ローカル変更ゼロ) |
| `src/Modules/CalcPerform.lua` | バグ修正各種 (fast-forward, ローカル変更ゼロ) |
| `src/Modules/ConfigOptions.lua` | 設定追加 (fast-forward, ローカル変更ゼロ) |
| `src/Modules/ModParser.lua` | 大量 unique mod 追加 (fast-forward, ローカル変更ゼロ) |
| `src/Modules/CalcActiveSkill.lua` | 上流変更 + `skillFlags` 後方互換性パッチ温存 |
| `src/Modules/ItemTools.lua` | 上流変更 + `i18n.translateModLine` パッチ温存 |
| `src/Modules/CalcSections.lua` | 上流変更 + `MindOverMatter` modName table 構文修正温存 (Physical/Cold/Fire 3 箇所) |
| `src/Modules/CalcSetup.lua` | 上流変更 + `gemName` i18n.t() 翻訳 / `srcInstance` 追加パッチ温存 |

#### Data (commit `a71cc5df1`) — 10 files (全 fast-forward)

| ファイル | 主な変更 |
|---|---|
| `src/Data/Gems.lua` | Eternal Mark Support export (#1858) |
| `src/Data/ModCache.lua` | 自動再生成 |
| `src/Data/SkillStatMap.lua` | Flame Breath attack rate fix (#1912), Zarokh's Revolt (#1811), Inhibitor consumed charge fix |
| `src/Data/Skills/act_dex.lua` | バグ修正各種 |
| `src/Data/Skills/act_int.lua` | Dark Effigy DPS scaling (#1939), Palm skills Quarterstaff fix (#1903), Temporal Chains support (#1812) |
| `src/Data/Skills/act_str.lua` | バグ修正各種 |
| `src/Data/Skills/other.lua` | バグ修正各種 |
| `src/Data/Skills/sup_dex.lua` | バグ修正各種 |
| `src/Data/Skills/sup_int.lua` | Dark Effigy DPS scaling (#1939), Zarokh's Revolt (#1811), Glacial Cascade Final Burst (#1815) |
| `src/Data/Skills/sup_str.lua` | Stomping Ground / Ferocious Roar Talisman fix (#1901), Lineage supports (#1828), Corrupting Cry fix (#1831) |

#### Classes (commit `8722c9a38`) — 9 files

3-way merge は `git apply --3way` 方式で実施 (`git merge-file -p` は unrelated histories で silent に theirs を採用する罠あり)。i18n.t() / macOS カスタマイズ全て温存確認。

| ファイル | 主な変更 |
|---|---|
| `src/Classes/PowerReportListControl.lua` | PoB1 PR #9823 取り込み (#1834) — local 変更ゼロ |
| `src/Classes/Item.lua` | Charm quality (#1940), Adnonia's Ego crash (#1936), pasted runes (#1877) |
| `src/Classes/ConfigTab.lua` | Show All Configurations filter (#1892), Corrupted Blood (#1831) |
| `src/Classes/EditControl.lua` | fractional full DPS (#1916) |
| `src/Classes/ItemDBControl.lua` | damage taken sort fix (#1889) |
| `src/Classes/PartyTab.lua` | party member stat decimal parsing (#1872) |
| `src/Classes/TreeTab.lua` | PoB1 PR #9823 (#1834) |
| `src/Classes/CalcBreakdownControl.lua` | Commanding Rage / Expendable Army (#1846) |
| `src/Classes/ModStore.lua` | 手動マージ: `getActor` ヘルパー追加 (上流必須) + `noFloor`/`scalar` 統合 + `replace`/`limitStat` パッチ温存 (Commanding Rage #1846, Deadeye Thrilling Chase #1860) |

#### Phase 8 へ分離 (大型 / 高衝突)

**Build comparison tab (#1830) — 30 files / +14998/-7838**:
- Modules: Build.lua, Main.lua, BuildList.lua, BuildListHelpers.lua, CalcFormat.lua, Data.lua
- Classes 新規: Compare{BuySimilar, CalcsHelpers, Entry, PowerReportListControl, Tab, TradeHelpers}.lua
- Classes 既存改造: CalcSectionControl, ControlHost, ImportTab, ItemsTab, PassiveMasteryControl, PassiveTreeView, TradeQueryGenerator, TradeQueryHelpers
- Data: ModCharm, ModCorrupted, ModFlask, ModIncursionLimb, ModItem, ModItemExclusive, ModJewel, ModVeiled, Global

理由: Build.lua/Main.lua のローカル独自カスタマイズ +515/+198 行との 3-way merge 衝突リスク、i18n 対応コスト、新 Tab 機能の macOS UI 適合性検証が独立 sprint 必要。

**高衝突 3 files**:
| ファイル | 上流 PR |
|---|---|
| `src/Classes/PassiveSpec.lua` | #1904 weapon set + node color, #1925 crash on old builds |
| `src/Classes/PoEAPI.lua` | #1922 OAuth error surfacing |
| `src/Classes/SkillsTab.lua` | #1916 fractional DPS, #1883 item-granted skill socket limit |

`git apply --3way` で conflict 残存。ローカル独自カスタマイズが大きく、Phase 8 で個別 cherry-pick を慎重に検討。

#### スキップ判定 (Phase 7 で取り込まないファイル)

| ファイル | 理由 |
|---|---|
| `CONTRIBUTING.md` | Phase 6 と同じく上流 doc 変更は取り込み価値低 |
| `src/Export/*` (10 ファイル) | Phase 6 と同じく別 sprint で扱う |
| `spec/*` (10 ファイル) | ローカルに `spec/` ディレクトリ自体なし (test/unit/ 構造) |
| `.busted`, `.github/workflows/test.yml` | ローカル独自完全カスタマイズ (luajit + test/unit/) と構造ずれ |

#### 検証

- 全 29 ファイル LuaJIT syntax check PASS (`luajit -bl <file> /dev/null`)
- i18n.t() / macOS カスタマイズ温存確認 (HEAD 出現数と一致):
  - ConfigTab=10, EditControl=0, ItemDBControl=10, PartyTab=24, TreeTab=1
- busted 単体テスト: 環境に未インストールのため未実施
- `scripts/build-app.sh --dev` 起動確認: ユーザー側で実施推奨

---

### ✅ Phase 8 — (2026-05-23): Compare Tab (#1830) + 高衝突 3 files

Phase 7 で分離していた **Compare Tab + PassiveSpec/PoEAPI/SkillsTab** を取り込み。
来週予定の大型アップデート前に upstream 追従するためユーザー指示で実施。
worktree `.worktrees/upstream-sync-phase8` (branch `sync/upstream-phase8`) で 2 commit に分割。

#### Phase 8a Compare Tab (commit `3f2ed6ad6`) — 28 files

**git apply --3way** + 手動マージで ローカル独自パッチ温存。
**`git merge-file -p` は unrelated histories で silent theirs 採用バグあり、`git apply --3way` 必須**。

新規 NEW 9 files (上流から checkout):
| ファイル | 内容 |
|---|---|
| `src/Modules/BuildListHelpers.lua` | buildSortDropList を Compare Tab と共有 |
| `src/Modules/CalcFormat.lua` | `formatCalcStr` グローバル関数 (Compare Tab で共通利用) |
| `src/Classes/Compare{BuySimilar, CalcsHelpers, Entry, PowerReportListControl, Tab, TradeHelpers}.lua` | Compare Tab 本体 6 files |
| `src/Classes/TradeQueryHelpers.lua` | `GetTradeCategory()` 関数化 |

CLEAN fast-forward 11 files (ローカル変更ゼロ):
| ファイル | 内容 |
|---|---|
| `src/Classes/PassiveMasteryControl.lua` | Mastery node 拡張 |
| `src/Modules/Data.lua`, `src/Classes/ControlHost.lua` | clean --3way apply |
| `src/Data/{Global, ModCharm, ModCorrupted, ModFlask, ModIncursionLimb, ModItem, ModItemExclusive, ModJewel, ModVeiled}.lua` | 大量 Mod データ更新 (+14000 行) |

手動マージ 8 files:
| ファイル | 統合内容 |
|---|---|
| `src/Modules/BuildList.lua` | BuildListHelpers shared list + i18n.t() label 上書き再適用 |
| `src/Modules/Main.lua` | isJapanese レイアウト + popupWidth ベース統合 + migrateAugments checkbox 取り込み |
| `src/Modules/Build.lua` | 7 conflicts 統合: save/saveAs ボタン (i18n) + buildName.x/y 動的 + secondaryAscendDrop (PoE2 alternate ascendancy) + Spec nil-safety + alternate_ascendancies sorting + statSet.skillFlags 経路 + Spectre/Companion 分岐 + buildNameConditional layout |
| `src/Classes/CalcSectionControl.lua` | displayLabel (i18n) + formatCalcStr (上流 global) 統合 |
| `src/Classes/ImportTab.lua` | ours (同期 OAuth) 維持 — ローカル PoEAPI と互換性確保 |
| `src/Classes/ItemsTab.lua` | clean apply + addCompareForSlot 関数の i18n.t() 化 |
| `src/Classes/TradeQueryGenerator.lua` | theirs 採用 (大量 elseif → tradeHelpers.GetTradeCategory 関数化) |

#### Phase 8b 高衝突 3 files (commit `fee57c35e`) — 2 files (PoEAPI は実質スキップ)

| ファイル | 内容 |
|---|---|
| `src/Classes/PassiveSpec.lua` | weapon set alloc + node color (#1904), crash on old builds (#1925), pathRoot + CanPathThroughAllocMode 取り込み (path 関数結果使用に統一)、PRJ-003 pathDist nil-safety + MINIMAL_PASSIVE_TEST (12 件) 温存 |
| `src/Classes/SkillsTab.lua` | fractional DPS (#1916), item-granted skill socket limit (#1883)、i18n.t (71 件) 温存 |
| `src/Classes/PoEAPI.lua` | **上流の callback 方式 OAuth は不採用** (LaunchSubScript 方式は ローカル macOS BeginAuth/secure_random_bytes/LaunchServer.lua dofile 実装と互換性なし)。HEAD と完全一致状態で commit にも含まれない (ImportTab と OAuth 方式統一) |

#### Phase 9 へ分離

| ファイル | 理由 |
|---|---|
| `src/Classes/PassiveTreeView.lua` | 描画ループ構造が完全に異なる: ローカル Metal/MINIMAL_PASSIVE_TEST + secondaryAscendNameMap + calcsTab nil-safety + Phase 1 描画書き換え と 上流 compareSpec hover + allocMode + jewel art が同領域で根本的衝突。compareSpec ツリー比較は機能しないが Compare Tab 本体 (テキスト比較) は動作 |

#### スキップ判定 (Phase 8 で取り込まないファイル)

Phase 7 と同じ。

#### 検証

- 全 30 files (Phase 8a 28 + Phase 8b 2) LuaJIT syntax check PASS
- ローカル独自パッチ温存確認 (HEAD 出現数と一致):
  - isJapanese=4, fontScale=7, deferTooltips=8, MINIMAL_PASSIVE_TEST=14 (PassiveTreeView 温存分含む)
  - PassiveSpec MINIMAL_PASSIVE_TEST=12, PoEAPI BeginAuth/secure_random_bytes=5, SkillsTab i18n.t=71
- busted 単体テスト: 環境に未インストールのため未実施
- `scripts/build-app.sh --dev` 起動確認: ユーザー側で実施推奨

#### i18n 新 UI 文字列の後追い (Phase 8 後の別 sprint)

Compare Tab + 新 UI 機能で英語ラベルが追加された。`ja.lua` への翻訳キー追加が必要:
- `migrateAugments` checkbox (Main.lua "Copy augments onto display item:")
- `Anoint 2/3/4` ボタン (ItemsTab.lua)
- "Auto"/"Manual" levelScaling button (Build.lua の英語ラベル温存)
- "Import/Export Build" (Build.lua)
- `gemNameHeader` 系 (SkillsTab i18n.t は温存済、新 UI のみ)
- Compare Tab 本体 UI ラベル

`MEMORY.md` の翻訳ワークフロー: grep で全使用箇所洗い出し → ja.lua/en.lua にキー追加 → label を i18n.t() に巻き直し。

---

### ✅ Phase 9 — v0.8.0 (2026-05-30): upstream/dev `9c2bf0316` (Release 0.16.0) まで同期

上流 `f0ed15fd4..9c2bf0316` を取り込み。0.5 ツリー大型更新。
worktree `.worktrees/upstream-sync-phase9` で分割 commit、main へ merge 済 (release v0.8.0)。

主な取り込み:
- `#1865` Loadout management UI (ItemSet/SkillSet サービス化、Build.lua fork機能/i18n 保全)
- `#1984` 0.5 JSON skill tree サポート + `#1998` orbit 値修正/node overlay
- `#1841` Tooltip multi-column (fork descFrame 統合)
- Modules 計算エンジン 13 files、SkillsTab/ItemsTab/Item/ConfigTab i18n 移植
- PassiveTree + PassiveTreeView: 0.5 JSONツリー採用 + macOS Metal 描画/MINIMAL_PASSIVE_TEST 保全

> 注: 当時 UPSTREAM.md への記録が漏れていたため Phase 10 で遡及記載。

### ✅ Phase 10 — v0.9.0 (2026-06-03): upstream/dev `adda26750` (Release 0.17.1) まで同期

上流 `9c2bf0316..adda26750` の 23 commits を取り込み。worktree `.worktrees/upstream-sync-phase10`
(branch `feature/upstream-sync-phase10`) で 3 commit に分割。

#### Phase 10a 計算/データ層 (commit `ad00e4f0f`) — 229 files

clean fast-forward 219 files (`git diff 9c2bf0316 upstream/dev | git apply --index`):
- Data/Bases/*, Mod*, Skills/*, StatDescriptions/* (再生成), Costs/Essence/Gems/Global/
  Minions/Misc/ModCache/QueryMods/QuestRewards/Rares/SkillStatMap/FlavourText/
  LegionPassives/Uniques/gloves。soulcore.lua は Bases→Uniques 移動。
- Modules: CalcDefence/CalcOffence/ConfigOptions/ModParser (ローカル変更ゼロ)

3-way merge 10 files (ローカル i18n/macOS パッチ温存):
- Build.lua/PassiveSpec.lua: `#2023` searchStrCached リセット + MINIMAL ガード温存
- ItemsTab.lua: 11衝突全て ours (i18n.t 136 + textInputActive ガード、`#2019`/`#2035` はクリーン適用部)
- ImportTab/Item/CalcActiveSkill/CalcSetup/Common/HeadlessWrapper: clean 3way
- PassiveTreeView.lua: `#2023`(Unseen Path search hide)のみ → Metal描画/deferred tooltip 保全でローカル版維持

主要 upstream 修正: Zarokh's Revolt inf DPS `#2045`, Aggravated bleeding `#2054`,
Amazon crit `#2039`, Trarthan Cannon crash `#2048`, Rapid Casting III `#1965`,
New Loadout Link `#2038`, 0.5新Data `#2035`/runes `#2019`/quest rewards `#2027`。

検証: 全229 LuaJIT syntax PASS。不変量 HEAD一致。headless calc golden (TotalDPS 25062.57) 一致。

#### Phase 10b tree texture-array → 2D atlas 変換 (commit `cfb90bf81` + fix `1aeb2821c`)

upstream 0.17 はツリーアートを `.dds.zst` テクスチャ配列(BC7/BC1/RGBA, 1アイコン=1配列レイヤ)で
配布し tree.lua は `ddsCoords[sheet][name]=layerIndex` で参照。macOS dylib は stb_image=2D画像のみ
(配列DDS不可, dylibリビルド禁止)。0.16以前の `spriteCoords[sheet][name]={x,y,w,h}` 2D blit が唯一の実績。

変換パイプライン (レンダラ無改変):
- `scripts/dds_to_png.py`: 単一DDS(BC1/BC7/RGBA)→PNG デコーダ (imagecodecs + Pillow)
- `scripts/convert_tree_dds.py`: 各シートの配列レイヤをデコード→2Dアトラス PNG に再パック →
  tree.lua を ddsCoords→spriteCoords 書換 (冪等)。skills-disabled は除外(レンダラが desaturate)。
- `scripts/convert-tree-dds.sh` + build-app.sh 統合 (webp変換の直後、冪等)
- 26シート→.png atlas (skills/group-background/legion/oils/jewel-sockets/mastery 等)

GUI 実機テストで判明し fix `1aeb2821c` で修正した2バグ:
1. ddsCoords の裸識別子キー(`JewelFrameAllocated=16` 等の frame sprite)をパーサが取りこぼし
   → nodeOverlay 解決不能で PassiveTree.lua:302 クラッシュ。両キー構文捕捉で解決(166/166)。
2. atlas を `.dds.zst` 名で出力 → dylib が拡張子で DDS 経路に回し読込失敗 → `.png` 名出力に修正。

検証: 実機 dist build で OnInit 完走 + フレーム描画継続、全 atlas 読込成功、ユーザー目視で
ツリー描画 OK。node.icon 528/579 (欠落51=mastery, upstream ddsCoords自体に不在で専用描画経路)。

> 既知の非致命: `CharacterPlanned_orbit_*.png` は upstream が 0_4 のみ配布・0_5 未同梱 (上流不整合)。
> planned node の orbit overlay のみ未描画、ツリー本体に影響なし。

#### tree-data の同期モデル
- `tree-data/0_5/tree.lua` は tracked (spriteCoords 形式の renderable 版を commit)。
- 画像アセット(`.dds.zst`/`.png`/`.webp`)は gitignore のビルド入力。同期時に upstream から
  `.dds.zst` を取得 → convert-tree-dds で .png atlas 生成。fresh checkout は同期ワークフローで再生成。

#### スキップ判定 (Phase 10 で取り込まないファイル)
- `src/Export/*` (spec.lua +64k 等): ローカル独自改造のため別 sprint (Phase 6-9 と同じ)
- gem-icons texture array (`src/Data/Skills/gem-icons_64_64_BC1.dds.zst`): 同方式で別途対応可

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
