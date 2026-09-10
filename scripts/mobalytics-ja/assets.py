import json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
CFG = json.load(open(sys.argv[1], encoding='utf-8'))
ASSET_ABS = os.path.join(REPO, CFG['asset_dir'])
doc = json.load(open(os.path.join(ASSET_ABS, 'doc.json'), encoding='utf-8'))
CDN = 'https://cdn.mobalytics.gg/assets/poe-2/images/game/'

tree = open(os.path.join(REPO, 'src/TreeData/0_5/tree.lua'), encoding='utf-8').read()
i = tree.find('\n\tnodes={'); icons = {}
for m in re.finditer(r'\[(\d+)\]=\{(.*?)\n\t\t\},', tree[i:], re.S):
    ic = re.search(r'icon="([^"]*)"', m.group(2))
    if ic:
        icons[m.group(1)] = ic.group(1)

urls = set()
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ('iconURL', 'iconUrl', 'icon', 'imageUrl') and isinstance(v, str) and v.startswith('http'):
                urls.add(v)
            walk(v)
    elif isinstance(o, list):
        for v in o:
            walk(v)
walk(doc)
for v in doc['data']['buildVariants']['values']:
    pt = v.get('passiveTree') or {}
    for key in ('mainTree', 'ascendancyTree', 'set1Tree', 'set2Tree'):
        for s in ((pt.get(key) or {}).get('selectedSlugs') or []):
            nid = s.split('-')[1]
            if nid in icons:
                urls.add(CDN + icons[nid].replace('.dds', '.webp'))
tags = {t.get('groupSlug'): t for t in doc['tags']['data']}
pattern = (((doc.get('typeData') or {}).get('displayMetadata') or {}).get('coverImageUrlPattern')) or ''
if pattern and 'class' in tags and 'ascendancy' in tags:
    urls.add(pattern.replace('{{class}}', tags['class']['slug']).replace('{{ascendancy}}', tags['ascendancy']['slug']))
urls = {u.replace('.avif', '.webp') if u.endswith('.avif') else u for u in urls}

def local(u):
    p = u.split('/images/game/')[-1] if '/images/game/' in u else u.split('/assets/')[-1]
    p = p.split('?')[0]
    return re.sub(r'[^A-Za-z0-9._-]', '_', p)

def fetch(u):
    f = os.path.join(ASSET_ABS, local(u))
    if os.path.exists(f) and os.path.getsize(f) > 0:
        return (u, 'cached')
    r = subprocess.run(['curl', '-s', '-m', '40', '-o', f, '-w', '%{http_code}', u], capture_output=True, text=True)
    if r.stdout != '200' and os.path.exists(f):
        os.remove(f)
    return (u, r.stdout)

with ThreadPoolExecutor(8) as ex:
    res = list(ex.map(fetch, sorted(urls)))
bad = [r for r in res if r[1] not in ('200', 'cached')]
print('total', len(urls), 'cached', sum(1 for r in res if r[1] == 'cached'), 'bad', len(bad))
for b in bad:
    print(' ', b)
json.dump({u: local(u) for u in urls}, open(os.path.join(ASSET_ABS, 'assetmap.json'), 'w'), indent=0)
