# Build Generator (PoE2) — 設計書

- **作成日**: 2026-05-18
- **status**: draft (brainstorming 合意済み、user 最終 review 待ち)
- **対象ゲーム**: Path of Exile 2 (0.x 系、月末 0.5 待ち)
- **依存先プロジェクト**: PoB-PoE2 fork (本リポジトリ `national-operations` で維持)
- **本プロジェクトのリポジトリ**: `kokagex/pob2-build-generator` (別リポとして新規作成予定、本リポと別管理)

## 1. 目的

メインスキル + サブスキル + ビルドのキーになる装備 (key items) を partial に指定した状態から「Generate」ボタンで残りの構成要素 (passive tree / gem links / 空きスロット gear / jewel / flask) を**最適補完**するアプリケーション。

PoB-PoE2 fork が持つデータ (skill / unique / mod / passive tree) と計算エンジン (DPS / EHP 算出) を外側から駆動する形で、独立した GUI アプリ (Tauri) として実装する。

## 2. 設計原則 (柱)

1. **Lean first**: trait 抽象化や並列化や preset 切替は MVP に入れない。動いてから後付け
2. **上流変更耐性**: PoE2 の game content (skill 名 / item 名 / mod id) を一切 hardcode しない。データは全て PoB の `src/Data/*` と `tree-data/*` から runtime 取得、月末 PoB2 アプデが入っても自動反映
3. **Single source of truth**: 独自 DB を持たない。PoB に JSON dump させて Rust はそれを読む構造
4. **Fail loudly**: PoB データの schema 変更を起動時に検出して loud error。silent degradation 禁止
5. **Progressive output**: 重い最適化は段階的に。「初期解 10-30 秒 → 裏で改善継続 → UI で更新」型 UX (MVP は割り切り、後付け)
6. **Distribution stage**: 最初 macOS 自分専用で iterate → 後で cross-platform 公開。技術選定は両対応前提

## 3. システム構成

```
┌─────────────────────────────────────────────────────────────┐
│  PoB2 Build Generator (Tauri app)                           │
│                                                             │
│  ┌─────────────┐    ┌──────────────────┐   ┌─────────────┐ │
│  │  React UI   │◄──►│  Rust core       │◄─►│ PoB JSON    │ │
│  │ (picker,    │    │  - BuildModel    │   │ Reader      │ │
│  │  generator, │    │  - BuildIntent   │   │ (cached)    │ │
│  │  result)    │    │  - Optimizer     │   └─────────────┘ │
│  └─────────────┘    │    (Greedy MVP)  │           ▲       │
│                     │  - Preset scorer │           │       │
│                     │  - Fitness       │           │       │
│                     │    (Rust 概算)   │           │       │
│                     └────────┬─────────┘           │       │
│                              ▼                     │       │
│                     ┌──────────────────┐           │       │
│                     │ PoB headless     │           │       │
│                     │ worker (long-    │           │       │
│                     │ lived luajit     │           │       │
│                     │ subprocess +     │           │       │
│                     │ stdin/stdout)    │           │       │
│                     └────────┬─────────┘           │       │
└──────────────────────────────┼─────────────────────┼───────┘
                               │ xml ↔ stats         │ JSON dump
                               ▼                     │ (起動時 1 回)
                  ┌──────────────────────┐           │
                  │ luajit (system)      │           │
                  │ + PoB-PoE2 install   │           │
                  │ (user 設定 path)     │           │
                  └────────┬─────────────┘           │
                           │                         │
                           ▼                         │
                  ┌────────────────────────────────────┐
                  │  PoB-PoE2 src/Data + tree-data     │
                  │  ← single source of truth          │
                  │  ← PoB upstream sync で自動更新    │
                  └────────────────────────────────────┘
```

### コンポーネント役割

| Component | 言語 / 場所 | 責務 |
|-----------|--------------|------|
| **React UI** | TypeScript / `src/` | item picker、generator UI、result 表示 (PoB build code copy/import button) |
| **Rust core** | Rust / `src-tauri/core/` | BuildModel、BuildIntent 推論、Greedy optimizer、preset fitness 関数、Rust 側概算計算 |
| **PoB JSON Reader** | Rust / `src-tauri/data/` | 起動時に `data_export.lua` を spawn して PoB 全データを JSON 化、Rust メモリに展開 |
| **PoB headless worker** | Rust + Lua / `src-tauri/pob_bridge/` + `scripts/pob_worker.lua` | 長時間生存 luajit subprocess。stdin から build xml、stdout に DPS/EHP の JSON を返す REPL-like worker |
| **data_export.lua** | Lua / `scripts/` | PoB headless 内で全 unique/mod/skill/tree node を parse → JSON で stdout 出力 |
| **pob_worker.lua** | Lua / `scripts/` | HeadlessWrapper を読み込み、stdin loop で build xml を受けて stats JSON を返す |

## 4. データ層

### 4.1 データソース (PoB single source of truth)

| 種別 | PoB 内パス | format | 読み方 |
|------|-----------|--------|--------|
| Mods | `src/Data/Mod*.lua` (ModItem, ModJewel, ModFlask 等) | 純 Lua table | data_export.lua が PoB の table を JSON 化 |
| Uniques | `src/Data/Uniques/*.lua` | 多段文字列 (PoB 独自タグ `{tags:*}` `{variant:*}` 含む) | **PoB text parser に通した結果**を JSON 化 |
| Skills | `src/Data/Skills/*.lua` (act_*, sup_*) | Lua table + 一部関数 | data_export.lua が parse 後の表現を dump |
| SkillStatMap | `src/Data/SkillStatMap.lua` | Lua | BuildIntent 推論で使う |
| Passive Tree | `tree-data/0_X/` (latest minor) | JSON / Lua | tree-data ロード関数を流用 |
| Bases | `src/Data/Bases.lua` | Lua table | dump |

### 4.2 データ更新フロー

1. PoB-PoE2 fork で upstream sync (Phase N)
2. user が Generator アプリ起動 → 「データ再 dump」ボタン or 起動時自動検出 (PoB ファイル mtime watch)
3. `data_export.lua` を luajit subprocess で実行 → JSON を `src-tauri/data/cache/*.json` に書き出し
4. Rust が JSON ロード、memory cache 構築

### 4.3 月末 PoB2 アプデ (0.5) 対応

- 0.5 で skill / mod / passive tree 大幅変更予定
- 想定される対応コスト
  - **新 skill 追加 / mod 値変更 / passive tree node 追加**: 設計どおり自動反映 (data_export.lua が parse、Rust は ID 直参照だけ)
  - **Lua data 構造の breaking change** (例: skill table のキー名変更): data_export.lua が fail → Rust に loud error 伝搬 → user に「PoB データ schema が変わった、export script の修正が必要」と表示
  - **passive tree のフォーマット変更**: tree-data loader を修正 (PoB 側に追随)
- CI: PoB upstream sync 完了後に「`data_export.lua` が走り切る + smoke test build が parse 通る」を確認

## 5. Core ロジック

### 5.1 BuildModel

```rust
struct BuildModel {
    class: Class,
    ascendancy: Option<Ascendancy>,
    main_skill: SkillId,
    sub_skills: Vec<SkillId>,
    locked_items: HashMap<Slot, ItemRef>,      // ユーザー固定 (unique or 詳細 mod 指定)
    candidate_items: HashMap<Slot, ItemDraft>, // optimizer が埋める
    passive_tree: BitSet,                       // allocated node id
    jewels: Vec<JewelDraft>,
}
```

### 5.2 BuildIntent 推論 (optimizer の肝)

key item と main/sub skill から「このビルドが何を目指しているか」を推論する層。

```rust
struct BuildIntent {
    damage_types: Vec<DamageType>,            // Lightning, Cold, Physical, ...
    delivery: Vec<Delivery>,                  // Attack, Spell, DoT, Minion
    crit_oriented: bool,
    conversion_chains: Vec<(DamageType, DamageType)>,  // Phys→Cold 等
    defensive_layers: Vec<Defense>,           // Block, ES, Armour, Evasion
}

impl BuildIntent {
    fn infer(
        main_skill: &Skill,
        sub_skills: &[Skill],
        key_items: &[Item],
        stat_map: &SkillStatMap,
    ) -> Self {
        // 1. skill の damage tag 集約 (e.g., Spark → Lightning, Spell)
        // 2. sub skill が conversion / aura / curse なら delivery 補足
        // 3. key item の mod を tag 抽出 (e.g., "20% of Physical converted to Cold" → conversion)
        // 4. crit-rate / crit-multi mod の重み合計が閾値超え → crit_oriented = true
        // 5. defensive mod (block / ES / armour) の偏りで defensive_layers
    }
}
```

- preset の fitness 係数と組み合わさって最終的な節点重みを決める
- 例: `BuildIntent { damage_types: [Lightning], crit_oriented: true }` × Preset `Balanced` → passive node の評価で "Lightning damage" "Crit chance" を高重み、"Cold damage" は無視

### 5.3 Fitness 関数 (MVP: preset 1 個のみ "Balanced")

```
fitness(build) =
    log(DPS) + 0.5 * log(EHP) - penalty(constraints)

penalty:
    resist 未cap     → -1e6 (fatal)
    accuracy 未 90%  → -1e3 (soft)
    mana sustain NG  → -1e3
```

将来 preset 追加 (Boss DPS / Mapper / Tanky / Budget) は係数とペナルティ条件を切り替えるだけ。

### 5.4 Optimizer (MVP Greedy)

生成順 (依存順):

1. **Ascendancy**: main_skill の damage type に合う ascendancy を推奨 (固定 or 入力)
2. **Passive tree allocation** (~100 node):
   - 開始 node から BFS で隣接候補列挙
   - 各候補の評価は **Rust 概算 fitness** (= sum of stat mods × BuildIntent weight) を使う (高速)
   - 100 step ごとに **PoB headless で実計算 checkpoint** を 1 回入れて Rust 概算とのズレを補正
3. **Gem links**:
   - main_skill の socket group に対し、SkillStatMap で `tag` マッチする support gem を damage 寄与順に top 5-6 個
4. **Gear (空きスロットのみ)**:
   - slot ごとに mod DB から fitness 寄与高い mod 組み合わせを top-K 構築 (rare: 6 affix 制約)
   - unique slot で unique の fitness が rare 合成を上回れば unique 採用
5. **Jewel**:
   - 通常 jewel のみ MVP 対象。cluster は phase 2
6. **Flask / Charm**:
   - MVP は PoE2 default (life flask + utility 1-2 個) 固定

### 5.5 計算コスト見積もり (MVP Greedy)

- Rust 概算 fitness: ~10μs / 評価、10,000 評価で 0.1 秒
- PoB headless calc: 50-200ms / 1 回 (long-lived worker で起動コスト除く)
- 設計: greedy 全体で PoB headless 呼び出しは **checkpoint 5 回 + 最終確定 1 回 = 6 回**
- 期待 total: 1-2 秒 (起動済み worker 前提)
- 起動コスト (worker 立ち上げ + PoB load + data dump): 10-30 秒 (起動時 1 回のみ)

精度が greedy で出ない場合の Phase 2 拡張: GA layer + worker pool + progressive UI 更新。

## 6. PoB 連携 (headless)

### 6.1 連携経路

- **データ取得**: `luajit data_export.lua --pob-path <PATH>` → JSON を stdout に dump (起動時 1 回)
- **ビルド計算**: `luajit pob_worker.lua --pob-path <PATH>` を long-lived process として spawn → stdin で build xml 投入 → stdout で stats JSON 受領 (calc 毎)

### 6.2 data_export.lua (新規作成)

PoB の HeadlessWrapper をロード → 全 unique / mod / skill / tree node を parse → JSON に serialize して stdout。

### 6.3 pob_worker.lua (新規作成)

```lua
-- 概念実装
dofile("HeadlessWrapper.lua")
newBuild()

while true do
    local cmd = io.read("*l")
    if cmd == "EXIT" then break end
    if cmd:sub(1, 5) == "BUILD" then
        local xml = io.read(tonumber(cmd:sub(7)))  -- 長さ指定
        loadBuildFromXML(xml, "tmp")
        local stats = extractStats(build)
        print(json.encode(stats))
        io.flush()
    end
end
```

### 6.4 Rust 側 worker pool

MVP は **worker 1 個**。並列化は phase 2 (GA で多数 candidate 評価する段階)。

## 7. UI / UX

### 7.1 主要画面 (MVP)

```
[Build Generator]
┌─────────────────────────────────────────────────┐
│ Class:        [Ranger ▼]                        │
│ Ascendancy:   [Deadeye ▼]   (推奨自動入力可)   │
│                                                  │
│ Main Skill:   [Lightning Arrow ▼]               │
│ Sub Skills:   [+ Add] [Returning Projectiles] │
│                                                  │
│ Key Items (固定スロット):                        │
│   Weapon: [🔍 Quill Rain]                       │
│   Helmet: [empty]    Body: [empty]              │
│   ...                                            │
│                                                  │
│ Preset:  ● Balanced    (MVP は 1 個のみ)        │
│                                                  │
│ Char Level: [95]                                │
│                                                  │
│ [   Generate   ]                                │
└─────────────────────────────────────────────────┘
```

結果ペイン:

```
[Result]
DPS: 1,234,567   EHP: 8,500   Resists: 75/75/75 (chaos 25)
Passive Tree: 95 / 100 nodes
Build Code (PoB import):
[..............................................]
[Copy] [Open in PoB]
```

### 7.2 item picker (要作り込み)

- **データ**: PoB の JSON dump から検索
- **検索**: skill 名 / item 名 / mod tag (e.g., "lightning damage") で fuzzy
- **表示**: item icon (PoB の assets を参照、license 注意)、mod 一覧、variant 選択
- 詳細は実装計画 phase で詰める

## 8. プロジェクト構成 (B 案: 別リポ)

```
pob2-build-generator/             # 新規リポ
├── README.md
├── CLAUDE.md                      # global rules 継承
├── package.json                   # React 依存
├── src-tauri/
│   ├── Cargo.toml
│   ├── src/
│   │   ├── main.rs
│   │   ├── core/
│   │   │   ├── model.rs           # BuildModel
│   │   │   ├── intent.rs          # BuildIntent
│   │   │   ├── optimizer.rs       # Greedy
│   │   │   ├── fitness.rs         # 概算 + preset
│   │   │   └── pob_xml.rs         # build code (de)serialize
│   │   ├── pob_bridge/
│   │   │   ├── data_reader.rs     # JSON cache loader
│   │   │   └── worker.rs          # long-lived luajit worker
│   │   └── tauri_commands.rs
│   └── data/cache/                # gitignored
├── src/                           # React
│   ├── App.tsx
│   ├── components/
│   ├── stores/
│   └── api/                       # tauri command wrapper
├── scripts/
│   ├── data_export.lua
│   └── pob_worker.lua
├── tests/
│   └── smoke.rs                   # end-to-end smoke
└── docs/specs/                    # 本 spec 等
```

PoB-PoE2 install 場所は user 設定 (Tauri app の settings で path 指定、初回起動時に検出)。

## 9. MVP 「done」 line

以下が満たされたら MVP 完了:

1. user が GUI で **class + main skill + sub skill 1 個 + key item 1 個 + Balanced preset** を選択できる
2. **Generate** ボタンで Greedy が走り、suggested build を 30 秒以内に返す (起動済み worker 前提)
3. 結果 panel に **PoB build code (xml)** が表示され、コピーして PoB で import すると build が読み込まれる
4. **smoke test 1 本** が CI で通る: 「上記フローを headless 起動 → 生成 build code を再度 PoB headless に投げて parse 成功 + DPS > 0」

MVP **外** (phase 2 以降):

- preset 切替 (Boss DPS / Mapper / Tanky / Budget)
- progressive output / GA layer
- worker pool (並列 PoB calc)
- constraint UI (Min EHP / Resist 指定 / Budget)
- history view
- cluster jewel 対応
- 多言語 UI
- Windows / Linux build と公開
- Trade API 連携モード

## 10. Open Questions / 未決定事項

| ID | 内容 | 対処 |
|----|------|------|
| OQ-1 | item picker UI で **PoB の item icon assets** を再利用する場合の license / 配布上の扱い | phase 1 末で確認、必要なら placeholder アイコンに代替 |
| OQ-2 | Greedy が Rust 概算でずれて bad build を返す頻度 | 実測してから判断 (MVP 動かしてから測る) |
| OQ-3 | 月末 PoB2 0.5 で **passive tree フォーマット**が変わるか、tree-data layout 変わるか | 0.5 リリース後に PoB upstream の対応待ち、対応 PR を取り込んでから tree loader 改修 |
| OQ-4 | brain_status 出力が CLAUDE.md mandate の 4 section ではなく バグパターン 1 section だけだった件 | brain MCP 側の仕様か doc 側の wish か session 末に open_question 化 |
| OQ-5 | data_export.lua が PoB の text parser を再利用するための API surface (PoB の build importer は具体的にどの関数で公開されてるか) | 実装 phase で `src/Classes/ImportTab.lua` 等を grep して確定 |

## 11. 検証戦略 (lean: 1 本だけ)

- **End-to-end smoke test** (`tests/smoke.rs`): app 起動 → 固定の partial build 入力 → Generate → build code 取得 → PoB headless に再投入 → parse 成功 + DPS > 0
- これ以上の test pyramid (unit / integration / E2E) は実装計画 phase で詰める。spec には書かない (premature)

## 12. 次のステップ

- 本 spec の user review → 修正 → 確定
- 確定後、`writing-plans` skill で実装計画 (phase 分割、ファイル別タスク、tdd 順序) を起草
