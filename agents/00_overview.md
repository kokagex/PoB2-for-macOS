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
