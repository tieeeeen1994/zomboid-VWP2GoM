import re,glob,os,json,sys
# Usage: python3 tools/item_stats.py  (writes items.json in the current directory)
W="/Users/blanc/Library/Application Support/Steam/steamapps/workshop/content/108600"
VAN="/Users/blanc/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/media/scripts"
def items(files):
    out={}
    for f in files:
        t=open(f,errors='ignore').read()
        t=re.sub(r'/\*.*?\*/','',t,flags=re.S)
        for mm in re.finditer(r'module\s+(\w+)\s*\{',t):
            pass
        mod=re.search(r'module\s+(\w+)',t); mod=mod.group(1) if mod else '?'
        for m in re.finditer(r'^\s*item\s+([\w\.\-&]+)\s*\{',t,flags=re.M):
            i=m.end();d=1
            while d and i<len(t):
                d+= (t[i]=='{') - (t[i]=='}'); i+=1
            body=t[m.end():i-1]
            props=out.setdefault(mod+'.'+m.group(1),{})
            for line in body.split('\n'):
                line=line.strip().rstrip(',')
                if '=' in line:
                    k,v=line.split('=',1); k=k.strip().lower(); v=v.strip()
                    if k=='modelweaponpart': continue
                    props[k]=v
    return out
def files(root): return sorted(glob.glob(root+'/**/*.txt',recursive=True))
van=items(files(VAN))
mvg=items(files(W+"/3773834525/mods/MarzVanillaGuns/42.18/media/scripts"))
gom=items(files(W+"/3722134990/mods/GunsOfMarz/42.16/media/scripts"))
merged={}
for k,v in mvg.items():
    base=dict(van.get(k,{})); base.update(v); merged[k]=base
json.dump({'van':van,'mvg':merged,'gom':gom},open('items.json','w'))
print(len(van),len(merged),len(gom))
