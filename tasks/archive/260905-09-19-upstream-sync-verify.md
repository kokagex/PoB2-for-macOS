---
kind: context-keeper-scratch
date: 2026-09-05
topic: upstream sync phase13 — 検証結果と worktree ビルドの落とし穴
---

# 検証結果 (worktree upstream-sync-phase13, base 11337eddc → 3887ae68a)

- smoke-test 30s: OK (Lua エラーなし)
- mcp/server npm test: 53/53 green
- 実機 .app: ツリー / アイテムツールチップ (unique ヘッダー・granted-skill サブツールチップ) / トレード検索 popup / サイドバー breakdown hover すべて表示OK、ログに Lua エラーなし

# 同期後に追加で直した回帰

- Tooltip.lua: 上流 #2493 の getHeaderImage/getInfluenceIconImage キャッシュ化で fork の self.headerMiddle 等が消え nil index → 5 箇所すべて `img:IsValid()` ガード付きで再実装
- _SimpleGraphic.def.lua (上流新規、HeadlessWrapper から stub 分離): fork の nil 耐性 ConPrintf (pcall(string.format)) が失われていた → 再適用
- PassiveTree.lua: `assetsLoaded` が未定義 (fork 既存バグ、C 版 ConPrintf が黙認していた) → local で計数
- mcp/worker patch.lua / query.lua: `new("Item", raw)` → `new("Item"):Item(raw)` (上流 ctor 規約 #2384)

# worktree でビルド/テストするときに main checkout からコピーが要る gitignored 資産

- `pob2macos` (symlink で可) — SGPAK rebuild ツール
- `tree-data/*.png` (トップレベル 180 枚) — 無いと rebuild_archives が途中で落ち treedata_0_5.sgpak が作られない
- `runtime/fonts/LiberationSans-*.ttf` — 無いと文字が描画されない (ユーザーが見た「UIがおかしい」の主因)
- `src/TreeData -> ../tree-data` symlink — 無いと headless worker が tree.lua を開けず mcp テスト全滅
