// Canvas 2D port of CreatureRenderer.swift. Same parts vocabulary, same unit
// coordinate space (0..1 square), so a recipe draws identically in both.

const INK = '#1B1524';

function hex(n) { return '#' + n.toString(16).padStart(6, '0'); }

const BODY_RECTS = {
  blob:     [0.16, 0.40, 0.68, 0.50],
  pear:     [0.20, 0.38, 0.60, 0.54],
  tall:     [0.29, 0.30, 0.42, 0.62],
  wide:     [0.12, 0.46, 0.76, 0.38],
  fruit:    [0.23, 0.34, 0.54, 0.56],
  cup:      [0.26, 0.40, 0.48, 0.48],
  log:      [0.32, 0.20, 0.36, 0.72],
  fuselage: [0.15, 0.44, 0.70, 0.34]
};

function anatomy(r) {
  const [x, y, w, h] = BODY_RECTS[r.body];
  const body = { minX:x, minY:y, w, h, maxX:x+w, maxY:y+h, midX:x+w/2, midY:y+h/2 };
  if (r.head === 'merged') {
    const c = { x: body.midX, y: body.minY + body.h * 0.34 };
    return { body, headCenter:c, headRadius:0, faceCenter:c, faceScale:Math.min(body.w, body.h) * 0.9 };
  }
  const radius = r.head === 'wedge' ? 0.19 : 0.165;
  const c = r.body === 'wide'
    ? { x: body.minX + 0.10, y: body.minY - 0.02 }
    : { x: body.midX, y: body.minY - radius * 0.55 };
  return { body, headCenter:c, headRadius:radius,
           faceCenter:{ x:c.x, y:c.y + radius * 0.12 }, faceScale:radius * 2 };
}

export function drawCreature(ctx, recipe, size, opts = {}) {
  const pal = recipe.palette;
  const inset = size * 0.06;
  const R = { x: inset, y: inset, w: size - inset * 2 };
  const P = (ux, uy) => [R.x + ux * R.w, R.y + uy * R.w];
  const S = u => u * R.w;
  const a = anatomy(recipe);
  const lw = S(0.012);

  if (opts.backdrop !== false) {
    const g = ctx.createLinearGradient(0, 0, size, size);
    g.addColorStop(0, hex(pal.backdropTop));
    g.addColorStop(1, hex(pal.backdropBottom));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, size, size);
  }

  const stroke = (color = INK, width = lw) => { ctx.strokeStyle = color; ctx.lineWidth = width; ctx.stroke(); };
  const fill = c => { ctx.fillStyle = c; ctx.fill(); };
  const bodyGradient = () => {
    const [x0, y0] = P(0.3, 0.2), [x1, y1] = P(0.8, 1.0);
    const g = ctx.createLinearGradient(x0, y0, x1, y1);
    g.addColorStop(0, hex(pal.body)); g.addColorStop(1, hex(pal.bodyShade));
    return g;
  };
  const circlePath = (cx, cy, rad) => {
    const [x, y] = P(cx, cy);
    ctx.beginPath(); ctx.arc(x, y, S(rad), 0, Math.PI * 2);
  };
  const ellipseRect = (rx, ry, rw, rh) => {
    const [x, y] = P(rx, ry);
    ctx.beginPath();
    ctx.ellipse(x + S(rw) / 2, y + S(rh) / 2, S(rw) / 2, S(rh) / 2, 0, 0, Math.PI * 2);
  };
  const roundRectPath = (rx, ry, rw, rh, rad) => {
    const [x, y] = P(rx, ry);
    ctx.beginPath(); ctx.roundRect(x, y, S(rw), S(rh), S(rad));
  };

  const b = a.body;

  // ---------------------------------------------------------- back props ---
  if (recipe.prop === 'planetRing') {
    const [x, y] = P(b.midX - 0.46, b.midY - 0.11);
    ctx.beginPath();
    ctx.ellipse(x + S(0.46), y + S(0.11), S(0.46), S(0.11), 0, 0, Math.PI * 2);
    stroke(hex(pal.accent), S(0.05));
    stroke('rgba(27,21,36,0.4)', S(0.008));
  } else if (recipe.prop === 'sparkles') {
    for (const [sx, sy, k] of [[0.14,0.20,0.055],[0.86,0.30,0.042],[0.20,0.78,0.035],[0.82,0.70,0.050]]) {
      const [cx, cy] = P(sx, sy); const s = S(k);
      ctx.beginPath();
      ctx.moveTo(cx, cy - s);
      ctx.quadraticCurveTo(cx, cy, cx + s, cy);
      ctx.quadraticCurveTo(cx, cy, cx, cy + s);
      ctx.quadraticCurveTo(cx, cy, cx - s, cy);
      ctx.quadraticCurveTo(cx, cy, cx, cy - s);
      fill(hex(pal.accent));
    }
  } else if (recipe.prop === 'propeller') {
    ctx.beginPath();
    ctx.moveTo(...P(b.maxX - 0.02, b.midY - 0.16));
    ctx.lineTo(...P(b.maxX + 0.03, b.midY + 0.16));
    stroke('rgba(27,21,36,0.7)', S(0.03));
  }

  // -------------------------------------------------------------- limbs ---
  const limb = (x, y, w, h) => { roundRectPath(x, y, w, h, w / 2); fill(hex(pal.bodyShade)); stroke(); };
  switch (recipe.limbs) {
    case 'stubby':
      limb(b.midX - 0.17, b.maxY - 0.03, 0.10, 0.14);
      limb(b.midX + 0.07, b.maxY - 0.03, 0.10, 0.14); break;
    case 'long':
      limb(b.midX - 0.17, b.maxY - 0.04, 0.075, 0.22);
      limb(b.midX + 0.09, b.maxY - 0.04, 0.075, 0.22);
      limb(b.minX - 0.05, b.minY + b.h * 0.20, 0.065, 0.20);
      limb(b.maxX - 0.02, b.minY + b.h * 0.20, 0.065, 0.20); break;
    case 'hooves':
      for (const x of [b.minX + 0.06, b.minX + 0.22, b.maxX - 0.30, b.maxX - 0.14]) {
        limb(x, b.maxY - 0.03, 0.075, 0.18);
        roundRectPath(x, b.maxY + 0.09, 0.075, 0.06, 0.02);
        fill('rgba(27,21,36,0.8)');
      } break;
    case 'fins':
      for (const side of [-1, 1]) {
        const ax = side < 0 ? b.minX + 0.03 : b.maxX - 0.03;
        ctx.beginPath();
        ctx.moveTo(...P(ax, b.midY - 0.02));
        ctx.quadraticCurveTo(...P(ax + side*0.18, b.midY - 0.06), ...P(ax + side*0.19, b.midY + 0.13));
        ctx.quadraticCurveTo(...P(ax + side*0.07, b.midY + 0.12), ...P(ax, b.midY + 0.09));
        ctx.closePath(); fill(hex(pal.bodyShade)); stroke();
      } break;
    case 'wings':
      for (const side of [-1, 1]) {
        ctx.beginPath();
        ctx.moveTo(...P(b.midX, b.midY - 0.02));
        ctx.lineTo(...P(b.midX + side*0.46, b.midY - 0.26));
        ctx.lineTo(...P(b.midX + side*0.40, b.midY + 0.06));
        ctx.closePath();
        const [gx0, gy0] = P(b.midX, b.midY), [gx1, gy1] = P(b.midX + side*0.4, b.midY);
        const g = ctx.createLinearGradient(gx0, gy0, gx1, gy1);
        g.addColorStop(0, hex(pal.bodyShade)); g.addColorStop(1, hex(pal.body));
        fill(g); stroke();
      } break;
    case 'tentacles':
      ctx.lineCap = 'round';
      for (let i = 0; i < 5; i++) {
        const t = i / 4, x = b.minX + b.w * (0.10 + 0.80 * t), even = i % 2 === 0;
        ctx.beginPath();
        ctx.moveTo(...P(x, b.maxY - 0.04));
        ctx.quadraticCurveTo(...P(x + (even ? -0.04 : 0.04), b.maxY + 0.06),
                             ...P(x + (even ?  0.05 : -0.05), b.maxY + 0.14));
        stroke(hex(pal.bodyShade), S(0.045));
      }
      ctx.lineCap = 'butt'; break;
  }

  // --------------------------------------------------------------- body ---
  ctx.beginPath();
  switch (recipe.body) {
    case 'blob': case 'fruit': {
      const [x, y] = P(b.minX, b.minY);
      ctx.ellipse(x + S(b.w)/2, y + S(b.h)/2, S(b.w)/2, S(b.h)/2, 0, 0, Math.PI*2); break;
    }
    case 'pear':
      ctx.moveTo(...P(b.midX, b.minY));
      ctx.quadraticCurveTo(...P(b.maxX + 0.02, b.minY + b.h*0.45), ...P(b.maxX, b.maxY - b.h*0.18));
      ctx.quadraticCurveTo(...P(b.maxX - b.w*0.1, b.maxY), ...P(b.midX, b.maxY));
      ctx.quadraticCurveTo(...P(b.minX + b.w*0.1, b.maxY), ...P(b.minX, b.maxY - b.h*0.18));
      ctx.quadraticCurveTo(...P(b.minX - 0.02, b.minY + b.h*0.45), ...P(b.midX, b.minY));
      break;
    case 'tall': case 'wide': {
      const [x, y] = P(b.minX, b.minY);
      ctx.roundRect(x, y, S(b.w), S(b.h), S(Math.min(b.w, b.h) * 0.48)); break;
    }
    case 'cup':
      ctx.moveTo(...P(b.minX, b.minY));
      ctx.lineTo(...P(b.maxX, b.minY));
      ctx.lineTo(...P(b.maxX - b.w*0.16, b.maxY));
      ctx.quadraticCurveTo(...P(b.midX, b.maxY + 0.03), ...P(b.minX + b.w*0.16, b.maxY));
      ctx.closePath(); break;
    case 'log': {
      const [x, y] = P(b.minX, b.minY);
      ctx.roundRect(x, y, S(b.w), S(b.h), S(b.w * 0.30)); break;
    }
    case 'fuselage':
      ctx.moveTo(...P(b.maxX, b.midY));
      ctx.quadraticCurveTo(...P(b.maxX - b.w*0.35, b.minY - 0.02), ...P(b.minX + b.w*0.12, b.minY));
      ctx.quadraticCurveTo(...P(b.minX - 0.02, b.minY + b.h*0.3), ...P(b.minX, b.midY));
      ctx.quadraticCurveTo(...P(b.minX - 0.02, b.maxY - b.h*0.3), ...P(b.minX + b.w*0.12, b.maxY));
      ctx.quadraticCurveTo(...P(b.maxX - b.w*0.35, b.maxY + 0.02), ...P(b.maxX, b.midY));
      break;
  }
  fill(bodyGradient());

  // ------------------------------------------------------------ pattern ---
  if (recipe.pattern !== 'none') {
    ctx.save(); ctx.clip();
    const ink = hex(pal.bodyShade) + '8C';
    ctx.fillStyle = ink; ctx.strokeStyle = ink;
    if (recipe.pattern === 'stripes') {
      for (let i = 0; i < 1; i += 0.19) {
        const [x, y] = P(b.minX + b.w * i, b.minY);
        ctx.fillRect(x, y, S(b.w * 0.075), S(b.h));
      }
    } else if (recipe.pattern === 'spots') {
      for (const [sx, sy, sr] of [[0.28,0.30,0.10],[0.62,0.22,0.07],[0.44,0.62,0.09],[0.75,0.58,0.06],[0.20,0.72,0.06]]) {
        const [x, y] = P(b.minX + b.w*sx, b.minY + b.h*sy);
        ctx.beginPath(); ctx.arc(x, y, S(b.w*sr), 0, Math.PI*2); ctx.fill();
      }
    } else if (recipe.pattern === 'scales') {
      let row = 0;
      for (let y = b.minY; y < b.maxY; y += b.h * 0.13) {
        for (let x = b.minX + (row % 2 === 0 ? 0 : b.w*0.07); x < b.maxX; x += b.w * 0.14) {
          const [px, py] = P(x, y);
          ctx.beginPath();
          ctx.arc(px + S(b.w*0.15)/2, py, S(b.w*0.15)/2, Math.PI, 0, true);
          ctx.lineWidth = S(0.008); ctx.stroke();
        }
        row++;
      }
    } else if (recipe.pattern === 'checker') {
      let row = 0;
      for (let y = b.minY; y < b.maxY; y += b.h * 0.15) {
        let col = 0;
        for (let x = b.minX; x < b.maxX; x += b.w * 0.17) {
          if ((row + col) % 2 === 0) {
            const [px, py] = P(x, y);
            ctx.fillRect(px, py, S(b.w*0.17), S(b.h*0.15));
          }
          col++;
        }
        row++;
      }
    } else if (recipe.pattern === 'swirl') {
      const [cx, cy] = P(b.midX, b.midY);
      ctx.beginPath(); ctx.moveTo(cx, cy);
      let rad = S(b.w*0.06), ang = 0;
      while (rad < S(b.w*0.5)) {
        ang += 0.35; rad += S(b.w*0.012);
        ctx.lineTo(cx + Math.cos(ang)*rad, cy + Math.sin(ang)*rad);
      }
      ctx.lineWidth = S(0.014); ctx.stroke();
    }
    ctx.restore();
  }
  // re-stroke the silhouette over the pattern
  ctx.save(); ctx.beginPath();
  switch (recipe.body) {
    case 'blob': case 'fruit': { const [x,y] = P(b.minX,b.minY);
      ctx.ellipse(x+S(b.w)/2, y+S(b.h)/2, S(b.w)/2, S(b.h)/2, 0, 0, Math.PI*2); break; }
    case 'tall': case 'wide': { const [x,y] = P(b.minX,b.minY);
      ctx.roundRect(x, y, S(b.w), S(b.h), S(Math.min(b.w,b.h)*0.48)); break; }
    case 'log': { const [x,y] = P(b.minX,b.minY);
      ctx.roundRect(x, y, S(b.w), S(b.h), S(b.w*0.30)); break; }
    default: break;
  }
  stroke('rgba(27,21,36,0.55)'); ctx.restore();

  // --------------------------------------------------------------- ears ---
  const c = a.headCenter, hr = Math.max(a.headRadius, 0.14);
  const mirrored = (build, color = hex(pal.bodyShade)) => {
    for (const side of [-1, 1]) { build(side); fill(color); stroke(); }
  };
  switch (recipe.ears) {
    case 'round':
      mirrored(side => circlePath(c.x + side*hr*0.82, c.y - hr*0.62, hr*0.36)); break;
    case 'pointy':
      mirrored(side => { ctx.beginPath();
        ctx.moveTo(...P(c.x + side*hr*0.28, c.y - hr*0.80));
        ctx.lineTo(...P(c.x + side*hr*0.92, c.y - hr*1.45));
        ctx.lineTo(...P(c.x + side*hr*1.00, c.y - hr*0.52)); ctx.closePath(); }); break;
    case 'floppy':
      mirrored(side => { ctx.beginPath();
        ctx.moveTo(...P(c.x + side*hr*0.70, c.y - hr*0.45));
        ctx.quadraticCurveTo(...P(c.x + side*hr*1.55, c.y + hr*0.05), ...P(c.x + side*hr*1.05, c.y + hr*0.65));
        ctx.quadraticCurveTo(...P(c.x + side*hr*0.85, c.y + hr*0.45), ...P(c.x + side*hr*0.55, c.y + hr*0.05));
        ctx.closePath(); }); break;
    case 'horns':
      mirrored(side => { ctx.beginPath();
        ctx.moveTo(...P(c.x + side*hr*0.62, c.y - hr*0.62));
        ctx.lineTo(...P(c.x + side*hr*1.25, c.y - hr*1.20));
        ctx.lineTo(...P(c.x + side*hr*0.92, c.y - hr*0.45)); ctx.closePath(); }, hex(pal.accent)); break;
    case 'fin':
      ctx.beginPath();
      ctx.moveTo(...P(b.midX - 0.09, b.minY + 0.03));
      ctx.lineTo(...P(b.midX + 0.02, b.minY - 0.16));
      ctx.lineTo(...P(b.midX + 0.10, b.minY + 0.03));
      ctx.closePath(); fill(hex(pal.bodyShade)); stroke(); break;
    case 'antennae':
      for (const side of [-1, 1]) {
        ctx.beginPath();
        ctx.moveTo(...P(c.x + side*hr*0.35, c.y - hr*0.85));
        ctx.quadraticCurveTo(...P(c.x + side*hr*0.45, c.y - hr*1.40), ...P(c.x + side*hr*0.95, c.y - hr*1.60));
        stroke(hex(pal.bodyShade), S(0.016));
        circlePath(c.x + side*hr*0.95, c.y - hr*1.60, hr*0.20);
        fill(hex(pal.accent)); stroke();
      } break;
    case 'leaf':
      for (const side of [-1, 1]) {
        ctx.beginPath();
        ctx.moveTo(...P(c.x + side*hr*0.25, c.y - hr*0.85));
        ctx.quadraticCurveTo(...P(c.x + side*hr*1.20, c.y - hr*0.55), ...P(c.x + side*hr*1.30, c.y - hr*1.35));
        ctx.quadraticCurveTo(...P(c.x + side*hr*0.55, c.y - hr*1.55), ...P(c.x + side*hr*0.25, c.y - hr*0.85));
        fill(hex(pal.accent)); stroke();
      } break;
  }

  // --------------------------------------------------------------- head ---
  if (recipe.head !== 'merged') {
    const hrad = a.headRadius;
    ctx.beginPath();
    if (recipe.head === 'round') { const [x,y] = P(c.x, c.y); ctx.arc(x, y, S(hrad), 0, Math.PI*2); }
    else if (recipe.head === 'snout') {
      const [x,y] = P(c.x, c.y); ctx.arc(x, y, S(hrad), 0, Math.PI*2);
      const [mx,my] = P(c.x + hrad*0.05, c.y + hrad*0.45);
      ctx.moveTo(mx + S(hrad*0.62), my); ctx.arc(mx, my, S(hrad*0.62), 0, Math.PI*2);
    } else if (recipe.head === 'wedge') {
      ctx.moveTo(...P(c.x - hrad*1.15, c.y - hrad*0.35));
      ctx.quadraticCurveTo(...P(c.x, c.y - hrad*1.05), ...P(c.x + hrad*1.2, c.y + hrad*0.1));
      ctx.quadraticCurveTo(...P(c.x, c.y + hrad*1.0), ...P(c.x - hrad*1.15, c.y + hrad*0.75));
      ctx.closePath();
    } else if (recipe.head === 'beak') { const [x,y] = P(c.x, c.y); ctx.arc(x, y, S(hrad*0.92), 0, Math.PI*2); }
    else if (recipe.head === 'box') {
      const [x,y] = P(c.x - hrad, c.y - hrad);
      ctx.roundRect(x, y, S(hrad*2), S(hrad*2), S(hrad*0.3));
    }
    const [gx0,gy0] = P(c.x - hrad, c.y - hrad), [gx1,gy1] = P(c.x + hrad, c.y + hrad);
    const hg = ctx.createLinearGradient(gx0, gy0, gx1, gy1);
    hg.addColorStop(0, hex(pal.body)); hg.addColorStop(1, hex(pal.bodyShade));
    fill(hg); stroke();

    if (recipe.head === 'beak') {
      ctx.beginPath();
      ctx.moveTo(...P(c.x + hrad*0.75, c.y - hrad*0.12));
      ctx.lineTo(...P(c.x + hrad*1.7,  c.y + hrad*0.14));
      ctx.lineTo(...P(c.x + hrad*0.75, c.y + hrad*0.42));
      ctx.closePath(); fill(hex(pal.accent)); stroke();
    }
  }

  // --------------------------------------------------------------- eyes ---
  const f = a.faceCenter, fs = a.faceScale;
  const dx = fs * 0.23, ey = f.y - fs * 0.06;
  switch (recipe.eyes) {
    case 'big': case 'googly': {
      const drift = recipe.eyes === 'googly' ? 0.035 : 0;
      for (const side of [-1, 1]) {
        circlePath(f.x + side*dx, ey, fs*0.155); fill('#fff'); stroke();
        circlePath(f.x + side*dx + side*drift, ey + drift, fs*0.072); fill(INK);
      } break;
    }
    case 'beady':
      for (const side of [-1, 1]) { circlePath(f.x + side*dx, ey, fs*0.055); fill(INK); } break;
    case 'sleepy':
      for (const side of [-1, 1]) {
        circlePath(f.x + side*dx, ey, fs*0.14); fill('#fff'); stroke();
        circlePath(f.x + side*dx, ey + fs*0.045, fs*0.062); fill(INK);
        ctx.beginPath();
        ctx.moveTo(...P(f.x + side*dx - fs*0.15, ey - fs*0.02));
        ctx.quadraticCurveTo(...P(f.x + side*dx, ey - fs*0.20), ...P(f.x + side*dx + fs*0.15, ey - fs*0.02));
        stroke(INK, S(0.018));
      } break;
    case 'shades': {
      roundRectPath(f.x - dx - fs*0.20, ey - fs*0.11, dx*2 + fs*0.40, fs*0.22, fs*0.06);
      fill(INK);
      ctx.beginPath();
      ctx.moveTo(...P(f.x - dx*0.6, ey + fs*0.05));
      ctx.lineTo(...P(f.x - dx*0.2, ey - fs*0.06));
      stroke('rgba(255,255,255,0.75)', S(0.012)); break;
    }
    case 'single':
      circlePath(f.x, ey, fs*0.24); fill('#fff'); stroke();
      circlePath(f.x, ey, fs*0.10); fill(INK); break;
  }

  // -------------------------------------------------------------- mouth ---
  const my = f.y + fs * 0.26;
  switch (recipe.mouth) {
    case 'flat':
      ctx.beginPath(); ctx.moveTo(...P(f.x - fs*0.13, my)); ctx.lineTo(...P(f.x + fs*0.13, my));
      stroke(INK, S(0.016)); break;
    case 'smile': case 'grin':
      ctx.beginPath();
      ctx.moveTo(...P(f.x - fs*0.18, my - fs*0.04));
      ctx.quadraticCurveTo(...P(f.x, my + fs*0.16), ...P(f.x + fs*0.18, my - fs*0.04));
      stroke(INK, S(0.016));
      if (recipe.mouth === 'grin') {
        ctx.beginPath();
        ctx.moveTo(...P(f.x - fs*0.15, my + fs*0.005));
        ctx.lineTo(...P(f.x + fs*0.15, my + fs*0.005));
        stroke(INK, S(0.010));
      } break;
    case 'gasp': circlePath(f.x, my + fs*0.03, fs*0.11); fill(INK); break;
    case 'fangs':
      ctx.beginPath();
      ctx.moveTo(...P(f.x - fs*0.22, my - fs*0.03));
      ctx.quadraticCurveTo(...P(f.x, my + fs*0.14), ...P(f.x + fs*0.22, my - fs*0.03));
      stroke(INK, S(0.016));
      for (const off of [-0.12, 0.02]) {
        ctx.beginPath();
        ctx.moveTo(...P(f.x + off, my - fs*0.01));
        ctx.lineTo(...P(f.x + off + fs*0.05, my - fs*0.01));
        ctx.lineTo(...P(f.x + off + fs*0.025, my + fs*0.09));
        ctx.closePath(); fill('#fff'); stroke(INK, S(0.008));
      } break;
  }

  // -------------------------------------------------------- front props ---
  switch (recipe.prop) {
    case 'sneakers':
      for (const x of [b.midX - 0.30, b.midX - 0.05, b.midX + 0.20]) {
        roundRectPath(x, b.maxY + 0.05, 0.16, 0.075, 0.032); fill('#fff'); stroke();
        ctx.beginPath();
        ctx.moveTo(...P(x + 0.02, b.maxY + 0.10));
        ctx.quadraticCurveTo(...P(x + 0.08, b.maxY + 0.11), ...P(x + 0.13, b.maxY + 0.068));
        stroke(hex(pal.accent), S(0.014));
      } break;
    case 'bomb':
      circlePath(b.midX + 0.02, b.maxY + 0.06, 0.115); fill(INK); stroke();
      ctx.beginPath();
      ctx.moveTo(...P(b.midX + 0.08, b.maxY - 0.03));
      ctx.quadraticCurveTo(...P(b.midX + 0.17, b.maxY - 0.02), ...P(b.midX + 0.17, b.maxY - 0.12));
      stroke(hex(pal.accent), S(0.018));
      circlePath(b.midX + 0.17, b.maxY - 0.135, 0.028); fill('#FFB030'); break;
    case 'coffeeCup':
      roundRectPath(b.maxX - 0.02, b.midY - 0.04, 0.17, 0.20, 0.03); fill('#fff'); stroke();
      { const [hx, hy] = P(b.maxX + 0.16, b.midY + 0.06);
        ctx.beginPath(); ctx.arc(hx, hy, S(0.06), -1.4, 1.4); stroke(INK, S(0.016)); } break;
    case 'cactus':
      for (const side of [-1, 1]) {
        roundRectPath(b.midX + side*0.22 - (side < 0 ? 0.08 : 0), b.minY + 0.16, 0.09, 0.24, 0.045);
        fill(hex(pal.body)); stroke();
      } break;
    case 'banana':
      ctx.beginPath();
      ctx.moveTo(...P(b.midX - 0.24, b.minY + 0.10));
      ctx.quadraticCurveTo(...P(b.midX, b.maxY + 0.10), ...P(b.midX + 0.24, b.minY + 0.10));
      ctx.quadraticCurveTo(...P(b.midX, b.maxY - 0.06), ...P(b.midX - 0.24, b.minY + 0.10));
      fill('#F2C63D'); stroke(); break;
    case 'drumstick':
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(...P(b.maxX + 0.02, b.maxY - 0.02));
      ctx.lineTo(...P(b.maxX + 0.20, b.minY + 0.06));
      stroke(hex(pal.accent), S(0.055)); stroke(INK, S(0.008));
      ctx.lineCap = 'butt'; break;
    case 'melon': {
      const [mx, myy] = P(b.midX, b.midY + 0.16);
      ctx.beginPath(); ctx.moveTo(...P(b.midX - 0.20, b.midY + 0.16));
      ctx.lineTo(...P(b.midX + 0.20, b.midY + 0.16));
      ctx.arc(mx, myy, S(0.20), 0, Math.PI);
      ctx.closePath(); fill(hex(pal.accent)); stroke();
      for (const d of [-0.09, 0, 0.09]) { circlePath(b.midX + d, b.midY + 0.24, 0.016); fill(INK); }
      break;
    }
    case 'pineapple':
      for (const side of [-1, 0, 1]) {
        ctx.beginPath();
        ctx.moveTo(...P(b.midX + side*0.05, b.minY + 0.02));
        ctx.lineTo(...P(b.midX + side*0.16, b.minY - 0.18));
        ctx.lineTo(...P(b.midX + side*0.11, b.minY + 0.02));
        ctx.closePath(); fill(hex(pal.accent)); stroke();
      } break;
    case 'tyre': {
      const [tx, ty] = P(b.midX, b.midY);
      ctx.beginPath(); ctx.ellipse(tx, ty, S(0.30), S(0.24), 0, 0, Math.PI*2);
      stroke('#2A2A2E', S(0.085)); stroke('rgba(27,21,36,0.5)', S(0.008)); break;
    }
    case 'coconut':
      for (const [ddx, ddy] of [[-0.09,-0.03],[0.09,-0.03],[0,0.09]]) {
        circlePath(b.midX + ddx, b.midY + ddy, 0.038); fill('rgba(27,21,36,0.75)');
      } break;
    case 'berry':
      for (const side of [-1, 0, 1]) {
        ctx.beginPath();
        ctx.moveTo(...P(b.midX, b.minY - 0.01));
        ctx.quadraticCurveTo(...P(b.midX + side*0.15, b.minY - 0.02), ...P(b.midX + side*0.16, b.minY - 0.11));
        ctx.quadraticCurveTo(...P(b.midX + side*0.05, b.minY - 0.09), ...P(b.midX, b.minY - 0.01));
        fill(hex(pal.accent)); stroke();
      } break;
    case 'ball':
      for (const [ddx, ddy] of [[0,-0.10],[-0.15,0.08],[0.15,0.08]]) {
        const [px, py] = P(b.midX + ddx, b.midY + ddy), k = S(0.075);
        ctx.beginPath();
        for (let i = 0; i < 5; i++) {
          const ang = i/5 * Math.PI*2 - Math.PI/2;
          const pt = [px + Math.cos(ang)*k, py + Math.sin(ang)*k];
          i === 0 ? ctx.moveTo(...pt) : ctx.lineTo(...pt);
        }
        ctx.closePath(); fill(INK); stroke();
      } break;
    case 'clock':
      circlePath(b.maxX + 0.06, b.midY - 0.02, 0.115); fill('#fff'); stroke();
      ctx.beginPath();
      ctx.moveTo(...P(b.maxX + 0.06, b.midY - 0.02)); ctx.lineTo(...P(b.maxX + 0.06, b.midY - 0.10));
      ctx.moveTo(...P(b.maxX + 0.06, b.midY - 0.02)); ctx.lineTo(...P(b.maxX + 0.12, b.midY - 0.02));
      stroke(INK, S(0.014)); break;
    case 'cigar':
      roundRectPath(f.x + 0.05, f.y + fs*0.22, 0.20, 0.045, 0.02); fill('#6B4A2A'); stroke();
      circlePath(f.x + 0.26, f.y + fs*0.24, 0.022); fill('#FF7A30'); break;
    case 'fridge':
      roundRectPath(b.minX - 0.12, b.minY - 0.04, 0.20, 0.34, 0.03); fill(hex(pal.accent)); stroke();
      ctx.beginPath();
      ctx.moveTo(...P(b.minX - 0.005, b.minY + 0.06)); ctx.lineTo(...P(b.minX - 0.005, b.minY + 0.16));
      stroke(INK, S(0.016)); break;
    case 'blade':
      ctx.lineCap = 'round';
      for (const side of [-1, 1]) {
        ctx.beginPath();
        ctx.moveTo(...P(b.midX + side*0.10, b.maxY - 0.02));
        ctx.lineTo(...P(b.midX + side*0.40, b.minY - 0.06));
        stroke('#D8DCE4', S(0.030)); stroke(INK, S(0.007));
      }
      ctx.lineCap = 'butt'; break;
    case 'tutu':
      ctx.beginPath();
      ctx.moveTo(...P(b.midX - 0.12, b.maxY - 0.10));
      ctx.quadraticCurveTo(...P(b.midX, b.maxY - 0.02), ...P(b.midX + 0.12, b.maxY - 0.10));
      ctx.lineTo(...P(b.midX + 0.30, b.maxY + 0.04));
      ctx.quadraticCurveTo(...P(b.midX, b.maxY + 0.14), ...P(b.midX - 0.30, b.maxY + 0.04));
      ctx.closePath(); fill(hex(pal.accent)); stroke(); break;
  }
}
