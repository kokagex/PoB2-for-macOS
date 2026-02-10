# ModDB.lua:104 mod.value nil修正計画 V1

## 根本原因分析

**エラー**: `ModDB.lua:104: attempt to perform arithmetic on field 'value' (a nil value)`
**原因**: PoE2のmod dataにvalue=nilのmodが存在。SumInternal()のみガードなし。
**証拠**: 同ファイル内の他の5関数は既にnilガード済み（MoreInternal line 131: `mod.value or 0`）

## 修正内容

### Step 1: ModDB.lua:104 nilガード追加
**変更**: `result = result + mod.value` → `result = result + (mod.value or 0)`
**理由**: MoreInternal(line 131)と同じパターン。他全関数も既にガード済み。
**影響**: SumInternal()がnilのmod.valueをスキップ（0として扱う）

### Step 2: アプリバンドルに同期
```bash
cp src/Classes/ModDB.lua PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
```

### Step 3: アプリ起動＋スクリーンショット確認
- BuildOutput成功 → サイドバーStats更新確認
- 新しいエラーが出た場合 → 次のnilガード追加（反復的修正）

## リスク評価
- **リスク**: 低（既存パターンの適用、1行変更）
- **ロールバック**: `mod.value or 0` → `mod.value` に戻すだけ
- **副作用**: value=nilのmodは0として計算される（意図的にスキップ）

## 成功基準
1. ModDB.lua:104エラーが消える
2. BuildOutputが成功（またはさらに先のエラーに進む）
3. サイドバーStatsが計算結果を反映

## 想定時間: 10分（修正5分 + テスト5分）
## レビュースコア: 6/6 (Auto-approved)
