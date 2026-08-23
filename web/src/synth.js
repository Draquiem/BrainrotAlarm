// Chant synthesiser — JS port of ChantSynth.swift.
// Ported from Tools/synth_port.py, which is itself a verified mirror of the Swift.
// The only deliberate divergence is the noise PRNG (mulberry32 here rather than
// xorshift64*, because JS lacks cheap 64-bit ints); noise is perceptually a wash.

const SR = 44100, BLOCK = 32;
const SOURCE_MAKEUP = 13.0, TILT2 = 0.6, TILT3 = 0.5;
const G2_BASE = 0.30, G2_BRIGHT = 0.35, G3_BASE = 0.10, G3_BRIGHT = 0.30;
const BURST_LEVEL = 0.55, FRICATIVE_LEVEL = 0.62, VOICE_BAR = 0.10;
const VOICED_BUS = 1.0, NOISE_BUS = 0.5;

const VOWEL_FORMANTS = { a:[730,1090,2440], e:[530,1840,2480], i:[270,2290,3010],
                         o:[570,840,2410],  u:[300,870,2240] };
const VOWEL_BW = [70, 100, 150];
const VOWEL_OPEN = { a:1.0, e:0.85, o:0.85, i:0.7, u:0.7 };
const PLACE_BURST = { labial:[900,1.2], dental:[3800,2.4], velar:[1900,3.0] };
const LATERAL=[350,1100,2600], RHOTIC=[400,1250,1700], NASAL=[260,1000,2250], NEUTRAL=[500,1400,2450];
const STOP_LOCUS = { labial:750, dental:1800, velar:2400 };

export const SCALES = {
  major:[0,2,4,5,7,9,11], minor:[0,2,3,5,7,8,10],
  penta:[0,3,5,7,10],     whole:[0,2,4,6,8,10]
};

// ---------------------------------------------------------------- parser ---
const ACCENTS = 'àáâäèéêëìíîïòóôöùúûü';
const PLAIN   = 'aaaaeeeeiiiioooouuuu';
const VOWELS = { a:'a', e:'e', i:'i', o:'o', u:'u', y:'i' };

function fold(s) {
  let out = '';
  for (const ch of s.toLowerCase()) {
    const i = ACCENTS.indexOf(ch);
    const c = i >= 0 ? PLAIN[i] : ch;
    if (c >= 'a' && c <= 'z') out += c;
  }
  return out;
}
const isFront = c => c === 'e' || c === 'i';

function onsetFor(cluster, following) {
  if (!cluster) return ['none'];
  if (cluster.length >= 2) {
    const pair = cluster.slice(0, 2);
    if (pair === 'gn') return ['nasal'];
    if (pair === 'gl') return ['liquid', false];
    if (pair === 'ch' || pair === 'gh') return ['plosive', 'velar', pair === 'gh'];
    if (pair === 'sc' && isFront(following)) return ['fricative', 'dental', false];
  }
  const f = cluster[0];
  if (f === 'c') return isFront(following) ? ['fricative','dental',false] : ['plosive','velar',false];
  if (f === 'g') return isFront(following) ? ['fricative','dental',true]  : ['plosive','velar',true];
  const table = {
    p:['plosive','labial',false], b:['plosive','labial',true],
    t:['plosive','dental',false], d:['plosive','dental',true],
    k:['plosive','velar',false],  q:['plosive','velar',false],
    f:['fricative','labial',false], v:['fricative','labial',true],
    s:['fricative','dental',false], z:['fricative','dental',true],
    m:['nasal'], n:['nasal'], l:['liquid',false], r:['liquid',true],
    j:['liquid',false], w:['liquid',false], y:['liquid',false], h:['none']
  };
  return table[f] || ['none'];
}

function parseSyllable(raw) {
  let forced = false, body = raw;
  if (body[0] === "'" || body[0] === '’') { forced = true; body = body.slice(1); }
  const accented = [...body.toLowerCase()].some(c => ACCENTS.includes(c));
  const letters = fold(body);
  if (!letters) return null;

  let vi = -1;
  for (let i = 0; i < letters.length; i++) if (VOWELS[letters[i]]) { vi = i; break; }
  if (vi < 0) return { onset:['trill'], vowel:'u', coda:true, stressed:true, liquidRelease:false, text:raw };

  const cluster = letters.slice(0, vi);
  const vowel = VOWELS[letters[vi]];
  let ti = vi + 1;
  while (ti < letters.length && VOWELS[letters[ti]]) ti++;
  return {
    onset: onsetFor(cluster, letters[vi]),
    vowel,
    coda: ti < letters.length,
    stressed: forced || accented,
    liquidRelease: cluster.length > 1 && (cluster.endsWith('l') || cluster.endsWith('r')),
    text: raw
  };
}

export function parseChant(chant) {
  const words = [];
  for (const w of chant.split(/[  ]+/)) {
    if (!w) continue;
    const sylls = w.split('-').map(parseSyllable).filter(Boolean);
    if (!sylls.length) continue;
    if (!sylls.some(s => s.stressed)) sylls[sylls.length >= 2 ? sylls.length - 2 : 0].stressed = true;
    words.push(sylls);
  }
  return words;
}

function lengthFactor(s) {
  let f = 1.0;
  if (s.stressed) f *= 1.35;
  if (s.coda) f *= 0.8;
  if (s.onset[0] === 'trill') f *= 1.2;
  return f;
}

// ---------------------------------------------------------------- biquad ---
class Biquad {
  constructor(sr) { this.sr = sr; this.b0=1; this.b1=0; this.b2=0; this.a1=0; this.a2=0;
                    this.x1=0; this.x2=0; this.y1=0; this.y2=0; }
  clamp(hz) { return Math.min(Math.max(20, hz), this.sr * 0.45); }
  bandpass(center, bw) {
    const f = this.clamp(center), q = Math.max(0.35, f / Math.max(20, bw));
    const w0 = 2 * Math.PI * f / this.sr, alpha = Math.sin(w0) / (2 * q), a0 = 1 + alpha;
    this.b0 = alpha / a0; this.b1 = 0; this.b2 = -alpha / a0;
    this.a1 = (-2 * Math.cos(w0)) / a0; this.a2 = (1 - alpha) / a0;
  }
  lowpass(cut, q = 0.707) {
    const f = this.clamp(cut), w0 = 2 * Math.PI * f / this.sr;
    const alpha = Math.sin(w0) / (2 * Math.max(0.1, q)), cw = Math.cos(w0), a0 = 1 + alpha;
    this.b0 = ((1 - cw) / 2) / a0; this.b1 = (1 - cw) / a0; this.b2 = this.b0;
    this.a1 = (-2 * cw) / a0; this.a2 = (1 - alpha) / a0;
  }
  highpass(cut, q = 0.707) {
    const f = this.clamp(cut), w0 = 2 * Math.PI * f / this.sr;
    const alpha = Math.sin(w0) / (2 * Math.max(0.1, q)), cw = Math.cos(w0), a0 = 1 + alpha;
    this.b0 = ((1 + cw) / 2) / a0; this.b1 = -(1 + cw) / a0; this.b2 = this.b0;
    this.a1 = (-2 * cw) / a0; this.a2 = (1 - alpha) / a0;
  }
  process(x) {
    const y = this.b0*x + this.b1*this.x1 + this.b2*this.x2 - this.a1*this.y1 - this.a2*this.y2;
    this.x2 = this.x1; this.x1 = x; this.y2 = this.y1; this.y1 = y;
    return y;
  }
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return (((t ^ (t >>> 14)) >>> 0) / 4294967296) * 2 - 1;
  };
}

const lerp = (a, b, t) => a + (b - a) * t;
const smoothstep = t => { const x = Math.min(1, Math.max(0, t)); return x * x * (3 - 2 * x); };
const scaled = (sh, k) => [sh[0]*k, sh[1]*k, sh[2]*k];

// ----------------------------------------------------------------- voice ---
export function voice(o = {}) {
  return Object.assign({
    fundamental:138, formantScale:1.0, tempo:3.4, swing:0,
    scale:SCALES.major, melody:[0,2,4,2], vibratoRate:5.2, vibratoDepth:0.18,
    breathiness:0.06, growl:0.15, declination:2.0, wordGap:0.13, brightness:0.5
  }, o);
}
function semitoneDegree(v, d) {
  const n = v.scale.length, oct = Math.floor(d / n), idx = d - oct * n;
  return v.scale[idx] + 12 * oct;
}
function semitoneAt(v, i) {
  const m = v.melody;
  return semitoneDegree(v, m[((i % m.length) + m.length) % m.length]);
}

// ----------------------------------------------------------------- synth ---
function segmentDurations(syl, d) {
  const table = { none:Math.min(0.010,d*0.1), plosive:Math.min(0.062,d*0.32),
                  fricative:Math.min(0.085,d*0.40), nasal:Math.min(0.070,d*0.33),
                  liquid:Math.min(0.055,d*0.28), trill:d*0.85 };
  let onset = table[syl.onset[0]];
  let coda = syl.coda ? Math.min(0.058, d * 0.24) : 0;
  const cap = d * 0.75;
  if (onset + coda > cap) { const k = cap / (onset + coda); return [onset*k, coda*k]; }
  return [onset, coda];
}

function layout(words, v) {
  const total = Math.max(1, words.reduce((n, w) => n + w.length, 0));
  const notes = []; let t = 0, idx = 0;
  const base = 1.0 / Math.max(0.5, v.tempo);
  words.forEach((word, wi) => {
    word.forEach((syl, pos) => {
      const swing = idx % 2 === 0 ? 1 + v.swing * 0.3 : 1 - v.swing * 0.3;
      const dur = base * lengthFactor(syl) * swing;
      notes.push({ syl, start:t, dur, index:idx, wordFinal:pos === word.length - 1, progress:idx / total });
      t += dur; idx++;
    });
    if (wi < words.length - 1) t += v.wordGap;
  });
  return notes;
}

export function render(chant, v, seed = 0x5EED) {
  const words = parseChant(chant);
  if (!words.length) return new Float32Array(0);
  const notes = layout(words, v);
  const last = notes[notes.length - 1];
  const n = Math.max(1, Math.floor((last.start + last.dur + 0.06) * SR));

  // ---- control track ----
  const nblocks = Math.floor(n / BLOCK) + 2;
  const F = {
    f0:new Float64Array(nblocks).fill(110), amp:new Float64Array(nblocks),
    voiced:new Float64Array(nblocks), noise:new Float64Array(nblocks),
    f1:new Float64Array(nblocks).fill(500), f2:new Float64Array(nblocks).fill(1500),
    f3:new Float64Array(nblocks).fill(2500), b1:new Float64Array(nblocks).fill(80),
    b2:new Float64Array(nblocks).fill(110), b3:new Float64Array(nblocks).fill(170),
    nHz:new Float64Array(nblocks).fill(2000), nQ:new Float64Array(nblocks).fill(2),
    trill:new Float64Array(nblocks)
  };
  const fscale = Math.max(0.5, v.formantScale);
  const f3lift = 0.9 + 0.3 * v.brightness;
  let carry = 0;

  for (const note of notes) {
    const syl = note.syl, d = note.dur;
    const [onsetDur, codaDur] = segmentDurations(syl, d);
    const bodyDur = Math.max(0.02, d - onsetDur - codaDur);
    const vf = VOWEL_FORMANTS[syl.vowel];
    const vowel = [vf[0]*fscale, vf[1]*fscale, vf[2]*fscale*f3lift];
    const o = syl.onset;
    let entry;
    if (o[0] === 'liquid') entry = scaled(o[1] ? RHOTIC : LATERAL, fscale);
    else if (o[0] === 'nasal') entry = scaled(NASAL, fscale);
    else if (o[0] === 'trill') entry = scaled(RHOTIC, fscale);
    else if (o[0] === 'plosive') entry = [vowel[0]*0.7, STOP_LOCUS[o[1]]*fscale, vowel[2]];
    else if (o[0] === 'fricative') entry = [vowel[0]*0.8, STOP_LOCUS[o[1]]*fscale*0.95, vowel[2]];
    else entry = vowel;
    const approach = syl.liquidRelease ? scaled(RHOTIC, fscale) : entry;
    const exitShape = syl.coda ? scaled(NASAL, fscale) : scaled(NEUTRAL, fscale);
    const peak = (syl.stressed ? 1.0 : 0.8) * (0.75 + 0.25 * VOWEL_OPEN[syl.vowel]);
    const floor = note.wordFinal ? 0 : 0.16;

    const sb = Math.max(0, Math.floor(note.start * SR / BLOCK));
    const eb = Math.min(nblocks - 1, Math.floor((note.start + d) * SR / BLOCK));
    if (sb > eb) continue;

    for (let block = sb; block <= eb; block++) {
      const t = (block * BLOCK) / SR - note.start;
      if (t < 0) continue;
      let amp = 0, voiced = 0, noise = 0, nHz = 2000, nQ = 2, trill = 0;
      let pos = vowel.slice(), bw = VOWEL_BW.slice();

      if (t < onsetDur) {
        const u = onsetDur > 0 ? t / onsetDur : 1;
        if (o[0] === 'none') { amp = carry + (peak - carry) * u; voiced = 1; pos = entry.slice(); }
        else if (o[0] === 'plosive') {
          const burstStart = 0.78;
          if (u < burstStart) {
            amp = o[2] ? peak * VOICE_BAR * (1 - u) : 0;
            voiced = o[2] ? 1 : 0;
            pos = [180 * fscale, entry[1], entry[2]]; bw = [240, 320, 400];
          } else {
            const bu = (u - burstStart) / (1 - burstStart);
            amp = peak * BURST_LEVEL * Math.exp(-bu * 4.5); noise = 1;
            voiced = o[2] ? 0.25 : 0;
            [nHz, nQ] = PLACE_BURST[o[1]]; pos = entry.slice(); bw = [140, 200, 260];
          }
        } else if (o[0] === 'fricative') {
          amp = peak * FRICATIVE_LEVEL * smoothstep(Math.min(1, u*3)) * (1 - 0.25*smoothstep(Math.max(0, u*2-1)));
          noise = 1; voiced = o[2] ? 0.4 : 0;
          const pb = PLACE_BURST[o[1]]; nHz = pb[0] * 1.15; nQ = pb[1] * 1.6;
          pos = entry.slice();
        } else if (o[0] === 'nasal') {
          amp = carry + (peak*0.55 - carry) * smoothstep(Math.min(1, u*2.5));
          voiced = 1; pos = entry.slice(); bw = [190, 250, 320];
        } else if (o[0] === 'liquid') {
          amp = carry + (peak*0.7 - carry) * smoothstep(Math.min(1, u*2));
          voiced = 1; pos = entry.slice();
        } else if (o[0] === 'trill') {
          amp = peak * 0.8; voiced = 1; pos = entry.slice(); trill = 1;
        }
      } else if (t < onsetDur + bodyDur) {
        const u = (t - onsetDur) / bodyDur;
        const attack = Math.min(0.35, Math.max(0.05, 0.014 / bodyDur));
        const release = Math.min(0.35, Math.max(0.05, 0.026 / bodyDur));
        const entryAmp = onsetDur > 0 ? peak * 0.6 : carry;
        if (u < attack) amp = entryAmp + (peak - entryAmp) * smoothstep(u / attack);
        else if (u > 1 - release) {
          const r = (u - (1 - release)) / release;
          const target = syl.coda ? peak * 0.45 : floor;
          amp = (peak * 0.88) + (target - peak * 0.88) * smoothstep(r);
        } else amp = peak * (1 - 0.12 * (u - attack) / Math.max(0.01, 1 - attack - release));
        voiced = 1; noise = v.breathiness * 0.5;
        const glide = syl.liquidRelease ? 0.42 : 0.3;
        if (u < glide) {
          const g = smoothstep(u / glide);
          const from = (syl.liquidRelease && u < glide * 0.45) ? entry : approach;
          pos = [lerp(from[0],vowel[0],g), lerp(from[1],vowel[1],g), lerp(from[2],vowel[2],g)];
        }
        if (o[0] === 'trill') trill = 1;
      } else {
        const u = codaDur > 0 ? (t - onsetDur - bodyDur) / codaDur : 1;
        amp = peak * 0.45 * (1 - smoothstep(u)) + floor * smoothstep(u);
        voiced = 1;
        const g = smoothstep(u);
        pos = [lerp(vowel[0],exitShape[0],g), lerp(vowel[1],exitShape[1],g), lerp(vowel[2],exitShape[2],g)];
        bw = [lerp(VOWEL_BW[0],200,g), lerp(VOWEL_BW[1],260,g), lerp(VOWEL_BW[2],340,g)];
      }

      const absT = note.start + t;
      const semi = semitoneAt(v, note.index) - v.declination * note.progress;
      const vramp = Math.min(1, t / 0.12);
      const vib = Math.sin(2 * Math.PI * v.vibratoRate * absT) * v.vibratoDepth * vramp;
      const scoop = syl.stressed ? -1.0 * Math.exp(-t / 0.05) : 0;
      F.f0[block] = v.fundamental * Math.pow(2, (semi + vib + scoop) / 12);
      F.amp[block] = Math.max(0, amp); F.voiced[block] = voiced; F.noise[block] = noise;
      F.f1[block] = pos[0]; F.f2[block] = pos[1]; F.f3[block] = pos[2];
      F.b1[block] = bw[0];  F.b2[block] = bw[1];  F.b3[block] = bw[2];
      F.nHz[block] = nHz;   F.nQ[block] = nQ;     F.trill[block] = trill;
      carry = F.amp[block];
    }
  }

  // ---- synthesise ----
  const out = new Float32Array(n);
  const rng = mulberry32(seed);
  const f1 = new Biquad(SR), f2 = new Biquad(SR), f3 = new Biquad(SR), nb = new Biquad(SR);
  const gb2 = G2_BASE + G2_BRIGHT * v.brightness, gb3 = G3_BASE + G3_BRIGHT * v.brightness;
  const oq = 0.55 + 0.25 * v.breathiness, growl = v.growl;
  let phase = 0, prevFlow = 0, even = true, trillPhase = 0;

  const rosenberg = (p, q) => {
    const oqc = Math.min(0.92, Math.max(0.35, q)), pk = oqc * 0.72;
    if (p < pk) { const x = p / pk; return 3*x*x - 2*x*x*x; }
    if (p < oqc) { const x = (p - pk) / (oqc - pk); return 1 - x*x; }
    return 0;
  };

  for (let block = 0; block < Math.floor(n / BLOCK) + 1; block++) {
    const i0 = Math.min(block, nblocks - 1), i1 = Math.min(block + 1, nblocks - 1);
    f1.bandpass(F.f1[i0], F.b1[i0]); f2.bandpass(F.f2[i0], F.b2[i0]); f3.bandpass(F.f3[i0], F.b3[i0]);
    nb.bandpass(F.nHz[i0], Math.max(120, F.nHz[i0] / Math.max(0.4, F.nQ[i0])));
    const ref = Math.max(120, F.f1[i0]);
    const g2 = gb2 * Math.pow(F.f2[i0] / ref, TILT2);
    const g3 = gb3 * Math.pow(F.f3[i0] / ref, TILT3);

    const start = block * BLOCK, end = Math.min(start + BLOCK, n);
    if (start >= end) break;
    for (let i = start; i < end; i++) {
      const u = (i - start) / BLOCK;
      const f0 = lerp(F.f0[i0], F.f0[i1], u), amp = lerp(F.amp[i0], F.amp[i1], u);
      const vg = lerp(F.voiced[i0], F.voiced[i1], u), ng = lerp(F.noise[i0], F.noise[i1], u);
      const td = lerp(F.trill[i0], F.trill[i1], u);
      phase += f0 / SR;
      if (phase >= 1) { phase -= 1; even = !even; }
      const pg = (growl > 0.01 && !even) ? 1 - 0.55 * growl : 1;
      const flow = rosenberg(phase, oq) * pg;
      const rad = (flow - 0.97 * prevFlow) * SOURCE_MAKEUP;
      prevFlow = flow;
      const src = (rad + rng() * v.breathiness * 0.18) * vg;
      const vo = f1.process(src) + f2.process(src) * g2 + f3.process(src) * g3;
      const no = nb.process(rng()) * ng;
      let s = vo * VOICED_BUS + no * NOISE_BUS;
      if (td > 0.01) {
        trillPhase += 27.0 / SR;
        if (trillPhase >= 1) trillPhase -= 1;
        const flutter = 0.45 + 0.55 * (0.5 - 0.5 * Math.cos(2 * Math.PI * trillPhase));
        s *= 1 - td + td * flutter;
      }
      out[i] = s * amp;
    }
  }

  // ---- output shaping ----
  const hp = new Biquad(SR); hp.highpass(75);
  const lp = new Biquad(SR); lp.lowpass(Math.min(9500, SR * 0.44));
  const drive = 1 + 3 * v.growl, norm = Math.tanh(drive);
  for (let i = 0; i < n; i++) {
    let x = hp.process(out[i]);
    x = Math.tanh(x * drive) / norm;
    out[i] = lp.process(x);
  }
  let peak = 0;
  for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(out[i]));
  if (peak > 1e-6) { const g = 0.89 / peak; for (let i = 0; i < n; i++) out[i] *= g; }
  const fade = (sec, atStart) => {
    const c = Math.min(n, Math.floor(sec * SR));
    if (c <= 1) return;
    for (let i = 0; i < c; i++) out[atStart ? i : n - 1 - i] *= i / (c - 1);
  };
  fade(0.004, true); fade(0.015, false);
  return out;
}

export const SAMPLE_RATE = SR;
