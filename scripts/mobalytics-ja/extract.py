import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
CFG = json.load(open(sys.argv[1], encoding='utf-8'))
ASSET_ABS = os.path.join(REPO, CFG['asset_dir'])
doc = json.load(open(os.path.join(ASSET_ABS, 'doc.json'), encoding='utf-8'))
C = doc['content']
byid = {c['id']: c for c in C}

gems = {}
cur = None
for line in open(os.path.join(REPO, 'src/Data/Gems.lua'), encoding='utf-8'):
    m = re.match(r'\s*name = "(.*)",', line)
    if m:
        cur = m.group(1)
    m = re.match(r'\s*grantedEffectId = "(.*)",', line)
    if m and cur:
        gems.setdefault(m.group(1).lower(), cur)

nodes = {}
txt = open(os.path.join(REPO, 'src/TreeData/0_5/tree.lua'), encoding='utf-8').read()
for m in re.finditer(r'\n\t\t\[(\d+)\]=\{\n(.*?)\n\t\t\},?\n', txt, re.S):
    nid = m.group(1); body = m.group(2)
    nm = re.search(r'\n\t\t\tname="(.*?)"', body)
    st = re.search(r'\n\t\t\tstats=\{(.*?)\n\t\t\t\}', body, re.S)
    stats = re.findall(r'"(.*?)"', st.group(1)) if st else []
    kind = 'notable' if 'isNotable=true' in body else 'keystone' if 'isKeystone=true' in body else 'small'
    if 'isAscendancyStart' in body:
        kind = 'ascstart'
    nodes[nid] = {'name': nm.group(1) if nm else '?', 'stats': stats, 'kind': kind}

def lex(node):
    t = node.get('type')
    ch = ''.join(lex(c) for c in node.get('children', []))
    if t == 'text':
        s = node['text']; f = node.get('format', 0)
        if f & 1: s = '**' + s + '**'
        if f & 2: s = '_' + s + '_'
        return s
    if t == 'static-data-widget': return '[' + node.get('label', '') + ']'
    if t in ('link', 'autolink'): return '[' + ch + '](' + node.get('url', '') + ')'
    if t == 'linebreak': return '\n'
    if t == 'paragraph': return ch + '\n\n'
    if t == 'heading': return '#' * int(node.get('tag', 'h2')[1]) + ' ' + ch + '\n\n'
    if t == 'list':
        out = ''
        for i, it in enumerate(node.get('children', [])):
            out += ('%d. ' % (i + 1) if node.get('listType') == 'number' else '- ') + ''.join(lex(c) for c in it.get('children', [])).strip() + '\n'
        return out + '\n'
    if t == 'image': return '(image)'
    return ch

def rich(d):
    if not d: return ''
    v = d.get('value') if isinstance(d, dict) and 'value' in d else d
    if not v: return ''
    return lex(v['root'])

out = []
def sec(title): out.append('\n\n# ' + title + '\n')
sec('META'); out.append(doc['data']['name']); out.append('updated ' + doc['updatedAt'] + ' author ' + json.dumps(doc['author'], ensure_ascii=False)[:300])
out.append('tags ' + ', '.join(t['name'] for t in doc['tags']['data']))
for c in C:
    if c['__typename'] == 'NgfDocumentCmWidgetVideoV2' and (c.get('data') or {}).get('videoUrl'):
        out.append('video %s %s' % (c['data'].get('title'), c['data']['videoUrl']))

variants_block = next(c for c in C if c['__typename'] == 'NgfDocumentCmWidgetContentVariantsV1')
variant_child_ids = {cid for var in variants_block['data']['childrenVariants'] for cid in var['childrenIds']}
for c in C:
    if c['__typename'] == 'NgfDocumentCmWidgetRichTextSimplifiedV2' and c['id'] not in variant_child_ids:
        d = c['data']; sec(d.get('title') or 'RichText'); out.append(rich(d.get('optionalSubTitleV2'))); out.append(rich(d.get('simplifiedContent')))
for c in C:
    if c['__typename'] == 'NgfDocumentCmWidgetStrengthsAndWeaknessesV1':
        d = c['data']; sec('Strengths and Weaknesses'); out.append(json.dumps({k: v for k, v in d.items() if k in ('strengths', 'weaknesses')}, ensure_ascii=False, indent=1))
for c in C:
    if c['__typename'] == 'Poe2DocumentUgWidgetQuestRewardsV1':
        sec('Quest Rewards'); out.append(rich(c['data'].get('descriptionPoe2QuestRewards')))
for q in ((doc['data'].get('questRewards') or {}).get('quests') or []):
    out.append('- %s / %s / %s -> %s' % (q['quest']['act'], q['quest']['area'], q['quest']['name'], q['reward']['bakedDescription'] if q.get('reward') else 'NONE'))

vd = {v['id']: v for v in doc['data']['buildVariants']['values']}
for var in variants_block['data']['childrenVariants']:
    sec('VARIANT: ' + var['title']); out.append(rich(var['description']))
    v = vd[var['id']]
    for cid in var['childrenIds']:
        b = byid[cid]; d = b['data']; tn = b['__typename']
        if 'Equipment' in tn:
            out.append('\n## Equipment text\n' + rich(d.get('descriptionPoeEquipment')) + rich(d.get('subTitlePoeEquipment')))
            eq = v.get('equipment') or {}
            for slot, item in eq.items():
                if not item:
                    continue
                if isinstance(item, dict) and 'commonItem' in item:
                    ci = item['commonItem']
                    line = '- %s: %s%s' % (slot, ci['name'], ' [UNIQUE]' if ci.get('isUnique') else '')
                    if ci.get('explicitDescriptions'): line += ' | ' + '; '.join(x['description'] + ('(must)' if x.get('mustHave') else '') for x in ci['explicitDescriptions'])
                    if item.get('anointment'): line += ' | anoint: ' + json.dumps(item['anointment'], ensure_ascii=False)[:200]
                    if item.get('runes'): line += ' | runes: ' + json.dumps([r.get('slug') if isinstance(r, dict) else r for r in item['runes']], ensure_ascii=False)
                    out.append(line)
                elif slot in ('mainHand', 'offHand'):
                    for ws, it in item.items():
                        ci = (it or {}).get('commonItem')
                        if not ci:
                            continue
                        line = '- %s/%s: %s%s' % (slot, ws, ci['name'], ' [UNIQUE]' if ci.get('isUnique') else '')
                        if ci.get('explicitDescriptions'): line += ' | ' + '; '.join(x['description'] + ('(must)' if x.get('mustHave') else '') for x in ci['explicitDescriptions'])
                        if it.get('providedSkill'): line += ' | providedSkill: ' + json.dumps(it['providedSkill'], ensure_ascii=False)[:200]
                        if it.get('runes'): line += ' | runes: ' + json.dumps([r.get('slug') if isinstance(r, dict) else r for r in it['runes']], ensure_ascii=False)
                        out.append(line)
                elif slot == 'priorityList':
                    out.append('- priority: ' + ' > '.join(p['name'] + ('(excluded)' if p.get('isExcluded') else '') for p in item))
                else:
                    out.append('- %s: %s' % (slot, json.dumps(item, ensure_ascii=False)[:600]))
        elif 'SkillGems' in tn:
            out.append('\n## Skill gems text\n' + rich(d.get('descriptionPoeSkillGems')) + rich(d.get('subTitlePoeSkillGems')))
            sg = v.get('skillGems') or {'gems': []}; out.append('req: ' + json.dumps(sg.get('gemRequirements')))
            for g in sg.get('gems') or []:
                a = g['activeSkill']; sup = [gems.get(s['gemSlug'], s['gemSlug']) for s in (g.get('subSkills') or [])]
                out.append('- %s%s%s: %s' % (a['name'], ' (ws%s)' % g['weaponSet'] if g.get('weaponSet') else '', ' [granted by ws%s]' % g['grantedByWeaponSet'] if g.get('grantedByWeaponSet') else '', ', '.join(sup)))
            out.append('priority: ' + ', '.join(p['name'] for p in sg.get('priorityGems') or []))
        elif 'PassiveTree' in tn:
            out.append('\n## Passive text\n' + rich(d.get('descriptionPoe2PassiveTree')) + rich(d.get('subTitlePoe2PassiveTree')))
            pt = v.get('passiveTree') or {'mainTree': {}}
            for tree in ('mainTree', 'set1Tree', 'set2Tree', 'ascendancyTree'):
                sl = (pt.get(tree) or {}).get('selectedSlugs') or []
                if not sl:
                    continue
                names = []
                for s in sl:
                    nd = nodes.get(s.replace('node-', ''), {'name': s, 'kind': '?', 'stats': []})
                    if nd['kind'] in ('notable', 'keystone', 'ascstart') or tree == 'ascendancyTree' or nd['name'] == '?':
                        names.append('%s(%s)' % (nd['name'], nd['kind']))
                out.append('%s: %d nodes; notable/keystone: %s' % (tree, len(sl), ', '.join(names)))
                if tree == 'mainTree':
                    small = {}
                    for s in sl:
                        nd = nodes.get(s.replace('node-', ''))
                        if nd and nd['kind'] == 'small':
                            small[nd['name']] = small.get(nd['name'], 0) + 1
                    out.append('  small: ' + ', '.join('%s x%d' % (k, n) for k, n in sorted(small.items())))
            out.append('priority: ' + ', '.join(p['name'] for p in (pt.get('mainTree') or {}).get('priorityList') or []))
            out.append('attr nodes: ' + json.dumps(sorted(set(a['attribute'] for a in pt.get('attributeNodes') or []))) + ' count=%d' % len(pt.get('attributeNodes') or []))
            out.append('jewels: ' + json.dumps(pt.get('jewels'), ensure_ascii=False)[:800])

cm_path = os.path.join(ASSET_ABS, 'comments.json')
if os.path.exists(cm_path):
    sec('COMMENTS (raw)')
    out.append(json.dumps(json.load(open(cm_path, encoding='utf-8')), ensure_ascii=False, indent=1)[:60000])

dump = os.path.join(ASSET_ABS, 'dump.md')
open(dump, 'w', encoding='utf-8').write('\n'.join(out))
print('written', dump, 'variants', len(variants_block['data']['childrenVariants']))
