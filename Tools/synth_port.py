"""Mechanical Python port of the Swift ChantSynth, used to verify the DSP.

Translated line-by-line on purpose: the goal is for logic bugs in the Swift to
reproduce here, not to write a better synthesiser.
"""
import math, struct, cmath

SR = 44100.0
BLOCK = 32
SOURCE_MAKEUP = 13.0
TILT2=0.6; TILT3=0.5
G2_BASE=0.30; G2_BRIGHT=0.35; G3_BASE=0.10; G3_BRIGHT=0.30
BURST_LEVEL = 0.55
FRICATIVE_LEVEL = 0.62
VOICED_BUS = 1.0
NOISE_BUS = 0.5

# ---------------------------------------------------------------- Syllable ---
VOWEL_FORMANTS = {'a': (730,1090,2440), 'e': (530,1840,2480), 'i': (270,2290,3010),
                  'o': (570,840,2410),  'u': (300,870,2240)}
VOWEL_BW = (70.0, 100.0, 150.0)
VOWEL_OPEN = {'a':1.0,'e':0.85,'o':0.85,'i':0.7,'u':0.7}
PLACE_BURST = {'labial':(900.0,1.2), 'dental':(3800.0,2.4), 'velar':(1900.0,3.0)}

class Syl:
    def __init__(self, onset, vowel, coda, stressed, liquid_release, text):
        self.onset = onset          # ('none',) ('plosive',place,voiced) ('fricative',place,voiced)
                                    # ('nasal',) ('liquid',rhotic) ('trill',)
        self.vowel = vowel; self.coda = coda; self.stressed = stressed
        self.liquid_release = liquid_release; self.text = text
    @property
    def length_factor(self):
        f = 1.0
        if self.stressed: f *= 1.35
        if self.coda: f *= 0.8
        if self.onset[0] == 'trill': f *= 1.2
        return f

# ------------------------------------------------------------------ Parser ---
ACCENTS = set('àáâäèéêëìíîïòóôöùúûü')
FOLD = str.maketrans('àáâäèéêëìíîïòóôöùúûü', 'aaaaeeeeiiiioooouuuu')
VOWELS = {'a':'a','e':'e','i':'i','o':'o','u':'u','y':'i'}

def is_front(c): return c in ('e','i')

def onset_for(cluster, following):
    if not cluster: return ('none',)
    if len(cluster) >= 2:
        pair = cluster[0]+cluster[1]
        if pair == 'gn': return ('nasal',)
        if pair == 'gl': return ('liquid', False)
        if pair in ('ch','gh'): return ('plosive','velar', pair=='gh')
        if pair == 'sc' and is_front(following): return ('fricative','dental',False)
    f = cluster[0]
    table = {'p':('plosive','labial',False),'b':('plosive','labial',True),
             't':('plosive','dental',False),'d':('plosive','dental',True),
             'k':('plosive','velar',False),'q':('plosive','velar',False),
             'f':('fricative','labial',False),'v':('fricative','labial',True),
             's':('fricative','dental',False),'z':('fricative','dental',True),
             'm':('nasal',),'n':('nasal',),'l':('liquid',False),'r':('liquid',True),
             'j':('liquid',False),'w':('liquid',False),'y':('liquid',False),'h':('none',)}
    if f == 'c':
        return ('fricative','dental',False) if is_front(following) else ('plosive','velar',False)
    if f == 'g':
        return ('fricative','dental',True) if is_front(following) else ('plosive','velar',True)
    return table.get(f, ('none',))

def parse_syllable(raw):
    forced = False; body = raw
    if body[:1] in ("'", '’'):
        forced = True; body = body[1:]
    accented = any(ch in ACCENTS for ch in body.lower())
    letters = ''.join(ch for ch in body.lower().translate(FOLD) if 'a' <= ch <= 'z')
    if not letters: return None
    vi = next((i for i,c in enumerate(letters) if c in VOWELS), None)
    if vi is None:
        return Syl(('trill',), 'u', True, True, False, raw)
    cluster = letters[:vi]
    vowel = VOWELS[letters[vi]]
    ti = vi+1
    while ti < len(letters) and letters[ti] in VOWELS: ti += 1
    has_coda = ti < len(letters)
    liquid_release = len(cluster) > 1 and cluster[-1] in ('l','r')
    return Syl(onset_for(cluster, letters[vi]), vowel, has_coda,
               forced or accented, liquid_release, raw)

def parse(chant):
    words = []
    for w in chant.replace(' ',' ').split(' '):
        if not w: continue
        sylls = [s for s in (parse_syllable(t) for t in w.split('-')) if s]
        if not sylls: continue
        if not any(s.stressed for s in sylls):
            sylls[len(sylls)-2 if len(sylls) >= 2 else 0].stressed = True
        words.append(sylls)
    return words

# ------------------------------------------------------------------ Biquad ---
class Biquad:
    def __init__(self, sr):
        self.sr = sr; self.b0=1.0; self.b1=0.0; self.b2=0.0; self.a1=0.0; self.a2=0.0
        self.x1=self.x2=self.y1=self.y2=0.0
    def _clamp(self, hz): return min(max(20.0, hz), self.sr*0.45)
    def bandpass(self, center, bw):
        f = self._clamp(center); q = max(0.35, f/max(20.0, bw))
        w0 = 2*math.pi*f/self.sr; alpha = math.sin(w0)/(2*q); a0 = 1+alpha
        self.b0 = alpha/a0; self.b1 = 0.0; self.b2 = -alpha/a0
        self.a1 = (-2*math.cos(w0))/a0; self.a2 = (1-alpha)/a0
    def lowpass(self, cutoff, q=0.707):
        f = self._clamp(cutoff); w0 = 2*math.pi*f/self.sr
        alpha = math.sin(w0)/(2*max(0.1,q)); cw = math.cos(w0); a0 = 1+alpha
        self.b0 = ((1-cw)/2)/a0; self.b1 = (1-cw)/a0; self.b2 = self.b0
        self.a1 = (-2*cw)/a0; self.a2 = (1-alpha)/a0
    def highpass(self, cutoff, q=0.707):
        f = self._clamp(cutoff); w0 = 2*math.pi*f/self.sr
        alpha = math.sin(w0)/(2*max(0.1,q)); cw = math.cos(w0); a0 = 1+alpha
        self.b0 = ((1+cw)/2)/a0; self.b1 = -(1+cw)/a0; self.b2 = self.b0
        self.a1 = (-2*cw)/a0; self.a2 = (1-alpha)/a0
    def process(self, x):
        y = self.b0*x + self.b1*self.x1 + self.b2*self.x2 - self.a1*self.y1 - self.a2*self.y2
        self.x2 = self.x1; self.x1 = x; self.y2 = self.y1; self.y1 = y
        return y

class Rng:
    def __init__(self, seed):
        s = (seed * 0x9E3779B97F4A7C15 + 0x123456789ABCDEF0) & 0xFFFFFFFFFFFFFFFF
        self.s = s or 0x853C49E6748FEA9B
    def bipolar(self):
        s = self.s
        s ^= (s >> 12); s &= 0xFFFFFFFFFFFFFFFF
        s ^= (s << 25) & 0xFFFFFFFFFFFFFFFF
        s ^= (s >> 27)
        self.s = s
        v = (s * 0x2545F4914F6CDD1D) & 0xFFFFFFFFFFFFFFFF
        return ((v >> 11) * (1.0/9007199254740992.0)) * 2 - 1

# ------------------------------------------------------------------- Voice ---
MAJOR=[0,2,4,5,7,9,11]; MINOR=[0,2,3,5,7,8,10]; PENTA=[0,3,5,7,10]; WHOLE=[0,2,4,6,8,10]
class Voice:
    def __init__(self, fundamental=138, formant_scale=1.0, tempo=3.4, swing=0.0,
                 scale=None, melody=None, vibrato_rate=5.2, vibrato_depth=0.18,
                 breathiness=0.06, growl=0.15, declination=2.0, word_gap=0.13, brightness=0.5):
        self.fundamental=fundamental; self.formant_scale=formant_scale; self.tempo=tempo
        self.swing=swing; self.scale=scale or MAJOR; self.melody=melody or [0,2,4,2]
        self.vibrato_rate=vibrato_rate; self.vibrato_depth=vibrato_depth
        self.breathiness=breathiness; self.growl=growl; self.declination=declination
        self.word_gap=word_gap; self.brightness=brightness
    def semitone_degree(self, d):
        n = len(self.scale)
        octave = math.floor(d/n); idx = d - octave*n
        return self.scale[idx] + 12*octave
    def semitone_at(self, i):
        m = self.melody
        return self.semitone_degree(m[((i % len(m)) + len(m)) % len(m)])

GOOFBALL = Voice(128,0.96,3.6,0.25,MAJOR,[0,2,4,2],5.0,0.2,0.05,0.2,2.0,0.13,0.5)
BRUISER  = Voice(82,0.82,2.7,0.15,MINOR,[0,0,-3,0,2],4.2,0.12,0.04,0.55,3.0,0.17,0.3)
SQUEAKER = Voice(268,1.28,5.0,0.35,PENTA,[0,3,2,4,2],6.4,0.3,0.1,0.08,1.4,0.1,0.8)
DIVA     = Voice(232,1.1,2.5,0.05,MAJOR,[4,2,0,2,4,7],5.6,0.55,0.09,0.05,2.6,0.2,0.68)
CHANTER  = Voice(146,0.92,4.2,0.0,[0,1,5,7],[0,0,0,1,0],7.0,0.1,0.03,0.3,1.0,0.1,0.42)
EERIE    = Voice(174,1.02,3.0,0.4,WHOLE,[0,2,1,3,2,5],3.4,0.42,0.16,0.12,0.5,0.16,0.6)

# ------------------------------------------------------------------- Synth ---
LATERAL=(350.0,1100.0,2600.0); RHOTIC=(400.0,1250.0,1700.0)
NASAL=(260.0,1000.0,2250.0);   NEUTRAL=(500.0,1400.0,2450.0)
STOP_LOCUS = {'labial':750.0,'dental':1800.0,'velar':2400.0}

def lerp(a,b,t): return a+(b-a)*t
def smoothstep(t):
    x = min(1.0, max(0.0, t)); return x*x*(3-2*x)
def scaled(sh,k): return (sh[0]*k, sh[1]*k, sh[2]*k)

class Frame:
    __slots__=('f0','amp','voiced','noise','f1','f2','f3','b1','b2','b3','noiseHz','noiseQ','trill')
    def __init__(self):
        self.f0=110.0; self.amp=0.0; self.voiced=0.0; self.noise=0.0
        self.f1=500.0; self.f2=1500.0; self.f3=2500.0
        self.b1=80.0; self.b2=110.0; self.b3=170.0
        self.noiseHz=2000.0; self.noiseQ=2.0; self.trill=0.0

def segment_durations(syl, d):
    o = syl.onset[0]
    onset = {'none':min(0.010,d*0.1),'plosive':min(0.062,d*0.32),'fricative':min(0.085,d*0.40),
             'nasal':min(0.070,d*0.33),'liquid':min(0.055,d*0.28),'trill':d*0.85}[o]
    coda = min(0.058, d*0.24) if syl.coda else 0.0
    cap = d*0.75
    if onset+coda > cap:
        k = cap/(onset+coda); return onset*k, coda*k
    return onset, coda

def layout(words, v):
    total = max(1, sum(len(w) for w in words))
    notes = []; t = 0.0; idx = 0
    base = 1.0/max(0.5, v.tempo)
    for wi, word in enumerate(words):
        for pos, syl in enumerate(word):
            swing = (1 + v.swing*0.3) if idx % 2 == 0 else (1 - v.swing*0.3)
            dur = base*syl.length_factor*swing
            notes.append(dict(syl=syl, start=t, dur=dur, index=idx,
                              word_final=(pos == len(word)-1), progress=idx/total))
            t += dur; idx += 1
        if wi < len(words)-1: t += v.word_gap
    return notes

def build_control(notes, v, total_samples):
    nblocks = total_samples//BLOCK + 2
    frames = [Frame() for _ in range(nblocks)]
    scale = max(0.5, v.formant_scale)
    f3lift = 0.9 + 0.3*v.brightness
    carry = 0.0
    for note in notes:
        syl = note['syl']; d = note['dur']
        onset_dur, coda_dur = segment_durations(syl, d)
        body_dur = max(0.02, d - onset_dur - coda_dur)
        vf = VOWEL_FORMANTS[syl.vowel]
        vowel = (vf[0]*scale, vf[1]*scale, vf[2]*scale*f3lift)
        vb = VOWEL_BW
        o = syl.onset
        if o[0]=='liquid': entry = scaled(RHOTIC if o[1] else LATERAL, scale)
        elif o[0]=='nasal': entry = scaled(NASAL, scale)
        elif o[0]=='trill': entry = scaled(RHOTIC, scale)
        elif o[0]=='plosive': entry = (vowel[0]*0.7, STOP_LOCUS[o[1]]*scale, vowel[2])
        elif o[0]=='fricative': entry = (vowel[0]*0.8, STOP_LOCUS[o[1]]*scale*0.95, vowel[2])
        else: entry = vowel
        approach = scaled(RHOTIC, scale) if syl.liquid_release else entry
        exit_ = scaled(NASAL, scale) if syl.coda else scaled(NEUTRAL, scale)
        peak = (1.0 if syl.stressed else 0.8)*(0.75+0.25*VOWEL_OPEN[syl.vowel])
        floor = 0.0 if note['word_final'] else 0.16
        sb = max(0, int(note['start']*SR)//BLOCK)
        eb = min(nblocks-1, int((note['start']+d)*SR)//BLOCK)
        if sb > eb: continue
        for block in range(sb, eb+1):
            t = (block*BLOCK)/SR - note['start']
            if t < 0: continue
            fr = Frame()
            amp=0.0; voiced=0.0; noise=0.0; noiseHz=2000.0; noiseQ=2.0
            pos = list(vowel); bw = list(vb)
            if t < onset_dur:
                u = t/onset_dur if onset_dur > 0 else 1.0
                if o[0]=='none':
                    amp = carry + (peak-carry)*u; voiced=1.0; pos=list(entry)
                elif o[0]=='plosive':
                    burst_start = 0.78
                    if u < burst_start:
                        amp = peak*0.10*(1-u) if o[2] else 0.0
                        voiced = 1.0 if o[2] else 0.0
                        pos = [180*scale, entry[1], entry[2]]; bw=[240.0,320.0,400.0]
                    else:
                        bu = (u-burst_start)/(1-burst_start)
                        amp = peak*BURST_LEVEL*math.exp(-bu*4.5); noise=1.0
                        voiced = 0.25 if o[2] else 0.0
                        noiseHz, noiseQ = PLACE_BURST[o[1]]; pos=list(entry)
                        bw=[140.0,200.0,260.0]
                elif o[0]=='fricative':
                    amp = peak*FRICATIVE_LEVEL*smoothstep(min(1,u*3))*(1-0.25*smoothstep(max(0,u*2-1)))
                    noise=1.0; voiced = 0.4 if o[2] else 0.0
                    bh,bq = PLACE_BURST[o[1]]; noiseHz = bh*1.15; noiseQ = bq*1.6
                    pos=list(entry)
                elif o[0]=='nasal':
                    amp = carry + (peak*0.55-carry)*smoothstep(min(1,u*2.5))
                    voiced=1.0; pos=list(entry); bw=[190.0,250.0,320.0]
                elif o[0]=='liquid':
                    amp = carry + (peak*0.7-carry)*smoothstep(min(1,u*2))
                    voiced=1.0; pos=list(entry)
                elif o[0]=='trill':
                    amp = peak*0.8; voiced=1.0; pos=list(entry); fr.trill=1.0
            elif t < onset_dur+body_dur:
                u = (t-onset_dur)/body_dur
                attack = min(0.35, max(0.05, 0.014/body_dur))
                release = min(0.35, max(0.05, 0.026/body_dur))
                entry_amp = peak*0.6 if onset_dur > 0 else carry
                if u < attack:
                    amp = entry_amp + (peak-entry_amp)*smoothstep(u/attack)
                elif u > 1-release:
                    r = (u-(1-release))/release
                    target = peak*0.45 if syl.coda else floor
                    amp = (peak*0.88) + (target-peak*0.88)*smoothstep(r)
                else:
                    amp = peak*(1 - 0.12*(u-attack)/max(0.01, 1-attack-release))
                voiced=1.0; noise = v.breathiness*0.5
                glide_span = 0.42 if syl.liquid_release else 0.3
                if u < glide_span:
                    g = smoothstep(u/glide_span)
                    frm = entry if (syl.liquid_release and u < glide_span*0.45) else approach
                    pos = [lerp(frm[0],vowel[0],g), lerp(frm[1],vowel[1],g), lerp(frm[2],vowel[2],g)]
                if o[0]=='trill': fr.trill=1.0
            else:
                u = (t-onset_dur-body_dur)/coda_dur if coda_dur > 0 else 1.0
                amp = peak*0.45*(1-smoothstep(u)) + floor*smoothstep(u)
                voiced=1.0; g = smoothstep(u)
                pos = [lerp(vowel[0],exit_[0],g), lerp(vowel[1],exit_[1],g), lerp(vowel[2],exit_[2],g)]
                bw = [lerp(vb[0],200,g), lerp(vb[1],260,g), lerp(vb[2],340,g)]
            abs_t = note['start']+t
            semi = v.semitone_at(note['index']) - v.declination*note['progress']
            vramp = min(1.0, t/0.12)
            vib = math.sin(2*math.pi*v.vibrato_rate*abs_t)*v.vibrato_depth*vramp
            scoop = -1.0*math.exp(-t/0.05) if syl.stressed else 0.0
            fr.f0 = v.fundamental*(2**((semi+vib+scoop)/12))
            fr.amp = max(0.0, amp); fr.voiced=voiced; fr.noise=noise
            fr.f1,fr.f2,fr.f3 = pos; fr.b1,fr.b2,fr.b3 = bw
            fr.noiseHz=noiseHz; fr.noiseQ=noiseQ
            frames[block]=fr; carry = fr.amp
    return frames

def synthesize(frames, v, total_samples, seed):
    out = [0.0]*total_samples
    rng = Rng(seed)
    f1 = Biquad(SR); f2 = Biquad(SR); f3 = Biquad(SR); nb = Biquad(SR)
    gb2 = G2_BASE + G2_BRIGHT*v.brightness; gb3 = G3_BASE + G3_BRIGHT*v.brightness
    oq = 0.55+0.25*v.breathiness; growl = v.growl
    phase=0.0; prev_flow=0.0; even=True; trill_phase=0.0
    def rosenberg(p, oq):
        oqc = min(0.92, max(0.35, oq)); peak = oqc*0.72
        if p < peak:
            x = p/peak; return 3*x*x - 2*x*x*x
        if p < oqc:
            x = (p-peak)/(oqc-peak); return 1-x*x
        return 0.0
    for block in range(total_samples//BLOCK + 1):
        fr = frames[min(block, len(frames)-1)]
        nx = frames[min(block+1, len(frames)-1)]
        f1.bandpass(fr.f1, fr.b1); f2.bandpass(fr.f2, fr.b2); f3.bandpass(fr.f3, fr.b3)
        base = max(120.0, fr.f1)
        g2 = gb2*((fr.f2/base)**TILT2)
        g3 = gb3*((fr.f3/base)**TILT3)
        nb.bandpass(fr.noiseHz, max(120.0, fr.noiseHz/max(0.4, fr.noiseQ)))
        start = block*BLOCK; end = min(start+BLOCK, total_samples)
        if start >= end: break
        for i in range(start, end):
            u = (i-start)/BLOCK
            f0 = lerp(fr.f0, nx.f0, u); amp = lerp(fr.amp, nx.amp, u)
            vg = lerp(fr.voiced, nx.voiced, u); ng = lerp(fr.noise, nx.noise, u)
            td = lerp(fr.trill, nx.trill, u)
            phase += f0/SR
            if phase >= 1: phase -= 1; even = not even
            pg = (1-0.55*growl) if (growl > 0.01 and not even) else 1.0
            flow = rosenberg(phase, oq)*pg
            rad = (flow - 0.97*prev_flow)*SOURCE_MAKEUP; prev_flow = flow
            src = (rad + rng.bipolar()*v.breathiness*0.18)*vg
            vo = f1.process(src) + f2.process(src)*g2 + f3.process(src)*g3
            no = nb.process(rng.bipolar())*ng
            s = vo*VOICED_BUS + no*NOISE_BUS
            if td > 0.01:
                trill_phase += 27.0/SR
                if trill_phase >= 1: trill_phase -= 1
                flutter = 0.45+0.55*(0.5-0.5*math.cos(2*math.pi*trill_phase))
                s *= 1-td+td*flutter
            out[i] = s*amp
    return out

def finish(sig, v):
    if not sig: return sig
    hp = Biquad(SR); hp.highpass(75.0)
    lp = Biquad(SR); lp.lowpass(min(9500.0, SR*0.44))
    drive = 1+3*v.growl; norm = math.tanh(drive)
    for i in range(len(sig)):
        x = hp.process(sig[i]); x = math.tanh(x*drive)/norm; sig[i] = lp.process(x)
    peak = max((abs(s) for s in sig), default=0.0)
    if peak > 1e-6:
        g = 0.89/peak
        for i in range(len(sig)): sig[i] *= g
    def fade(sec, at_start):
        n = min(len(sig), int(sec*SR))
        if n <= 1: return
        for i in range(n):
            gain = i/(n-1); idx = i if at_start else len(sig)-1-i
            sig[idx] *= gain
    fade(0.004, True); fade(0.015, False)
    return sig

def render(chant, voice, seed=0x5EED):
    words = parse(chant)
    if not words: return []
    notes = layout(words, voice)
    last = notes[-1]
    total_sec = last['start']+last['dur']+0.06
    n = max(1, int(total_sec*SR))
    frames = build_control(notes, voice, n)
    sig = synthesize(frames, voice, n, seed)
    return finish(sig, voice)

def write_wav(path, sig, sr=SR):
    data = b''.join(struct.pack('<h', int(max(-1.0,min(1.0,s))*32767)) for s in sig)
    with open(path,'wb') as f:
        f.write(b'RIFF'+struct.pack('<I',36+len(data))+b'WAVEfmt ')
        f.write(struct.pack('<IHHIIHH',16,1,1,int(sr),int(sr)*2,2,16))
        f.write(b'data'+struct.pack('<I',len(data))+data)
