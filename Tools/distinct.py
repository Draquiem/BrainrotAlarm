import math
from synth_port import *
import synth_port as sp
from roster import ROSTER
from spectrum import fft

N=8192
def features(sig, chant):
    # 10 log-spaced band energies (timbre fingerprint) over the whole render
    hop=N//2; bands=[0.0]*10
    edges=[120*(2**(i*0.48)) for i in range(11)]
    frames=0
    for st in range(0, max(1,len(sig)-N), hop):
        seg=sig[st:st+N]
        if len(seg)<N: break
        win=[0.5-0.5*math.cos(2*math.pi*i/(N-1)) for i in range(N)]
        X=fft([complex(seg[i]*win[i],0) for i in range(N)])
        for b in range(10):
            lo=int(edges[b]*N/SR); hi=min(N//2,int(edges[b+1]*N/SR))
            if hi>lo: bands[b]+=sum(abs(X[i])**2 for i in range(lo,hi))
        frames+=1
    tot=sum(bands) or 1
    bands=[10*math.log10(max(b/tot,1e-9)) for b in bands]
    dur=len(sig)/SR
    nsyl=sum(len(w) for w in parse(chant))
    rate=nsyl/dur
    return bands, dur, rate

print("Rendering roster and extracting timbre fingerprints...")
feats={}
for cid,name,chant,fam,v in ROSTER:
    sig=render(chant,v)
    bands,dur,rate=features(sig,chant)
    f0=sum(v.fundamental*(2**(v.semitone_at(i)/12)) for i in range(len(v.melody)))/len(v.melody)
    feats[cid]=(bands, math.log2(f0), rate, dur, name, fam)
    print(f"  {cid:12s} f0~{f0:6.1f}Hz  {rate:4.2f} syl/s  {dur:4.2f}s")

def dist(a,b):
    ba,f0a,ra,da,_,_=feats[a]; bb,f0b,rb,db,_,_=feats[b]
    tim=math.sqrt(sum((x-y)**2 for x,y in zip(ba,bb)))/10.0
    return math.sqrt(tim**2 + (4*(f0a-f0b))**2 + (1.5*(ra-rb))**2 + (1.2*(da-db))**2)

ids=[c[0] for c in ROSTER]
pairs=sorted(((dist(a,b),a,b) for i,a in enumerate(ids) for b in ids[i+1:]))
print("\n10 most-confusable pairs (low = risk of an unfair round):")
for d,a,b in pairs[:10]:
    fa=feats[a][5]; fb=feats[b][5]
    print(f"  {d:5.2f}  {a:12s} vs {b:12s}  {'[SAME FAMILY]' if fa==fb else ''}")
print(f"\nmedian pair distance {pairs[len(pairs)//2][0]:.2f}, max {pairs[-1][0]:.2f}")
worst=pairs[0][0]
print(f"tightest pair {worst:.2f} -> {'OK' if worst>1.0 else 'TOO CLOSE, retune'}")
