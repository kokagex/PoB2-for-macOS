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

---

## Learning Protocol（学習プロトコル）

### 神託：学習を行うたびに関連設定ファイルを更新せよ

**すべてのエージェントは、新しい知識や重要な学習を得た際、該当するドキュメントファイルに即座に反映する責任を負う。**

#### 1. 学習タイプと更新先マッピング

| 学習タイプ | 更新先ファイル | 責任エージェント | 更新セクション |
|----------|--------------|----------------|--------------|
| **技術的発見** | `{project}/CLAUDE.md` | Sage | 該当する技術セクション |
| **プロジェクトパターン** | `memory/{PRJ-XXX}/LESSONS_LEARNED.md` | Mayor | パターンライブラリ |
| **エージェントシステム改善** | `agents/00_overview.md` | Prophet | 該当エージェントセクション |
| **トラブルシューティング** | `{project}/CLAUDE.md` | Paladin | よくある問題セクション |
| **ワークフロー最適化** | `agents/{NN}_*.md` | Mayor | 該当エージェント定義 |
| **外部リソース発見** | `memory/{PRJ-XXX}/RESOURCES.md` | Merchant | リソースリスト |
| **ドキュメント改善** | 該当ドキュメント | Bard | 該当セクション |

#### 2. 学習記録プロトコル（4ステップ）

**Step 1: 学習内容の識別**
- 学習タイプを分類（上記7タイプから選択）
- 重要度を評価（CRITICAL / HIGH / MEDIUM / LOW）
- 影響範囲を特定（プロジェクト固有 / 全体システム / エージェント固有）

**Step 2: 更新先ファイルの決定**
- 学習タイプマッピングに従って更新先を決定
- 複数ファイルへの反映が必要な場合はリスト化
- 既存セクションの有無を確認

**Step 3: ドキュメント更新の実行**
- 該当ファイルを読み込み
- 適切なセクションに学習内容を追加
- 既存内容との重複を排除
- 日付とエージェント名を記録

**Step 4: 学習記録の報告**
- YAML形式で学習記録を報告
- 更新したファイルと変更内容を明記
- 次回セッションでの活用方法を提示

#### 3. 学習記録フォーマット（YAML）

```yaml
learning_record:
  date: "2026-02-01"
  agent: "Sage"
  learning_type: "技術的発見"
  importance: "HIGH"
  scope: "PRJ-003固有"

  discovery:
    title: "Metal renderEncoder NULL問題の根本原因"
    description: "ProcessEvents()呼び出し前のDraw*()実行が原因"
    solution: "必ずProcessEvents() → Draw*()の順序を守る"

  files_updated:
    - file: "pob2macos/CLAUDE.md"
      section: "## Metalバックエンドレンダーパイプライン"
      changes: "NULL renderEncoderエラーの詳細説明を追加"
    - file: "memory/PRJ-003_pob2macos/LESSONS_LEARNED.md"
      section: "## Metal API パターン"
      changes: "ProcessEvents()順序パターンを追加"

  future_application:
    - "新規Metal機能実装時に必ず参照"
    - "Paladinの検証チェックリストに追加"
    - "Artisan実装前の確認項目に追加"
```

#### 4. 学習タイプ別の詳細

##### A. 技術的発見（Sage責任）

**対象**: 新しいAPI使用方法、パフォーマンス最適化、互換性パターン

**更新ファイル**: `{project}/CLAUDE.md`

**更新タイミング**: 技術検証完了後、即座に

**例**:
- Metal APIの新しいレンダリングパターン
- LuaJIT FFIの効率的な使用方法
- ファイル同期の失敗パターンと対策

##### B. プロジェクトパターン（Mayor責任）

**対象**: 繰り返し発生する問題、成功パターン、失敗パターン

**更新ファイル**: `memory/{PRJ-XXX}/LESSONS_LEARNED.md`

**更新タイミング**: タスク完了後、パターン認識時

**例**:
- ファイル同期忘れによる「修正が反映されない」問題
- エージェント並列実行による効率化パターン
- リスク評価で見落としがちな項目

##### C. エージェントシステム改善（Prophet責任）

**対象**: エージェント間連携の最適化、新しいプロトコル、権限変更

**更新ファイル**: `agents/00_overview.md` または `agents/{NN}_*.md`

**更新タイミング**: システム改善提案の承認後

**例**:
- Auto-Approval基準の追加
- 新しいエージェント役割の定義
- コミュニケーションフローの改善

##### D. トラブルシューティング（Paladin責任）

**対象**: よくあるエラー、デバッグ方法、検証失敗パターン

**更新ファイル**: `{project}/CLAUDE.md` の「よくある問題」セクション

**更新タイミング**: 問題解決後、即座に

**例**:
- "permission denied"エラーの解決方法
- "renderEncoder is NULL"警告の対処法
- パッシブツリー非表示問題の診断手順

##### E. ワークフロー最適化（Mayor責任）

**対象**: タスク実行手順の改善、並列化パターン、依存関係の明確化

**更新ファイル**: `agents/{NN}_*.md` の該当プロトコルセクション

**更新タイミング**: ワークフロー改善の検証完了後

**例**:
- Merchant + Sage の並列実行条件
- Artisan → Paladin の順次実行理由
- Safety Check の新しいチェック項目

##### F. 外部リソース発見（Merchant責任）

**対象**: 有用なライブラリ、公式ドキュメント、技術記事、ツール

**更新ファイル**: `memory/{PRJ-XXX}/RESOURCES.md`

**更新タイミング**: リサーチ完了後、即座に

**例**:
- Metal APIの公式ガイド（最新版）
- LuaJIT FFIのベストプラクティス記事
- 依存ライブラリの最新版情報

##### G. ドキュメント改善（Bard責任）

**対象**: 説明の明確化、例の追加、構造の改善

**更新ファイル**: 該当するドキュメントファイル

**更新タイミング**: ドキュメント作成・レビュー時

**例**:
- README の使用例追加
- CLAUDE.md のセクション再編成
- API ドキュメントの詳細化

#### 5. 学習記録の保存場所

##### プロジェクト固有の学習

```
memory/PRJ-XXX_{project_name}/
├── LESSONS_LEARNED.md          # パターンライブラリ
├── RESOURCES.md                # 外部リソースリスト
├── TROUBLESHOOTING.md          # トラブルシューティングガイド
└── learning_records/           # 学習記録アーカイブ
    ├── 2026-02-01_sage_metal_pattern.yaml
    ├── 2026-02-01_paladin_verification_pattern.yaml
    └── ...
```

##### システム全体の学習

```
agents/
├── 00_overview.md              # システム改善の反映先
├── 01-07_*.md                  # 各エージェント改善の反映先
└── learning_records/           # システム学習記録
    └── 2026-02-01_prophet_auto_approval_update.yaml
```

#### 6. 学習記録の活用

**セッション開始時**:
- `memory/{PRJ-XXX}/LESSONS_LEARNED.md` を必ず読む
- 過去の失敗パターンを回避
- 成功パターンを積極的に活用

**タスク実行時**:
- 該当する学習記録を参照
- トラブルシューティングガイドを活用
- リソースリストから最新情報を取得

**タスク完了時**:
- 新しい学習を即座に記録
- 既存ドキュメントを更新
- 学習記録YAMLを保存

#### 7. 禁止事項（学習の損失を防ぐ）

- ❌ 学習内容を口頭報告のみで済ませること（必ずドキュメント化）
- ❌ 学習記録の更新を「後でやる」と先送りすること（即座に実行）
- ❌ 重要な発見をメモリファイル外に記録すること（必ず指定場所に）
- ❌ 同じ問題を繰り返し解決すること（初回解決時にドキュメント化）
- ❌ 学習内容の記録を省略すること（すべての重要な学習を記録）

#### 8. 学習記録の品質基準

**良い学習記録**:
- ✅ 具体的（「Metal APIが難しい」ではなく「ProcessEvents()の順序が重要」）
- ✅ 再現可能（手順が明確、例が豊富）
- ✅ 実用的（次回すぐに活用できる）
- ✅ 文脈付き（なぜその学習が重要か説明）
- ✅ 日付・エージェント名記録済み

**悪い学習記録**:
- ❌ 曖昧（「うまくいった」「問題があった」）
- ❌ 手順不明（どうやって解決したか不明）
- ❌ 抽象的（具体例なし）
- ❌ 文脈なし（なぜ重要か不明）
- ❌ 記録者不明

---

**学習プロトコルの記録日**: 2026-02-01
**更新**: 全エージェントに学習記録の責任を明確化、7タイプの学習分類を制定
