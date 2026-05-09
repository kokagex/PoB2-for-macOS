## Skill routing

- `/brain-spec`, `spec を html 化`, `html spec 出して` → invoke `brain-spec`

## MCP Brain（opti-brain）

セッション間の記憶を Supabase に蓄積する。

- **セッション開始時**: `brain_status()` で未解決 open_questions と最近のバグパターンを確認 →
  作業文脈に照らして既に解決 / 別件 / moot な質問は **その場で `brain_resolve "<キーワード>"` で閉じる**
  (normalize 弱で別 row 化するため "保存時統合" でなく "参照時 close" 運用が正解。詳細は global CLAUDE.md `## Brain`)
- **デバッグ時**: `brain_search("エラーメッセージ or 症状")` で過去の解決策を検索
- **セッション終了時**: `/brain-save` スキルでセッションを記録
