# pob2起動不能 + 不要ファイル削除 計画 v1

## 原因分析

### 起動不能の原因
- `PathOfBuilding.app/Contents/MacOS/PathOfBuilding` の実行権限が消失
- 現在: `-rw-r--r--` (644) → 必要: `-rwxr-xr-x` (755)
- git操作またはファイルコピー時に権限が落ちた可能性

### 不要ファイル
| パス | サイズ | 内容 | 判定 |
|------|--------|------|------|
| `debug/passive_tree_app.log` | 87MB | 累積ログ | 削除可 |
| `dev/pob2-original/` | 975MB | Windows版PoB2オリジナル | 要確認 |
| `dev/simplegraphic/` | 4.2MB | SG開発用コピー | 削除可 |
| `dev/*.lua` (5ファイル) | ~20KB | テスト用Lua | 削除可 |
| `dev/*.md, *.txt` | ~数KB | 調査ログ | 削除可 |
| `v3_vertex_log.txt` | 153MB | 頂点デバッグログ | 削除可 |
| `v3_vertex_analysis_summary.txt` | 4KB | 分析サマリ | 削除可 |
| `test_tab_*.lua` (3ファイル) | ~20KB | タブテスト | 削除可 |
| `backups/20260202/` | 48KB | 古いバックアップ | 要確認 |

**合計削除予定**: ~1.2GB (dev/pob2-original含む場合)

## 修正案

### Step 1: 実行権限の復元 (即効修正)
```bash
chmod +x PathOfBuilding.app/Contents/MacOS/PathOfBuilding
```

### Step 2: 不要ファイル削除
- debug/passive_tree_app.log (87MB)
- v3_vertex_log.txt (153MB)
- v3_vertex_analysis_summary.txt
- test_tab_*.lua (3ファイル)
- dev/内の不要ファイル (simplegraphic/, *.lua, *.md, *.txt)

### Step 3: ユーザー確認が必要
- `dev/pob2-original/` (975MB) - Windows版オリジナル。まだ参照する？
- `backups/20260202/` - 古いバックアップ。必要？

## リスク・ロールバック
- chmod: `chmod 644` で戻せる
- ファイル削除: gitに入っていないのでゴミ箱経由(`mv`→確認後完全削除)
- **Risk**: Low

## 成功基準
1. `./PathOfBuilding.app/Contents/MacOS/PathOfBuilding` が実行可能
2. アプリが正常に起動する
3. 不要ファイルで1GB+のディスク領域を回復

## 6点レビュー
1. 原因が明確か？ → YES (chmod)
2. 技術的に妥当か？ → YES
3. リスクが低い/管理可能か？ → YES (Low risk)
4. ロールバックが容易か？ → YES
5. 視覚確認計画があるか？ → YES (アプリ起動確認)
6. タイムラインが現実的か？ → YES (~5分)

**Score: 6/6**
