# シンボリックリンク解消 - アプリ単独動作化

**Date**: 2026-02-10
**Status**: 承認待ち

## 原因分析

4つの絶対パスシンボリックリンクがアプリバンドル内に存在し、別環境で動作不可。

| # | パス | 種別 | 対処 |
|---|------|------|------|
| 1 | TreeData → /Users/kokage/.../dev/pob2-original/src/TreeData | 外部絶対 | 実ファイルコピー(0_1~0_4+PNGs+legion) |
| 2 | runtime/lua → /Users/kokage/.../dev/runtime/lua | 外部絶対 | 実ファイルコピー(360KB) |
| 3 | Data → .../Resources/src/Data | バンドル内絶対 | 相対シンボリックリンク |
| 4 | Assets → .../Resources/src/Assets | バンドル内絶対 | 相対シンボリックリンク |

追加: LOG_DIR ハードコードパス修正

## 修正案

### Step 1: TreeData
- GameVersions.luaで `treeVersionList = { "0_1", "0_2", "0_3", "0_4" }` のみ使用
- 3_19 (8.5MB, PoE1 only) は除外
- ルート直下の168 PNGファイル + legion/ をコピー
- 予想サイズ: ~265MB → ~257MB (3_19除外)

### Step 2: runtime/lua
- 360KBの小さなディレクトリ、全コピー

### Step 3: Data, Assets → 相対リンク
- `ln -s src/Data` / `ln -s src/Assets`

### Step 4: LOG_DIR 修正
- `$(dirname "$0")/../Resources/debug` に変更

## リスク・ロールバック
- **リスク**: Low - ファイルコピーとシンボリックリンク変更のみ
- **ロールバック**: git checkout でバンドル復元可能

## 成功基準
1. `find ... -type l` で絶対パスシンボリックリンクなし
2. アプリ起動 → Build List表示
3. ビルド開く → パッシブツリー表示

## 6点レビュー
1. 原因が明確か？ ✅ 絶対パスシンボリックリンクが原因
2. 技術的に妥当か？ ✅ コピー+相対リンクは標準的手法
3. リスクが低い/管理可能か？ ✅ Low
4. ロールバックが容易か？ ✅ git checkout
5. 視覚確認計画があるか？ ✅ アプリ起動+ツリー表示
6. タイムラインが現実的か？ ✅ 15分程度

**Score: 6/6 → 自動承認推奨**
