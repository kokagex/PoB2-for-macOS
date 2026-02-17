# PoB2 上流データ 次の30%統合計画書

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** リバート後にディスク残存している未追跡PoE2データファイル（StatDescriptions 5ファイル + WorldAreas.lua）を安全性検証の上でgit管理下に追加する

**Architecture:** 前回（Phase 1: 664ファイル）と同様の作業。検証→git add→コミット。コード変更なし。

**Tech Stack:** LuaJIT 5.1データファイル、Git

---

## Context

前回コミット `4681b02` で664個の`Specific_Skill_Stat_Descriptions/`配下ファイルを追跡開始済み。
残存する未追跡Dataファイル:

| ファイル | 行数 | 備考 |
|---------|------|------|
| `StatDescriptions/passive_skill_stat_descriptions.lua` | 4,302 | パッシブスキル統計記述 |
| `StatDescriptions/advanced_mod_stat_descriptions.lua` | 1,154 | アドバンスドMod記述 |
| `StatDescriptions/meta_gem_stat_descriptions.lua` | 574 | メタジェム記述 |
| `StatDescriptions/passive_skill_aura_stat_descriptions.lua` | 573 | パッシブオーラ記述 |
| `StatDescriptions/utility_flask_buff_stat_descriptions.lua` | 141 | フラスクバフ記述 |
| `WorldAreas.lua` | 6,471 | ワールドエリアデータ |

**注意**: `WorldAreas.lua`はPoE2専用カスタムデータとして`RESEARCH_local.md`に記載あり（PoE2固有エリア定義）。上流の`WorldAreas.lua`とは内容が異なる可能性があるため要検証。

---

## Task 1: StatDescriptions 5ファイルの内容検証

**Files:**
- Read: `PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/passive_skill_stat_descriptions.lua` (先頭30行)
- Read: `PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/advanced_mod_stat_descriptions.lua` (先頭30行)
- Read: `PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/meta_gem_stat_descriptions.lua` (先頭30行)
- Read: `PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/passive_skill_aura_stat_descriptions.lua` (先頭30行)
- Read: `PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/utility_flask_buff_stat_descriptions.lua` (全文)

**Step 1: 各ファイルの先頭20-30行を読む（並列）**

5ファイル同時読み込み。

**Step 2: PoE2形式の確認チェックリスト**

各ファイルに対して以下を確認:
- [ ] `return { ... }` 形式のLuaテーブル
- [ ] `stats = { ... }` キーを含む
- [ ] `parent = "..."` キーを含む（継承チェーン）
- [ ] PoE1専用スキル名が含まれない（`PoE1`固有: `Vaal`, `Pledge of Hands`等の旧スキル）

**成功基準**: 全5ファイルがPoE2 stat description形式であること

---

## Task 2: WorldAreas.lua の内容検証

**Files:**
- Read: `PathOfBuilding.app/Contents/Resources/src/Data/WorldAreas.lua` (先頭50行 + 末尾20行)
- Compare: `pob2macos/dev/pob2-original/src/Data/WorldAreas.lua` が存在する場合、行数を比較

**Step 1: ファイル先頭50行を読む**

```bash
# 先頭50行
head -50 PathOfBuilding.app/Contents/Resources/src/Data/WorldAreas.lua
# 上流との行数比較（存在する場合）
wc -l pob2macos/dev/pob2-original/src/Data/WorldAreas.lua 2>/dev/null || echo "upstream not found"
wc -l PathOfBuilding.app/Contents/Resources/src/Data/WorldAreas.lua
```

**Step 2: PoE2エリアデータの確認**

確認ポイント:
- [ ] `worldAreas["..."] = { ... }` 形式
- [ ] PoE2固有エリア名が含まれる（`"Ogham Village"`, `"Clearfell"`等）
- [ ] または上流と比較して行数差が大きい → ローカルカスタム版

**Step 3: 上流との差分チェック（任意）**

上流ファイルが存在する場合:
```bash
diff pob2macos/dev/pob2-original/src/Data/WorldAreas.lua \
     PathOfBuilding.app/Contents/Resources/src/Data/WorldAreas.lua | head -40
```

**判定基準**:
- ローカル行数 > 上流行数 → PoE2エリア追加済みの独自版 → 追跡OK
- ローカル == 上流 → 上流データのコピー → 追跡OK（データファイルのみ）
- PoE1固有エリアのみ → 要確認

---

## Task 3: StatDescriptions 5ファイルのgit追加とコミット

**前提**: Task 1の全チェックリストがパス済みであること

**Step 1: ステージング**

```bash
git add PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/passive_skill_stat_descriptions.lua
git add PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/advanced_mod_stat_descriptions.lua
git add PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/meta_gem_stat_descriptions.lua
git add PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/passive_skill_aura_stat_descriptions.lua
git add PathOfBuilding.app/Contents/Resources/src/Data/StatDescriptions/utility_flask_buff_stat_descriptions.lua
```

**Step 2: ステージング確認**

```bash
git diff --cached --stat
```

期待出力: 5ファイル、合計6,000〜7,000行程度

**Step 3: コミット**

```bash
git commit -m "data: track PoE2 StatDescriptions base files (passive_skill, advanced_mod, meta_gem, passive_aura, flask)"
```

---

## Task 4: WorldAreas.lua のgit追加とコミット

**前提**: Task 2のチェックリストがパス済みであること

**Step 1: ステージング**

```bash
git add PathOfBuilding.app/Contents/Resources/src/Data/WorldAreas.lua
```

**Step 2: ステージング確認**

```bash
git diff --cached --stat
```

期待出力: 1ファイル、6,471行

**Step 3: コミット**

```bash
git commit -m "data: track WorldAreas.lua (PoE2 world area definitions, 6471 lines)"
```

---

## Task 5: 最終確認

**Step 1: コミット履歴の確認**

```bash
git log --oneline -5
```

**Step 2: 未追跡のData関連ファイルがないか確認**

```bash
git status --short | grep "src/Data"
```

期待出力: src/Data配下の未追跡ファイルなし（または意図的なもののみ）

**Step 3: アプリ起動テスト（オプション）**

起動してエラーなしを確認。

---

## 統合禁止リスト（変更なし）

| カテゴリ | 保護対象 |
|---------|---------|
| i18n/CJK | pob2_launch.lua, i18n.lua, ja*.lua |
| PoE2データ | Uniques/*, Skills/act_* |
| macOS/表示 | Main.lua, Build.lua, PassiveTree.lua |

---

## リスク評価

| Phase | リスク | 理由 |
|-------|--------|------|
| StatDescriptions 5ファイル | LOW | 前回と同形式のデータファイル |
| WorldAreas.lua | LOW-MEDIUM | 6,471行の大きなファイル。PoE2専用版かを要確認 |
