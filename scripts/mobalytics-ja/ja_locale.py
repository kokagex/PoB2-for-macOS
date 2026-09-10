import re, os
import os
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','src','Locales','ja')
KV=re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')
def unesc(s): return s.replace('\\n','\n').replace('\\"','"').replace('\\\\','\\')
def load(path):
    d={}
    with open(path,encoding='utf-8') as f:
        for line in f:
            m=KV.match(line)
            if m: d[unesc(m.group(1))]=unesc(m.group(2))
    return d
def load_section(path, name):
    d={}; inside=False; depth=0
    with open(path,encoding='utf-8') as f:
        for line in f:
            if not inside:
                if re.match(r'^\t'+name+r' = \{', line): inside=True; depth=1
                continue
            depth+=line.count('{')-line.count('}')
            if depth<=0: break
            m=KV.match(line)
            if m: d[unesc(m.group(1))]=unesc(m.group(2))
    return d
BASE=load(ROOT+'/base_names.lua'); UNIQ=load(ROOT+'/unique_names.lua'); PNAME=load(ROOT+'/passive_names.lua')
MOD=load(ROOT+'/mod_stat_lines.lua'); SD=load(ROOT+'/stat_descriptions.lua')
SDC=load(ROOT+'/stat_descriptions_custom.lua'); SDM=load(ROOT+'/stat_descriptions_manual.lua')
GDESC=load(ROOT+'/gem_descriptions.lua'); GEMS=load_section(ROOT+'.lua','gems')
def _tmpl(line):
    caps=[]; PH='\x01'
    t=re.sub(r'\(-?[\d.]+--?[\d.]+\)', lambda m:(caps.append(m.group(0)),PH)[1], line)
    t=re.sub(r'#', lambda m:(caps.append('#'),PH)[1], t)
    t=re.sub(r'-?\d+\.?\d*', lambda m:(caps.append(m.group(0)),PH)[1], t)
    i=[0]
    def ph(m):
        r='{%d}'%i[0]; i[0]+=1; return r
    return re.sub(PH,ph,t), caps
def _lookup(k):
    return MOD.get(k) or SDM.get(k) or SD.get(k) or SDC.get(k)
SING=[(' metres',' metre'),(' seconds',' second'),(' Charges',' Charge'),(' Stages',' Stage'),(' Targets',' Target'),(' targets',' target'),(' Enemies',' Enemy'),(' enemies',' enemy'),(' Seals',' Seal'),(' times',' time'),(' Projectiles',' Projectile'),(' Bolts',' Bolt'),(' Aftershocks',' Aftershock'),(' Fissures',' Fissure'),(' Spikes',' Spike'),(' Remnants',' Remnant'),(' Spears',' Spear'),(' Beetles',' Beetle'),(' Plants',' Plant'),(' pustules',' pustule')]
PLUR=['metre','second','Charge','Stage','Target','Seal','Bolt']
def translate_mod(line):
    if not line: return line
    t,caps=_tmpl(line)
    tr=_lookup(t)
    if not tr:
        a=t
        for x,y in SING: a=a.replace(x,y)
        if a!=t: tr=_lookup(a)
    if not tr:
        a=t
        for w in PLUR: a=re.sub(r' %s(?=[\s\W]|$)'%w,' %ss'%w,a)
        if a!=t: tr=_lookup(a)
    if not tr: return line
    return re.sub(r'\{(\d+)\}', lambda m: caps[int(m.group(1))] if int(m.group(1))<len(caps) else m.group(0), tr)

_WS=re.compile(r'\s+')
_NOWS={}
for D in (MOD,SDM,SD,SDC):
    for k,v in D.items():
        _NOWS.setdefault(_WS.sub('',k),v)
MANUAL={
    'Minions have {0}% increased Immobilisation buildup':'ミニオンの移動不可蓄積が{0}%増加する',
    '{0}% of Recovery applied Instantly':'回復の{0}%が即座に適用される',
    'Grants Two Weapon Set Passive Skill Points':'武器セット用パッシブスキルポイントを2つ獲得',
    'Two Weapon Set Passive Skill Points':'武器セット用パッシブスキルポイント ×2',
    'Two Weapon Set Passive Skill Points, Skill Gem(Lv {0}), Delirium Drop':'武器セット用パッシブスキルポイント ×2、スキルジェム (Lv {0})、デリリウムドロップ',
    '{0}% increased Charm Charges gained, +{1} Charm Slot':'チャームの獲得チャージが{0}%増加する、チャームスロット +{1}',
    '{0}% increased Maximum Mana':'最大マナが{0}%増加する',
    '{0}% increased Maximum Life':'最大ライフが{0}%増加する',
    '+{0}% increased Global Armour, Evasion and Energy Shield':'グローバルのアーマー、回避、エナジーシールドが{0}%増加する',
}
def translate(line):
    if not line: return line
    r=translate_mod(line)
    if r!=line: return r
    t,caps=_tmpl(line)
    tr=MANUAL.get(t) or _NOWS.get(_WS.sub('',line)) or _NOWS.get(_WS.sub('',t))
    if not tr: return line
    return re.sub(r'\{(\d+)\}', lambda m: caps[int(m.group(1))] if int(m.group(1))<len(caps) else m.group(0), tr)
def translate_lines(lines):
    out=[]; i=0
    while i<len(lines):
        r=translate(lines[i])
        if r!=lines[i]:
            out.append(r); i+=1; continue
        done=False
        for j in range(i+1,min(i+4,len(lines))):
            comb='\n'.join(lines[i:j+1]); rc=translate(comb)
            if rc!=comb:
                out.append(rc); i=j+1; done=True; break
        if not done: out.append(lines[i]); i+=1
    return out
STAT_JA={'Armour':'アーマー','Energy Shield':'エナジーシールド','Evasion':'回避','Spirit':'スピリット','Item Level':'アイテムレベル','Quality':'品質','Quality (Defence Modifiers)':'品質 (防御 Mod)','Quality (Minion Modifiers)':'品質 (ミニオン Mod)','Minimum Physical Damage':'物理ダメージ (最小)','Maximum Physical Damage':'物理ダメージ (最大)','Critical Hit Chance':'クリティカルヒット率','Weapon Speed':'攻撃速度','Attacks per Second':'秒間攻撃回数','Block Chance':'ブロック率'}
def stat_label(s):
    if s in STAT_JA: return STAT_JA[s]
    m=re.match(r'Currently has (\d+) Charges$',s)
    if m: return '現在のチャージ数 %s'%m.group(1)
    m=re.match(r'Consumes (\d+) of (\d+) Charges on use$',s)
    if m: return '使用時に %s/%s チャージを消費'%(m.group(1),m.group(2))
    m=re.match(r'Recovers (\d+) (Life|Mana) over (\d+) Seconds$',s)
    if m: return '%s秒かけて%sを%s回復'%(m.group(3),'ライフ' if m.group(2)=='Life' else 'マナ',m.group(1))
    return s
def item_name(name, unique):
    return (UNIQ.get(name) if unique else BASE.get(name)) or None
def node_name(name): return PNAME.get(name)
def gem_name(name): return GEMS.get(name)
