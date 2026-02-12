-- Japanese translations for Passive Skill Tree nodes
-- Source: poe2db.tw/jp (verified 2026-02-13)
-- Tree Version: 0_4 (PoE2)
-- Keys match tree.json English text exactly
return {
    version = "0_4",
    names = {
        -- ========== KEYSTONES (33) ==========
        ["Ancestral Bond"] = "アンセストラルボンド",
        ["Avatar of Fire"] = "アバターオブファイヤー",
        ["Blackflame Covenant"] = "ブラックフレームコヴェナント",
        ["Blood Magic"] = "ブラッドマジック",
        ["Bulwark"] = "バルワーク",
        ["Chaos Inoculation"] = "カオスイノキュレイション",
        ["Conduit"] = "コンジット",
        ["Crimson Assault"] = "クリムゾンアサルト",
        ["Dance with Death"] = "ダンスウィズデス",
        ["Eldritch Battery"] = "エルドリッチバッテリー",
        ["Elemental Equilibrium"] = "エレメンタルイクイリブリアム",
        ["Eternal Youth"] = "エターナルユース",
        ["Giant's Blood"] = "ジャイアントブラッド",
        ["Glancing Blows"] = "グランシングブロウズ",
        ["Heartstopper"] = "ハートストッパー",
        ["Hollow Palm Technique"] = "ホローパームテクニック",
        ["Iron Reflexes"] = "アイアンリフレックス",
        ["Lord of the Wilds"] = "ロードオブザワイルド",
        ["Mind Over Matter"] = "マインドオーバーマター",
        ["Necromantic Talisman"] = "ネクロマンティックタリスマン",
        ["Oasis"] = "オアシス",
        ["Pain Attunement"] = "ペインアチューンメント",
        ["Primal Hunger"] = "プライマルハンガー",
        ["Resolute Technique"] = "レゾリュートテクニック",
        ["Resonance"] = "レゾナンス",
        ["Ritual Cadence"] = "リチュアルケイデンス",
        ["Scarred Faith"] = "スカードフェイス",
        ["Trusted Kinship"] = "トラステッドキンシップ",
        ["Unwavering Stance"] = "アンウェイバリングスタンス",
        ["Vaal Pact"] = "ヴァールパクト",
        ["Whispers of Doom"] = "ウィスパーオブドゥーム",
        ["Wildsurge Incantation"] = "ワイルドサージインカンテーション",
        ["Zealot's Oath"] = "ゼロッツオース",
    },
    stats = {
        -- ========== KEYSTONE STATS ==========
        -- Ancestral Bond
        ["Unlimited number of Summoned Totems"] = "トーテムの最大召喚数の上限がなくなる",
        ["Totems reserve 75 Spirit each"] = "トーテムはそれぞれ75のスピリットをリザーブする",
        -- Avatar of Fire
        ["75% of Damage Converted to Fire Damage"] = "ダメージの75%を火ダメージに変換する",
        ["Deal no Non-Fire Damage"] = "火ダメージ以外のダメージを与えられない",
        -- Blackflame Covenant
        ["Fire Spells Convert 100% of Fire Damage to Chaos Damage"] = "火スペルは火ダメージの100%を混沌ダメージに変換する",
        ["Chaos Damage from Fire Spells Contributes to Flammability and Ignite Magnitudes"] = "火スペルによる混沌ダメージは可燃性と発火の強度に寄与する",
        ["Ignite inflicted with Fire Spells deals Chaos Damage instead of Fire Damage"] = "火スペルによって付与された発火は火ダメージの代わりに混沌ダメージを与える",
        -- Blood Magic
        ["You have no Mana"] = "マナが0になる",
        ["Skill Mana Costs Converted to Life Costs"] = "スキルのマナコストはライフコストに変換される",
        -- Bulwark
        ["Dodge Roll cannot Avoid Damage"] = "ドッジロールはダメージを無効化できない",
        ["Take 30% less Damage from Hits while Dodge Rolling"] = "ドッジロール中は受けるヒットダメージが30%低下する",
        -- Chaos Inoculation
        ["Maximum Life is 1"] = "最大ライフは1になる",
        ["Immune to Chaos Damage and Bleeding"] = "混沌ダメージと出血に完全耐性を得る",
        -- Conduit
        ["If you would gain a Charge, Allies in your Presence gain that Charge instead"] = "チャージを獲得するはずの場合、代わりにプレゼンス内の味方がそのチャージを獲得する",
        -- Crimson Assault
        ["Bleeding you inflict is Aggravated"] = "付与した出血は悪化する",
        ["Base Bleeding Duration is 1 second"] = "出血の基礎持続時間は1秒",
        ["50% more Magnitude of Bleeding you inflict"] = "付与した出血の強度が50%上昇する",
        -- Dance with Death
        ["25% more Skill Speed while Off Hand is empty and you have"] = "オフハンドに何も装備せず、片手武器をメインハンドに装備している時に、スキルスピードが25%上昇する",
        ["a One-Handed Martial Weapon equipped in your Main Hand"] = "",
        ["Cannot use Helmets"] = "兜を使用できない",
        ["Player's Critical Hit Chance is Lucky"] = "プレイヤーのクリティカルヒット率が幸運になる",
        ["Player's Critical Hit Damage is Lucky"] = "クリティカルヒットのダメージが幸運になる",
        ["Enemy Critical Hit Damage against the Player is Lucky"] = "敵のプレイヤーへのクリティカルヒットのダメージが幸運になる",
        -- Eldritch Battery
        ["Converts all Energy Shield to Mana"] = "全てのエナジーシールドをマナに変換する",
        ["Doubles Mana Costs"] = "マナコストが2倍になる",
        -- Elemental Equilibrium
        ["Create Lightning Infusion Remnants instead of Fire"] = "ファイヤーの代わりにライトニングインフュージョンレムナントを生成する",
        ["Create Cold Infusion Remnants instead of Lightning"] = "ライトニングの代わりにコールドインフュージョンレムナントを生成する",
        ["Create Fire Infusion Remnants instead of Cold"] = "コールドの代わりにファイヤーインフュージョンレムナントを生成する",
        -- Eternal Youth
        ["Life Recharges instead of Energy Shield"] = "エナジーシールドの代わりにライフをリチャージする",
        ["50% less Life Recovery from Flasks"] = "フラスコによるライフ回復が50%低下する",
        -- Giant's Blood
        ["You can wield Two-Handed Axes, Maces and Swords in one hand"] = "両手装備の斧、メイスおよび剣を片手に装備できる",
        ["Triple Attribute requirements of Martial Weapons"] = "武器の要求能力値が三倍になる",
        ["Inherent Life granted by Strength is halved"] = "筋力の固有ボーナスとして付与されるライフが半分になる",
        -- Glancing Blows
        ["Chance to Evade is Unlucky"] = "回避率は不運になる",
        ["Chance to Deflect is Lucky"] = "受け流し率は幸運になる",
        -- Heartstopper
        ["Take 50% less Damage over Time if you've started taking Damage over Time in the past second"] = "過去1秒間に継続ダメージを受け始めていれば、受ける継続ダメージが50%低下する",
        ["Take 50% more Damage over Time if you haven't started taking Damage over Time in the past second"] = "過去1秒間に継続ダメージを受け始めていなければ、受ける継続ダメージが50%上昇する",
        -- Hollow Palm Technique
        ["Can Attack as though using a Quarterstaff while both of your hand slots are empty"] = "両手のスロットが空の時クォータースタッフを装備しているかのようにアタックを行える",
        ["Unarmed Attacks that would use your Quarterstaff's damage gain:"] = "クォータースタッフのダメージを使用するとされる素手アタックは以下を獲得する:",
        ["Physical damage based on their Skill Level"] = "スキルレベルに基づく物理ダメージ",
        ["1% more Attack Speed per 75 Item Evasion Rating on Equipped Armour Items"] = "装備中の防具のアイテムの回避力75ごとにアタックスピードが1%上昇する",
        ["+0.1% to Critical Hit Chance per 10 Item Energy Shield on Equipped Armour Items"] = "装備中の防具のアイテムのエナジーシールド10ごとにクリティカルヒット率が+0.1%される",
        -- Iron Reflexes
        ["Converts all Evasion Rating to Armour"] = "全ての回避力をアーマーに変換する",
        -- Lord of the Wilds
        ["You can equip a non-Unique Sceptre while wielding a Talisman"] = "タリスマン装備中にユニーク以外のセプターを装備できるようになる",
        ["50% less Spirit"] = "スピリットが50%低下する",
        ["Non-Minion Skills have 50% less Reservation Efficiency"] = "ミニオン以外のスキルのリザーブ効率が50%低下する",
        -- Mind Over Matter
        ["All Damage is taken from Mana before Life"] = "全てのダメージをライフより先にマナで受ける",
        ["50% less Mana Recovery Rate"] = "マナ自動回復レートが50%低下する",
        -- Necromantic Talisman
        ["All bonuses from Equipped Amulet apply to your Minions instead of you"] = "装備中のアミュレットから得られるボーナスの全てがプレイヤーの代わりにミニオンに適用される",
        -- Oasis
        ["Cannot use Charms"] = "チャームを使用できなくなる",
        ["30% more Recovery from Flasks"] = "フラスコによる回復量が30%上昇する",
        -- Pain Attunement
        ["30% less Critical Damage Bonus when on Full Life"] = "フルライフ状態の時にクリティカルダメージボーナスが30%低下する",
        ["30% more Critical Damage Bonus when on Low Life"] = "低ライフ状態の時にクリティカルダメージボーナスが30%上昇する",
        -- Primal Hunger
        ["100% more Maximum Rage"] = "憤怒の最大値が100%上昇する",
        ["Regenerate 1 Rage per second per 4 Rage spent Recently"] = "直近憤怒を4使用するごとに毎秒憤怒を1自動回復する",
        ["No Rage effect"] = "憤怒の効果がなくなる",
        -- Resolute Technique
        ["Accuracy Rating is Doubled"] = "命中力が二倍になる",
        ["Never deal Critical Hits"] = "クリティカルヒットを与えられなくなる",
        -- Resonance
        ["Gain Power Charges instead of Frenzy Charges"] = "フレンジーチャージの代わりにパワーチャージを獲得する",
        ["Gain Frenzy Charges instead of Endurance Charges"] = "エンデュランスチャージの代わりにフレンジーチャージを獲得する",
        ["Gain Endurance Charges instead of Power Charges"] = "パワーチャージの代わりにエンデュランスチャージを獲得する",
        -- Ritual Cadence
        ["Invocation Skills instead Trigger Spells every 2 seconds"] = "インボケーションスキルは代わりに2秒ごとにスペルをトリガーする",
        ["Invocation Skills cannot gain Energy while Triggering Spells"] = "インボケーションスキルはスペルをトリガー中はエネルギーを獲得できない",
        ["Invoked Spells consume 50% less Energy"] = "インボケーションされたスペルが消費するエネルギーが50%低下する",
        -- Scarred Faith
        ["5% of Physical Damage prevented Recouped as Energy Shield per enemy Power"] = "敵のパワーごとに防いだ物理ダメージの5%をエナジーシールドとして回収する",
        ["Energy Shield does not Recharge"] = "エナジーシールドはリチャージしなくなる",
        ["You cannot Recover Energy Shield from Regeneration"] = "自動回復によりエナジーシールドを回復できなくなる",
        ["You cannot Recover Energy Shield to above Armour"] = "エナジーシールドをアーマーを超えて回復できなくなる",
        -- Trusted Kinship
        ["You can have two Companions of different types"] = "異なる種類の2体のコンパニオンを使役できる",
        ["You have 30% less Defences"] = "防御力が30%低下する",
        ["Companions have +1 to each Defence for every 2 of that Defence you have"] = "プレイヤーが持つ防御力2ごとにコンパニオンの同じ防御力がそれぞれ+1される",
        -- Unwavering Stance
        ["Cannot be Light Stunned"] = "ライトスタンを受けることがなくなる",
        ["Cannot Dodge Roll or Sprint"] = "ドッジロールまたはスプリントができなくなる",
        -- Vaal Pact
        ["Life Leech is Instant"] = "ライフリーチが即時になる",
        ["Cannot use Life Flasks"] = "ライフフラスコを使用できなくなる",
        -- Whispers of Doom
        ["You can apply an additional Curse"] = "追加の呪いを付与できる",
        ["Double Activation Delay of Curses"] = "呪いのアクティベーション遅延が二倍になる",
        -- Wildsurge Incantation
        ["Storm and Plant Spells:"] = "ストームおよびプラントスペル:",
        ["deal 50% more damage"] = "ダメージが50%上昇する",
        ["cost 50% less"] = "コストが50%低下する",
        ["have 75% less duration"] = "持続時間が75%低下する",
        -- Zealot's Oath
        ["Excess Life Recovery from Regeneration is applied to Energy Shield"] = "自動回復によるライフ回復超過分はエナジーシールドに適用される",
    },
}
