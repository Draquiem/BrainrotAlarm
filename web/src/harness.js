const fs = require('fs');
const js = fs.readFileSync('/tmp/combined.js', 'utf8');

// --- minimal canvas / DOM stubs -------------------------------------------
let ops = 0;
const grad = { addColorStop() {} };
const ctx2d = new Proxy({}, {
  get(_, k) {
    if (k === 'createLinearGradient') return () => grad;
    if (k === 'canvas') return { width: 100, height: 100 };
    return (...a) => { ops++; for (const v of a) if (typeof v === 'number' && !Number.isFinite(v)) throw new Error('non-finite arg to ' + String(k)); };
  },
  set() { return true; }
});
const listeners = {};
function makeEl(id) {
  return {
    id, children: [], style: {}, dataset: {}, textContent: '', innerHTML: '',
    clientWidth: 320, clientHeight: 56, width: 0, height: 0, disabled: false,
    classList: { add() {}, remove() {}, toggle() {}, contains: () => false },
    setAttribute() {}, getAttribute() { return null; },
    appendChild(c) { this.children.push(c); }, append(...c) { this.children.push(...c); },
    addEventListener(ev, fn) { (listeners[id] ||= {})[ev] = fn; },
    getContext: () => ctx2d
  };
}
const registry = {};
global.document = {
  getElementById: id => (registry[id] ||= makeEl(id)),
  createElement: tag => makeEl('<' + tag + '>')
};
global.window = { devicePixelRatio: 2 };
global.navigator = {};
global.requestAnimationFrame = () => 0;
global.setTimeout = () => 0;

const scope = {};
new Function('with(this){' + js + '\n; this.__x = {CATALOG, DIFF, decoys, makeRound, distance, meta, drawCreature, parseChant, render, voiceOf, tileCanvas, state, newSession};}').call(scope);
const X = scope.__x;

console.log('=== 1. catalogue ===');
console.log('  characters:', X.CATALOG.length);
console.log('  ids unique:', new Set(X.CATALOG.map(c => c.id)).size === X.CATALOG.length);

console.log('\n=== 2. every creature draws without throwing ===');
let drawn = 0, before = ops;
for (const c of X.CATALOG) { X.drawCreature(ctx2d, c.art, 220); drawn++; }
console.log(`  ${drawn}/24 recipes drew, ${ops - before} canvas ops, no non-finite coordinates`);

console.log('\n=== 3. decoy bands ===');
for (const [name, cfg] of Object.entries(X.DIFF)) {
  let sum = 0, n = 0, sizes = new Set();
  for (let t = 0; t < 200; t++) {
    const r = X.makeRound(cfg, X.CATALOG);
    sizes.add(r.options.length);
    if (new Set(r.options.map(o => o.id)).size !== r.options.length) throw new Error('duplicate tile in ' + name);
    if (!r.options.some(o => o.id === r.answer.id)) throw new Error('answer missing in ' + name);
    for (const o of r.options) if (o.id !== r.answer.id) { sum += X.distance(r.answer, o); n++; }
  }
  console.log(`  ${name.padEnd(10)} tiles=${[...sizes].join('/')}  mean decoy distance ${(sum/n).toFixed(2)}`);
}

console.log('\n=== 4. difficulty gradient ===');
const md = k => { let s=0,n=0; for(let t=0;t<300;t++){const r=X.makeRound(X.DIFF[k],X.CATALOG);
  for(const o of r.options) if(o.id!==r.answer.id){s+=X.distance(r.answer,o);n++;}} return s/n; };
const g = md('gentle'), nm = md('nightmare');
console.log(`  gentle ${g.toFixed(2)} vs nightmare ${nm.toFixed(2)} — ${g > nm*1.5 ? 'gradient holds' : 'COLLAPSED'}`);

console.log('\n=== 5. pitch / rate spread (matches the Swift analysis) ===');
const pitches = X.CATALOG.map(c => X.meta(c).pitch);
const tempos = X.CATALOG.map(c => c.voice.tempo);
console.log(`  pitch ${Math.min(...pitches).toFixed(0)}–${Math.max(...pitches).toFixed(0)} Hz`);
console.log(`  tempo ${Math.min(...tempos).toFixed(1)}–${Math.max(...tempos).toFixed(1)} syl/s`);
let closest = Infinity, pair = '';
for (let i = 0; i < X.CATALOG.length; i++)
  for (let j = i+1; j < X.CATALOG.length; j++) {
    const d = X.distance(X.CATALOG[i], X.CATALOG[j]);
    if (d < closest) { closest = d; pair = X.CATALOG[i].id + '/' + X.CATALOG[j].id; }
  }
console.log(`  closest pair ${closest.toFixed(2)} (${pair})`);

console.log('\n=== 6. audio renders for all 24 ===');
let slowest = 0, slowId = '';
const t0 = Date.now();
for (const c of X.CATALOG) {
  const s0 = Date.now();
  const s = X.render(c.chant, X.voiceOf(c), 0x5EED);
  const dt = Date.now() - s0;
  if (dt > slowest) { slowest = dt; slowId = c.id; }
  if (!s.length || !s.every(Number.isFinite)) throw new Error('bad audio for ' + c.id);
}
console.log(`  all 24 rendered in ${Date.now()-t0}ms total, slowest ${slowId} at ${slowest}ms`);
console.log('\nALL CHECKS PASSED');
