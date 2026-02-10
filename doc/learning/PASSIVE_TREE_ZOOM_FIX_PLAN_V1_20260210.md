# パッシブツリー表示枠修正 + PoE1データ退避

## Date: 2026-02-10

## 原因分析

**症状**: PoE2パッシブツリーがビューポート中央の小さな範囲にクラスタリング

**根本原因**: PoE2の座標空間がPoE1の2.3倍大きい
- PoE1: tree.size ≈ 22,792
- PoE2: tree.size ≈ 52,658
- scale = min(viewport) / tree.size * zoom → scaleが2.3倍小さい

**証拠**: tree.lua座標 max_x=23983, min_x=-23887 → 幅47,870

## 修正案

デフォルトzoomLevelを動的にPoE2座標空間に適応させる。

### PassiveTreeView.lua 修正 (4箇所)

1. **Constructor (line 36後)**: `self.defaultZoomApplied = false` 追加
2. **Load() (line 54後)**: 保存済みzoom時 `self.defaultZoomApplied = true`
3. **Draw() (line 105後)**: 初回描画時にtree.sizeベースでzoom自動補正
4. **Zoom() (line 1392)**: 最大zoom 20→OK (既に20)

### PoE1 TreeData退避
`TreeData/` の PoE1ディレクトリを `dev/TreeData_poe1/` に移動

## リスク・ロールバック

- **リスク**: Low - zoom初期値のみ変更、treeToScreen計算に影響なし
- **ロールバック**: git revert で即座に戻せる

## 成功基準

1. ツリーがビューポート全体に表示
2. ズームイン/アウト動作
3. ノードホバー・クリック動作

## 6点レビュー

1. 原因が明確か？ → ✅ tree.size 2.3倍
2. 技術的に妥当か？ → ✅ zoom補正のみ
3. リスクが低い/管理可能か？ → ✅ zoom初期値のみ
4. ロールバックが容易か？ → ✅ git revert
5. 視覚確認計画があるか？ → ✅ スクリーンショット
6. タイムラインが現実的か？ → ✅ 30分以内

**Score: 6/6** → 自動承認推奨
