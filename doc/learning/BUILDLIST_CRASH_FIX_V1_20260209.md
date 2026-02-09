# BuildList.lua Line 60 Nil Crash Fix

**Date**: 2026-02-09
**Version**: V1
**Status**: PENDING APPROVAL

## 原因分析

### 症状
- `BuildList.lua:60: attempt to index field 'buildList' (a nil value)`
- アプリ起動時にクラッシュ

### 根本原因
Lines 52, 56, 60, 64 の `.enabled` 関数が `self.controls.buildList` を参照するが、
`buildList` は line 70 で作成される。Draw時に `.enabled` が評価されると nil crash。

### 証拠
- エラーメッセージが line 60 を指す
- Line 70 で `buildList` が作成される = lines 52-64 の `.enabled` 関数定義時点では未作成
- `.enabled` はクロージャなので定義時ではなくDraw時に評価 → Draw順序次第でcrash

## 修正案

**最小侵襲nilガード** - 4箇所に `self.controls.buildList and` を追加

```lua
-- Lines 52, 56, 60, 64: 同一パターン
self.controls.X.enabled = function()
    return self.controls.buildList and self.controls.buildList.selValue ~= nil
end
```

## 実装手順

1. BuildList.lua lines 52, 56, 60, 64 に nil ガード追加（1ファイルのみ）
2. src/ → app bundle にファイル同期
3. アプリ起動テスト

## リスク・ロールバック

- **リスク**: Low - nil ガード追加のみ、既存ロジック変更なし
- **ロールバック**: git checkout で即座に戻せる

## 成功基準

1. アプリ起動時に BuildList エラーなし
2. ビルドリスト画面が正常表示
3. ビルドを開く → パッシブツリー表示

## 6点レビュー

1. ✅ 原因が明確 - line 70 作成前に lines 52-64 の .enabled が評価される
2. ✅ 技術的に妥当 - nil ガードは PoB 全体で使用される標準パターン
3. ✅ リスク低い - nil ガード追加のみ
4. ✅ ロールバック容易 - git checkout
5. ✅ 視覚確認計画あり - アプリ起動 → BuildList 表示確認
6. ✅ タイムライン現実的 - 5分以内

**Score: 6/6** → 自動承認推奨
