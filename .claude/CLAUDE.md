# CLAUDE.md

pob2macos: Path of Building 2のmacOSネイティブポート（Lua + C++/Metal）

## 必須ルール

### 1. ルーティン実行
タスク開始前に `/routine` スキルを必ず実行。定義: `skills/routine/SKILL.md`

### 2. Lua修正はサブエージェント必須
`.lua`ファイルの修正はTask toolに委譲。メインエージェントが直接Edit/Writeしない。
詳細: `.claude/AGENT.md`

### 3. エラーハンドリング: 予測ベース消去法
- 自律分析は**最大2ラウンド**→ユーザーに質問
- 3候補予測 → AskUserQuestionで提示 → 選択された修正のみ実装
- テスト指示: ① 具体的操作 ② 確認ポイント ③ やってはいけないこと
- 消去サイクル: 失敗→候補消去→新観察→再予測
- 禁止: 3ラウンド以上の自律分析、ログ注入を第一選択

### 4. 表示確認ワークフロー
アプリ起動（ユーザー承認）→「撮った」→ pkill → スクリーンショット分析 → 削除

---

## 運用ルール

### コンテキスト管理
- `/compact`はコンテキスト使用率**50%**で実行
- サブタスクは**50%未満**のコンテキストで完了できるよう分割

### サブエージェント
- 汎用エージェントではなくスキル（プログレッシブ開示）を使用
- 機能固有のサブエージェントを作成
- トラブルシューティング: `.claude/AGENT.md`

### 複雑なタスク
- **プランモード**（EnterPlanMode）で実行
- マルチステップ手順: `.claude/WORKFLOW.md` を参照

### バックグラウンド実行
- 長時間ターミナルコマンドは `run_in_background: true` で実行
- ログ可視性のためTaskOutputで定期確認

###　タスクキューの管理
- レート制限監視　`.claude/TASK_QUEUE_README.md` を参照

---

## 技術制約

### LuaJIT 5.1（NOT Lua 5.4）
- Lua 5.2+機能禁止（bitwise, goto, _ENV）
- FFIでC interop、`table.insert()` 推奨

### Nil-Safety必須
```lua
-- 必ずチェーンを検証
local itemsTab = self.build and self.build.itemsTab
local item = itemsTab and itemsTab.items[itemId]
```

### ProcessEvents()順序
`ProcessEvents()` → `Draw*()` の順序厳守。逆はNULL renderEncoderエラー。

### ファイル同期（手動）
修正後は必ずアプリバンドルにコピー:
```bash
cp -r src/ PathOfBuilding.app/Contents/Resources/pob2macos/src/
```

### ConPrintf安全性
`%d`はLua doublesで常にゴミ値。`%s` + `tostring()` を使用。

---

## ビルド・実行

```bash
# SimpleGraphicビルド
cd simplegraphic && cmake -B build -DCMAKE_BUILD_TYPE=Release -DSG_BACKEND=metal && make -C build

# デプロイ
cp simplegraphic/build/libSimpleGraphic.dylib runtime/SimpleGraphic.dylib
cp runtime/SimpleGraphic.dylib PathOfBuilding.app/Contents/Resources/pob2macos/runtime/

# 実行
./run_pob2.sh
```

詳細ワークフロー: `.claude/WORKFLOW.md`

---

## アーキテクチャ概要

```
run_pob2.sh → pob2_launch.lua(FFI) → Launch.lua → Main.lua → Game Loop
```

- **SimpleGraphic**: Metal API, GLFW3, FreeType2（`simplegraphic/src/`）
- **FFI Bridge**: `pob2_launch.lua` - 48関数宣言、ImageHandleラッパー
- **PoB Core**: `src/Modules/` - Build.lua, Calcs.lua, Data.lua
- **Key Classes**: PassiveTree, PassiveSpec, ModDB, Item

---

## デバッグ

```lua
ConPrintf("DEBUG: %s", tostring(value))  -- Lua
```
```bash
./PathOfBuilding.app/Contents/MacOS/PathOfBuilding 2>&1 | tee ~/pob_debug.log
```

よくある問題: renderEncoder NULL → ProcessEvents順序、変更反映なし → バンドル同期忘れ

---

## 参照ファイル
- `.claude/WORKFLOW.md` - ビルド・テスト・デプロイ手順
- `.claude/LIBRARY.md` - ドキュメント・リファレンスリンク集
- `.claude/AGENT.md` - サブエージェント運用・トラブルシューティング
- `docs/rundown.md` - モジュール詳細
