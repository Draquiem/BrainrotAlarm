import math
from synth_port import *
from spectrum import fft

N=16384
def band_db(sig, lo, hi):
    seg=list(sig[:N]); seg += [0.0]*(N-len(seg))
    win=[0.5-0.5*math.cos(2*math.pi*i/(N-1)) for i in range(N)]
    X=fft([complex(seg[i]*win[i],0) for i in range(N)])
    e=0.0
    for i in range(int(lo*N/SR), int(hi*N/SR)+1):
        e += abs(X[i])**2
    return 10*math.log10(max(e,1e-30))

dense = Voice(fundamental=110, formant_scale=1.0, tempo=0.9, swing=0, scale=[0], melody=[0],
              vibrato_depth=0.0, breathiness=0.02, growl=0.0, declination=0.0, brightness=0.5)
print("Band energy relative to F1 band (real speech: F2 is 3-15 dB under F1)")
print(f"{'vowel':6s} {'F1dB':>7s} {'F2':>7s} {'F3':>7s} {'null@F2/2':>10s}")
for vw,(t1,t2,t3) in VOWEL_FORMANTS.items():
    sig = render(vw, dense)
    st = sig[int(len(sig)*0.30):int(len(sig)*0.80)]
    t3l=t3*(0.9+0.3*0.5)
    e1=band_db(st,t1-90,t1+90); e2=band_db(st,t2-110,t2+110); e3=band_db(st,t3l-160,t3l+160)
    # a control band deliberately between formants
    mid=(t1+t2)/2
    ctl=band_db(st, mid-60, mid+60) if abs(t2-t1)>400 else band_db(st, t3l+700, t3l+900)
    print(f"  {vw:4s} {e1:7.1f} {e2-e1:+7.1f} {e3-e1:+7.1f} {ctl-e1:+10.1f}")

print("\nBrightness knob should lift F2/F3:")
for b in (0.3, 0.5, 0.8):
    v=Voice(fundamental=110,formant_scale=1.0,tempo=0.9,swing=0,scale=[0],melody=[0],
            vibrato_depth=0.0,breathiness=0.02,growl=0.0,declination=0.0,brightness=b)
    sig=render("a", v); st=sig[int(len(sig)*0.3):int(len(sig)*0.8)]
    e1=band_db(st,640,820); e2=band_db(st,980,1200)
    print(f"  brightness={b}: F2-F1 = {e2-e1:+.1f} dB")
