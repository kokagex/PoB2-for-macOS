# Gem tooltip アイコン/背景が常に非表示 — dds.zst 変換 TODO (2026-06-10)

## 現状
- `src/Data/Skills/SkillAssets.lua` の ddsCoords キーは `gem-backgrounds_700_372_BC7.dds.zst` 等の .dds.zst
- macOS dylib の stb_image は DDS/zstd をデコードできず、全エントリ `found=false`
- 2026-06-10 のバグ修正で「無効ハンドル DrawImage → 白矩形 (gemBG は 500x266 白背景)」は遮断済み
  (`Tooltip.lua` GEM パスで `found` チェック)。現在は gemEmptyImage フォールバック表示

## 残作業（機能追加）
- パッシブツリーで実績のある変換パイプライン (`scripts/convert_tree_dds.py` /
  `scripts/convert-tree-webp.sh`) を Data/Skills の .dds.zst にも適用し PNG atlas 化
- `getSkillAssetByName` (src/Classes/Tooltip.lua:37) のロードパスを変換後拡張子にルーティング
  （tree の「裸キー取りこぼし + .dds.zst 拡張子ルーティング」バグパターンに注意 — brain 参照）
- 完了すると gem tooltip にアイコンと背景アートが初めて表示される

## 参考
- brain: 「PoB2 tree dds.zst→atlas変換」メモリ (MEMORY.md)
- PassiveTree.lua:276 のコメントに同問題への言及あり
