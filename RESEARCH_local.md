# RESEARCH_local.md — PoB2 macOS ローカルデータ解析

## 1. 日本語ローカライゼーション

### 1.1 ファイル一覧と統計

| ファイル | 行数 | エントリ数 | 用途 |
|---|---|---|---|
| `src/Locales/ja.lua` | 3152 | ~300 (ネスト構造) | UI文字列全般 |
| `src/Locales/ja_mod_stat_lines.lua` | 3298 | **3286エントリ** | Mod表示テキスト |
| `src/Locales/ja_stat_descriptions.lua` | 1337 | ~500 | スキルサポートGem説明 |
| `src/Locales/ja_unique_names.lua` | 394 | ~370 | ユニークアイテム名 |
| `src/Locales/ja_unique_flavourtext.lua` | 1348 | ~330 | ユニークフレーバーテキスト |
| `src/Locales/ja_gem_descriptions.lua` | 967 | ~450 | ジェム/スキル説明 |
| `src/Locales/ja_gem_flavourtext.lua` | 61 | ~30 | ジェムロアテキスト |
| `src/Locales/ja_base_names.lua` | 1420 | ~700 | ベースアイテム名 |

**合計: 8ファイル / ~12,000行 / ~6,000エントリ**

### 1.2 データ構造パターン

**ja.lua** — ネスト型テーブル (最大3階層) + `i18n.t("options.app.uiScaling")` でアクセス:
```lua
return {
    options = { title = "オプション", app = { uiScaling = "UI拡大率:" } },
    tabs = { tree = "ツリー", skills = "スキル" },
}
```

**ja_mod_stat_lines.lua** — 英語全文字列→日本語のフラットテーブル (数値入りキー):
```lua
["+{0} Armour if you've Blocked Recently"] = "+{0} アーマー 最近ブロックした場合"
["(-15—-10)% to Cold Resistance"] = "冷気耐性 (-15—-10)%"
```

**ja_stat_descriptions.lua** — `{N}` プレースホルダー型 + 単数/複数形を両登録:
```lua
["Base radius is {0} metre"]  = "基本半径は{0}m"
["Base radius is {0} metres"] = "基本半径は{0}m"
```

**ja_unique_flavourtext.lua** — 複数行対応の配列型:
```lua
["Alpha's Howl"] = { "自然は強者に敬意を払い、", "弱者の血で雪を赤く染め上げる。" }
```

**ja_unique_names.lua / ja_base_names.lua** — フラットKV:
```lua
["Alpha's Howl"] = "アルファズハウル"
```

### 1.3 翻訳ルール・属性名標準化

| 英語 | 日本語 | 備考 |
|---|---|---|
| Fire | **火** | "ファイア"ではなく漢字 |
| Cold | **冷気** | "コールド"ではない |
| Lightning | **雷** | "ライトニング"ではない |
| Chaos | **混沌** | "カオス"ではない |
| Physical | **物理** | - |
| Elemental | **元素** | - |
| Life | **ライフ** | カタカナ |
| Mana | **マナ** | カタカナ |
| Energy Shield | **エナジーシールド** | カタカナ |
| Armour | **アーマー** | カタカナ |
| Evasion | **回避** | 漢字 |

**重要: スキル名は翻訳しない（英語のまま維持）**
- 過去の失敗: "Avatar of Fire" → "アバター・オブ・火" のような混合翻訳が発生
- スキル名ホワイトリストで保護が必要

### 1.4 特殊処理パターン

- **2種類のプレースホルダー:** `{N}` (mod_stat_lines/stat_descriptions) と `%{varName}` (ja.lua変数置換)
- **color escape維持:** `"^8(PoBでは未サポート)"` の `^8` をそのまま日本語文中に埋め込む
- **DNTマーカー:** 未翻訳エントリには `"[DNT] ..."` プレフィックスを維持
- **単数/複数形:** 英語では別エントリだが日本語は同一訳（"metre"/"metres" → "m"）

---

## 2. 表示・レンダリングカスタマイズ

### 2.1 フォント切替メカニズム

`pob2_launch.lua` L420-433:
```lua
_G.SwitchFontFile = function(langCode)
    local srcName = langCode == "ja"
        and "NotoSansCJKjp-Medium.ttf"
        or "LiberationSans-Original.ttf"
    -- NotoSansCJKjp-Medium.ttf → LiberationSans-Regular.ttf に上書きコピー
    -- 次回起動時に有効化 (再起動必須)
end
```

**保護対象フォントファイル:**
- `runtime/fonts/NotoSansCJKjp-Medium.ttf` — 日本語CJKフォント
- `runtime/fonts/LiberationSans-Original.ttf` — 英語フォントバックアップ
- `runtime/fonts/LiberationSans-Regular.ttf` — 実行時使用フォント（ランタイムで上書き）

### 2.2 フォントスケーリング

`pob2_launch.lua` L409-418:
- **日本語: fontScale = 0.93** / 英語: 1.0
- Noto Sans CJKは同ptでLiberationSansより大きくレンダリングされるため補正
- `Main.lua` L688, L999: `SetFontScale(self.language == "ja" and 0.93 or 1.0)`

### 2.3 CJKテキストラップ

`src/Modules/Main.lua` L1806-1890:
```lua
local function hasCJK(str)
    return str:find("[\227-\233][\128-\191][\128-\191]") ~= nil
    -- UTF-8 3バイトシーケンス 0xE3-0xE9 = Hiragana/Katakana/Kanji/CJK記号
end

function main:WrapString(str, height, width)
    if not hasCJK(str) then
        -- 英語: スペース区切り (オリジナル実装)
    else
        -- CJK: スペース(b==32) または CJK開始バイト(b>=227) を改行候補
        -- DrawStringWidth で幅測定して折り返し判定
    end
end
```

### 2.4 DrawString/DrawStringWidthオーバーライド

`pob2_launch.lua` L436-462:
```lua
_G.DrawString = function(left, top, align, height, font, text)
    sg.DrawString(..., math.floor(height * scale * fontScale), ...)
    -- fontScale が height に乗算される
end

_G.DrawStringWidth = function(height, font, text)
    local w = sg.DrawStringWidth(math.floor(height * scale * fontScale), font, text)
    if fontScale < 1.0 then
        return math.floor(w / scale * 1.30)  -- 日本語時: 幅を1.30倍補正
    end
    return math.floor(w / scale)
end
```

**注意:** `1.30` 定数はNoto Sans CJK固有の幅補正値。フォント変更時に要再調整。

---

## 3. i18nモジュール

### 3.1 アーキテクチャ

`src/Modules/i18n.lua` — ローカル独自モジュール（上流に存在しない）

- メインロケールファイル (`ja.lua`) は `i18n.init("ja")` 時に即時ロード
- 補助ファイル7種は `i18n.lookup(section, key)` の初回呼び出し時に遅延ロード

### 3.2 遅延ロード機構

```lua
local auxiliaryFiles = {
    gemDescriptions   = "_gem_descriptions",   -- → ja_gem_descriptions.lua
    statDescriptions  = "_stat_descriptions",  -- → ja_stat_descriptions.lua
    gemFlavourText    = "_gem_flavourtext",     -- → ja_gem_flavourtext.lua
    uniqueNames       = "_unique_names",        -- → ja_unique_names.lua
    baseNames         = "_base_names",          -- → ja_base_names.lua
    modStatLines      = "_mod_stat_lines",      -- → ja_mod_stat_lines.lua
    uniqueFlavourText = "_unique_flavourtext",  -- → ja_unique_flavourtext.lua
}
-- auxLoaded["ja:gemDescriptions"] = true で二重ロードを防止
```

### 3.3 翻訳適用フロー

`i18n.translateModLine(line)` の数値抽出順序（**この順序を変えると全Mod翻訳が壊れる**）:
1. `(X-Y)` 範囲をプレースホルダーに置換
2. `#` をプレースホルダーに置換
3. 単独数値をプレースホルダーに置換
4. プレースホルダーを `{0}`, `{1}`, ... に変換
5. `ja_mod_stat_lines` テーブルで照合
6. 日本語テンプレートに元の数値を復元

---

## 4. ローカル独自データファイル

### 4.1 TreeTranslations/ja.lua

4,379行。パッシブツリーノード名の日本語訳。

```lua
return {
    version = "0_4",  -- ツリーJSONバージョンと照合
    names = {
        -- KEYSTONES (33件): カタカナ音訳
        ["Avatar of Fire"] = "アバターオブファイヤー",
        -- NOTABLES (932+件): 意味重視の日本語訳
        ["Acceleration"] = "加速",
    }
}
```

### 4.2 StatDescriptions（664ファイル）

`src/Data/StatDescriptions/Specific_Skill_Stat_Descriptions/` — 自動生成。
上流には存在しない完全ローカル独自ディレクトリ。

各ファイル構造:
```lua
return {
    [1] = { stats = { [1] = "stat_id" } },
    [2] = {
        [1] = {
            [1] = { k = "divide_by_ten_1dp_if_required", v = 1,
                    limit = { [1] = { [1]=10, [2]=10 } },
                    text = "Explosion radius is {0} metre" },
        },
        stats = { [1] = "active_skill_base_area_of_effect_radius" }
    },
    ["active_skill_base_area_of_effect_radius"] = 2,
    parent = "skill_stat_descriptions"
}
```

### 4.3 独自Modファイル

| ファイル | 用途 | 備考 |
|---|---|---|
| `ModCharm.lua` | チャームAffix (PoE2新要素) | `type = "Prefix"/"Suffix"` |
| `ModCorrupted.lua` | コラプトImplicit | `type = "Corrupted"`, `affix = ""` |
| `ModIncursionLimb.lua` | インカージョン義肢Mod | Leg系6件 + Arm系6件, `weightKey = {}` |
| `ModItemExclusive.lua` | ユニーク専用/クラスImplicit | Quiver/Amulet/Ring等 |
| `ModScalability.lua` | Passiveジュエルスケーラビリティ | `isScalable`, `formats` |

### 4.4 独自Uniqueファイル

PoE2新武器タイプ等、9ファイル:

| ファイル | 内容 |
|---|---|
| `crossbow.lua` | Double Vision, The Last Lament等 |
| `flail.lua` | 現在空 |
| `focus.lua` | Apep's Supremacy, Carrion Call等 |
| `spear.lua` | スピア系ユニーク |
| `traptool.lua` | トラップツール系 |
| `soulcore.lua` | ソウルコア系 |
| `incursionlimb.lua` | インカージョン義肢 |
| `graft.lua` | グラフト（`return {}`、上流404エラー対策） |
| `tincture.lua` | チンキチャ系 |

Uniqueファイル形式: Lua長文字列 `[[ ... ]]` ブロック、`Variant: Pre 0.x.x` / `{variant:N}` 構文でバリアント管理。

---

## 5. Data.luaローダー構造

### 5.1 ロード順序

独立した `Data.lua` ローダーは `ModCache.lua` がアグリゲート。

各Modファイルはデータテーブルとして返却され、`ModCache.lua`内で統合される。

### 5.2 ローカル独自ロード処理

- `i18n.lua` は `Main.lua` L25 で `LoadModule("Modules/i18n")` によりロード
- 言語設定は `Settings.xml` の `language` 属性として保存・読み込み
- `i18n.setLocale()` + `SetFontScale()` + `SwitchFontFile()` が連動して呼ばれる

---

## 6. 上流統合時の保護対象サマリー

### 絶対保護ファイル（上流に存在しないローカル独自）

```
pob2_launch.lua                          # FFI/DPI/フォント/CJK入力の全実装
src/Modules/i18n.lua                     # i18nシステム全体
src/Locales/ja*.lua (8ファイル)          # 日本語翻訳データ
src/Data/TreeTranslations/ja.lua         # パッシブツリー日本語訳
runtime/fonts/NotoSansCJKjp-Medium.ttf   # 日本語フォント
runtime/fonts/LiberationSans-Original.ttf # 英語フォントバックアップ
```

### Main.lua のマージ必須保持コード

```lua
-- [PROTECT-1] fontScale定数
SetFontScale(self.language == "ja" and 0.93 or 1.0)

-- [PROTECT-2] DrawStringWidth 幅補正
if fontScale < 1.0 then return math.floor(w / scale * 1.30) end

-- [PROTECT-3] CJK文字判定
local function hasCJK(str)
    return str:find("[\227-\233][\128-\191][\128-\191]") ~= nil
end

-- [PROTECT-4] Unicode強制有効化
if not self.unicode and i18n and i18n.getLocale() ~= "en" then
    self.unicode = true
end

-- [PROTECT-5] i18n初期化チェーン
LoadModule("Modules/i18n")           -- L25
if i18n and i18n.init then i18n.init("en") end  -- L81
i18n.setLocale(self.language)        -- L683 (Settings読み込み時)
```

### 共通ファイルマージ時の注意点

- **Modファイル**: 上流の新Modエントリは追加可。既存エントリの構造変更は要検証
- **Uniqueファイル**: 上流の新ユニークは追加可。既存バリアント構文変更は要検証
- **Skills/**: 上流のスキルデータ更新は基本的に安全（i18nは参照のみ）
- **Bases/**: 上流のベースデータ更新は基本的に安全（ja_base_names.luaとの照合が必要）
