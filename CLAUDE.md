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
- **デバッグ時**: `brain_search("エラーメッセージ or 症状")` で過去の解決策を検索
- **セッション終了時**: `/brain-save` スキルでセッションを記録
