import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def swift(rel): return os.path.join(REPO, "BrainrotAlarm", rel)
import re
py=open('synth_port.py').read()
sw=open(swift('Chant/ChantSynth.swift')).read()
bq=open(swift('Chant/Biquad.swift')).read()
syl=open(swift('Chant/Syllable.swift')).read()

checks = [
 ("source makeup",        r'SOURCE_MAKEUP\s*=\s*([\d.]+)', py,  r'sourceMakeup\s*=\s*([\d.]+)', sw),
 ("burst level",          r'BURST_LEVEL\s*=\s*([\d.]+)', py,    r'let burst\s*=\s*([\d.]+)', sw),
 ("fricative level",      r'FRICATIVE_LEVEL\s*=\s*([\d.]+)', py,r'let fricative\s*=\s*([\d.]+)', sw),
 ("voiced bus",           r'VOICED_BUS\s*=\s*([\d.]+)', py,     r'voicedBus\s*=\s*([\d.]+)', sw),
 ("noise bus",            r'NOISE_BUS\s*=\s*([\d.]+)', py,      r'noiseBus\s*=\s*([\d.]+)', sw),
 ("tilt F2",              r'TILT2\s*=\s*([\d.]+)', py,          r'tiltF2\s*=\s*([\d.]+)', sw),
 ("tilt F3",              r'TILT3\s*=\s*([\d.]+)', py,          r'tiltF3\s*=\s*([\d.]+)', sw),
 ("g2 base/bright",       r'G2_BASE=([\d.]+); G2_BRIGHT=([\d.]+)', py, r'g2Base = ([\d.]+) \+ ([\d.]+) \* voice\.brightness', sw),
 ("g3 base/bright",       r'G3_BASE=([\d.]+); G3_BRIGHT=([\d.]+)', py, r'g3Base = ([\d.]+) \+ ([\d.]+) \* voice\.brightness', sw),
 ("block size",           r'BLOCK\s*=\s*(\d+)', py,             r'blockSize = (\d+)', sw),
 ("radiation coeff",      r'flow - ([\d.]+)\*prev_flow', py,    r'flow - ([\d.]+) \* previousFlow', sw),
 ("open quotient",        r'oq = ([\d.]+)\+([\d.]+)\*v\.breathiness', py, r'openQuotient = ([\d.]+) \+ ([\d.]+) \* voice\.breathiness', sw),
 ("growl depth",          r'1-([\d.]+)\*growl', py,             r'1 - ([\d.]+) \* growl', sw),
 ("trill rate",           r'trill_phase \+= ([\d.]+)/SR', py,   r'trillPhase \+= ([\d.]+) / sampleRate', sw),
 ("highpass",             r'hp\.highpass\(([\d.]+)\)', py,      r'setHighpass\(cutoffHz: (\d+)\)', sw),
 ("normalise peak",       r'g = ([\d.]+)/peak', py,             r'let gain = ([\d.]+) / peak', sw),
 ("biquad clamp",         r'max\(20\.0, hz\), self\.sr\*([\d.]+)', py, r'hz\), sampleRate \* ([\d.]+)', bq),
 ("stop locus labial",    r"'labial':([\d.]+)", py,             r'case \.labial: return (\d+)\n', sw),
 ("rosenberg peak",       r'peak = oqc\*([\d.]+)', py,          r'let peak = oq \* ([\d.]+)', sw),
]

bad=0
print(f"{'constant':22s} {'python':>16s} {'swift':>16s}")
for name, pyre, pysrc, swre, swsrc in checks:
    m1=re.search(pyre, pysrc); m2=re.search(swre, swsrc)
    v1 = tuple(float(x) for x in m1.groups()) if m1 else None
    v2 = tuple(float(x) for x in m2.groups()) if m2 else None
    ok = v1 is not None and v1==v2
    if not ok: bad+=1
    print(f"{name:22s} {str(v1):>16s} {str(v2):>16s}  {'ok' if ok else 'MISMATCH'}")

# vowel formant table
swv={m[0]: m[1:] for m in re.findall(r'case \.([aeiou]): return \((\d+),\s*(\d+),\s*(\d+)\)', syl)}
print("\nvowel formant table:")
for v in "aeiou":
    p=tuple(int(x) for x in re.search(rf"'{v}': \((\d+),(\d+),(\d+)\)", py).groups())
    s=tuple(int(x) for x in swv[v])
    ok = p==s
    if not ok: bad+=1
    print(f"  /{v}/  python {p}  swift {s}  {'ok' if ok else 'MISMATCH'}")

# tract shapes
print("\ntract shapes:")
for name, pyname in [("lateral","LATERAL"),("rhotic","RHOTIC"),("nasal","NASAL"),("neutral","NEUTRAL")]:
    p=tuple(float(x) for x in re.search(rf'{pyname}=\(([\d.]+),([\d.]+),([\d.]+)\)', py).groups())
    s=tuple(float(x) for x in re.search(rf'static let {name}\s*= \(f1: ([\d.]+), f2: ([\d.]+), f3: ([\d.]+)\)', sw).groups())
    ok = p==s
    if not ok: bad+=1
    print(f"  {name:8s} python {p}  swift {s}  {'ok' if ok else 'MISMATCH'}")

print(f"\n{bad} mismatches" if bad else "\nPython reference and Swift implementation agree on every checked constant")
