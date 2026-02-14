# GEM_DESC_KEY_FIX_PLAN_V1_20260214

## 原因分析

### 症状
- ジェム説明文（フレーバーテキスト）の翻訳が表示されない
- `i18n.lookup("gemDescriptions", gemName)` が nil を返し、英語フォールバックが使われる

### 仮説（確認済み）
- `ja_gem_descriptions.lua` のキーがSkillsファイル（act_*.lua, sup_*.lua）のスキル名を使用
- 例: キー = "Load Armour Piercing Rounds"
- しかし `GemSelectControl.lua:824` は `gemInstance.gemData.name` でルックアップ
- `Gems.lua` の name = "Armour Piercing Rounds"（"Load"なし）
- → キー不一致で翻訳が見つからない

### 証拠
- Gems.lua line 8198: `name = "Armour Piercing Rounds"`
- ja_gem_descriptions.lua: `["Load Armour Piercing Rounds"]` → ミスマッチ
- ただし "Skeletal Warrior" は両方同じ → マッチする

## 修正案

### アプローチ: キー修正スクリプト
1. Gems.lua から全gem name を抽出
2. ja_gem_descriptions.lua の全キーと比較
3. マッチしないキーを特定
4. Gems.lua の name に合わせてキーを修正

### 実装手順
1. Pythonスクリプトで Gems.lua の全 name フィールドを抽出
2. ja_gem_descriptions.lua の全キーを抽出
3. 差分を分析（キー修正が必要なもの vs 存在しないもの）
4. 修正版 ja_gem_descriptions.lua を生成
5. アプリ起動で視覚確認

## リスク・ロールバック
- リスク: LOW（翻訳データファイルのみ変更）
- ロールバック: git checkout でファイル復元

## 成功基準
- アプリ起動 → ジェムツールチップにフレーバーテキストが日本語で表示される

## 6点レビュー
1. 原因が明確か？ → YES（キー不一致を具体例で確認）
2. 技術的に妥当か？ → YES（キー修正のみ、ロジック変更なし）
3. リスクが低い/管理可能か？ → YES（データファイルのみ）
4. ロールバックが容易か？ → YES（git checkout 1ファイル）
5. 視覚確認計画があるか？ → YES（アプリ起動+ジェム選択）
6. タイムラインが現実的か？ → YES（15分以内）

**Score: 6/6**
