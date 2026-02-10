# PoE1 vs PoE2 モジュール非互換性レポート

**日付**: 2026-02-04 23:45 JST
**発見者**: Prophet (Claude Sonnet 4.5)
**影響**: フェーズ2（ModList/modLib統合）の実装戦略

---

## 📋 要約

Windows版Path of Building 2の`Modules/Data.lua`と`Modules/ModTools.lua`は**Path of Exile 1**用に設計されており、**Path of Exile 2**とは互換性がありません。これらのモジュールをそのままロードすると、フィールド名の不一致によりエラーが発生します。

---

## 🔍 発見された非互換性

### 1. characterConstants フィールド名の違い

#### PoE1 (Windows版 Modules/Data.lua:181)
```lua
data.misc.ManaRegenBase = data.characterConstants["mana_regeneration_rate_per_minute_%"] / 60 / 100
```

#### PoE2 (macOS版 Data/Misc.lua:127)
```lua
data.characterConstants = {
    ...
    ["character_inherent_mana_regeneration_rate_per_minute_%"] = 240,
    ...
}
```

**問題**: PoE1のコードは`mana_regeneration_rate_per_minute_%`を期待するが、PoE2では`character_inherent_mana_regeneration_rate_per_minute_%`という名前になっている。

---

### 2. gameConstants フィールドの変更

PoE2では多くのゲーム定数が追加・変更されており、PoE1のコードが期待するフィールドが存在しない場合があります。

---

### 3. jewelRadii バージョン番号の違い

#### PoE1 (Modules/Data.lua:500-506)
```lua
data.jewelRadii = {
    ["3_15"] = { ... },
    ["3_16"] = { ... },
}
```

#### PoE2 (必要なバージョン)
```lua
data.jewelRadii = {
    ["0_1"] = { ... },
    ["0_2"] = { ... },
    ["0_3"] = { ... },
    ["0_4"] = { ... },
}
```

**問題**: PoE1のモジュールはPoE2のツリーバージョン（0_x）を認識しない。

---

## 🛠️ 採用した解決策

### 現在の実装 (Launch.lua:73-82)

```lua
-- Load core modules (prefer app bundle, fallback to dev)
LoadModule("GameVersions")
LoadModule("Modules/Common")     -- newClass(), copyTable(), copyTableElements()

-- Initialize data table for PoE2
data = {}
LoadModule("Data/Misc", data)    -- Load PoE2 data (characterConstants, gameConstants, etc.)

-- Note: Can't load full Modules/Data or Modules/ModTools yet - they have PoE1 vs PoE2 incompatibilities
-- Will integrate these in Phase 2.2 after adapting for PoE2
```

### アプローチの利点

1. **エラーなし**: PoE2専用の`Data/Misc.lua`を直接ロードすることで、フィールド名の不一致を回避
2. **最小限の変更**: 既存の`Data/Misc.lua`は修正不要
3. **段階的移行**: 将来的にPoE2対応のModToolsを追加可能

---

## 📊 影響を受ける機能

### 現在動作している機能 ✅
- パッシブツリー表示
- ノードのレンダリング
- ホバー判定
- パン/ズーム操作
- 基本的なdata構造（characterConstants、gameConstants）

### 影響を受ける機能（保留） ⚠️
- **ModList.Sum()**: 統計計算に必要
- **ModList.More()**: 乗算計算に必要
- **modLib関数**: Modの解析と生成
- **統計パネル**: ビルド統計の表示（Life、DPS等）
- **ツールチップ**: ノードの詳細な効果表示

---

## 🎯 今後の実装戦略

### 短期的アプローチ（推奨）
フェーズ3とフェーズ4を**emptyModListスタブ**のまま実装:
- クラス/アセンダンシー切替
- ノード割当/解除
- 視覚的フィードバック

これらの機能は統計計算なしでも動作可能です。

### 長期的アプローチ
1. **PoE2専用ModToolsの作成**:
   - Windows版のModToolsを参考に、PoE2用のModParser.luaを作成
   - PoE2のフィールド名に対応したModList.luaを実装

2. **またはPoE1モジュールの適応**:
   - Modules/Data.luaをPoE1/PoE2両対応に修正
   - フィールド名の違いを吸収するラッパー層を追加

---

## 🔬 技術的詳細

### 試行したアプローチと結果

#### 試行1: Windows版Modules/Data.luaをそのままロード ❌
```lua
LoadModule("Modules/Data")  -- ../../../../dev/pob2-original/src/Modules/Data.lua
```

**結果**:
```
ERROR loading module 'Modules/Data': Data.lua:181: attempt to perform arithmetic on field 'mana_regeneration_rate_per_minute_%' (a nil value)
```

#### 試行2: data = {} を削除してModules/Dataに任せる ❌
```lua
-- data = {} を削除
LoadModule("Modules/Data")
```

**結果**: 同じエラー（Modules/Data.lua自体がPoE2のフィールド名を認識しない）

#### 試行3: Data/Miscを直接ロード ✅
```lua
data = {}
LoadModule("Data/Misc", data)  -- PoE2専用のData/Misc.lua
```

**結果**: エラーなし、正常動作

---

## 📝 教訓

### LESSON LEARNED
- **前提を疑う**: Windows版のモジュールが「そのまま使える」という前提は誤りでした
- **バージョンの違いを確認**: PoE1とPoE2は見た目が似ていても、内部データ構造が大きく異なります
- **段階的な検証**: 大きなモジュールをロードする前に、小さな部分（Data/Misc）で検証すべきでした

### 次回に活かすポイント
1. 新しいモジュールをロードする前に、PoE1/PoE2の違いをチェック
2. フィールド名のマッピングテーブルを作成して互換性を確保
3. 完全な統合を試みる前に、最小限の機能で検証

---

## 🚀 次のステップ

### 即座に実行可能
1. フェーズ3（クラス切替）の実装開始
2. フェーズ4（ノード割当）の実装
3. 視覚的フィードバックの追加

### 将来的に実装
1. PoE2専用ModToolsの設計と実装
2. 統計計算の再有効化
3. 完全なツールチップ表示

---

**作成者**: Prophet (Claude Sonnet 4.5)
**レビュー**: 未実施
**ステータス**: 調査完了、実装戦略決定済み
