# スキルツールチップ全面日本語化 進捗管理

## Phase 1: UIラベル（~36文字列）
- [x] Step 1: en.lua — gemTooltipセクション追加
- [x] Step 2: ja.lua — gemTooltipセクション追加
- [x] Step 3: GemSelectControl.lua — AddGrantedEffectInfo内ラベルi18n化 + stringシャドウイング修正
- [x] Step 4: Build.lua — AddRequirementsToTooltip内ラベルi18n化
- [x] Step 5: i18n.lua — lookup()関数追加 + 補助ファイル読み込み
- [x] 👁 視覚確認 #1
- [ ] 📦 コミット Phase 1

## Phase 2: メタデータ（~90値）
- [ ] Step 6: ja.lua — gemTypes/tags/weaponRequirements/costResources テーブル追加
- [ ] Step 7: GemSelectControl.lua — ヘルパー関数追加 + 表示箇所で翻訳適用
- [ ] 👁 視覚確認 #2
- [ ] 📦 コミット Phase 2

## Phase 3: ジェム説明文（~895件）
- [ ] Step 8: ja_gem_descriptions.lua — 新規作成（PoE2DBデータ）
- [ ] Step 9: GemSelectControl.lua — 行790で説明文翻訳適用
- [ ] 👁 視覚確認 #3
- [ ] 📦 コミット Phase 3

## Phase 4: Stat Description基盤
- [ ] Step 10: StatDescriber.lua — locale-awareオーバーレイ注入
- [ ] 👁 視覚確認 #4（Phase 5データと合わせて）

## Phase 5: Stat Descriptionデータ（~20,143件）
- [ ] Step 11: ja_stat_descriptions.lua — 新規作成（段階的）
- [ ] 👁 視覚確認 #5
- [ ] 📦 コミット Phase 4+5
