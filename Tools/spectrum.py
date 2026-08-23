import math, cmath
from synth_port import *

def fft(x):
    n=len(x)
    if n & (n-1): raise ValueError("power of two required")
    j=0
    x=list(x)
    for i in range(1,n):
        bit=n>>1
        while j & bit: j^=bit; bit>>=1
        j|=bit
        if i<j: x[i],x[j]=x[j],x[i]
    ln=2
    while ln<=n:
        ang=-2*math.pi/ln; w=cmath.exp(1j*ang)
        for i in range(0,n,ln):
            wn=1+0j
            for k in range(ln//2):
                u=x[i+k]; t=wn*x[i+k+ln//2]
                x[i+k]=u+t; x[i+k+ln//2]=u-t; wn*=w
            
        ln<<=1
    return x

def spectral_peaks(seg, sr=SR, n=4096, top=4):
    seg=list(seg[:n])+[0.0]*(n-len(seg))
    win=[0.5-0.5*math.cos(2*math.pi*i/(n-1)) for i in range(n)]
    X=fft([complex(seg[i]*win[i],0) for i in range(n)])
    mag=[abs(X[i]) for i in range(n//2)]
    # smooth so we find formant envelopes not individual harmonics
    k=9; sm=[sum(mag[max(0,i-k):i+k+1])/len(mag[max(0,i-k):i+k+1]) for i in range(len(mag))]
    peaks=[]
    for i in range(3,len(sm)-3):
        if sm[i]>sm[i-1] and sm[i]>=sm[i+1] and sm[i]>max(sm)*0.05:
            peaks.append((sm[i], i*sr/n))
    peaks.sort(reverse=True)
    out=sorted(f for _,f in peaks[:top])
    return out

print("Sustained vowel check — steady voice, formantScale=1.0, expecting textbook values")
flat = Voice(fundamental=110, formant_scale=1.0, tempo=1.1, swing=0, scale=[0], melody=[0],
             vibrato_depth=0.0, breathiness=0.02, growl=0.0, declination=0.0, brightness=0.5)
print(f"{'vowel':6s} {'target F1/F2/F3':22s} {'measured peaks':30s}")
for vw, tgt in VOWEL_FORMANTS.items():
    sig = render(vw, flat)                       # single open syllable, no onset
    mid = sig[int(0.25*len(sig)):]
    pk = spectral_peaks(mid)
    t3 = (tgt[0], tgt[1], tgt[2]*(0.9+0.3*0.5))  # f3Lift applied in build_control
    print(f"  {vw:4s} {str(tuple(round(x) for x in t3)):22s} {str([round(f) for f in pk]):30s}")

print("\nformantScale check (should shift everything proportionally):")
for k in (0.82, 1.0, 1.28):
    v2 = Voice(fundamental=110, formant_scale=k, tempo=1.1, swing=0, scale=[0], melody=[0],
               vibrato_depth=0.0, breathiness=0.02, growl=0.0, declination=0.0)
    pk = spectral_peaks(render("a", v2)[int(0.25*SR*0.9):])
    print(f"  scale={k}: expect F1≈{730*k:.0f} F2≈{1090*k:.0f} -> measured {[round(f) for f in pk]}")
