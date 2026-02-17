# Active ORBIT LLM-Side Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the token-heavy /routine 5-phase system and verbose CLAUDE.md ORBIT section with a lightweight, event-driven Active ORBIT protocol that reduces per-task token consumption by 94-98%.

**Architecture:** Two file edits: (1) CLAUDE.md rewrite of sections 0, 1, 2 and the ORBIT Trinity block; (2) skills/routine/SKILL.md complete replacement with Tier-based lightweight routine. No code changes — text/config only.

**Tech Stack:** Markdown (CLAUDE.md, SKILL.md)

---

### Task 1: Rewrite CLAUDE.md sections 0 + 1 (Chronos + Routine)

**Files:**
- Modify: `.claude/CLAUDE.md:7-17`

**Step 1: Replace section 0 and section 1**

Replace lines 7-17 (sections "0. 第一規律" and "1. ルーティン実行") with:

```markdown
### 0. LOGOS-ORBIT: Active Protocol
`record_action` を唯一のエントリポイントとし、3モードが**イベント駆動**で自動発動する:

- **Guardian** (edit前): 過去失敗パターン照合 + インターフェース破壊検出。`audit_contract` が自動実行
- **Navigator** (search 5回超 or entropy >0.9): 未探索ファイル提案 + 未検証edit警告。`check_drift` が自動実行
- **Chronicler** (タスク完了後): 失敗→ルール自動生成 / 成功→パターン永続化 / ユーザー修正→新基準学習

呼び出し: **`record_action` のみ**。`/routine` は廃止。Tier判定で作業量を自動調整:
- **Micro** (単一ファイル修正): record_actionのみで着手
- **Standard** (通常タスク): 関連ルール確認 + 1行計画提示後に着手
- **Full** (大規模変更): EnterPlanModeで計画策定 + AskUserQuestion承認後に着手

**迷走警告**: record_actionまたはcheck_driftで迷走警告が出た場合、即座に作業を中断しユーザーに報告。
```

Old string to match for Edit tool:
```
### 0. 第一規律: Chronos記録と迷走監視
**あらゆる作業を開始する前に**、必ず `mcp__logos-chronos__record_action` を呼び出し現在の計画を記録せよ。
- actionType: 実行しようとしているアクション種別（search/edit/read/write/verify/plan/ask）
- target: 対象ファイルまたはリソース
- intent: 何をしようとしているか（10文字以上）
- rationale: なぜそれをするのか（10文字以上）

**迷走警告**: `mcp__logos-chronos__check_drift` またはrecord_actionの応答で迷走（drift）警告が出た場合、**即座に作業を中断してユーザーに報告**せよ。自己判断で続行してはならない。

### 1. ルーティン実行
タスク開始前に `/routine` スキルを必ず実行。定義: `skills/routine/SKILL.md`
```

**Step 2: Verify the edit**

Run: Read `.claude/CLAUDE.md` lines 7-20 and confirm the new content is in place.

**Step 3: Commit**

```bash
git add .claude/CLAUDE.md
git commit -m "refactor(orbit): replace Chronos+routine sections with Active ORBIT protocol"
```

---

### Task 2: Rewrite CLAUDE.md section 2 (Subagent rules)

**Files:**
- Modify: `.claude/CLAUDE.md:19-21` (after Task 1 edit, line numbers will shift)

**Step 1: Replace section 2**

Replace the current section 2:
```
### 2. Lua修正はサブエージェント必須
`.lua`ファイルの修正はTask toolに委譲。メインエージェントが直接Edit/Writeしない。
詳細: `.claude/AGENT.md`
```

With:
```markdown
### 1. Lua修正: Micro-Agent Protocol（5000トークン上限）
`.lua`修正はTask toolに委譲（メインエージェントは直接Edit/Writeしない）。

**プロンプト形式**（300トークン以内）:
```
TASK: [1行で何をするか]
FILE: [絶対パス]
LINE: [行番号]
CHANGE: old_string → new_string
CONSTRAINT: LuaJIT 5.1 | no nil fallback | %s+tostring()
```

**モデル選択**: `haiku`(単純置換, max_turns:3) / `sonnet`(ロジック変更, max_turns:5)
**ルール**: 1サブエージェント = 1ファイル1変更。ファイル全文をプロンプトに含めない。
```

**Step 2: Renumber remaining sections**

After replacing section 2, renumber:
- Old "### 3. エラーハンドリング" → "### 2. エラーハンドリング"
- Old "### 4. 表示確認ワークフロー" → "### 3. 表示確認ワークフロー"

**Step 3: Verify the edit**

Run: Read `.claude/CLAUDE.md` lines 1-40 and confirm numbering and content.

**Step 4: Commit**

```bash
git add .claude/CLAUDE.md
git commit -m "refactor(orbit): replace subagent section with Micro-Agent Protocol"
```

---

### Task 3: Replace CLAUDE.md ORBIT Trinity section

**Files:**
- Modify: `.claude/CLAUDE.md:136-155` (line numbers approximate after prior edits)

**Step 1: Replace the entire LOGOS-ORBIT Trinity Protocol block**

Replace:
```
## LOGOS-ORBIT Trinity Protocol

### 物理制約: Extreme Pruning
- **30行ルール**: 1ファイル30行 or 3関数を超える変更は禁止。超過時はタスクを分割
- **Index-Only Matching**: 過去パターンはUUID/Tag目次のみロード。中身のFetchは実装時まで遅延
- **AST-Partial Snippet**: 全文読み込み禁止。grep/ast-queryで必要シンボル周辺のみ抽出

### 審議・再考: Logos Deliberation
- **Pre-Contract Audit**: 実装前に `audit_contract` でインターフェース契約を監査
- **Blind Verification**: `blind_verify` で過去履歴を無視した独立再評価を実施
- **Chronos Sentinel**: `check_drift` の `explorationRoutes` に従い未知の探索ルートを試行

### 自律成長: Recursive Growth
- **Nomos Tattooing**: 成功パターンを `tattoo_spec` でUUID付きスキルとして永続化
- **Integrity Evolution**: 人間の修正指摘を `evolve_criterion` で新検閲基準に変換
- **Traceable Singularity**: `generate_rule` の `trace` で変更差異と改善率を開示

### 報告義務
- セッション完了時に `report_session` で集計報告を生成
```

With:
```markdown
## LOGOS-ORBIT Active Protocol（詳細）

### 制約
- **30行ルール**: 1ファイル30行超の変更は分割
- **AST-Partial**: grep/ast-queryで必要シンボル周辺のみ抽出

### 報告義務
- セッション完了時に `report_session` で集計報告を生成
```

**Step 2: Verify the edit**

Run: Read the ORBIT section and confirm it's now 6 lines instead of 19.

**Step 3: Commit**

```bash
git add .claude/CLAUDE.md
git commit -m "refactor(orbit): compress Trinity Protocol to Active Protocol essentials"
```

---

### Task 4: Update サブエージェント section in 運用ルール

**Files:**
- Modify: `.claude/CLAUDE.md` (運用ルール > サブエージェント section)

**Step 1: Replace the サブエージェント subsection**

Replace:
```
### サブエージェント
- 汎用エージェントではなくスキル（プログレッシブ開示）を使用
- 機能固有のサブエージェントを作成
- トラブルシューティング: `.claude/AGENT.md`
```

With:
```markdown
### サブエージェント
- Micro-Agent Protocol準拠（必須ルール§1参照）
- トラブルシューティング: `.claude/AGENT.md`
```

**Step 2: Commit**

```bash
git add .claude/CLAUDE.md
git commit -m "refactor(orbit): simplify subagent operational rules"
```

---

### Task 5: Rewrite skills/routine/SKILL.md

**Files:**
- Modify: `skills/routine/SKILL.md` (full replacement)

**Step 1: Replace entire file**

Write the following content to `skills/routine/SKILL.md`:

```markdown
---
name: routine
description: Execute mandatory planning routine before task execution
---

# /routine

Lightweight pre-task routine. Replaces the former 5-phase system.

## When to use

Use at the start of significant tasks (code changes, investigations, feature work).
Skip for simple read-only queries or single-line fixes.

## Prompt

Execute the Active ORBIT pre-task routine:

### Step 1: Tier判定

Assess the task and assign a Tier:

| Tier | Criteria | Action |
|------|----------|--------|
| **Micro** | Single file, simple fix, clear change | `record_action` only. Start immediately. |
| **Standard** | Normal task, 1-3 files | `record_action` → check related Nomos rules → present 1-line plan to user → start |
| **Full** | 3+ files, architectural change, unclear requirements | `record_action` → `EnterPlanMode` → full plan → `AskUserQuestion` approval → start |

### Step 2: Execute per Tier

**Micro:**
1. Call `record_action` with intent/rationale
2. Begin work immediately

**Standard:**
1. Call `record_action` with intent/rationale
2. If response contains `guardianAlert` or related rules, review them
3. Present 1-line plan: "I will [action] in [file] because [reason]"
4. Begin work

**Full:**
1. Call `record_action` with intent/rationale
2. Use `EnterPlanMode` to create detailed plan
3. Present plan via `AskUserQuestion` for approval
4. Begin work only after approval

### Key constraints (always apply)
- LuaJIT 5.1 only (no Lua 5.2+ features)
- No nil fallback (`or {}`, `or ""`) — fix root cause
- `ConPrintf`: `%s` + `tostring()` only (no `%d`)
- `ProcessEvents()` before `Draw*()`
- Lua edits via subagent (Micro-Agent Protocol, 5000 token cap)

## Expected output

- Tier announced to user
- For Standard/Full: plan presented before work begins
- Work started (or approval awaited for Full tier)
```

**Step 2: Verify the file**

Run: Read `skills/routine/SKILL.md` and confirm it's the new content (~60 lines vs old 280 lines).

**Step 3: Commit**

```bash
git add skills/routine/SKILL.md
git commit -m "refactor(orbit): replace 5-phase routine with Tier-based Active ORBIT"
```

---

### Task 6: Final verification

**Step 1: Count lines in modified files**

Run:
```bash
wc -l .claude/CLAUDE.md skills/routine/SKILL.md
```

Expected: CLAUDE.md ~130 lines (was 163), SKILL.md ~60 lines (was 280).

**Step 2: Read both files end-to-end**

Verify:
- No references to "Phase 1-5" remain in either file
- No references to "Prophet", "Mayor", "Paladin" etc. in CLAUDE.md
- Section numbering is consistent (0, 1, 2, 3)
- ORBIT section is under 10 lines

**Step 3: Final commit if any cleanup needed**

```bash
git add -A && git commit -m "chore(orbit): final cleanup of Active ORBIT migration"
```

---

## Summary of token savings

| File | Before (lines) | After (lines) | Saved |
|------|----------------|---------------|-------|
| CLAUDE.md | 163 | ~130 | ~20% per-turn base cost |
| SKILL.md | 280 | ~60 | ~79% per-routine invocation |
| /routine execution cost | 5,000-15,000 tokens | 100-500 tokens | 90-97% |
