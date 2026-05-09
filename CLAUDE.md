## Skill routing

- `/brain-spec`, `spec を html 化`, `html spec 出して` → invoke `brain-spec`

## MCP Brain（opti-brain）

セッション間の記憶を Supabase に蓄積する。

- **セッション開始時の brain レビュー & クリーンアップ (毎セッション必須)**: `brain_status()` を呼び、出力 4 セクション全部に対し action を取るまでがセッション開始タスク。「確認した」で終わらず必ず resolve / supersede まで進めること (read-time judgement の責任は Claude 側):
  1. **未解決 open_questions 上位**: 作業文脈に照らして既に解決 / 別件 / moot な質問は `brain_resolve "<キーワード>"` で閉じる
  2. **閉じ忘れの可能性 (sim≥40%)**: 直近コミット / 現状コードで実装済 or 不要なら `brain_resolve` で閉じる
  3. **同一案件の可能性クラスタ (sim≥50%)**: 重複は代表 1 件だけ残し、残りはまとめて `brain_resolve` で閉じる (normalize 弱の別 row 化が原因。詳細 global CLAUDE.md `## Brain`)
  4. **重要バグパターン**: 当セッションの作業領域に関係するものはこの段階で記憶 (検索コスト節約)
  Auto Mode 下でも本ステップは確認最小化の対象外。形骸化したら brain は機能しない。「ユーザーに聞いてから閉じる」も禁止 — 文脈で判断できないものだけ open_question として残し、それ以外は能動的にクローズ。
- **セッション開始時の brain MCP 自体の能動的レビュー (毎セッション必須)**: brain MCP を運用してきた経験を活かし、Claude 側から能動的に改善提案を 1-3 件挙げる。受動的に外部指摘を待つだけでなく、運用知見ベースで議題化:
  1. **直近の使用感**: 当セッションで brain_save / brain_resolve / brain_status / brain_search を使ったとき違和感はあったか (e.g., resolve query 広すぎで巻き込み close、frontmatter 解釈ズレ、検索精度の不一致)
  2. **再発パターン**: bug-pattern として記録された問題が新規 commit で再発していないか
  3. **wish list**: 運用上「こうなれば楽」と気づいた改善点を open_question 化 (重複しないよう brain_search で先に確認)
  ユーザー判断で即実装 / open_question 化 / 却下に分岐。何も提案がない (= MCP は完璧) と判断したらその旨明言する (沈黙は「忘れた」と区別がつかない)。
- **デバッグ時**: `brain_search("エラーメッセージ or 症状")` で過去の解決策を検索
- **セッション終了時**: `/brain-save` スキルでセッションを記録
