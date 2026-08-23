import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def swift(rel): return os.path.join(REPO, "BrainrotAlarm", rel)
from synth_port import render, write_wav, SR
from roster import ROSTER
out=[]
for cid,name,chant,fam,v in ROSTER:
    sig=render(chant,v)
    out.extend(sig); out.extend([0.0]*int(0.45*SR))
write_wav(os.path.join(REPO,"preview_all_voices.wav"), out)
print(f"wrote {len(out)/SR:.1f}s, {len(ROSTER)} voices")
# single loud alarm loop, as the app would play it
sig=render("Tra-la-le-ro Tra-la-la", ROSTER[0][4])
loop=[]
for _ in range(3): loop.extend(sig); loop.extend([0.0]*int(0.35*SR))
write_wav(os.path.join(REPO,"preview_alarm_loop.wav"), loop)
print(f"wrote alarm loop {len(loop)/SR:.1f}s")
