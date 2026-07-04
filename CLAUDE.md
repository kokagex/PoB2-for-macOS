## Skill routing

- `/brain-spec`, `spec を html 化`, `html spec 出して` → invoke `brain-spec`
- `mcp/` 配下 (pob2-advisor / worker / probes) のリファクタ・整理依頼 → invoke `refactor-prep`。オリジナル開発領域 (上流 fork 制約なし) のため skill 規律をフル適用する。既存 ledger の完了確認だけで済みそうな場合も skill 入口から判定 (1 行バグ修正は `investigate` 側)

## MCP Brain（opti-brain）

セッション間の記憶を Supabase に蓄積する。

- **セッション開始時の brain レビュー (毎セッション必須)**: `brain_status()` を呼び、出力を作業文脈に照らして取り込む:
  1. **直近セッション**: 今回の作業に関係する決定・教訓を把握
  2. **頻繁に修正されたファイル**: 当セッションで触る予定のファイルが挙がっていれば `brain_search(file:)` で過去の試行を確認
  3. **重要バグパターン**: 当セッションの作業領域に関係するものはこの段階で記憶 (検索コスト節約)
  (open_questions / brain_resolve は 2026-06 廃止済み — ゴミが溜まるだけで機能しなかった。復活提案禁止)
- **セッション開始時の brain MCP 自体の能動的レビュー (毎セッション必須)**: brain MCP を運用してきた経験を活かし、Claude 側から能動的に改善提案を 1-3 件挙げる。受動的に外部指摘を待つだけでなく、運用知見ベースで議題化:
  1. **直近の使用感**: 当セッションで brain_save / brain_status / brain_search を使ったとき違和感はあったか (e.g., frontmatter 解釈ズレ、検索精度の不一致)
  2. **再発パターン**: bug-pattern として記録された問題が新規 commit で再発していないか
  3. **wish list**: 運用上「こうなれば楽」と気づいた改善点を提案 (重複しないよう brain_search で先に確認)
  ユーザー判断で即実装 / 却下に分岐。何も提案がない (= MCP は完璧) と判断したらその旨明言する (沈黙は「忘れた」と区別がつかない)。
- **デバッグ時**: `brain_search("エラーメッセージ or 症状")` で過去の解決策を検索
- **セッション終了時**: `/brain-save` スキルでセッションを記録
