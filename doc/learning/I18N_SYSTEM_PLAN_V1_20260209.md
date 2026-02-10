# i18n多言語対応システム実装計画 V1

**Date**: 2026-02-09
**Task**: i18n (日本語/英語) 多言語対応システムの実装
**Score**: 6/6

---

## 修正案: 技術的アプローチ

### Phase 0: CJKフォントフォールバック (sg_text.cpp)

**ファイル**: `simplegraphic/src/rendering/sg_text.cpp`

**現状**: Liberation Sans Regular/Bold (ラテン文字のみ)
**目標**: グリフ不在時にHiragino Sansへフォールバック

**実装**:
1. 2番目の`FT_Face`をグローバル変数として追加 (`g_fallback_face`)
2. `sg_load_font()`で`/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc`をロード
3. `sg_rasterize_glyph()`で`FT_Get_Char_Index()`が0を返したらフォールバックFaceで再試行
4. SimpleGraphicリビルド + デプロイ

**リスク**: macOS標準フォントなのでバンドルサイズ増加なし。TTCファイルのface_index=0でW3にアクセス。

### Phase 1: コアインフラ (3新規ファイル)

**新規ファイル**:
- `src/Modules/i18n.lua` - グローバルi18nモジュール
- `src/Locales/en.lua` - 英語定義
- `src/Locales/ja.lua` - 日本語定義

**i18n.lua API**:
```lua
i18n.init(localeCode)       -- ロケール初期化
i18n.t("key.path")          -- 翻訳取得 (ドット区切り階層)
i18n.t("key", {count=5})    -- 変数置換
i18n.setLocale("ja")        -- 言語切替 + コールバック
i18n.getLocale()            -- 現在言語
i18n.onChange(callback)      -- 変更通知
```

**フォールバック**: 現在言語 → 英語 → キー文字列

### Phase 2: Settings統合 (Main.lua)

**変更箇所** (6箇所):
1. `LoadModule("Modules/i18n")` (top)
2. `self.language = "en"` (Init defaults)
3. `i18n.init(self.language)` (LoadSettings後)
4. LoadSettings: `node.attrib.language` 読み込み
5. SaveSettings: `language = self.language` 書き込み

### Phase 3: Optionsドロップダウン (Main.lua)

**変更箇所**:
6. Language DropDown追加 (OpenOptionsPopup)
7. Cancel処理でロールバック

### Phase 4: OptionsラベルI18n化

**変更箇所**:
- OpenOptionsPopup内のハードコードラベルを`i18n.t()`に置換
- en.lua/ja.luaにOptionsセクションの翻訳追加

---

## 実装手順

| Step | Phase | 内容 | ファイル | 担当 |
|------|-------|------|---------|------|
| 1 | 0 | フォールバックFace追加 | sg_text.cpp | メイン (C++) |
| 2 | 0 | ビルド+デプロイ+テスト | - | メイン (bash) |
| 3 | 1 | i18n.lua作成 | src/Modules/i18n.lua | サブエージェント |
| 4 | 1 | en.lua作成 | src/Locales/en.lua | サブエージェント |
| 5 | 1 | ja.lua作成 | src/Locales/ja.lua | サブエージェント |
| 6 | 2 | Main.lua Settings統合 | Main.lua | サブエージェント |
| 7 | 3 | Language DropDown | Main.lua | サブエージェント |
| 8 | 4 | OptionsラベルI18n化 | Main.lua + locale | サブエージェント |
| 9 | - | ファイル同期+テスト | - | メイン (bash) |

---

## リスク・ロールバック

| リスク | 対策 |
|-------|------|
| CJKフォント未表示 | Phase 0で事前テスト |
| 翻訳漏れ | フォールバック→英語→キー文字列 |
| Main.lua統合失敗 | 新規ファイル削除+数行リバート |
| テキスト幅の差異 | DrawStringWidthで動的サイズ |

**ロールバック**: 新規ファイル3つ削除 + Main.lua 6箇所リバート + sg_text.cppリバート

---

## 成功基準

1. ✅ `DrawString(100,100,"LEFT",16,"VAR","日本語テスト")` が表示される (Phase 0)
2. ✅ Options→Language→"日本語"でUIラベルが即時日本語化 (Phase 3)
3. ✅ 保存→再起動で日本語設定が維持 (Phase 2)
4. ✅ 英語フォールバック機能（未翻訳キーは英語表示） (Phase 1)

---

## 6点レビュー

1. ✅ **目的明確**: 日本語/英語UI切替システム
2. ✅ **技術的妥当**: LuaJIT 5.1互換、FreeTypeフォールバック標準パターン
3. ✅ **リスク低**: 新規ファイル中心、既存コード変更最小
4. ✅ **ロールバック容易**: 新規ファイル削除+数行リバート
5. ✅ **視覚確認計画**: Phase 0でフォント確認、各Phase後にスクリーンショット
6. ✅ **タイムライン現実的**: Phase 0-3で基盤完成

**Score**: 6/6

---

## 適用した教訓TOP3

1. **ConPrintf %d禁止** → i18n.luaのデバッグ出力は全て`%s` + `tostring()`
2. **ファイル同期必須** → 各Phase後に`cp -r src/ PathOfBuilding.app/.../src/`
3. **Nil-Safety必須** → i18n.t()のキー解決で全階層をnilチェック
