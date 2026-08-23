// ---------------------------------------------------------------- audio ---
let audioCtx = null, analyser = null, current = null, meterRAF = 0;
const buffers = new Map();

function scaleFor(name) {
  return name === 'chanterScale' ? [0, 1, 5, 7] : SCALES[name] || SCALES.major;
}
function voiceOf(c) {
  const v = Object.assign({}, c.voice);
  v.scale = scaleFor(v.scale);
  return v;
}

function base64ToBytes(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

// Appends the gap the loop needs, whatever the source's rate or channel count.
function withGap(decoded, seconds) {
  const gap = Math.floor(seconds * decoded.sampleRate);
  const buf = audioCtx.createBuffer(decoded.numberOfChannels,
                                    decoded.length + gap, decoded.sampleRate);
  for (let ch = 0; ch < decoded.numberOfChannels; ch++) {
    buf.getChannelData(ch).set(decoded.getChannelData(ch));
  }
  return buf;
}

// A real recording wins over the synthesiser; anything that fails to decode
// quietly falls back rather than leaving a round silent.
async function ensureBuffer(c) {
  if (buffers.has(c.id)) return buffers.get(c.id);
  const asset = ASSETS[c.id];
  if (asset && asset.audio) {
    try {
      const decoded = await audioCtx.decodeAudioData(base64ToBytes(asset.audio));
      const buf = withGap(decoded, 0.45);
      buffers.set(c.id, buf);
      return buf;
    } catch (e) {
      console.warn('could not decode bundled audio for ' + c.id + ', synthesising instead', e);
    }
  }
  const samples = render(c.chant, voiceOf(c), 0x5EED);
  const gap = Math.floor(0.45 * SAMPLE_RATE);
  const buf = audioCtx.createBuffer(1, samples.length + gap, SAMPLE_RATE);
  buf.copyToChannel(samples, 0);
  buffers.set(c.id, buf);
  return buf;
}

// Fills the buffer cache during idle time. Rendering a chant is a few hundred
// milliseconds of main-thread maths, which would show as a stall right when a
// round starts; doing it ahead of time means only the very first play can wait.
function warmCache() {
  const queue = CATALOG.slice();
  const idle = window.requestIdleCallback || (fn => setTimeout(() => fn({ timeRemaining: () => 8 }), 32));
  const step = deadline => {
    while (queue.length && deadline.timeRemaining() > 4) ensureBuffer(queue.shift());
    if (queue.length) idle(step);
  };
  idle(step);
}

function stopAudio() {
  if (current) { try { current.stop(); } catch (e) {} current.disconnect(); current = null; }
}

let playToken = 0;
async function play(c, loop) {
  if (!audioCtx) return;
  const token = ++playToken;
  const buffer = await ensureBuffer(c);
  if (token !== playToken) return;   // a newer play() overtook this one
  stopAudio();
  const src = audioCtx.createBufferSource();
  src.buffer = buffer;
  src.loop = !!loop;
  src.connect(analyser);
  src.start();
  current = src;
}

// The bars are driven by a real AnalyserNode, so they track the actual formants
// moving through the chant rather than miming to a timer.
function startMeter() {
  const canvas = document.getElementById('meter');
  const g = canvas.getContext('2d');
  const bins = new Uint8Array(analyser.frequencyBinCount);
  const BARS = 22;
  function frame() {
    meterRAF = requestAnimationFrame(frame);
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (canvas.width !== w * dpr) { canvas.width = w * dpr; canvas.height = h * dpr; }
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, w, h);
    analyser.getByteFrequencyData(bins);
    const gap = 4, bw = (w - gap * (BARS - 1)) / BARS;
    for (let i = 0; i < BARS; i++) {
      // log-ish spacing so the low formants get the room they deserve
      const lo = Math.floor(Math.pow(i / BARS, 1.7) * bins.length * 0.55);
      const hi = Math.max(lo + 1, Math.floor(Math.pow((i + 1) / BARS, 1.7) * bins.length * 0.55));
      let sum = 0;
      for (let k = lo; k < hi; k++) sum += bins[k];
      const level = Math.min(1, (sum / (hi - lo)) / 190);
      const bh = Math.max(3, level * h);
      g.fillStyle = current ? '#FF7A45' : 'rgba(242,239,233,.14)';
      g.globalAlpha = current ? 0.35 + level * 0.65 : 1;
      g.beginPath();
      g.roundRect(i * (bw + gap), (h - bh) / 2, bw, bh, bw / 2);
      g.fill();
    }
    g.globalAlpha = 1;
  }
  frame();
}

// ------------------------------------------------------------ character ---
function avgPitch(c) {
  const v = voiceOf(c), m = v.melody, n = v.scale.length;
  let sum = 0;
  for (let i = 0; i < m.length; i++) {
    const d = m[((i % m.length) + m.length) % m.length];
    const oct = Math.floor(d / n), idx = d - oct * n;
    sum += v.fundamental * Math.pow(2, (v.scale[idx] + 12 * oct) / 12);
  }
  return sum / m.length;
}
function syllableCount(c) {
  return parseChant(c.chant).reduce((n, w) => n + w.length, 0);
}
const META = new Map();
function meta(c) {
  if (!META.has(c.id)) META.set(c.id, { pitch: avgPitch(c), syl: syllableCount(c) });
  return META.get(c.id);
}
// Mirrors BrainrotCharacter.distance(to:)
function distance(a, b) {
  const ma = meta(a), mb = meta(b);
  return Math.abs(Math.log2(ma.pitch) - Math.log2(mb.pitch)) * 4
       + Math.abs(a.voice.tempo - b.voice.tempo) * 0.45
       + Math.abs(ma.syl - mb.syl) * 0.28
       + (a.family === b.family ? 0 : 0.7);
}

// ------------------------------------------------------------ challenge ---
const DIFF = {
  gentle:    { tiles:3, rounds:1, band:[0.55,1.0], lock:600,  penalty:'reshuffle', replay:true,
               blurb:'3 tiles, 1 round, nothing similar. For soft landings.' },
  standard:  { tiles:4, rounds:2, band:[0.25,0.85], lock:1000, penalty:'reshuffle', replay:true,
               blurb:'4 tiles, 2 rounds. The default.' },
  brutal:    { tiles:6, rounds:3, band:[0.0,0.5],  lock:1500, penalty:'addRound',  replay:true,
               blurb:'6 tiles, 3 rounds, similar-sounding decoys. A miss adds a round.' },
  nightmare: { tiles:9, rounds:3, band:[0.0,0.3],  lock:2500, penalty:'restart',   replay:false,
               blurb:'9 tiles, 3 rounds, the closest decoys, no replays. A miss starts you over.' }
};

const shuffle = a => { for (let i = a.length - 1; i > 0; i--) { const j = Math.random() * (i + 1) | 0; [a[i], a[j]] = [a[j], a[i]]; } return a; };

function decoys(answer, pool, count, band) {
  if (count <= 0) return [];
  const others = pool.filter(c => c.id !== answer.id)
                     .sort((x, y) => distance(answer, x) - distance(answer, y));
  if (!others.length) return [];
  if (others.length <= count) return others.slice(0, count);
  let lo = Math.floor(others.length * band[0]);
  let hi = Math.min(others.length, Math.ceil(others.length * band[1]));
  lo = Math.max(0, Math.min(lo, hi - 1));
  while (hi - lo < count) { if (lo > 0) lo--; else if (hi < others.length) hi++; else break; }
  return shuffle(others.slice(lo, hi)).slice(0, count);
}

function makeRound(cfg, pool, forced) {
  const answer = forced || pool[Math.random() * pool.length | 0];
  const options = decoys(answer, pool, cfg.tiles - 1, cfg.band).concat([answer]);
  return { answer, options: shuffle(options) };
}

const state = {
  level: 'standard', rounds: [], index: 0, misses: 0,
  lockedUntil: 0, solved: 0, totalMisses: 0, clean: 0, attempts: 0, roundMisses: 0
};

function pool() { return CATALOG; }

function newSession(keepStats) {
  const cfg = DIFF[state.level];
  state.rounds = Array.from({ length: cfg.rounds }, () => makeRound(cfg, pool()));
  state.index = 0; state.misses = 0; state.roundMisses = 0; state.lockedUntil = 0;
  if (!keepStats) { state.solved = 0; state.totalMisses = 0; state.clean = 0; state.attempts = 0; }
  drawAll();
  playCurrent();
}

function playCurrent() {
  const r = state.rounds[state.index];
  if (!r) return;
  if (!buffers.has(r.answer.id)) {
    setPrompt('Loading the chant\u2026');
    setTimeout(() => { play(r.answer, true).then(() => setPrompt('Who is chanting?')); }, 16);
  } else {
    play(r.answer, true);
  }
}

// ----------------------------------------------------------------- view ---
const IMAGES = new Map();

function preloadImages() {
  const entries = Object.entries(ASSETS).filter(([, a]) => a.image);
  return Promise.all(entries.map(([id, a]) => new Promise(resolve => {
    const im = new Image();
    im.onload = () => { IMAGES.set(id, im); resolve(); };
    im.onerror = () => resolve();      // fall back to the drawing
    im.src = a.image;
  })));
}

function tileCanvas(character, px) {
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const cv = document.createElement('canvas');
  cv.width = px * dpr; cv.height = px * dpr;
  const g = cv.getContext('2d');
  g.scale(dpr, dpr);
  const art = IMAGES.get(character.id);
  if (art) {
    // Cover-fit, so a non-square source is cropped rather than squashed.
    const s = Math.max(px / art.width, px / art.height);
    const w = art.width * s, h = art.height * s;
    g.drawImage(art, (px - w) / 2, (px - h) / 2, w, h);
  } else {
    drawCreature(g, character.art, px);
  }
  return cv;
}

function drawAll() { drawGrid(); drawPips(); drawStats(); drawSegs(); }

function drawGrid() {
  const grid = document.getElementById('grid');
  const r = state.rounds[state.index];
  grid.innerHTML = '';
  if (!r) return;
  const n = r.options.length;
  grid.dataset.cols = n === 3 ? 3 : (n <= 4 ? 2 : 3);
  const px = n <= 4 ? 240 : 170;
  for (const c of r.options) {
    const b = document.createElement('button');
    b.className = 'tile';
    b.type = 'button';
    b.setAttribute('aria-label', 'Unnamed creature');
    b.appendChild(tileCanvas(c, px));
    b.addEventListener('click', () => tap(c, b));
    grid.appendChild(b);
  }
}

function drawPips() {
  const pips = document.getElementById('pips');
  pips.innerHTML = '';
  state.rounds.forEach((_, i) => {
    const d = document.createElement('div');
    d.className = 'pip' + (i < state.index ? ' done' : i === state.index ? ' now' : '');
    pips.appendChild(d);
  });
}

function drawStats() {
  document.getElementById('sSolved').textContent = state.solved;
  document.getElementById('sMiss').textContent = state.totalMisses;
  document.getElementById('sClean').textContent =
    state.attempts ? Math.round(state.clean / state.attempts * 100) + '%' : '—';
}

function drawSegs() {
  const segs = document.getElementById('segs');
  if (!segs.children.length) {
    for (const key of Object.keys(DIFF)) {
      const b = document.createElement('button');
      b.className = 'seg'; b.type = 'button';
      b.textContent = key[0].toUpperCase() + key.slice(1);
      b.addEventListener('click', () => { state.level = key; newSession(true); });
      segs.appendChild(b);
    }
  }
  [...segs.children].forEach((b, i) => {
    const key = Object.keys(DIFF)[i];
    b.setAttribute('aria-pressed', String(key === state.level));
  });
  document.getElementById('blurb').textContent = DIFF[state.level].blurb;
  document.getElementById('replay').disabled = !DIFF[state.level].replay;
}

function setPrompt(text, mood) {
  const p = document.getElementById('prompt');
  p.textContent = text;
  if (mood) p.dataset.state = mood; else delete p.dataset.state;
}

// ------------------------------------------------------------------ tap ---
function tap(c, el) {
  const now = Date.now();
  if (now < state.lockedUntil) return;
  const cfg = DIFF[state.level];
  const r = state.rounds[state.index];
  if (!r) return;

  if (c.id === r.answer.id) {
    el.classList.add('right');
    state.attempts++;
    if (state.roundMisses === 0) state.clean++;
    state.roundMisses = 0;
    state.index++;
    if (state.index >= state.rounds.length) {
      state.solved++;
      stopAudio();
      setPrompt('Silenced. That was ' + r.answer.name + '.', 'right');
      drawPips(); drawStats();
      setTimeout(() => { setPrompt('Who is chanting?'); newSession(true); }, 2200);
    } else {
      setPrompt('Correct — next one', 'right');
      setTimeout(() => { setPrompt('Who is chanting?'); drawAll(); playCurrent(); }, 700);
    }
    return;
  }

  // wrong
  el.classList.add('wrong');
  state.misses++; state.totalMisses++; state.roundMisses++;
  state.lockedUntil = now + cfg.lock;
  setPrompt('Not that one. Listen again.', 'wrong');
  if (navigator.vibrate) navigator.vibrate(60);

  if (cfg.penalty === 'addRound') state.rounds.push(makeRound(cfg, pool()));
  else if (cfg.penalty === 'restart') {
    const keep = state.rounds[0].answer;
    state.rounds = Array.from({ length: cfg.rounds }, (_, i) => makeRound(cfg, pool(), i === 0 ? keep : null));
    state.index = 0;
  }
  const r2 = state.rounds[state.index];
  if (r2) r2.options = shuffle(r2.options.slice());

  const tick = () => {
    const left = state.lockedUntil - Date.now();
    const lock = document.getElementById('lock');
    if (left > 0) { lock.textContent = 'locked ' + (left / 1000).toFixed(1) + 's'; requestAnimationFrame(tick); }
    else { lock.textContent = ''; setPrompt('Who is chanting?'); drawAll(); playCurrent(); }
  };
  tick();
}

// --------------------------------------------------------------- roster ---
function buildRoster() {
  const host = document.getElementById('roster');
  if (host.children.length) return;
  for (const c of CATALOG) {
    const b = document.createElement('button');
    b.className = 'card'; b.type = 'button';
    b.appendChild(tileCanvas(c, 160));
    const name = document.createElement('b'); name.textContent = c.name;
    const hz = document.createElement('small');
    hz.textContent = Math.round(meta(c).pitch) + ' Hz · ' + c.voice.tempo.toFixed(1) + '/s';
    b.append(name, hz);
    b.addEventListener('click', () => {
      [...host.children].forEach(x => x.classList.remove('playing'));
      b.classList.add('playing');
      play(c, false);
    });
    host.appendChild(b);
  }
}

// ----------------------------------------------------------------- boot ---
function showTab(which) {
  const isPlay = which === 'play';
  document.getElementById('playView').classList.toggle('hidden', !isPlay);
  document.getElementById('rosterView').classList.toggle('hidden', isPlay);
  document.getElementById('tabPlay').setAttribute('aria-selected', String(isPlay));
  document.getElementById('tabRoster').setAttribute('aria-selected', String(!isPlay));
  if (!isPlay) { stopAudio(); buildRoster(); }
  else { drawAll(); playCurrent(); }
}

document.getElementById('start').addEventListener('click', async () => {
  const AC = window.AudioContext || window.webkitAudioContext;
  audioCtx = new AC({ sampleRate: SAMPLE_RATE });
  await audioCtx.resume();
  analyser = audioCtx.createAnalyser();
  analyser.fftSize = 2048;
  analyser.smoothingTimeConstant = 0.72;
  analyser.connect(audioCtx.destination);
  document.getElementById('gate').classList.add('hidden');
  document.getElementById('app').classList.remove('hidden');
  startMeter();
  await preloadImages();
  newSession(false);
  warmCache();
});

document.getElementById('replay').addEventListener('click', () => {
  if (Date.now() < state.lockedUntil) return;
  playCurrent();
});
document.getElementById('skip').addEventListener('click', () => {
  const r = state.rounds[state.index];
  if (r) setPrompt('That was ' + r.answer.name + '.');
  state.attempts++;
  setTimeout(() => { setPrompt('Who is chanting?'); newSession(true); }, 1600);
});
document.getElementById('tabPlay').addEventListener('click', () => showTab('play'));
document.getElementById('tabRoster').addEventListener('click', () => showTab('roster'));

// A creature on the gate, so you see what you are getting into.
(function gateArt() {
  const cv = document.getElementById('gateArt');
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  cv.width = 150 * dpr; cv.height = 150 * dpr;
  const g = cv.getContext('2d'); g.scale(dpr, dpr);
  const art = IMAGES.get(CATALOG[0].id);
  if (art) g.drawImage(art, 0, 0, 150, 150); else drawCreature(g, CATALOG[0].art, 150);
})();
