import html, math, re

def parse_tree(path):
    t = open(path, encoding='utf-8').read()
    ci = t.find('\n\tconstants={'); gi = t.find('\n\tgroups={'); ni = t.find('\n\tnodes={')
    const = t[ci:gi]
    def lua_list(name):
        m = re.search(r'\n\t\t' + name + r'=\{(.*?)\n\t\t\}', const, re.S)
        return m.group(1)
    radii = [float(v) for v in re.findall(r'\[\d+\]=(-?[\d.]+)', lua_list('orbitRadii'))]
    angles = []
    for m in re.finditer(r'\n\t\t\t\[\d+\]=\{(.*?)\n\t\t\t\}', lua_list('orbitAnglesByOrbit'), re.S):
        angles.append([float(v) for v in re.findall(r'\[\d+\]=(-?[\d.]+)', m.group(1))])
    groups = {}
    for m in re.finditer(r'\n\t\t\[(\d+)\]=\{(.*?)\n\t\t\},', t[gi:ni], re.S):
        b = m.group(2)
        groups[int(m.group(1))] = (float(re.search(r'\n\t\t\tx=(-?[\d.]+)', b).group(1)), float(re.search(r'\n\t\t\ty=(-?[\d.]+)', b).group(1)))
    nodes = {}
    for m in re.finditer(r'\n\t\t\[(\d+)\]=\{(.*?)\n\t\t\},', t[ni:], re.S):
        b = m.group(2)
        nid = int(m.group(1))
        g = groups[int(re.search(r'\n\t\t\tgroup=(\d+)', b).group(1))]
        o = int(re.search(r'\n\t\t\torbit=(\d+)', b).group(1)); oi = int(re.search(r'\n\t\t\torbitIndex=(\d+)', b).group(1))
        a = angles[o][oi]; r = radii[o]
        st = b.split('stats={')[1].split('\n\t\t\t}')[0] if 'stats={' in b else ''
        asc = re.search(r'ascendancyName="([^"]*)"', b)
        nodes[nid] = {
            'id': nid, 'x': g[0] + math.sin(a) * r, 'y': g[1] - math.cos(a) * r, 'gx': g[0], 'gy': g[1], 'o': o, 'ang': a,
            'name': (re.search(r'\n\t\t\tname="([^"]*)"', b) or [None, '?'])[1],
            'icon': (re.search(r'\n\t\t\ticon="([^"]*)"', b) or [None, None])[1],
            'stats': re.findall(r'\[\d+\]="([^"]*)"', st),
            'notable': 'isNotable=true' in b, 'keystone': 'isKeystone=true' in b,
            'asc': asc.group(1) if asc else None, 'ascstart': 'isAscendancyStart' in b,
            'jewel': 'isJewelSocket=true' in b, 'attr': 'isAttribute=true' in b,
            'image': 'isOnlyImage=true' in b, 'mcopt': 'isMultipleChoiceOption=true' in b,
            'classstart': 'classesStart' in b,
            'conn': [(int(i), int(o_)) for i, o_ in re.findall(r'id=(\d+),\s*orbit=(-?\d+)', b)],
        }
    return nodes, radii

def _arc(n1, n2, r, cx, cy):
    cross = (n1['x'] - cx) * (n2['y'] - cy) - (n1['y'] - cy) * (n2['x'] - cx)
    return 'M%.0f %.0fA%.0f %.0f 0 0 %d %.0f %.0f' % (n1['x'], n1['y'], r, r, 1 if cross > 0 else 0, n2['x'], n2['y']), (cx, cy)

def edge_path(n1, n2, orbit, radii):
    if orbit != 0 and abs(orbit) < len(radii):
        r = radii[abs(orbit)]
        dx, dy = n2['x'] - n1['x'], n2['y'] - n1['y']
        dist = math.hypot(dx, dy)
        if 0 < dist < r * 2:
            perp = math.sqrt(r * r - dist * dist / 4) * (1 if orbit > 0 else -1)
            return _arc(n1, n2, r, n1['x'] + dx / 2 + perp * dy / dist, n1['y'] + dy / 2 - perp * dx / dist)
    elif orbit == 0 and (n1['gx'], n1['gy']) == (n2['gx'], n2['gy']) and n1['o'] == n2['o'] and n1['o'] > 0:
        d = abs(n1['ang'] - n2['ang'])
        if d < math.pi - 1e-6 or (2 * math.pi - d) < math.pi - 1e-6:
            return _arc(n1, n2, radii[n1['o']], n1['gx'], n1['gy'])
    return 'M%.0f %.0fL%.0f %.0f' % (n1['x'], n1['y'], n2['x'], n2['y']), None

def edges_of(nodes, ids):
    seen = {}
    for nid in ids:
        n = nodes[nid]
        for cid, orb in n['conn']:
            o = nodes.get(cid)
            if o and cid in ids and cid != nid and o['asc'] == n['asc'] and not (o['classstart'] and n['classstart']) and not (o['image'] or n['image']):
                key = (min(nid, cid), max(nid, cid))
                if key not in seen:
                    seen[key] = (nid, cid, orb)
    return list(seen.values())

def base_layer(nodes, radii):
    main = {nid for nid, n in nodes.items() if not n['asc'] and not n['mcopt']}
    paths = []
    for a, b, orb in edges_of(nodes, main):
        paths.append(edge_path(nodes[a], nodes[b], orb, radii)[0])
    out = ['<g id="tb"><path class="be" d="%s"/>' % ''.join(paths)]
    for nid in sorted(main):
        n = nodes[nid]
        if n['image']:
            continue
        cls = 'bk' if n['keystone'] else 'bn' if n['notable'] else 'bj' if n['jewel'] else 'bc' if n['classstart'] else 'bs'
        out.append('<circle class="%s" cx="%.0f" cy="%.0f"/>' % (cls, n['x'], n['y']))
    out.append('</g>')
    return ''.join(out)

def asc_base(nodes, radii, ascname):
    ids = {nid for nid, n in nodes.items() if n['asc'] == ascname and not n['mcopt']}
    paths = [edge_path(nodes[a], nodes[b], orb, radii)[0] for a, b, orb in edges_of(nodes, ids)]
    out = ['<path class="be" d="%s"/>' % ''.join(paths)]
    for nid in sorted(ids):
        n = nodes[nid]
        out.append('<circle class="%s" cx="%.0f" cy="%.0f"/>' % ('bn' if (n['notable'] or n['ascstart']) else 'bs', n['x'], n['y']))
    return ''.join(out), ids

def node_radius(n):
    return 120 if n['keystone'] else 100 if n['notable'] or n['ascstart'] else 70 if n['jewel'] else 55

def alloc_layer(nodes, radii, ids, img_src, tip_of, attr_of, cls_prefix='al', with_start=False):
    out = []
    ids = [i for i in ids if i in nodes]
    idset = set(ids)
    edge_ids = set(idset)
    if with_start:
        edge_ids |= {nid for nid, n in nodes.items() if n['classstart'] and any(c in idset for c, _ in n['conn'])}
        edge_ids |= {c for i in idset for c, _ in nodes[i]['conn'] if c in nodes and nodes[c]['classstart']}
    paths = []
    for a, b, orb in edges_of(nodes, edge_ids):
        paths.append(edge_path(nodes[a], nodes[b], orb, radii)[0])
    if paths:
        out.append('<path class="%se" d="%s"/>' % (cls_prefix, ''.join(paths)))
    for nid in ids:
        n = nodes[nid]
        r = node_radius(n)
        kind = 'k' if n['keystone'] else 'n' if (n['notable'] or n['ascstart']) else 'j' if n['jewel'] else 's'
        src = img_src(n)
        tip = html.escape(tip_of(n), quote=True)
        g = ['<g class="tn %s%s" data-tip="%s">' % (cls_prefix, kind, tip)]
        g.append('<circle class="ring" cx="%.0f" cy="%.0f" r="%d"/>' % (n['x'], n['y'], r))
        if src:
            g.append('<image href="%s" x="%.0f" y="%.0f" width="%d" height="%d" clip-path="circle(48%%)" preserveAspectRatio="xMidYMid slice"/>' % (src, n['x'] - r * 0.86, n['y'] - r * 0.86, r * 1.72, r * 1.72))
        lab = attr_of(n) if n['attr'] else None
        if lab:
            g.append('<text class="alab" x="%.0f" y="%.0f">%s</text>' % (n['x'], n['y'] + 4, html.escape(lab)))
        g.append('</g>')
        out.append(''.join(g))
    return ''.join(out)

def bbox(nodes, ids, pad=600, min_w=3200):
    xs = [nodes[i]['x'] for i in ids if i in nodes]; ys = [nodes[i]['y'] for i in ids if i in nodes]
    if not xs:
        return (-1000, -1000, 2000, 2000)
    x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad
    w, h = x1 - x0, y1 - y0
    if w < min_w:
        cx = (x0 + x1) / 2; x0, w = cx - min_w / 2, min_w
    if h < min_w * 0.6:
        cy = (y0 + y1) / 2; y0, h = cy - min_w * 0.3, min_w * 0.6
    return (x0, y0, w, h)

CSS = """
.tree{position:relative;background:#07060d;border:1px solid var(--bd2);border-radius:10px;overflow:hidden;margin-bottom:14px}
.tree svg{display:block;width:100%;height:520px;cursor:grab;touch-action:none}
.tree svg.drag{cursor:grabbing}
.tree.asc svg{height:300px}
.tree .tbar{position:absolute;top:8px;right:8px;display:flex;gap:6px;z-index:2}
.tree .tbar button{background:#1b1730;color:#ddd;border:1px solid var(--bd2);border-radius:6px;padding:3px 9px;font-size:12px;cursor:pointer}
.tree .tbar button:hover{border-color:var(--gold);color:#fff}
.tree .tleg{position:absolute;left:10px;bottom:8px;display:flex;flex-wrap:wrap;gap:10px;font-size:11px;color:var(--muted);pointer-events:none}
.tree .tleg i{display:inline-block;width:10px;height:10px;border-radius:50%;vertical-align:-1px;margin-right:4px}
.be{fill:none;stroke:#2a2740;stroke-width:14}
.bs{r:30px;fill:#1d1a2e;stroke:#3a3555;stroke-width:6}.bn{r:60px;fill:#221d38;stroke:#4a4380;stroke-width:8}.bk{r:80px;fill:#2a1d1d;stroke:#6a3a2a;stroke-width:8}.bj{r:45px;fill:#12202a;stroke:#2a5a7a;stroke-width:8}.bc{r:120px;fill:#1a1a1a;stroke:#555;stroke-width:10}
.ale{fill:none;stroke:#e6c25a;stroke-width:26;stroke-linecap:round}
.w1e{fill:none;stroke:#5ad0ff;stroke-width:26;stroke-linecap:round;stroke-dasharray:60 40}
.w2e{fill:none;stroke:#ff9a5a;stroke-width:26;stroke-linecap:round;stroke-dasharray:60 40}
.ace{fill:none;stroke:#c697ff;stroke-width:22;stroke-linecap:round}
.tn{cursor:pointer}.tn .ring{fill:#0b0b14;stroke:#e6c25a;stroke-width:10}
.tn.aln .ring,.tn.acn .ring{stroke:#ffd76a;stroke-width:14}.tn.alk .ring{stroke:#ff7a3a;stroke-width:16}.tn.alj .ring{stroke:#5ad0ff;stroke-width:12}
.tn.acs .ring,.tn.acn .ring{stroke:#c697ff}.tn.acn .ring{stroke-width:14}
.tn.w1s .ring,.tn.w1n .ring{stroke:#5ad0ff}.tn.w2s .ring,.tn.w2n .ring{stroke:#ff9a5a}
.tn:hover .ring{stroke:#fff}
.alab{fill:#fff;font:700 52px sans-serif;text-anchor:middle;pointer-events:none}
"""

JS = r"""
document.querySelectorAll('.tree svg').forEach(function(svg){
  var vb0=svg.getAttribute('viewBox').split(' ').map(Number);var vb=vb0.slice();
  function apply(){svg.setAttribute('viewBox',vb.join(' '));}
  svg.addEventListener('wheel',function(e){e.preventDefault();var r=svg.getBoundingClientRect();var mx=vb[0]+(e.clientX-r.left)/r.width*vb[2],my=vb[1]+(e.clientY-r.top)/r.height*vb[3];var f=e.deltaY>0?1.15:1/1.15;var w=Math.min(60000,Math.max(800,vb[2]*f));var h=vb[3]*w/vb[2];vb=[mx-(mx-vb[0])*w/vb[2],my-(my-vb[1])*h/vb[3],w,h];apply();},{passive:false});
  var drag=null;
  svg.addEventListener('pointerdown',function(e){drag=[e.clientX,e.clientY,vb.slice()];svg.classList.add('drag');svg.setPointerCapture(e.pointerId);});
  svg.addEventListener('pointermove',function(e){if(!drag)return;var r=svg.getBoundingClientRect();vb[0]=drag[2][0]-(e.clientX-drag[0])/r.width*vb[2];vb[1]=drag[2][1]-(e.clientY-drag[1])/r.height*vb[3];apply();});
  function up(e){if(drag){drag=null;svg.classList.remove('drag');}}
  svg.addEventListener('pointerup',up);svg.addEventListener('pointercancel',up);
  var wrap=svg.parentElement;var bar=wrap.querySelector('.tbar');
  if(bar){bar.querySelector('.rst').addEventListener('click',function(){vb=vb0.slice();apply();});
    var all=bar.querySelector('.all');if(all){var full=all.getAttribute('data-vb').split(' ').map(Number);all.addEventListener('click',function(){vb=full.slice();apply();});}}
});
"""
