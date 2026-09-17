import re,sys,os,json
KEYS=['ItemType','DisplayName','Type','PartType','AmmoType','MagazineType','MaxAmmo','ClipSize','AmmoBox','MountOn','FireMode','FireModePossibilities','WeaponReloadType','SubCategory','Categories','Tags','ProjectileCount','Weight','CanStack','Count','OnCreate','DisplayCategory','ModelWeaponPart','WorldStaticModel','GunType','ManuallyRemoveSpentRounds','RackAfterShoot','HaveChamber','InsertAllBulletsReload','AttachmentType','Icon','StaticModel','MaxRange','MinDamage','MaxDamage','ReplaceOnUse','CanAttach']
def strip_comments(s):
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S)
    return s
def parse(path):
    txt=strip_comments(open(path,encoding='utf-8',errors='ignore').read())
    mod=re.search(r'module\s+(\w+)',txt); mod=mod.group(1) if mod else '?'
    out=[]
    for m in re.finditer(r'^\s*item\s+([\w\.\-&]+)\s*\{',txt,flags=re.M):
        i=m.end(); depth=1
        while depth and i<len(txt):
            if txt[i]=='{':depth+=1
            elif txt[i]=='}':depth-=1
            i+=1
        body=txt[m.end():i-1]
        d={'_type':mod+'.'+m.group(1),'_file':os.path.basename(path)}
        for line in body.split('\n'):
            line=line.strip().rstrip(',')
            if '=' in line and not line.startswith('//'):
                k,v=line.split('=',1); k=k.strip(); v=v.strip()
                if k in KEYS: d[k]=v
        out.append(d)
    return out
res=[]
for root in sys.argv[1:]:
    for dp,dn,fn in os.walk(root):
        for f in sorted(fn):
            if f.endswith('.txt'): res+=parse(os.path.join(dp,f))
for d in res:
    print(' | '.join(f'{k}={v}' if not k.startswith('_') else v for k,v in d.items()))
