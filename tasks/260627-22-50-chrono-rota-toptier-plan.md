---
kind: build-advice
topic: Chrono_RotA を sample 水準（トップティア）に引き上げる具体ビルドプラン
date: 2026-06-27
builds:
  current: ~/Library/Application Support/Path of Building/Builds/Chrono_RotA.xml (Lv96)
  sample:  ~/Library/Application Support/Path of Building/Builds/sample.xml (Lv97)
ascendancy: Disciple of Varashta (Sorceress) — Navira/Water Djinn 主火力
---

# 診断
- ナヴィラの破砕 ヒットDPS: 現状 151,802 / sample 1,298,012 = **8.55x**（平均ダメージ 6.87x、速度 1.24x）。GUI/calc 一致確認済み。
- 差の主因は **ミニオンのクリティカル**: クリ率 32.4%→60.96%、**クリ倍率 2.7→6.47**。
- ミニオンスキルレベルは両方 **+12 で同一**（ここは差ではない）。
- ジュエルソケット: 現状 [7960,21984,61419] 3枠、sample [7960,21984,26196,61419] 4枠。

# 装備差分（slot 別）
| slot | 現状 | sample(トップティア) | 要点 |
|---|---|---|---|
| Jewel 7960 | Blight Shine (Sapphire) | **From Nothing (Diamond)** | Conduit範囲を接続なし取得 |
| Jewel 21984 | Vivid Stone (Sapphire) | **Brood Creed (Time-Lost Sapphire)** | 範囲内notableに ミニオンクリダメ+14%/クリ率+12% |
| Jewel 61419 | Armageddon Essence (Sapphire) | **Eagle Vessel (Time-Lost Sapphire)** | 同上 + notable効果+25% |
| Jewel 26196 | 未取得 | **Megalomaniac (Diamond)** | 4枠目を増設 |
| Ring1 | Evergrasping Ring (unique) | **Behemoth Twirl (Breach Ring, rare)** | ミニオンダメ/クリ rare |
| Ring2 | Evergrasping Ring (unique) | **Kalandra's Touch** | 反対指輪mod複製→Behemoth二重化 |
| Amulet | Rift Clasp (Wolf Pack/rarity) | **Beast Medallion** | +4 minion lv, ミニオン28% CDR |
| Helmet | Rune Visage | **Brood Crest** | +2 minion lv, Gigantic Following |
| Belt | Loath Lash (minion life) | **Headhunter** | 周回(レアmod奪取) |
| Body | Grim Curtain | Demon Carapace (916 ES) | ES↑ |
| Weapon1 | Behemoth Breaker (Sceptre) | **Victory Breaker (Sceptre)** | global ミニオン倍率厚い |
| Weapon2 | Empyrean Call (Focus) | Storm Refuge (Focus) | ES↑ |

# スキル(support)差分 — メインのナヴィラ群
- 現状: Navira + Bidding III / Hulking Minions / Encroaching Ground / Frost Nexus / Muster
- sample: Navira + Bidding II / Frost Nexus / Muster / **Tul's Stillness** / **Rakiata's Flow**(=「ラキアタ」)
- → 生存寄りの Hulking Minions 等を **Rakiata's Flow + Tul's Stillness** に入替（純DPS support）。

# パッシブ
- 現状150ノード(keystone: CI + Whispers of Doom) / sample **129ノード**(CIのみ)。少ないノードで上位DPS = Time-Lostジュエルが各notableを増幅 + Megalomaniac/From Nothing の押し上げ。
- sample はコールド/クリ寄りクラスタ: Brain Freeze, Brain Storm, Heavy Frost, Harsh Winter, Thin Ice, Frozen Limit, Storm Driven, Shattered Crystal, Ice Walls。
- Whispers of Doom(2カース目)は sample 不採用 → 現状の Blasphemy+Temporal Chains+Despair 二重カースは整理候補。

# 防御
- 三耐性 55/66/59(未キャップ) → **75/75/75キャップ(overcap)**。ES 7,530→12,000+。EHP 16k→29k。両方 CI。

# 優先度順アクション（コスパ順）
- **P0 ジュエル**: 21984/61419 の通常Sapphire→Time-Lost Sapphire(ミニオンクリダメ/クリ率 notable変換)。半径Very Largeをミニオンnotable密集帯へ。socket 26196 を増設し4枠目。← クリ倍率/率の桁違い差の源。最大効果。
- **P1 主スキルsupport**: ナヴィラ群に Rakiata's Flow + Tul's Stillness を投入。
- **P2 指輪**: Behemoth Twirl(rare) + Kalandra's Touch で二重化。
- **P3 アミュ/兜**: +minion lv & ミニオンCDR付きへ(攻撃速度0.54→0.67はCDR由来)。
- **P4 防御**: 耐性キャップ→ES底上げ。火力より先。
- **P5 ツリー**: コールド/クリクラスタへ寄せ、汎用notable整理、Whispers of Doom外す。

# 検証 — subtractive 帰属（sample から1レバーずつ current に戻す）
**加算ラダー(current + sample 部品)は撤回**: piecewise 移植は Time-Lost ジュエル×ツリー notable の**共設計を破壊**し、ツリーを ~0 と誤報告した(plan-doc 内で test T と符号矛盾していた)。代わりに**実 sample(検証済み 1,298,012)から1レバーだけ current に戻し、低下幅 = そのレバーの真の限界寄与**を測る。戻す slot だけが `parseItems` を通り、戻す item は baked ロール値を持つので faithful(`mcp/worker/construct_toptier.lua`)。交互作用があるため各行は加算不可（「完成形からそれ1つだけ戻したら失う量」）。

| 戻すレバー(→current) | MinionDPS | 低下幅 | クリ率 | クリ倍率 | EHP | 耐性 |
|---|---|---|---|---|---|---|
| **0 SAMPLE(target)** | **1,298,012** | — | 61.0 | 6.47 | 29,666 | 75/75/75 |
| Time-Lost ジュエル → plain Sapphire | 589,008 | **−709k (−55%)** | 34.2 | 3.75 | 25,100 | 75/75/75 |
| amulet/helm/weapon → current | 805,094 | **−493k (−38%)** | 65.0 | 6.08 | 20,599 | **38/75/39** |
| 指輪 → Evergrasping×2 | 812,289 | **−486k (−37%)** | 48.0 | 5.51 | 29,666 | 75/75/75 |
| supports (Rakiata's Flow を外す¹) | 614,848 | **−683k (−53%)** | 61.0 | 6.47 | — | — |
| From Nothing → Blight Shine | 916,501 | **−382k (−29%)** | 48.8 | 5.11 | 25,503 | 75/75/75 |
| ツリー → current (test T) | 953,882 | **−344k (−27%)** | 46.0 | 4.90 | **42,414** | 75/75/75 |

¹ supports 行は「Rakiata's Flow を**空ソケットに**外す」であって current の support gem に**戻していない**ので、対 current の真の差はこれより小さい(apples-to-apples でない)。それでも Rakiata's Flow 単体が ~53% の乗数を持つ大レバーであることは確か。

**読み筋**:
- **Time-Lost ジュエル(−55%)が最大の単体レバー** — クリ率/倍率を一気に崩す(61→34, 6.47→3.75)。ただし下のツリーと**共設計**(ジュエルが変換器、ツリーが変換される notable を供給)。
- **ツリー(−27%)は決定的レバーだが防御トレード**: current ツリーに戻すと DPS は落ちるが EHP は 29,666→**42,414 に上昇**。sample のツリーは EHP を削ってクリ密度を買っている。
- **amulet/helm/weapon(−38%)は火力と防御を兼ねる** — 戻すと耐性が Fire 75→38/Lightning 75→39 に崩落。火力単独レバーではない。
- **指輪(−37%)は純火力**(EHP 不変)。From Nothing ジュエル(−29%)も純火力寄り。

**⚠️ 訂正履歴(2026-06-27)**: 当初「ツリーはレバーでない」と誤結論した根拠(加算移植 867k→838k 微減)は**交絡**(移植ジュエルが `<ModRange>` 過小ロール → radius 内 notable が薄く効かず)。実ロール(test T)ではツリーは決定的。加算ラダー自体を撤回し subtractive に置換済み。

**機構(Time-Lost Sapphire × ツリー notable 密集の共設計)**:
- Brood Creed / Eagle Vessel(共に Time-Lost Sapphire, **Radius: Very Large**)の核 mod:
  - `Notable Passive Skills in Radius also grant Minions have 14% increased Critical Damage Bonus`
  - `Notable Passive Skills in Radius also grant Minions have 12% increased Critical Hit Chance`
  - `25% increased Effect of Notable Passive Skills in Radius`
- → **radius 内の notable 1個ごとにミニオンクリダメ+14%/クリ率+12%**。sample のツリーは 21984/61419 ソケット周辺の Very Large radius に notable を密集させてクリを最大化する設計。current ツリーはこの密集がなく、同じジュエルでもクリ率61→46/倍率6.47→4.90 に崩れる。
- **トップティア化の本丸 = Time-Lost ジュエル + ソケット radius に notable を詰めたツリー設計**。ジュエル単体でもツリー単体でもなく両者の積。

# 構築 — reference 超え（sample のツリーは point-optimal ではない）
**「人間より速く構築」の本命: in-radius notable レバー**。sample は tree points を 121 使用。socket 61419(Eagle Vessel)の radius には **未割当 notable が 16個**ある。各 notable は**割り当てるだけ**で Time-Lost mod(+14%クリダメ/+12%クリ率)が乗る — notable 自身の stat は無関係。

**前提(使用条件)**: PoE2 0.5 のポイント予算 = (level−1) + quest23(+bandit1)。121点 = キャラ Lv ~99(96+23 = 119 は L97、bandit 込みで 120)、つまり sample/B どちらも **実質 Lv 99-100 を前提**にした構成。Lv97 で組むなら 1-2 点を別所から捻出する必要がある(下表の B は used=120 なので L99 相当)。

実測(`mcp/worker/net_swap*.lua`): どの候補も単独で同じ **+61,435(+4.7%)**、crit 61→62.8、EHP 不変。利得が notable の中身でなく Time-Lost 変換から来ている証明。最安は Ice Storm/Lightning Storm/Empowering Remnants の **3 ポイント**。

予算超過を避けるため **net-0 ポイント**で検証(radius 外の死にポイントを dealloc → in-radius notable を alloc、`used ≤ 121` 維持):

| 構成 | MinionDPS | net | クリ率 | クリ倍率 | EHP | 耐性 | used |
|---|---|---|---|---|---|---|---|
| sample(参照) | 1,298,012 | — | 61.0 | 6.47 | 29,666 | 75/75/75 | 121 |
| +1 notable (Int 11248→Ice Storm) | 1,359,447 | **+4.7%** | 62.8 | 6.64 | 29,666 | 75/75/75 | 121 |
| +2 (…→Lightning Storm) | 1,422,714 | **+9.6%** | 64.6 | 6.81 | 29,666 | 75/75/75 | 120 |
| +3 (…→Empowering Remnants) | **1,487,814** | **+14.6%** | 66.4 | 6.98 | 29,666 | 75/75/75 | 120 |

- dealloc 標的(Int 11248 / Minion Area 45343 / Puppet Master chance 53795)は **この単一指標(ボス単体ミニオン hit DPS)に対しては** 寄与ゼロ(各々単独 dealloc で net 正)。ただし「死にポイント」は**ボス単体 DPS 限定の意味**であり、グローバルに無価値ではない: **Minion Area 45343 = AoE/周回速度**、**Puppet Master chance 53795 = proc/ユーティリティ**を犠牲にする。トップティア sample がこれらを取っていた理由がここ。Int 11248 のみ純粋に DPS 寄与ゼロ。Minion Life(40894)は DPS 寄与あり(net −23k)なので標的不適。
- スタッキングは crit 66% でまだ**ほぼ線形**(逓減せず)。さらに進めると (a) dealloc 標的が値を持ち始め (b) crit がキャップに近づくため逓減する見込み。安全圏は ~3 notable。
- **結論: sample のツリーはボス単体 DPS では最適化余地あり**。3点を socket 61419 radius の notable へ移すだけで **+14.6%(ボス単体ミニオン hit DPS)を同ポイント・同 EHP(29,666)・全耐性キャップ(75/75/75)で**達成。**トレードは clear 速度/ユーティリティ proc**(Minion Area + Puppet Master chance を手放す)。ボス特化なら純益、汎用周回ビルドなら Int 11248 の 1 点だけ移すのが安全。calc 実測 + import code round-trip 検証済み。

**成果物(import code, PoB GUI に貼付可)**:
- A `scratchpad/upgraded_chrono_rota.code` = sample 構成(= 1,298,012、現状 Chrono_RotA の 8.55x)。current → トップティアの到達点。
- B `scratchpad/beyond_reference_chrono_rota.code` = **A + 上記3スワップ = 1,487,814(+14.6%)**。reference を超えた構築版。
- **round-trip 検証済み(`mcp/worker/roundtrip_verify.lua`)**: 両 .code を decode→XML→BuildOutput で再測 → A=1,298,012 / B=1,487,814 を**厳密一致で再現**(exportCode が live spec でなく元 XML をシリアライズする失敗モードが無いことを確認)。import すれば申告 DPS がそのまま出る。

**結論(構築で判明したこと)**:
- **harness 検証済み**: sample.xml 直接測定 = GUI の 1,298,012 を小数まで一致。MCP/calc エンジンは信頼できる(=この基盤でビルド構築・最適化が可能)。
- **ギャップの正体はクリティカル**、その源は **Time-Lost ジュエル × ツリー notable 密集の共設計**(subtractive 帰属: ジュエル −55%/ツリー −27% が確定)。
- **防御の決定(確定)**: current の Body/Focus/Belt は +8.3% DPS を生むが EHP を半減(29,666→16,203)し Fire 脱キャップ(75→55)。CI ピナクル用には割に合わず **sample の防御スロットを維持**。test S の「current 装備の方が高火力」は実在するが**採用不可**。
- **reference 超え = in-radius notable 再配分**(上表)。装備/ジュエルは sample が既にほぼ最適、伸び代はツリーのポイント配分にあった。
- **観察ツールの構造的欠陥 → 改善済み(2026-06-27)**: 当初ツリーを軽視したのは、私の観察手段が (a) item の mod(ロール反映後の実値)を見ていない、(b) 各ジュエル socket の radius 内 notable 数/種別を見ていない、(c) allocated notable 名を見ていない、ため。**`build_info` に 2 surface を追加して解消**:
  - `passives.jewelSockets`: socket 毎に `{jewel, base, radius, notableCount, totalAllocInRadius, totalInRadius, notables[]}`。Time-Lost の radius 内 **allocated** notable 数を engine-resolved (`spec.nodes[id].nodesInRadius[item.jewelRadiusIndex]`) から `spec.allocNodes` で filter して surface。再パース不要。
    - **重要(2回目の訂正)**: `nodesInRadius` は **geometric**(radius 内の全 notable)。alloc filter を掛けないと sample/current ツリーで同じ ~20 になり、**ツリーのレバー効果(test T)が不可視**になる(geometric が −26.5% を隠す)。「Notable in Radius also grant」は **allocated notable のみ**に発火するので `spec.allocNodes[nodeId]` filter が必須。
  - `items[].mods`: item 毎の解決済み mod テキスト `{kind, text}`（通常 load では `modLine.line` がロール反映後の実値を持つ）。
  - (c) notable 名は既存 `passives.notables` で surface 済み。
  - **検証(受け入れテスト)**: 両ビルド + test T(sample ジュエル + current ツリー)に新 build_info を当て、差分が予備知識なしで legible:
    | | Time-Lost が変換する allocated notable | クリ変換 |
    |---|---|---|
    | TOP-TIER(sample ツリー) | 12+4 = **16** | +224% クリダメ / +192% クリ率 |
    | test T(同ジュエル + current ツリー) | 3+2 = **5** | +70% / +60% |
    | CURRENT(plain Sapphire) | **0** | 0 |
    - → 同じジュエルでツリーだけ current にすると変換 notable が 16→5(−69%)。これがクリ 61→46/倍率 6.47→4.90(−26.5% DPS)の正体を一目で説明。geom totalInRadius は 91/101 で、alloc filter が効いている証拠。`mcp/server/test/build-info.test.ts` で回帰固定(fixture: `golden_toptier_build.xml`、socket 21984→12/61419→4 を pin)。
- 注: 起動中の MCP サーバープロセスは旧コード(編集前)。検証はディスク最新 calc.lua の直接 luajit で実施。
  MCP 経由で minion DPS を使うには Claude Code 再接続でサーバー再起動が要る(コミット後)。
