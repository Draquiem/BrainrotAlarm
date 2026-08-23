# Verification harness

`synth_port.py` is a line-by-line Python port of `ChantSynth.swift`. It exists
because the synthesiser was written on a machine with no Swift toolchain, and
"it compiles" would not have told us whether it *sounds* like anything.

Porting mechanically rather than rewriting is the point: a logic error in the
Swift reproduces here, where it can be measured.

Run any of these with plain `python3` — no dependencies.

| script | what it answers |
| --- | --- |
| `measure.py` | Is the output loud enough, and is the crest factor speech-like? |
| `spectrum2.py` | Do the formant resonators actually sit on their target frequencies? |
| `bands.py` | Is F2 audible enough to carry vowel identity? |
| `distinct.py` | Can the 24 characters be told apart by ear? |
| `decoy.py` | Does the decoy-band index maths hold for every pool size? |
| `parity.py` | Have the Python reference and the Swift drifted apart? |
| `demo.py` | Render the preview WAVs. |

`parity.py` is the one that matters most: it fails loudly if a constant is
changed in `ChantSynth.swift` without being changed here, which is what would
otherwise silently invalidate every other measurement.
