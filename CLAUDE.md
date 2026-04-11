## MCP Brain（opti-brain）

セッション間の記憶を Supabase に蓄積する。

- **セッション開始時**: `brain_status()` で未解決 open_questions と最近のバグパターンを確認
- **デバッグ時**: `brain_search("エラーメッセージ or 症状")` で過去の解決策を検索
- **セッション終了時**: `/brain-save` スキルでセッションを記録
