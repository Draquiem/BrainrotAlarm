import math
import synth_port as sp
from synth_port import *

cases = [("tralalero","Tra-la-le-ro Tra-la-la",GOOFBALL),
         ("bombardiro","Bom-bar-di-ro Cro-co-di-lo",BRUISER),
         ("tungtung","Tung Tung Tung Sa-hur",CHANTER),
         ("ballerina","Bal-le-ri-na Cap-puc-ci-na",DIVA),
         ("chimpanzini","Chim-pan-zi-ni Ba-na-ni-ni",SQUEAKER),
         ("lirili","Li-ri-lì La-ri-là",EERIE)]

def report(tag):
    print(f"--- {tag}: makeup={sp.SOURCE_MAKEUP} burst={sp.BURST_LEVEL} noiseBus={sp.NOISE_BUS}")
    tot=[]
    for name,chant,v in cases:
        sig = render(chant, v)
        a = sorted(abs(s) for s in sig)
        pk=a[-1]; rms=math.sqrt(sum(s*s for s in sig)/len(sig))
        # loudness of the voiced parts only: RMS over samples above the 40th pct
        loud=[s for s in sig if abs(s)>0.02]
        lrms=math.sqrt(sum(s*s for s in loud)/len(loud)) if loud else 0
        crest=20*math.log10(pk/max(rms,1e-9))
        tot.append(crest)
        print(f"  {name:12s} rms={rms:.3f} voicedRms={lrms:.3f} crest={crest:5.1f}dB active={len(loud)/len(sig)*100:4.1f}%")
    print(f"  mean crest {sum(tot)/len(tot):.1f} dB   (speech ≈ 12-18 dB)")
report("after fixes")
