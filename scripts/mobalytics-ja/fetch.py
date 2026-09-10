import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
CFG = json.load(open(sys.argv[1], encoding='utf-8'))
ASSET_ABS = os.path.join(REPO, CFG['asset_dir'])
os.makedirs(ASSET_ABS, exist_ok=True)

raw_path = os.path.join(ASSET_ABS, 'raw.html')
if not (os.path.exists(raw_path) and os.path.getsize(raw_path) > 0):
    r = subprocess.run(['curl', '-sL', '-m', '120', '-H', 'X-Return-Format: html', 'https://r.jina.ai/' + CFG['url'], '-o', raw_path, '-w', '%{http_code}'], capture_output=True, text=True)
    print('fetch', r.stdout, os.path.getsize(raw_path) if os.path.exists(raw_path) else 0)
raw = open(raw_path, encoding='utf-8', errors='replace').read()

m = re.search(r'window\.__PRELOADED_STATE__\s*=\s*(.*?)\s*</script>', raw, re.S)
if not m:
    sys.exit('__PRELOADED_STATE__ not found in raw.html (Cloudflare block or page format change)')
blob = m.group(1).strip().rstrip(';')
if blob.startswith('JSON.parse('):
    blob = json.loads(blob[len('JSON.parse('):-1])
state = json.loads(blob)
json.dump(state, open(os.path.join(ASSET_ABS, 'state.json'), 'w', encoding='utf-8'), ensure_ascii=False)

found = []
def walk(o, path):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == 'userGeneratedDocumentBySlug' and isinstance(v, dict) and isinstance(v.get('data'), dict) and 'content' in v['data']:
                found.append((path + '/' + k, v['data']))
            elif k == 'comments' and isinstance(v, list) and v and isinstance(v[0], dict):
                found.append((path + '/' + k, v))
            walk(v, path + '/' + k)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(v, path + '/%d' % i)
walk(state, '')

docs = [d for p, d in found if p.endswith('userGeneratedDocumentBySlug')]
comments = [d for p, d in found if p.endswith('/comments')]
if not docs:
    sys.exit('userGeneratedDocumentBySlug not found')
doc = docs[0]
json.dump(doc, open(os.path.join(ASSET_ABS, 'doc.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
json.dump(comments[0] if comments else [], open(os.path.join(ASSET_ABS, 'comments.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('doc', doc['data']['name'], 'updated', doc.get('updatedAt'), 'variants', len(doc['data']['buildVariants']['values']), 'comments', len(comments[0]) if comments else 0)
print('tags', [t['name'] for t in doc['tags']['data']])
