# 神の掟（Divine Rules）

村人たちが従うべき神からの指示を記録する。

---

## 作業ルール

### API検証
- **制限時間**: 15分まで
- API検証を行う際は、15分を超えないこと

---

## 通信ルール
- エージェント間の通信は `village_communications.yaml` で行う
- 各村人は作業前後に `memory/` を参照・更新する

## 進捗報告ルール
- 神から「進捗」を尋ねられた場合、`todo.md` に進捗を保存する
- 現在のタスク状況を整理して記録すること

## コンソール表示ルール（村人名の明示）

Task ツール呼び出し時、`description` パラメータに村人名をプレフィックスとして含める：

```
[村人名] 作業内容（3-5語）
```

**例:**
```
description: "[builder] UI列変更"
description: "[architect] 設計書作成"
description: "[tester] テスト実行"
```

**村人名一覧:**
| プレフィックス | 役職 |
|---------------|------|
| `[prophet]` | 預言者 |
| `[mayor]` | 村長 |
| `[architect]` | 設計士 |
| `[builder]` | 建築士 |
| `[tester]` | テスト担当 |
| `[librarian]` | 司書 |
| `[guardian]` | 守護者 |

---

## 村人作業報告ルール（並列実行時の可視化）

並列実行時に誰が何をしているかを明確にするため、以下のルールを遵守する：

### 作業開始時
- `village_communications.yaml` の自分のステータスを `working` に更新
- `current_work` フィールドに作業内容を記載
- 作業開始時刻を `started_at` に記録

### 作業中
- 重要な進捗があれば通信ログに追記
- 長時間かかる場合は中間報告を行う

### 作業完了時
- ステータスを `completed` に更新
- `completed_at` に完了時刻を記録
- 完了報告を通信ログ（`communications`）に追記
- 成果物や変更内容を明記する

### ステータス形式例
```yaml
villagers:
  architect:
    status: working
    current_work: "設計書作成中"
    started_at: "2026-01-28T10:00:00"
  builder:
    status: completed
    current_work: "UI実装完了"
    started_at: "2026-01-28T10:05:00"
    completed_at: "2026-01-28T10:30:00"
```

---

*最終更新: 2026-01-28（コンソール表示ルール追加）*
