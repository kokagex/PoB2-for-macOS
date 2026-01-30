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
| Prophet | 1 (Top) | On_Divine_Mandate | Strategic vision & high-level directives |
| Mayor | 2 | On_Prophet_Revelation | Task coordination & resource allocation |
| Paladin | 3 | On_Mayor_Assignment | Security & protection tasks |
| Merchant | 3 | On_Mayor_Assignment | Commerce & transaction handling |
| Sage | 3 | On_Mayor_Assignment | Research & knowledge synthesis |
| Bard | 3 | On_Mayor_Assignment | Communication & documentation |
| Artisan | 3 | On_Mayor_Assignment | Building & implementation |

## Communication Flow

1. **Top-Down**: Prophet -> Mayor -> Specialized Agents
2. **Bottom-Up**: Results bubble up through the hierarchy
3. **Peer-to-Peer**: Level 3 agents can collaborate on shared tasks

## Usage

Each agent can be invoked via the Task tool:
```
subagent_type: "Prophet" | "Mayor" | "Paladin" | "Merchant" | "Sage" | "Bard" | "Artisan"
```

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
