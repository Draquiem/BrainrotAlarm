import math, cmath
from synth_port import *
from spectrum import fft

def resp_peaks(sig, n=16384, top=3, smooth=0):
    seg=list(sig[:n])+[0.0]*(max(0,n-len(sig)))
    X=fft([complex(v,0) for v in seg[:n]])
    mag=[abs(X[i]) for i in range(n//2)]
    if smooth:
        mag=[sum(mag[max(0,i-smooth):i+smooth+1])/len(mag[max(0,i-smooth):i+smooth+1]) for i in range(len(mag))]
    peaks=[]
    for i in range(2,len(mag)-2):
        if mag[i]>mag[i-1] and mag[i]>=mag[i+1] and mag[i]>max(mag)*0.02:
            peaks.append((mag[i], i*SR/n))
    peaks.sort(reverse=True)
    return sorted(f for _,f in peaks[:top])

print("=== 1. Formant filter bank impulse response (isolates the resonators) ===")
print(f"{'vowel':6s} {'target F1/F2/F3':24s} {'measured':24s} {'err':10s}")
ok=True
for vw,(t1,t2,t3) in VOWEL_FORMANTS.items():
    b1=Biquad(SR); b2=Biquad(SR); b3=Biquad(SR)
    t3l = t3*(0.9+0.3*0.5)
    b1.bandpass(t1,70); b2.bandpass(t2,100); b3.bandpass(t3l,150)
    g2=0.55+0.30*0.5; g3=0.20+0.35*0.5
    ir=[]
    for i in range(16384):
        x = 1.0 if i==0 else 0.0
        ir.append(b1.process(x)+b2.process(x)*g2+b3.process(x)*g3)
    m=resp_peaks(ir, top=3)
    tgt=(t1,t2,t3l)
    errs=[abs(m[i]-tgt[i])/tgt[i]*100 if i<len(m) else 999 for i in range(3)]
    if max(errs)>3: ok=False
    print(f"  {vw:4s} {str(tuple(round(x) for x in tgt)):24s} {str([round(f) for f in m]):24s} {max(errs):.1f}%")
print("  -> resonators land on target" if ok else "  -> MISPLACED")

print("\n=== 2. Full voice, dense harmonics (f0=70), envelope-smoothed ===")
dense = Voice(fundamental=70, formant_scale=1.0, tempo=0.9, swing=0, scale=[0], melody=[0],
              vibrato_depth=0.0, breathiness=0.02, growl=0.0, declination=0.0, brightness=0.5)
for vw,(t1,t2,t3) in VOWEL_FORMANTS.items():
    sig = render(vw, dense)
    steady = sig[int(len(sig)*0.30):int(len(sig)*0.75)]
    m = resp_peaks(steady, top=3, smooth=30)   # 30 bins ≈ 81 Hz at n=16384 -> > f0 spacing
    print(f"  {vw:4s} target F1={t1:4d} F2={t2:4d}  ->  measured {[round(f) for f in m]}")
