import json, re, os, html, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tree_svg as TS
from collections import Counter, OrderedDict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
CFG = json.load(open(sys.argv[1], encoding='utf-8'))
OLD = os.path.join(REPO, CFG['prose_html'])
OUT = os.path.join(REPO, CFG['out_html'])
ASSET_ABS = os.path.join(REPO, CFG['asset_dir'])
ASSET_DIR = os.path.relpath(ASSET_ABS, os.path.dirname(OUT))
SRC_URL = CFG['url']

doc = json.load(open(os.path.join(ASSET_ABS, 'doc.json'), encoding='utf-8'))
CDN = 'https://cdn.mobalytics.gg/assets/poe-2/images/game/'
def local(u):
    if not u:
        return None
    p = u.split('/images/game/')[-1] if '/images/game/' in u else u.split('/assets/')[-1]
    p = p.split('?')[0]
    f = re.sub(r'[^A-Za-z0-9._-]', '_', p)
    if not os.path.exists(os.path.join(ASSET_ABS, f)) and f.endswith('.avif'):
        f = f[:-5] + '.webp'
    if not os.path.exists(os.path.join(ASSET_ABS, f)):
        return None
    return ASSET_DIR + '/' + f

def img(u, cls='ic', alt=''):
    l = local(u)
    if not l:
        return '<span class="%s ph"></span>' % cls
    return '<img class="%s" src="%s" alt="%s" loading="lazy">' % (cls, l, html.escape(alt, quote=True))
tree = open(REPO + '/src/TreeData/0_5/tree.lua').read()
ti = tree.find('\n\tnodes={')
NODES = {}
for m in re.finditer(r'\[(\d+)\]=\{(.*?)\n\t\t\},', tree[ti:], re.S):
    b = m.group(2)
    n = re.search(r'name="([^"]*)"', b)
    if not n:
        continue
    ic = re.search(r'icon="([^"]*)"', b)
    st = b.split('stats={')[1] if 'stats={' in b else ''
    NODES[m.group(1)] = {
        'name': n.group(1),
        'icon': CDN + ic.group(1).replace('.dds', '.webp') if ic else None,
        'notable': 'isNotable=true' in b,
        'keystone': 'isKeystone=true' in b,
        'ascstart': 'isAscendancyStart' in b,
        'stats': re.findall(r'\[\d+\]="([^"]*)"', st.split('\n\t\t\t}')[0]),
        'stringId': (re.search(r'stringId="([^"]*)"', b) or [None, None])[1],
    }
BY_STRINGID = {v['stringId']: v for v in NODES.values() if v['stringId']}
TNODES, TRADII = TS.parse_tree(REPO + '/src/TreeData/0_5/tree.lua')
TREE_BASE = TS.base_layer(TNODES, TRADII)
FULL_VB = TS.bbox(TNODES, [nid for nid, n in TNODES.items() if not n['asc']], pad=800)
GEMS = {}
GEM_SPIRIT = set()
cur = None; curtags = False
for line in open(REPO + '/src/Data/Gems.lua', encoding='utf-8'):
    m = re.match(r'\s*name = "(.*)",', line)
    if m:
        cur = m.group(1)
    m = re.match(r'\s*grantedEffectId = "(.*)",', line)
    if m and cur:
        GEMS.setdefault(m.group(1).lower(), cur)
        lastge = m.group(1).lower()
    if cur and re.match(r'\s*persistent = true', line):
        GEM_SPIRIT.add(cur)

def gem_name(slug):
    return GEMS.get(slug.lower(), slug)
sys.path.insert(0, HERE)
import ja_locale as L

def dual(ja, en, cls='en'):
    if not ja or ja == en:
        return html.escape(en)
    return '%s <small class="%s">%s</small>' % (html.escape(ja), cls, html.escape(en))

def T(line):
    return L.translate(line)

def item_disp(ci):
    return dual(L.item_name(ci['name'], bool(ci.get('isUnique'))), ci['name'])

def node_disp(name):
    return dual(L.node_name(name), name)

def gem_disp(name):
    return dual(L.gem_name(name), name)

def rune_disp(en):
    return dual(L.BASE.get(en), en)
RUNES = CFG.get('runes') or {}
ANOINTS = CFG.get('anoints') or {}
def anoint_icon(slug):
    sid = slug.replace('anointment-', '')
    n = BY_STRINGID.get(sid)
    if not n:
        for v in NODES.values():
            if v['name'] == ANOINTS.get(slug):
                n = v; break
    return n['icon'] if n else None
WIDGETS = {}
def walk_widgets(o):
    if isinstance(o, dict):
        if o.get('type') == 'static-data-widget' and o.get('icon') and o.get('label'):
            WIDGETS.setdefault(o['label'].strip(), o['icon'])
        for v in o.values():
            walk_widgets(v)
    elif isinstance(o, list):
        for v in o:
            walk_widgets(v)
walk_widgets(doc)
VARS = OrderedDict()
byid = {c['id']: c for c in doc['content']}
vdata = {v['id']: v for v in doc['data']['buildVariants']['values']}
JA_TITLES = CFG.get('variant_titles_ja') or {}
VARIANT_BLOCK = next(c for c in doc['content'] if c['__typename'] == 'NgfDocumentCmWidgetContentVariantsV1')
for i, var in enumerate(VARIANT_BLOCK['data']['childrenVariants']):
    VARS[var['id']] = {'idx': i + 1, 'title': var['title'], 'ja': JA_TITLES.get(var['title'], var['title']), 'data': vdata[var['id']]}
OLD_IDS = ['v%d' % (i + 1) for i in range(len(VARS))]
old = open(OLD, encoding='utf-8').read()
def section(idname):
    m = re.search(r'<h2 id="%s">.*?</h2>(.*?)(?=<h2 id=|</main>|</body>)' % idname, old, re.S)
    r = m.group(1).strip() if m else ''
    return re.sub(r'</ul>\s*</div>\s*$', '</ul>', r)

def strip_tables(s):
    s = re.sub(r'<h4>掲載アイテム例</h4>\s*', '', s)
    s = re.sub(r'<div class="tbl">.*?</table></div>\s*', '', s, flags=re.S)
    s = re.sub(r'<p class="m">(装備優先順|必要ステータス)[^<]*</p>\s*', '', s)
    s = re.sub(r'<!--.*?-->', '', s, flags=re.S)
    return s.strip()

def split_variant(sec):
    parts = re.split(r'<h3>(装備|スキルジェム[^<]*|パッシブツリー)</h3>', sec)
    out = {'intro': parts[0].strip(), 'equip': '', 'gems': '', 'passive': '', 'gems_title': ''}
    for k in range(1, len(parts), 2):
        key = parts[k]
        body = parts[k + 1]
        if key == '装備':
            out['equip'] = strip_tables(body)
        elif key.startswith('スキルジェム'):
            out['gems'] = strip_tables(body)
            out['gems_title'] = key
        else:
            jew = re.search(r'<li>ジュエル[^<]*</li>', body)
            out['jewel'] = jew.group(0)[4:-5] if jew else ''
            asc = re.search(r'<li>アセンダンシー: データ上は[^<]*</li>', body)
            out['asc_note'] = asc.group(0)[4:-5] if asc else ''
            body = re.sub(r'<ul>.*?</ul>', '', body, flags=re.S)
            out['passive'] = strip_tables(body)
    return out

PROSE = {}
for vid, oid in zip(VARS, OLD_IDS):
    PROSE[vid] = split_variant(section(oid))

overview_html = section('overview')
overview_html = re.sub(r'<h3 id="([^"]*)">\d+\.\d+ ', r'<h3 id="\1">', overview_html)
sw_html = section('sw')
sw_lists = re.findall(r'<ul>(.*?)</ul>', sw_html, re.S)
quest_html = section('quest')
quest_extra = re.sub(r'<div class="tbl">.*?</table></div>\s*', '', quest_html, flags=re.S).strip()
faq_html = section('faq')
changelog_html = section('changelog')
notes_html = section('notes')
ICONS = {}
def add_icon(name, url):
    if name and url and name not in ICONS:
        ICONS[name] = url
for k, v in WIDGETS.items():
    add_icon(k, v)
for v in vdata.values():
    sg = v.get('skillGems') or {}
    for g in sg.get('gems') or []:
        add_icon(g['activeSkill']['name'], g['activeSkill']['iconURL'])
        for s in g.get('subSkills') or []:
            add_icon(gem_name(s['gemSlug']), s['iconURL'])
    for p in sg.get('priorityGems') or []:
        add_icon(p['name'], p['iconURL'])
    eq = v.get('equipment') or {}
    def items_of(eq):
        for k, slot in eq.items():
            if not isinstance(slot, dict):
                continue
            if 'commonItem' in slot:
                yield slot
            for ws in ('set1', 'set2'):
                if isinstance(slot.get(ws), dict) and slot[ws].get('commonItem'):
                    yield slot[ws]
    for it in items_of(eq):
        ci = it['commonItem']
        if ci.get('isUnique'):
            add_icon(ci['name'], ci['iconURL'])
    pt = v.get('passiveTree') or {}
    for key in ('mainTree', 'ascendancyTree'):
        for p in ((pt.get(key) or {}).get('priorityList') or []):
            add_icon(p['name'], p['iconURL'])
for n in NODES.values():
    if (n['notable'] or n['keystone']) and n['icon']:
        add_icon(n['name'], n['icon'])
GENERIC = {'Energy Shield', 'Minion Damage', 'Attribute', 'Spell Damage', 'Elemental Damage', 'Minion Life', 'Life', 'Mana', 'Armour', 'Evasion', 'Spirit', 'Intelligence', 'Strength', 'Dexterity', 'Cast Speed', 'Attack Speed', 'Fire Penetration', 'Damage', 'Cold', 'Fire', 'Lightning', 'Chaos', 'Physical', 'Cooldown Recovery', 'Melee', 'Focus', 'Charm', 'Shield', 'Amulet', 'Ring', 'Belt', 'Boots', 'Gloves', 'Helmet', 'Body Armour', 'Sceptre', 'Crossbow', 'Talisman', 'Jewel Socket', 'Minion Area', 'Command Skill Damage', 'Command Skill Cooldown', 'Archon Effect', 'Archon Duration', 'Archon Delay', 'Minion Critical Chance', 'Minion Critical Damage', 'Minion Attack and Cast Speed', 'Stun Threshold from Energy Shield', 'Stun and Ailment Threshold from Energy Shield', 'Energy Shield and Mana Regeneration', 'Minion Damage and Command Speed', 'Spell and Minion Damage', 'Damage against Ailments', 'Elemental Ailment Chance', 'Spell Critical Chance', 'Spell Critical Damage', 'Minion Damage and Command Skill Cooldown', 'Armour and Energy Shield', 'Energy Shield and Armour applies to Elemental Damage Hits', 'Chaos Inoculation'}
for g in GENERIC:
    ICONS.pop(g, None)
add_icon('Chaos Inoculation', next((n['icon'] for n in NODES.values() if n['name'] == 'Chaos Inoculation' and n['keystone']), None))
ICONS = {k: v for k, v in ICONS.items() if local(v)}
ICON_NAMES = sorted(ICONS, key=len, reverse=True)
ICON_RE = re.compile(r'(?<![A-Za-z\'])(' + '|'.join(re.escape(n) for n in ICON_NAMES) + r')(?![A-Za-z])')

def ent(name):
    return '<span class="ent">%s%s</span>' % (img(ICONS[name], 'ei', name), html.escape(name))

def iconize(fragment):
    out = []
    depth_code = 0
    depth_a = 0
    for tok in re.split(r'(<[^>]+>)', fragment):
        if tok.startswith('<'):
            t = tok.lower()
            if t.startswith('<code'): depth_code += 1
            elif t.startswith('</code'): depth_code -= 1
            elif t.startswith('<a '): depth_a += 1
            elif t.startswith('</a'): depth_a -= 1
            out.append(tok)
        else:
            if depth_code or depth_a or not tok.strip():
                out.append(tok)
            else:
                out.append(ICON_RE.sub(lambda m: ent(m.group(1)), tok))
    s = ''.join(out)
    ENT = r'(<span class="ent">(?:<img[^>]*>|<span[^>]*></span>)[^<]*</span>)'
    s = re.sub(r'<strong>' + ENT + r'</strong>', r'\1', s)
    s = re.sub(r'<span class="uniq">' + ENT + r'</span>', r'\1', s)
    return s
SLOT_JA = {'mainHand': 'メインハンド', 'offHand': 'オフハンド', 'helmet': 'ヘルメット', 'body': 'ボディアーマー', 'gloves': 'グローブ', 'boots': 'ブーツ', 'amulet': 'アミュレット', 'leftRing': 'リング (左)', 'rightRing': 'リング (右)', 'belt': 'ベルト', 'flask1': 'フラスコ 1', 'flask2': 'フラスコ 2', 'charm1': 'チャーム 1', 'charm2': 'チャーム 2', 'charm3': 'チャーム 3', 'extraRing': 'リング (追加)'}
DOLL_ORDER = ['mainHand', 'offHand', 'helmet', 'body', 'gloves', 'boots', 'amulet', 'leftRing', 'rightRing', 'belt', 'flask1', 'flask2', 'charm1', 'charm2', 'charm3']

def item_of(eq, slot, ws):
    s = eq.get(slot)
    if not isinstance(s, dict):
        return None
    if slot in ('mainHand', 'offHand'):
        s = s.get(ws)
        if not isinstance(s, dict):
            return None
    return s if s.get('commonItem') else None

def prio_map(eq):
    m = {}
    for i, p in enumerate(eq.get('priorityList') or []):
        m.setdefault((p['type'], p['slug']), i + 1)
    return m

def item_tip(it, slot):
    ci = it['commonItem']
    cls = 'unique' if ci.get('isUnique') else 'rare'
    rows = []
    rows.append('<div class="tt-head %s"><div class="tt-name">%s</div><div class="tt-base">%s</div></div>' % (cls, item_disp(ci), html.escape(SLOT_JA.get(slot, slot))))
    stats = [s for s in (ci.get('stats') or []) if s.get('value') not in (None, 0, '0')]
    if stats:
        rows.append('<div class="tt-sec">' + ''.join('<div class="tt-stat">%s: <b>%s</b></div>' % (html.escape(L.stat_label(str(s['name']))), html.escape(str(s['value']))) for s in stats) + '</div>')
    mods = [d['description'] for d in (ci.get('explicitDescriptions') or []) if d.get('description')]
    if mods:
        rows.append('<div class="tt-sec">' + ''.join('<div class="tt-mod" title="%s">%s</div>' % (html.escape(m, quote=True), html.escape(T(m))) for m in mods) + '</div>')
    runes = it.get('runes') or []
    if runes:
        rows.append('<div class="tt-sec">' + ''.join('<div class="tt-rune"><span class="rune-b">R</span>%s</div>' % rune_disp(RUNES.get(r['slug'], r['slug'])) for r in runes) + '</div>')
    an = it.get('anointment')
    if an and an.get('slug'):
        nm = ANOINTS.get(an['slug'], an['slug'])
        rows.append('<div class="tt-sec"><div class="tt-anoint">%s アノイント: <b>%s</b></div></div>' % (img(anoint_icon(an['slug']), 'ei', nm), node_disp(nm)))
    if not stats and not mods and not runes and not an:
        rows.append('<div class="tt-sec tt-empty">掲載モッドなし (ベースのみ)</div>')
    return ''.join(rows)

def doll(eq, ws, pm):
    cells = []
    for slot in DOLL_ORDER:
        it = item_of(eq, slot, ws)
        if it:
            ci = it['commonItem']
            key = ('mainHand' if slot in ('mainHand', 'offHand') and slot == 'mainHand' else slot, ci['slug'])
            pr = pm.get((slot, ci['slug'])) or pm.get(('mainHand', ci['slug'])) or pm.get(('offHand', ci['slug']))
            cls = 'slot s-%s filled%s' % (slot, ' uq' if ci.get('isUnique') else '')
            cells.append('<div class="%s" tabindex="0" data-tip="%s">%s%s<span class="slot-lbl">%s</span></div>' % (
                cls, html.escape(item_tip(it, slot), quote=True), img(ci['iconURL'], 'slot-img', ci['name']),
                ('<span class="badge">%d</span>' % pr) if pr else '', html.escape(SLOT_JA[slot])))
        else:
            cells.append('<div class="slot s-%s empty"><span class="slot-lbl">%s</span></div>' % (slot, html.escape(SLOT_JA[slot])))
    return '<div class="doll">' + ''.join(cells) + '</div>'

def item_cards(eq, ws, pm):
    cards = []
    for slot in DOLL_ORDER:
        it = item_of(eq, slot, ws)
        if not it:
            continue
        ci = it['commonItem']
        pr = pm.get((slot, ci['slug'])) or pm.get(('mainHand', ci['slug'])) or pm.get(('offHand', ci['slug']))
        cards.append('<div class="icard%s"><div class="icard-ic">%s%s</div><div class="icard-body">%s</div></div>' % (
            ' uq' if ci.get('isUnique') else '', img(ci['iconURL'], 'icard-img', ci['name']),
            ('<span class="badge">%d</span>' % pr) if pr else '', item_tip(it, slot)))
    return '<div class="icards">' + ''.join(cards) + '</div>'

def equipment_block(vid):
    v = VARS[vid]['data']
    eq = v.get('equipment')
    pr = PROSE[vid]
    out = []
    if not eq:
        out.append('<div class="warn">🚧 <strong>WIP</strong> — 原文サイト上でもまだ執筆中で、装備データは未登録。</div>')
        if pr['equip']:
            out.append(iconize(pr['equip']))
        return ''.join(out)
    pm = prio_map(eq)
    has2 = bool(item_of(eq, 'mainHand', 'set2') or item_of(eq, 'offHand', 'set2'))
    out.append('<div class="setbar"><button class="setbtn on" data-set="set1">武器セット 1</button><button class="setbtn" data-set="set2">武器セット 2%s</button></div>' % ('' if has2 else ' <small>(データなし)</small>'))
    for ws in ('set1', 'set2'):
        out.append('<div class="setpane" data-set="%s"%s>' % (ws, '' if ws == 'set1' else ' hidden'))
        if ws == 'set2' and not has2:
            out.append('<div class="note">このバリアントでは武器セット 2 の武器が元データに登録されていない。防具・装飾品はセット 1 と共通。</div>')
        out.append(doll(eq, ws, pm))
        out.append('<h4 class="sub">アイテム詳細</h4>')
        out.append(item_cards(eq, ws, pm))
        out.append('</div>')
    pl = [p for p in (eq.get('priorityList') or []) if not p.get('isExcluded')]
    if pl:
        out.append('<div class="prio"><div class="prio-h">装備優先度</div><div class="prio-row">' + ''.join(
            '<div class="prio-it" title="%s"><span class="pnum">%d</span>%s<span class="pname">%s</span></div>' % (html.escape(p['name'], quote=True), i + 1, img(p['iconURL'], 'pic', p['name']), dual(L.BASE.get(p['name']) or L.UNIQ.get(p['name']), p['name'])) for i, p in enumerate(pl)) + '</div></div>')
    if pr['equip']:
        out.append('<div class="prose">' + iconize(pr['equip']) + '</div>')
    return ''.join(out)
def subst_gem_name(name):
    for k, v in (CFG.get('gem_name_subst') or {}).items():
        name = name.replace(k, v)
    return name

def gems_block(vid):
    v = VARS[vid]['data']
    sg = v.get('skillGems')
    pr = PROSE[vid]
    out = []
    if not sg or not sg.get('gems'):
        out.append('<div class="warn">🚧 <strong>WIP</strong> — 原文サイト上でもまだ執筆中で、スキルジェムデータは未登録。</div>')
        if pr['gems']:
            out.append('<div class="prose">' + iconize(pr['gems']) + '</div>')
        return ''.join(out)
    req = sg.get('gemRequirements') or {}
    out.append('<div class="reqbar"><span class="req-l">サポートジェム要求ステータス</span>' + ''.join(
        '<span class="req"><span class="req-k %s">%s</span> %s</span>' % (k, k.capitalize(), req.get(k) or 0) for k in ('str', 'dex', 'int')) + '</div>')
    cards = []
    for i, g in enumerate(sg['gems']):
        a = g['activeSkill']
        a = dict(a, name=subst_gem_name(a['name']))
        tags = []
        if a['name'] in GEM_SPIRIT:
            tags.append('<span class="tag spirit">Spirit</span>')
        if g.get('weaponSet'):
            tags.append('<span class="tag ws">武器セット %s</span>' % g['weaponSet'])
        if g.get('grantedByWeaponSet'):
            tags.append('<span class="tag ws">武器セット %s から付与</span>' % g['grantedByWeaponSet'])
        sups = ''.join('<div class="sup" title="%s">%s<span>%s</span></div>' % (html.escape(L.GDESC.get(gem_name(s['gemSlug']), ''), quote=True), img(s['iconURL'], 'sup-ic', gem_name(s['gemSlug'])), gem_disp(gem_name(s['gemSlug']))) for s in (g.get('subSkills') or []))
        cards.append('<div class="gcard"><div class="gcard-h"><div class="gic">%s<span class="badge">%d</span></div><div class="gname">%s%s</div></div>%s%s</div>' % (
            img(a['iconURL'], 'gimg', a['name']), i + 1, gem_disp(a['name']), (' ' + ''.join(tags)) if tags else '',
            ('<div class="gdesc">' + html.escape(L.GDESC[a['name']]) + '</div>') if a['name'] in L.GDESC else '',
            ('<div class="sups">' + sups + '</div>') if sups else ''))
    out.append('<div class="gcards">' + ''.join(cards) + '</div>')
    pg = sg.get('priorityGems') or []
    if pg:
        out.append('<div class="prio"><div class="prio-h">ジェム優先度 (サポート取得順)</div><div class="prio-row">' + ''.join(
            '<div class="prio-it" title="%s"><span class="pnum">%d</span>%s<span class="pname">%s</span></div>' % (html.escape(p['name'], quote=True), i + 1, img(p['iconURL'], 'pic', p['name']), gem_disp(p['name'])) for i, p in enumerate(pg)) + '</div></div>')
    if pr['gems']:
        out.append('<div class="prose">' + iconize(pr['gems']) + '</div>')
    return ''.join(out)
def node_row(nid, extra=''):
    n = NODES[nid]
    stats = ''.join('<div class="nstat">%s</div>' % html.escape(s) for s in L.translate_lines(n['stats']))
    kind = 'keystone' if n['keystone'] else 'notable' if n['notable'] else 'small'
    return '<div class="nrow %s">%s<div class="nbody"><div class="nname">%s%s</div>%s</div></div>' % (kind, img(n['icon'], 'nic', n['name']), node_disp(n['name']), extra, stats)

def tree_img_src(n):
    return local(CDN + n['icon'].replace('.dds', '.webp')) if n['icon'] else None
def tree_tip(n):
    stats = L.translate_lines(n['stats'])
    return '<b>%s</b>%s' % (node_disp(n['name']), ''.join('<div class="nstat">%s</div>' % html.escape(x) for x in stats))
def tree_block(pt):
    ids = lambda key: [int(s.split('-')[1]) for s in ((pt.get(key) or {}).get('selectedSlugs') or []) if s.split('-')[1].isdigit()]
    main, set1, set2, asc = ids('mainTree'), ids('set1Tree'), ids('set2Tree'), ids('ascendancyTree')
    amap = {int(a['nodeSlug'].split('-')[1]): a['attribute'] for a in (pt.get('attributeNodes') or []) if a.get('nodeSlug', '').split('-')[-1].isdigit()}
    attr_of = lambda n: {'str': 'S', 'dex': 'D', 'int': 'I', 'any': '?'}.get(amap.get(n['id'], ''), '')
    vb = TS.bbox(TNODES, main + set1 + set2)
    out = ['<div class="tree"><div class="tbar"><button class="rst" type="button">選択範囲</button><button class="all" type="button" data-vb="%s">ツリー全体</button></div>' % ' '.join('%.0f' % v for v in FULL_VB)]
    out.append('<svg viewBox="%s" xmlns="http://www.w3.org/2000/svg"><use href="#tb"/>%s%s%s</svg>' % (
        ' '.join('%.0f' % v for v in vb),
        TS.alloc_layer(TNODES, TRADII, set1, tree_img_src, tree_tip, attr_of, 'w1'),
        TS.alloc_layer(TNODES, TRADII, set2, tree_img_src, tree_tip, attr_of, 'w2'),
        TS.alloc_layer(TNODES, TRADII, main, tree_img_src, tree_tip, attr_of, 'al', with_start=True)))
    out.append('<div class="tleg"><span><i style="background:#e6c25a"></i>メイン %d</span>%s%s<span>ホイールで拡大縮小 / ドラッグで移動 / ノードにカーソルで効果表示</span></div></div>' % (
        len(main), '<span><i style="background:#5ad0ff"></i>武器セット 1 %d</span>' % len(set1) if set1 else '', '<span><i style="background:#ff9a5a"></i>武器セット 2 %d</span>' % len(set2) if set2 else ''))
    if asc:
        ascname = TNODES[asc[0]]['asc'] if asc[0] in TNODES else None
        if ascname:
            base, allids = TS.asc_base(TNODES, TRADII, ascname)
            avb = TS.bbox(TNODES, allids, pad=250, min_w=2400)
            out.append('<div class="tree asc"><div class="tbar"><button class="rst" type="button">リセット</button></div><svg viewBox="%s" xmlns="http://www.w3.org/2000/svg">%s%s</svg><div class="tleg"><span><i style="background:#c697ff"></i>%s %d ノード</span></div></div>' % (
                ' '.join('%.0f' % v for v in avb), base, TS.alloc_layer(TNODES, TRADII, asc, tree_img_src, tree_tip, attr_of, 'ac'), node_disp(ascname), len(asc)))
    return ''.join(out)

def passive_block(vid):
    v = VARS[vid]['data']
    pt = v.get('passiveTree')
    pr = PROSE[vid]
    out = []
    if not pt or not (pt.get('mainTree') or {}).get('selectedSlugs'):
        out.append('<div class="warn">🚧 <strong>WIP</strong> — 原文サイト上でもまだ執筆中で、パッシブツリーデータは未登録。</div>')
        if pr['passive']:
            out.append('<div class="prose">' + iconize(pr['passive']) + '</div>')
        return ''.join(out)
    main = [s.split('-')[1] for s in pt['mainTree']['selectedSlugs']]
    asc = [s.split('-')[1] for s in ((pt.get('ascendancyTree') or {}).get('selectedSlugs') or [])]
    set1 = ((pt.get('set1Tree') or {}).get('selectedSlugs') or [])
    set2 = ((pt.get('set2Tree') or {}).get('selectedSlugs') or [])
    attrs = pt.get('attributeNodes') or []
    ac = Counter(a['attribute'] for a in attrs)
    out.append('<div class="cntbar"><span class="cnt">メイン <b>%d</b></span><span class="cnt">アセンダンシー <b>%d</b></span><span class="cnt">武器セット 1 <b>%d</b></span><span class="cnt">武器セット 2 <b>%d</b></span><span class="cnt">属性ノード <b>%d</b> <small>(%s)</small></span></div>' % (
        len(main), len(asc), len(set1), len(set2), len(attrs), ' / '.join('%s %d' % (k.upper() if k != 'any' else '任意', c) for k, c in ac.most_common()) or '—'))
    out.append(tree_block(pt))
    pl = pt['mainTree'].get('priorityList') or []
    if pl:
        out.append('<div class="prio"><div class="prio-h">ノータブル優先度 (取得順)</div><div class="prio-row">' + ''.join(
            '<div class="prio-it" title="%s"><span class="pnum">%d</span>%s<span class="pname">%s</span></div>' % (html.escape(p['name'], quote=True), i + 1, img(p['iconURL'], 'pic', p['name']), node_disp(p['name'])) for i, p in enumerate(pl)) + '</div></div>')
    if pr['passive']:
        out.append('<div class="prose">' + iconize(pr['passive']) + '</div>')
    if asc:
        out.append('<h4 class="sub">アセンダンシー (%d ノード)</h4><div class="nlist">' % len(asc))
        for nid in asc:
            out.append(node_row(nid))
        out.append('</div>')
        if pr.get('asc_note'):
            out.append('<div class="note">' + html.escape(pr['asc_note']) + '</div>')
    nots = [nid for nid in main if NODES[nid]['notable'] or NODES[nid]['keystone']]
    seen = OrderedDict()
    for nid in nots:
        seen.setdefault(NODES[nid]['name'], []).append(nid)
    out.append('<h4 class="sub">ノータブル / キーストーン (%d ノード)</h4><div class="nlist two">' % len(nots))
    for name, ids in seen.items():
        out.append(node_row(ids[0], (' <span class="mult">×%d</span>' % len(ids)) if len(ids) > 1 else ''))
    out.append('</div>')
    smalls = [nid for nid in main if not (NODES[nid]['notable'] or NODES[nid]['keystone']) and NODES[nid]['name'] != 'Attribute']
    sc = Counter(NODES[nid]['name'] for nid in smalls)
    first = {}
    for nid in smalls:
        first.setdefault(NODES[nid]['name'], nid)
    out.append('<h4 class="sub">小ノード (%d ノード)</h4><div class="chips">' % len(smalls))
    for name, c in sc.most_common():
        n = NODES[first[name]]
        out.append('<div class="chip" title="%s">%s<span>%s</span><b>×%d</b></div>' % (html.escape(' / '.join(L.translate_lines(n['stats'])), quote=True), img(n['icon'], 'cic', name), node_disp(name), c))
    out.append('</div>')
    nattr = sum(1 for nid in main if NODES[nid]['name'] == 'Attribute')
    if nattr:
        out.append('<div class="m">ほか属性小ノード %d 個 (振り分け指定: %s)</div>' % (nattr, ' / '.join('%s %d' % (k.upper() if k != 'any' else '任意', c) for k, c in ac.most_common()) or '未指定'))
    if pr.get('jewel'):
        jw = (pt.get('jewels') or [{}])[0]
        out.append('<h4 class="sub">ジュエル</h4><div class="nrow"><div class="nic-w">%s</div><div class="nbody"><div class="nname">%s</div></div></div>' % (img(jw.get('iconURL'), 'nic', 'Jewel'), html.escape(pr['jewel'])))
    return ''.join(out)
def quest_block():
    groups = OrderedDict()
    for q in doc['data']['questRewards']['quests']:
        groups.setdefault(q['quest']['act'], []).append(q)
    rows = []
    for act, qs in groups.items():
        rows.append('<tr class="act"><td colspan="3">%s</td></tr>' % html.escape(act))
        for q in qs:
            rw = q.get('reward')
            rows.append('<tr><td>%s</td><td>%s</td><td class="rw">%s</td></tr>' % (html.escape(q['quest']['area']), html.escape(q['quest']['name']), html.escape(T(rw['bakedDescription'])) if rw else '<span class="muted">選択なし</span>'))
    return '<div class="tbl"><table class="qt"><tr><th>エリア</th><th>クエスト</th><th>選択する報酬</th></tr>' + ''.join(rows) + '</table></div>'
def tabs(section_key):
    return '<div class="tabs" data-sec="%s">' % section_key + ''.join(
        '<button class="tab%s" data-v="%s">%s</button>' % (' on' if i == 0 else '', vid, html.escape(VARS[vid]['ja'])) for i, vid in enumerate(VARS)) + '</div>'

def panes(section_key, fn):
    out = []
    for i, vid in enumerate(VARS):
        out.append('<div class="pane" data-v="%s"%s><div class="pane-title">%s <span class="en">%s</span></div>%s</div>' % (vid, '' if i == 0 else ' hidden', html.escape(VARS[vid]['ja']), html.escape(VARS[vid]['title']), fn(vid)))
    return ''.join(out)

def variants_block(vid):
    pr = PROSE[vid]
    return '<div class="prose">' + iconize(pr['intro']) + '</div>' if pr['intro'] else '<div class="m">本文なし</div>'
CSS = TS.CSS + r"""
:root{--bg:#0c091f;--panel:#171233;--panel2:#12121f;--panel3:#1f1a3d;--bd:#2d2752;--bd2:#3f3966;--gold:#f2bf43;--orange:#fc7c00;--txt:#ffffff;--muted:#a5a2b8;--green:#16b474;--red:#f04438;--blue:#8888ff;--uniq:#af6025;--rare:#ffff77;}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--txt);font-family:Roboto,"Hiragino Sans","Hiragino Kaku Gothic ProN","Noto Sans JP","Yu Gothic",system-ui,sans-serif;font-size:15px;line-height:1.7}
a{color:var(--gold);text-decoration:none}a:hover{text-decoration:underline}
img{max-width:100%}
.topbar{position:sticky;top:0;z-index:50;background:#0f0c26;border-bottom:1px solid var(--bd);padding:8px 20px;display:flex;align-items:center;gap:14px;font-size:13px}
.topbar .logo{font-weight:900;letter-spacing:.5px;color:#fff}.topbar .logo b{color:var(--gold)}
.topbar .crumb{color:var(--muted)}.topbar .crumb a{color:var(--muted)}
.wrap{max-width:1280px;margin:0 auto;padding:20px;display:grid;grid-template-columns:minmax(0,1fr) 300px;gap:20px}
@media(max-width:1000px){.wrap{grid-template-columns:1fr}.side{position:static!important}}
.side{position:sticky;top:60px;align-self:start;max-height:calc(100vh - 80px);overflow:auto}
.card{background:var(--panel);border:1px solid var(--bd);border-radius:10px;margin-bottom:20px}
.card-h{padding:14px 20px;border-bottom:1px solid var(--bd);font-weight:700;font-size:17px;display:flex;align-items:center;justify-content:space-between;gap:10px}
.card-b{padding:18px 20px}
.hero{position:relative;overflow:hidden;border-radius:10px;border:1px solid var(--bd);margin-bottom:20px;background:#0f0c26}
.hero .bg{position:absolute;inset:0;background-size:cover;background-position:center 30%;opacity:.55;filter:saturate(.9)}
.hero .bg::after{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(12,9,31,.95) 0%,rgba(12,9,31,.75) 50%,rgba(12,9,31,.3) 100%)}
.hero .in{position:relative;padding:26px 24px}
.hero .kicker{color:var(--muted);font-size:12px;margin-bottom:8px}
.hero h1{font-size:24px;margin:0 0 4px;line-height:1.35}
.hero .en{color:var(--muted);font-size:13px;margin-bottom:12px}
.tags{display:flex;flex-wrap:wrap;gap:6px;margin:10px 0}
.tagc{display:inline-flex;align-items:center;gap:6px;background:#2a2450;border:1px solid var(--bd2);border-radius:6px;padding:3px 9px;font-size:12px;color:#ddd}
.tagc img{width:18px;height:18px;border-radius:50%;object-fit:cover}
.byline{color:var(--muted);font-size:13px;margin-top:8px}.byline b{color:#fff}
.btns{display:flex;gap:8px;margin-top:14px;flex-wrap:wrap}
.btn{display:inline-flex;align-items:center;gap:6px;background:#2a2450;border:1px solid var(--bd2);color:#fff;border-radius:8px;padding:8px 14px;font-size:13px;font-weight:600}
.btn.gold{background:var(--gold);color:#1a1400;border-color:var(--gold)}
.toc{padding:6px 10px}
.toc a{display:block;padding:8px 12px;border-radius:8px;color:#ddd;font-size:14px;border-left:2px solid transparent}
.toc a:hover,.toc a.on{background:#2a2450;color:var(--gold);text-decoration:none;border-left-color:var(--gold)}
.toc a.sub{padding:5px 12px 5px 26px;font-size:13px;color:var(--muted)}
.totop{display:block;margin:10px;text-align:center;background:#2a2450;border-radius:8px;padding:8px;font-size:13px;color:#fff}
.prose h3{font-size:16px;margin:22px 0 8px;padding-bottom:6px;border-bottom:1px solid var(--bd);color:#fff}
.prose h3:first-child{margin-top:0}
.prose h4{font-size:15px;margin:18px 0 6px;color:var(--gold)}
.prose p{margin:8px 0}.prose ul,.prose ol{margin:6px 0 10px;padding-left:24px}.prose li{margin:3px 0}
.prose dl{margin:6px 0;display:grid;grid-template-columns:max-content 1fr;gap:4px 14px}
.prose dt{color:var(--gold);font-weight:700}.prose dd{margin:0}
code{background:#0b0b14;border:1px solid var(--bd2);border-radius:4px;padding:2px 6px;font-size:13px;color:#ffd28a;word-break:break-all}
.warn,.note,.info,.pick{border-radius:8px;padding:10px 14px;margin:10px 0}
.warn{background:rgba(240,68,56,.12);border:1px solid rgba(240,68,56,.45)}
.note{background:rgba(242,191,67,.1);border:1px solid rgba(242,191,67,.4)}
.info{background:rgba(136,136,255,.12);border:1px solid rgba(136,136,255,.4)}
.pick{background:var(--panel2);border:1px solid var(--bd2)}
.pick ol{margin:4px 0 10px}
.m,.muted{color:var(--muted);font-size:13px}
.uniq{color:var(--uniq);font-weight:700}
.ent{color:var(--gold);white-space:nowrap;font-weight:500}
.ei{width:20px;height:20px;vertical-align:-5px;margin-right:3px;border-radius:4px;object-fit:cover}
.ph{display:inline-block;background:#2a2450;border-radius:4px}
.sw{display:grid;grid-template-columns:1fr 1fr;gap:16px}
@media(max-width:700px){.sw{grid-template-columns:1fr}}
.sw h4{margin:0 0 8px;font-size:15px}.sw .g h4{color:var(--green)}.sw .r h4{color:var(--red)}
.sw ul{margin:0;padding-left:20px}.sw li{margin:4px 0}
.tabs{display:flex;flex-wrap:wrap;gap:6px;padding:12px 20px 0;border-bottom:1px solid var(--bd)}
.tab{flex:0 0 auto;background:#2a2450;border:1px solid var(--bd2);color:#ddd;border-radius:8px 8px 0 0;padding:8px 14px;font-size:13px;font-weight:600;cursor:pointer;border-bottom:none;white-space:nowrap}
.tab.on{background:#3a3270;color:#fff;box-shadow:inset 0 -3px 0 var(--gold)}
.pane-title{font-weight:700;font-size:15px;margin-bottom:12px;color:#fff}.pane-title .en{color:var(--muted);font-weight:400;font-size:12px;margin-left:6px}
.setbar{display:flex;gap:6px;margin:0 0 14px}
.setbtn{background:#2a2450;border:1px solid var(--bd2);color:#ddd;border-radius:6px;padding:6px 12px;font-size:13px;cursor:pointer}
.setbtn.on{background:#3a3270;color:#fff;border-color:var(--gold)}
.setbtn small{color:var(--muted)}
.doll{display:grid;grid-template-columns:repeat(8,60px);grid-auto-rows:60px;gap:6px;justify-content:center;margin:10px auto 16px;padding:14px;background:var(--panel2);border:1px solid var(--bd);border-radius:10px;width:max-content;max-width:100%}
@media(max-width:620px){.doll{grid-template-columns:repeat(8,40px);grid-auto-rows:40px;gap:4px;padding:8px}.slot-lbl{display:none}}
.slot{position:relative;background:#0b0b14;border:1px solid var(--bd2);border-radius:6px;display:flex;align-items:center;justify-content:center;overflow:hidden}
.slot.filled{cursor:pointer;border-color:#4a4380}.slot.filled:hover,.slot.filled:focus{border-color:var(--gold);outline:none}
.slot.uq{border-color:var(--uniq)}
.slot-img{max-width:92%;max-height:92%;object-fit:contain}
.slot-lbl{position:absolute;left:3px;bottom:2px;font-size:9px;color:var(--muted);line-height:1;pointer-events:none}
.slot.empty .slot-lbl{position:static;font-size:10px;text-align:center}
.badge{position:absolute;right:2px;bottom:2px;background:var(--gold);color:#1a1400;font-size:10px;font-weight:800;border-radius:4px;min-width:16px;height:16px;line-height:16px;text-align:center;padding:0 3px}
.s-mainHand{grid-column:1/3;grid-row:1/5}.s-offHand{grid-column:7/9;grid-row:1/5}
.s-helmet{grid-column:4/6;grid-row:1/3}.s-amulet{grid-column:6/7;grid-row:2/3}
.s-body{grid-column:4/6;grid-row:3/6}.s-leftRing{grid-column:3/4;grid-row:4/5}.s-rightRing{grid-column:6/7;grid-row:4/5}
.s-gloves{grid-column:1/3;grid-row:5/7}.s-boots{grid-column:7/9;grid-row:5/7}.s-belt{grid-column:4/6;grid-row:6/7}
.s-flask1{grid-column:1/2;grid-row:7/9}.s-flask2{grid-column:2/3;grid-row:7/9}
.s-charm1{grid-column:4/5;grid-row:7/8}.s-charm2{grid-column:5/6;grid-row:7/8}.s-charm3{grid-column:6/7;grid-row:7/8}
.tip{position:fixed;z-index:100;width:320px;max-width:92vw;background:#050409;border:1px solid var(--bd2);border-radius:8px;box-shadow:0 10px 30px rgba(0,0,0,.6);font-size:13px;pointer-events:none}
.tip[hidden]{display:none}
.tt-head{padding:8px 12px;text-align:center;border-bottom:1px solid var(--bd)}
.tt-head.rare .tt-name{color:var(--rare)}.tt-head.unique .tt-name{color:var(--uniq)}
.tt-name{font-weight:700;font-size:15px}.tt-base{color:var(--muted);font-size:12px}
.tt-sec{padding:6px 12px;border-bottom:1px solid var(--bd)}.tt-sec:last-child{border-bottom:none}
.tt-stat{color:#ddd}.tt-stat b{color:#fff}
.tt-mod{color:var(--blue)}
small.en{font-weight:400;color:var(--muted);font-size:.8em;margin-left:2px}
.gdesc{font-size:12px;color:var(--muted);line-height:1.6;padding:6px 10px 2px}
.tt-rune{color:#c8c0ff}.rune-b{display:inline-block;width:16px;height:16px;line-height:16px;text-align:center;border-radius:50%;background:#3a3270;border:1px solid #8888ff;font-size:10px;font-weight:800;margin-right:6px;color:#fff}
.tt-anoint{color:#ffd28a}.tt-empty{color:var(--muted)}
.icards{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:10px;margin-bottom:16px}
.icard{display:flex;gap:10px;background:#0b0b14;border:1px solid var(--bd2);border-radius:8px;padding:10px;font-size:13px}
.icard.uq{border-color:var(--uniq)}
.icard-ic{position:relative;flex:0 0 64px;height:64px;background:#050409;border:1px solid var(--bd);border-radius:6px;display:flex;align-items:center;justify-content:center}
.icard-img{max-width:90%;max-height:90%;object-fit:contain}
.icard-body{flex:1;min-width:0}
.icard-body .tt-head{text-align:left;padding:0 0 6px}.icard-body .tt-sec{padding:4px 0}
.sub{font-size:14px;color:var(--gold);margin:16px 0 8px}
.prio{background:var(--panel2);border:1px solid var(--bd);border-radius:8px;padding:10px 14px;margin:14px 0}
.prio-h{font-weight:700;font-size:14px;margin-bottom:8px}
.prio-row{display:flex;flex-wrap:wrap;gap:6px}
.prio-it{display:inline-flex;align-items:center;gap:5px;background:#0b0b14;border:1px solid var(--bd2);border-radius:6px;padding:3px 8px 3px 4px;font-size:12px}
.pnum{background:var(--gold);color:#1a1400;font-weight:800;border-radius:4px;min-width:18px;height:18px;line-height:18px;text-align:center;font-size:11px}
.pic{width:26px;height:26px;border-radius:4px;object-fit:cover}
.pname{color:#ddd}
.reqbar{display:flex;flex-wrap:wrap;align-items:center;gap:14px;background:var(--panel2);border:1px solid var(--bd);border-radius:8px;padding:8px 14px;margin-bottom:14px;font-size:13px}
.req-l{color:var(--muted)}.req-k{font-weight:800}.req-k.str{color:#ff7070}.req-k.dex{color:#c6ff70}.req-k.int{color:#9898ff}
.gcards{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:10px}
.gcard{background:#0b0b14;border:1px solid var(--bd2);border-radius:8px;padding:10px}
.gcard-h{display:flex;align-items:center;gap:10px}
.gic{position:relative;flex:0 0 48px;height:48px;border-radius:6px;overflow:hidden;background:#050409;border:1px solid var(--bd)}
.gimg{width:100%;height:100%;object-fit:cover}
.gname{font-weight:700;font-size:14px;line-height:1.3}
.tag{display:inline-block;font-size:10px;font-weight:700;border-radius:4px;padding:1px 6px;vertical-align:middle;margin-left:2px}
.tag.spirit{background:#3a2a60;color:#c697ff;border:1px solid #6a4aa0}.tag.ws{background:#2a3a50;color:#70ffff;border:1px solid #3a6a90}
.sups{margin-top:8px;padding-top:8px;border-top:1px solid var(--bd);display:flex;flex-direction:column;gap:5px}
.sup{display:flex;align-items:center;gap:8px;font-size:13px;color:#ddd}
.sup-ic{width:28px;height:28px;border-radius:50%;object-fit:cover;background:#050409}
.cntbar{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:14px}
.cnt{background:var(--panel2);border:1px solid var(--bd);border-radius:6px;padding:5px 10px;font-size:13px;color:var(--muted)}.cnt b{color:#fff;margin-left:2px}.cnt small{color:var(--muted)}
.nlist{display:grid;grid-template-columns:1fr;gap:8px}
.nlist.two{grid-template-columns:repeat(auto-fill,minmax(360px,1fr))}
.nrow{display:flex;gap:10px;background:#0b0b14;border:1px solid var(--bd2);border-radius:8px;padding:8px 10px;align-items:flex-start}
.nrow.keystone{border-color:var(--orange)}.nrow.notable{border-color:#4a4380}
.nic{flex:0 0 40px;width:40px;height:40px;border-radius:50%;object-fit:cover;background:#050409;border:1px solid var(--bd2)}
.nrow.notable .nic{border-color:var(--gold)}.nrow.keystone .nic{border-color:var(--orange);border-radius:8px}
.nname{font-weight:700;font-size:14px}.nrow.keystone .nname{color:var(--orange)}
.nstat{color:var(--blue);font-size:12.5px;line-height:1.5}
.mult{color:var(--gold);font-size:12px}
.chips{display:flex;flex-wrap:wrap;gap:6px}
.chip{display:inline-flex;align-items:center;gap:6px;background:#0b0b14;border:1px solid var(--bd2);border-radius:20px;padding:3px 10px 3px 4px;font-size:12px;color:#ddd}
.chip b{color:var(--gold)}.cic{width:24px;height:24px;border-radius:50%;object-fit:cover}
.tbl{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:13.5px}
th,td{border:1px solid var(--bd);padding:7px 10px;text-align:left;vertical-align:top}
th{background:#2a2450;color:#fff}
tr.act td{background:#1f1a3d;color:var(--gold);font-weight:700}
td.rw{color:var(--blue)}
.qt td:first-child{color:var(--muted)}
.foot{color:var(--muted);font-size:12px;text-align:center;padding:20px}
"""

JS = TS.JS + r"""
(function(){
  var tip=document.getElementById('tip');
  function show(el){tip.innerHTML=el.getAttribute('data-tip');tip.hidden=false;var r=el.getBoundingClientRect();var w=tip.offsetWidth,h=tip.offsetHeight;var x=r.right+10,y=r.top;if(x+w>window.innerWidth-8)x=r.left-w-10;if(x<8)x=8;if(y+h>window.innerHeight-8)y=Math.max(8,window.innerHeight-h-8);tip.style.left=x+'px';tip.style.top=y+'px';}
  function hide(){tip.hidden=true;}
  document.querySelectorAll('.slot.filled, .tn').forEach(function(el){el.addEventListener('mouseenter',function(){show(el)});el.addEventListener('mouseleave',hide);el.addEventListener('focus',function(){show(el)});el.addEventListener('blur',hide);el.addEventListener('click',function(){tip.hidden?show(el):hide()});});
  window.addEventListener('scroll',hide,{passive:true});
  function selectVariant(v){
    document.querySelectorAll('.tabs').forEach(function(t){t.querySelectorAll('.tab').forEach(function(b){b.classList.toggle('on',b.getAttribute('data-v')===v)});});
    document.querySelectorAll('.pane').forEach(function(p){p.hidden=p.getAttribute('data-v')!==v});
    try{localStorage.setItem('__STORAGE__',v)}catch(e){}
  }
  document.querySelectorAll('.tab').forEach(function(b){b.addEventListener('click',function(){var sec=b.closest('.card');selectVariant(b.getAttribute('data-v'));if(sec){var y=sec.getBoundingClientRect().top;if(y<0)sec.scrollIntoView();}});});
  try{var q=new URLSearchParams(location.search).get('v');var s=q||localStorage.getItem('__STORAGE__');if(s&&document.querySelector('.tab[data-v="'+s+'"]'))selectVariant(s);}catch(e){}
  document.querySelectorAll('.setbar').forEach(function(bar){bar.querySelectorAll('.setbtn').forEach(function(b){b.addEventListener('click',function(){var ws=b.getAttribute('data-set');bar.querySelectorAll('.setbtn').forEach(function(x){x.classList.toggle('on',x===b)});var pane=bar.parentElement;pane.querySelectorAll('.setpane').forEach(function(p){p.hidden=p.getAttribute('data-set')!==ws});});});});
  var links=Array.prototype.slice.call(document.querySelectorAll('.toc a[href^="#"]'));var secs=links.map(function(a){return document.getElementById(a.getAttribute('href').slice(1))}).filter(Boolean);
  function spy(){var y=window.scrollY+120;var cur=null;secs.forEach(function(s){if(s.offsetTop<=y)cur=s.id});links.forEach(function(a){a.classList.toggle('on',cur&&a.getAttribute('href')==='#'+cur)});}
  window.addEventListener('scroll',spy,{passive:true});spy();
})();
"""
JS = JS.replace('__STORAGE__', CFG['slug'] + '-variant')
TAGS = [t for t in doc['tags']['data'] if t.get('name')]
def tag_of(group):
    return next((t for t in TAGS if t.get('groupSlug') == group), None)
cls_tag = tag_of('class'); asc_tag = tag_of('ascendancy')
pattern = (((doc.get('typeData') or {}).get('displayMetadata') or {}).get('coverImageUrlPattern')) or ''
hero_bg = local(pattern.replace('{{class}}', cls_tag['slug']).replace('{{ascendancy}}', asc_tag['slug'])) if cls_tag and asc_tag and pattern else None
AUTHOR = doc.get('author') or {}
NET_LABEL = {'twitch': 'Twitch', 'youtube': 'YouTube', 'twitter': 'X', 'discord': 'Discord'}
title_en = doc['data']['name'].strip()
updated = doc.get('updatedAt', '')[:10]

TOC = [('overview', '1. ビルド概要'), ('sw', '2. 強みと弱み'), ('variants', '3. ビルドバリアント'), ('equipment', '4. 装備'), ('gems', '5. スキルジェム'), ('passive', '6. パッシブツリー'), ('quest', '7. クエスト報酬'), ('changelog', '8. 更新履歴'), ('faq', '9. 著者コメント欄からの補足'), ('notes', '10. 訳注・データ上の注意')]
toc_html = ''.join('<a href="#%s">%s</a>' % (k, t) for k, t in TOC)
ov_subs = re.findall(r'<h3 id="([^"]*)">([^<]*)</h3>', overview_html)
toc_html = toc_html.replace('<a href="#overview">1. ビルド概要</a>', '<a href="#overview">1. ビルド概要</a>' + ''.join('<a class="sub" href="#%s">%s</a>' % (i, html.escape(re.sub(r'\s*\(.*\)$', '', t))) for i, t in ov_subs))

def card(idname, title, body, tabbed=None):
    return '<section class="card" id="%s"><div class="card-h"><span>%s</span></div>%s<div class="card-b">%s</div></section>' % (idname, title, tabbed or '', body)

parts = []
parts.append('<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>%s</title><style>%s</style></head><body>' % (html.escape(CFG['page_title']), CSS))
parts.append('<div class="topbar"><span class="logo">MOBA<b>LYTICS</b> <span class="muted">クローン (日本語ローカル版)</span></span><span class="crumb">Path of Exile 2 › Builds › <a href="%s">原文ページ</a></span></div>' % SRC_URL)
parts.append('<div class="wrap"><main>')
tag_html = ''.join('<span class="tagc">%s%s</span>' % (img(t['imageUrl'], '', t['name']) if t.get('imageUrl') else '', html.escape(t['name'])) for t in TAGS)
author_links = ' · '.join('<a href="%s">%s</a>' % (html.escape(l['url'], quote=True), NET_LABEL.get((l.get('network') or {}).get('id', ''), (l.get('network') or {}).get('id', 'link').capitalize())) for l in (AUTHOR.get('links') or []) if l.get('url'))
byline = 'By <b>%s</b>%s · 原文更新日 %s · 日本語版作成 %s' % (html.escape(AUTHOR.get('name', '')), (' (' + author_links + ')') if author_links else '', updated, CFG['made_on'])
btn_html = '<a class="btn gold" href="%s">原文を開く</a>' % SRC_URL + ''.join('<a class="btn" href="%s">%s</a>' % (html.escape(b_['url'], quote=True), html.escape(b_['label'])) for b_ in (CFG.get('buttons') or [])) + '<a class="btn" href="#equipment">装備へ</a><a class="btn" href="#gems">スキルジェムへ</a><a class="btn" href="#passive">パッシブへ</a>'
parts.append('''<div class="hero"><div class="bg" style="background-image:url('%s')"></div><div class="in"><div class="kicker">PoE 2 Build · 原文: <a href="%s">mobalytics.gg</a></div>
<h1>%s</h1>
<div class="en">%s</div>
<div class="tags">%s</div>
<div class="byline">%s</div>
<div class="btns">%s</div>
</div></div>''' % (hero_bg or '', SRC_URL, html.escape(CFG['title_ja']), html.escape(title_en), tag_html, byline, btn_html))

parts.append(card('overview', 'ビルド概要 <span class="muted">Build Overview</span>', '<div class="prose">' + iconize(overview_html) + '</div>'))
sw_body = '<div class="sw"><div class="g"><h4>✅ 強み</h4><ul>%s</ul></div><div class="r"><h4>⚠️ 弱み</h4><ul>%s</ul></div></div>' % (iconize(sw_lists[0]), iconize(sw_lists[1])) if len(sw_lists) >= 2 else iconize(sw_html)
parts.append(card('sw', '強みと弱み <span class="muted">Strengths and Weaknesses</span>', sw_body))
parts.append(card('variants', 'ビルドバリアント <span class="muted">Build Variants</span>', panes('variants', variants_block), tabs('variants')))
parts.append(card('equipment', '装備 <span class="muted">Equipment</span>', panes('equipment', equipment_block), tabs('equipment')))
parts.append(card('gems', 'スキルジェム <span class="muted">Skill Gems</span>', panes('gems', gems_block), tabs('gems')))
parts.append(card('passive', 'パッシブツリー <span class="muted">Passive Tree</span>', panes('passive', passive_block), tabs('passive')))
parts.append(card('quest', 'クエスト報酬 <span class="muted">Quest Rewards</span>', quest_block()))
parts.append(card('changelog', '更新履歴 <span class="muted">Changelog</span>', '<div class="prose">' + changelog_html + '</div>'))
parts.append(card('faq', '著者コメント欄からの補足', '<div class="prose">' + iconize(faq_html) + '</div>'))
notes_extra = '<li>この UI クローン版は、元サイトのレイアウト (バリアントタブ / 装備グリッド / ジェムカード / パッシブ一覧) を再現し、アイコン画像は元サイトの CDN から取得してフォルダ <code>%s/</code> に保存している。パッシブツリーは本リポジトリのツリーデータ (<code>src/TreeData/0_5/tree.lua</code>) の座標から SVG で描画したもので、元サイトの描画とは見た目が異なる (ノード配置・接続は同一データ)。割当ノードのアイコンは元サイト CDN 由来、その下にノード一覧 (効果テキスト付き) を併記している。</li><li>ルーンソケットの画像は CDN で取得できなかったため「R」バッジで代替している。</li><li>アイテム名 / ベース名 / Mod 行 / ジェム名 / パッシブ名と効果 / クエスト報酬の日本語は、Path of Building 2 (本リポジトリ) の日本語ロケールデータ (<code>src/Locales/ja/</code>、出典 poe2db.tw/jp) で照合したもの。数値はテンプレート照合で当てはめているため、原文は各行の英語併記またはマウスオーバーで確認できる。ロケールに無かった数行 (武器セット用パッシブポイント等のクエスト報酬、一部の Mod) は訳者が補った。</li>' % ASSET_DIR
notes_body = re.sub(r'<ul>', '<ul>' + notes_extra, notes_html, count=1)
parts.append(card('notes', '訳注・データ上の注意', '<div class="prose">' + notes_body + '</div>'))
parts.append('<div class="foot">原文: <a href="%s">%s</a> · 著者 %s · 本ページは個人利用の日本語ローカル版</div>' % (SRC_URL, SRC_URL, html.escape(AUTHOR.get('name', ''))))
parts.append('</main><aside class="side"><div class="card"><div class="card-h">目次</div><nav class="toc">%s</nav><a class="totop" href="#top">トップへ戻る</a></div></aside></div>' % toc_html)
parts.append('<div id="tip" class="tip" hidden></div><script>%s</script></body></html>' % JS)

out = '\n'.join(parts)
out = out.replace('<body>', '<body id="top"><svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>%s</defs></svg>' % TREE_BASE, 1)
open(OUT, 'w', encoding='utf-8').write(out)
print('written', OUT, len(out))
missing = sorted(set(re.findall(r'(?:src|href)="(%s/[^"]+)"' % re.escape(ASSET_DIR), out)) - set(ASSET_DIR + '/' + f for f in os.listdir(ASSET_ABS)))
print('missing src', missing[:10])
print('placeholders', out.count('class="ic ph"') + out.count('ph"'))
print('icons mapped', len(ICONS))
