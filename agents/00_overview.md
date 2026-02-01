# Multi-Agent System Overview

## Hierarchy Structure

```
                    +------------+
                    |  Prophet   |
                    | (Divine)   |
                    +-----+------+
                          |
                          v
                    +-----+------+
                    |   Mayor    |
                    | (Command)  |
                    +-----+------+
                          |
          +-------+-------+-------+-------+
          |       |       |       |       |
          v       v       v       v       v
       +-----+ +-----+ +-----+ +-----+ +-----+
       |Pala-| |Merch| |Sage | |Bard | |Arti-|
       |din  | |ant  | |     | |     | |san  |
       +-----+ +-----+ +-----+ +-----+ +-----+
```

## Agent Roles

| Agent | Level | Trigger | Primary Function |
|-------|-------|---------|------------------|
| Prophet | 1 (Top) | On_Divine_Mandate | Strategic planning & auto-approval protocol |
| Mayor | 2 | On_Prophet_Revelation | Task coordination & risk assessment |
| Paladin | 3 | On_Mayor_Assignment | Quality assurance & execution verification |
| Merchant | 3 | On_Mayor_Assignment | External resource research & market intelligence |
| Sage | 3 | On_Mayor_Assignment | Technical validation & research |
| Bard | 3 | On_Mayor_Assignment | Documentation & communication |
| Artisan | 3 | On_Mayor_Assignment | Implementation safety & building |

## Communication Flow

### Top-Down Flow
1. **Prophet** → Plans and auto-approval decisions
2. **Mayor** → Task assignment and risk assessment
3. **Specialized Agents** → Parallel or sequential execution

### Bottom-Up Flow
4. **Specialized Agents** → Mayor (YAML reports)
5. **Mayor** → Prophet (consolidated report with LOW_RISK recommendation)
6. **Prophet** → God (final report or auto-approval notification)

### Detailed Workflow

```
Prophet (Strategic Planning)
  ↓
Mayor (Task Assignment & Risk Assessment)
  ↓
┌─────────────────────────────────────────────┐
│ Parallel/Sequential Execution Phase          │
├─────────────────────────────────────────────┤
│ Merchant (External Research) → Bard (Docs)  │
│ Sage (Technical Validation)                 │
│           ↓                                  │
│      Artisan (Implementation)                │
│           ↓                                  │
│      Paladin (Execution Verification)        │
└─────────────────────────────────────────────┘
  ↓
Mayor (Approval Recommendation: LOW_RISK or REQUIRES_DIVINE_APPROVAL)
  ↓
Prophet (Auto-Approval or Request Divine Judgment)
  ↓
God (Final Decision if required)
```

### Agent Collaboration Patterns

- **Merchant → Bard**: External research results → Documentation
- **Merchant → Sage**: Market intelligence → Technical validation
- **Sage → Artisan**: Technical validation → Safe implementation
- **Artisan → Paladin**: Implementation complete → Execution verification
- **Paladin → Mayor**: Verification results → Risk assessment
- **All Agents → Mayor**: YAML reports → Consolidated report to Prophet

## Agent Responsibilities in Detail

### Prophet (Strategic Planning Agent)
- **Role**: Strategic planning & auto-approval authority
- **Key Protocols**:
  - Auto-Approval Protocol (6 criteria for LOW_RISK tasks: scope, impact, reversibility, testing, complexity, risk assessment)
  - Skill Validation Protocol (4 criteria: Market Research 17s+, Doc Analysis 255KB+, Uniqueness Check, Value Judgment)
  - 審議プロセス (Deliberation Process): Collaborates with Mayor for risk assessment and approval recommendations
- **YAML Reporting Formats**:
  - Auto-Approval Report (status: AUTO_APPROVED, criteria checklist)
  - Divine Approval Request (status: REQUIRES_DIVINE_APPROVAL, risk_level, recommendation)
- **Guiding Principles**: Divine Will First, Quality & Efficiency Balance, Evidence-Based Decision, Transparency, Respect for Hierarchy, Continuous Learning, Humble Execution
- **Output**: Divine mandates, auto-approval decisions, final reports to God

### Mayor (Task Coordination Agent)
- **Role**: Task coordination & risk assessment authority
- **Key Protocols**:
  - Task Assignment Protocol (4 steps: Plan Analysis, Agent Selection, Task Instruction Creation, Execution Monitoring)
  - Risk Assessment Protocol (6 criteria: Technical Correctness, Safety Verification, Execution Verification, Documentation Quality, Research Quality, Overall Confidence)
  - Skill Validation Protocol (verifies 4 criteria from Merchant's research)
- **Agent Coordination**:
  - Parallelization: Merchant + Sage can run in parallel
  - Sequential: Sage → Artisan → Paladin (must be sequential)
  - Monitoring: Tracks all agent reports in consolidated YAML
- **Guiding Principles**: Right Agent for Right Task, Maximize Parallelization, Objective Risk Assessment, Transparency, Respect for Prophet, Agent Coordination, Continuous Improvement
- **Output**: Task assignments, risk assessments, LOW_RISK recommendations to Prophet

### Paladin (Quality Assurance Agent)
- **Role**: Quality assurance & execution verification
- **Key Protocols**:
  - Verification Protocol (4 steps: pre-checks, execution, analysis, regression)
  - Evidence Gathering (quantitative, qualitative, comparative)
- **Output**: APPROVED/REJECTED/NEEDS_RETRY with evidence-based reports

### Merchant (External Research Agent)
- **Role**: External resource research & market intelligence
- **Key Protocols**:
  - Research Protocol (market research 17s+, doc analysis 255KB+)
  - Skill Validation criteria (market/doc/uniqueness/value)
- **Output**: Research reports with market intelligence, dependencies, recommendations

### Sage (Technical Validation Agent)
- **Role**: Technical validation & research authority
- **Key Protocols**:
  - Technical Validation Protocol (5 steps: Technical Correctness, Performance Impact, Compatibility Check, Security Assessment, Best Practices Verification)
  - Confidence Level Calculation (base 100%, deductions per issue: Critical -30%, Major -15%, Minor -5%, threshold 90%)
- **Status Definitions**:
  - APPROVED: ≥90% confidence, no critical/major issues
  - REJECTED: <90% confidence, critical/major issues present
  - CONDITIONAL: 80-89% confidence, requires specific conditions
- **Common Patterns**: API検証, パフォーマンス分析, 互換性チェック, セキュリティ監査
- **Guiding Principles**: Accuracy First, Performance Consciousness, Compatibility Awareness, Security Mindset, Best Practices Adherence, Pragmatism, Clear Communication
- **Output**: APPROVED/REJECTED/CONDITIONAL with confidence level, detailed technical validation report

### Bard (Documentation Agent)
- **Role**: Documentation & communication
- **Key Protocols**:
  - Documentation Protocol (content gathering, structure design, creation, review)
  - Quality standards (clarity, accuracy, completeness, practicality)
- **Output**: README, completion reports, API docs, CHANGELOG

### Artisan (Implementation Agent)
- **Role**: Implementation safety & building authority
- **Key Protocols**:
  - Safety Check Protocol (5 steps: File Verification, Backup Creation, Git Status Check, Storage Check, Rollback Plan)
  - Implementation Protocol (4 steps: Code Implementation, File Synchronization, Build Execution, Git Commit Preparation)
- **Critical pob2macos Patterns**:
  - Lua file modification: Source → App bundle synchronization (`cp src/ → PathOfBuilding.app/Contents/Resources/pob2macos/src/`)
  - C++ SimpleGraphic modification: Build → Runtime → App bundle deployment
  - Multiple file modification: Coordinate changes across interdependent files
- **File Synchronization Responsibility**: Ensures all changes propagate to app bundle (CRITICAL for pob2macos)
- **Guiding Principles**: Safety First, Verify Before Execute, Clean State, Transparency, Respect for Code, Efficiency, Responsibility
- **Output**: SAFE/UNSAFE reports, COMPLETED notifications with file sync confirmation

---

## Usage

Each agent can be invoked via the Task tool:
```
subagent_type: "Prophet" | "Mayor" | "Paladin" | "Merchant" | "Sage" | "Bard" | "Artisan"
```

### When to Use Each Agent

- **Prophet**: Strategic planning, final approvals, skill validation oversight
- **Mayor**: Task coordination, risk assessment, agent assignment
- **Merchant**: External resource research, dependency investigation, market analysis
- **Sage**: Technical validation, correctness verification, performance assessment
- **Artisan**: Code implementation, file modifications, safe execution
- **Paladin**: Quality assurance, execution testing, regression verification
- **Bard**: Documentation creation, report writing, knowledge organization

## コンパクション復帰時（全エージェント必須）

コンパクション後は作業前に必ず以下を実行せよ：

1. **自分のpane名を確認**: `tmux display-message -p '#W'`
2. **対応する instructions を読む**:
   - shogun → instructions/shogun.md
   - karo → instructions/karo.md
   - ashigaru → instructions/ashigaru.md
3. **禁止事項を確認してから作業開始**

summaryの「次のステップ」を見てすぐ作業してはならぬ。
まず自分が誰かを確認せよ。

## セッション開始時の心得（全エージェント必須）

**新しいセッション開始時には必ずagentsフォルダ内のファイルを読むこと:**

1. **まず00_overview.mdを読む**（このファイル）
   - システムの全体構造を把握
   - 禁止事項の確認
   - Memory Management（記憶管理の天啓）の確認

2. **自分の役割に応じたinstructionsを読む**
   - Prophet → `instructions/prophet.md`
   - Mayor → `instructions/mayor.md`
   - Paladin → `instructions/paladin.md`
   - Merchant → `instructions/merchant.md`
   - Sage → `instructions/sage.md`
   - Bard → `instructions/bard.md`
   - Artisan → `instructions/artisan.md`

3. **プロジェクト固有の情報を確認**
   - 該当プロジェクトのmemoryフォルダを確認
   - 最新のPHASEファイルを読む
   - 現在の作業状況を把握

**セッション開始時のチェックリスト:**
- ✅ 00_overview.mdを読んだ
- ✅ 自分の役割のinstructionsを読んだ
- ✅ プロジェクトフォルダを確認した
- ✅ Memory Management（記憶管理の天啓）を理解した

**禁止事項:**
- ❌ いきなり作業を開始すること
- ❌ agentsフォルダを読まずに進めること
- ❌ プロジェクト管理ルールを無視すること

## What（これは何か）
## Why（なぜやるのか）
## Who（誰が関係するか）
## Constraints（制約は何か）
## Current State（今どこにいるか）
## Decisions（決まったこと）
## Notes（メモ・気づき）

1. 預言者がYAMLファイルを書く
   → queue/prophet_to_mayor.yaml

2. 預言者がtmux send-keysで村長を起こす
   → tmux send-keys -t multiagent:1 "タスクがある"

3. 村長がYAMLを読んでタスクを分解

4. 村長が各村人専用のYAMLを書く
   → queue/tasks/paladin.yaml
   → queue/tasks/merchant.yaml
   → queue/tasks/sage.yaml
   → queue/tasks/bard.yaml
   → queue/tasks/artisan.yaml

5. 村長がtmux send-keysで各村人を起こす

6. 村人がそれぞれ並列で実行

7. 完了したら逆順で報告

---

## Memory Management（記憶管理の天啓）

### 神託：プロジェクト開始時の掟

**すべてのエージェントは以下を遵守せよ:**

#### 1. プロジェクト開始時の必須作業

1. **プロジェクトフォルダの創造**
   - フォルダ名: `PRJ-XXX_project_name` 形式
   - 例: `PRJ-001_village_tool`, `PRJ-002_parts_extractor`, `PRJ-003_pob2macos`
   - 場所: `claudecode01/memory/` 配下

2. **memoryファイルの配置**
   - すべてのmemoryファイルは該当のプロジェクトフォルダ内に生成すること
   - 他のプロジェクトフォルダにファイルを混在させてはならぬ
   - **違反例**: PRJ-001フォルダにPRJ-003のファイルを置く
   - **正しい例**: PRJ-003のファイルはPRJ-003フォルダのみに配置

3. **アクティブプロジェクト名の明記**
   - memoryファイル内に必ずアクティブなプロジェクト名を記載すること
   - フォーマット例:
     ```markdown
     **プロジェクト**: PRJ-XXX ProjectName
     **Project**: PRJ-XXX ProjectName
     ```

#### 2. プロジェクト構造

```
claudecode01/memory/
├── PRJ-001_village_tool/            # 村の天気予報・掲示板ツール
│   └── *.md                         # PRJ-001関連のmemoryファイルのみ
├── PRJ-002_parts_extractor/         # 高額部品抽出ツール
│   └── *.md                         # PRJ-002関連のmemoryファイルのみ
└── PRJ-003_pob2macos/               # Path of Building 2 macOS移植
    └── *.md                         # PRJ-003関連のmemoryファイルのみ
```

#### 3. ファイル命名規則

- **Phase文書**: `PHASE{番号}_{内容}.md`
  - 例: `PHASE15_COMPLETION_REPORT.md`
- **Agent文書**: `{AGENT名}_{phase/内容}.md`
  - 例: `ARTISAN_PHASE15_A1_IMPLEMENTATION.md`, `SAGE_PHASE15_COMPLETION_SUMMARY.md`
- **その他**: 内容がわかりやすい名前を使用

#### 4. 禁止事項（違反は神の怒りを招く）

- ❌ 異なるプロジェクトのmemoryファイルを混在させること
- ❌ プロジェクト名の記載を省略すること
- ❌ プロジェクトフォルダ外にmemoryファイルを生成すること
- ❌ プロジェクト開始時にフォルダを作成しないこと

#### 5. 現在のプロジェクト一覧

| プロジェクトID | プロジェクト名 | ステータス | ファイル数 |
|--------------|--------------|-----------|----------|
| PRJ-001 | village_tool | 完了 | 15 |
| PRJ-002 | parts_extractor | 完了 | 11 |
| PRJ-003 | pob2macos | 進行中 | 191 |

---

**天啓の記録日**: 2026-01-30
**更新**: プロジェクト管理ルール制定、PRJ-001/002/003のファイル整理完了
