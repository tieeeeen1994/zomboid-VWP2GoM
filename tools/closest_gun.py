# Usage: python3 tools/closest_gun.py PistolGlock Pistol3 ...  (needs items.json from item_stats.py)
import json,sys
d=json.load(open('items.json'))
CAL={'base:bullets_9mm':'9x19','base:bullets_45':'45','base:bullets_44':'44','base:bullets_556':'556','base:bullets_308':'308','mvgi:bullets_762':'762x39','base:shotgun_shells':'12g','swmg:shell_12g':'12g','base:bullets_38':'38357','base:bullets_357':'38357','base:bullets_3030':'3030',
 'swmg:bullet_9x19':'9x19','swmg:bullet_45':'45','swmg:bullet_44':'44','swmg:bullet_556x45':'556','swmg:bullet_223':'556','swmg:bullet_308':'308','swmg:bullet_762x51':'308','swmg:bullet_762x39':'762x39','swmg:bullet_357':'38357','swmg:bullet_38':'38357','swmg:bullet_3030':'3030','swmg:bullet_50':'50','swmg:bullet_545x39':'545','swmg:bullet_3006':'3006','swmg:bullet_4570':'4570','swmg:bullet_762x54':'762x54','swmg:bullet_9x39':'9x39'}
NUM=[('mindamage',2),('maxdamage',2),('criticalchance',1),('critdmgmultiplier',1),('hitchance',1.5),('aimingtime',1),('recoildelay',1),('maxrange',.5),('minangle',.5),('projectilecount',3),('soundradius',.5),('weight',.5),('jamgunchance',.5),('stoppower',.5)]
def f(p,k):
    try: return float(p.get(k,'nan'))
    except: return float('nan')
def cal(p):
    a=p.get('ammotype','').lower()
    for k,v in CAL.items():
        if a.startswith(k): return v
    return a
guns={k:p for k,p in d['gom'].items() if p.get('itemtype')=='base:weapon' and p.get('ranged','').lower()=='true' and 'round_40mm' not in p.get('ammotype','') and not k.endswith(('_Weapon',))}
rng={}
for k,_ in NUM:
    vals=[f(p,k) for p in list(guns.values())+list(d['mvg'].values()) if f(p,k)==f(p,k)]
    rng[k]=(max(vals)-min(vals)) or 1
def modes(p): return set((p.get('firemodepossibilities') or p.get('firemode') or 'Single').split('/'))
def dist(a,b):
    s=0
    for k,w in NUM:
        x,y=f(a,k),f(b,k)
        if x!=x or y!=y: continue
        s+=w*abs(x-y)/rng[k]
    import math
    ca,cb=f(a,'maxammo'),f(b,'maxammo')
    s+=1.5*abs(math.log(ca)-math.log(cb))/math.log(100)
    s+=1.0*(a.get('weaponreloadtype')!=b.get('weaponreloadtype'))
    ma,mb=modes(a),modes(b); s+=1.0*(1-len(ma&mb)/len(ma|mb))
    s+=1.5*(cal(a)!=cal(b))
    return s
for name in sys.argv[1:]:
    a=d['mvg']['Base.'+name]
    r=sorted((dist(a,b),k) for k,b in guns.items())[:6]
    print(name, cal(a), '->', ', '.join(f"{k.split('.')[1]}({cal(guns[k])}) {v:.2f}" for v,k in r))
