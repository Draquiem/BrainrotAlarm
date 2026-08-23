# Web build

The alarm's dismissal game, running in a browser — the same synthesiser and the
same artwork as the iOS app, ported so the mechanic can be tested on a phone
without an Apple Developer account.

`index.html` is generated. Edit the sources in `src/` and rebuild:

```
cd src && python3 gencatalog.py     # regenerate catalog.js from the Swift
python3 - <<'EOF'
import re
shell = open('shell.html').read()
strip = lambda p: re.sub(r'^export ', '', open(p).read(), flags=re.M)
open('../index.html','w').write(shell + "\n<script>\n" + "\n".join(
    [open('catalog.js').read(), strip('synth.js'), strip('creature.js'), open('app.js').read()]
) + "\n</script>\n")
EOF
node harness.js                     # headless check of the ported logic
```

`gencatalog.py` reads `BrainrotCatalog.swift` directly, so the roster cannot
drift from the app.

`harness.js` stubs the DOM and canvas, then exercises the real code: every
recipe must draw without producing a non-finite coordinate, every round must
contain its answer with no duplicate tiles, and the decoy-distance gradient must
still fall from gentle to nightmare.

The one deliberate difference from the Swift: the noise PRNG is mulberry32
rather than xorshift64*, because JS has no cheap 64-bit integers. It moves the
measured RMS by about 0.003 — audibly nothing.
