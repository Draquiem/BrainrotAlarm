"""Generate catalog.js straight from BrainrotCatalog.swift so the web build
cannot drift from the app."""
import re, json

SRC = "/home/king/BrainrotAlarm/BrainrotAlarm/Model/BrainrotCatalog.swift"
src = open(SRC).read()

PRESETS = {
 'goofball': dict(fundamental=128, formantScale=0.96, tempo=3.6, swing=0.25, scale='major',
                  melody=[0,2,4,2], vibratoRate=5.0, vibratoDepth=0.2, breathiness=0.05,
                  growl=0.2, declination=2.0, wordGap=0.13, brightness=0.5),
 'bruiser':  dict(fundamental=82, formantScale=0.82, tempo=2.7, swing=0.15, scale='minor',
                  melody=[0,0,-3,0,2], vibratoRate=4.2, vibratoDepth=0.12, breathiness=0.04,
                  growl=0.55, declination=3.0, wordGap=0.17, brightness=0.3),
 'squeaker': dict(fundamental=268, formantScale=1.28, tempo=5.0, swing=0.35, scale='penta',
                  melody=[0,3,2,4,2], vibratoRate=6.4, vibratoDepth=0.3, breathiness=0.1,
                  growl=0.08, declination=1.4, wordGap=0.1, brightness=0.8),
 'diva':     dict(fundamental=232, formantScale=1.1, tempo=2.5, swing=0.05, scale='major',
                  melody=[4,2,0,2,4,7], vibratoRate=5.6, vibratoDepth=0.55, breathiness=0.09,
                  growl=0.05, declination=2.6, wordGap=0.2, brightness=0.68),
 'chanter':  dict(fundamental=146, formantScale=0.92, tempo=4.2, swing=0.0, scale='chanterScale',
                  melody=[0,0,0,1,0], vibratoRate=7.0, vibratoDepth=0.1, breathiness=0.03,
                  growl=0.3, declination=1.0, wordGap=0.1, brightness=0.42),
 'eerie':    dict(fundamental=174, formantScale=1.02, tempo=3.0, swing=0.4, scale='whole',
                  melody=[0,2,1,3,2,5], vibratoRate=3.4, vibratoDepth=0.42, breathiness=0.16,
                  growl=0.12, declination=0.5, wordGap=0.16, brightness=0.6),
}

blocks = re.findall(
  r'BrainrotCharacter\(\s*'
  r'id:\s*"(\w+)",\s*name:\s*"([^"]+)",\s*'
  r'chant:\s*"([^"]+)",\s*'
  r'tagline:\s*"([^"]+)",\s*'
  r'family:\s*\.(\w+),\s*tier:\s*\.(\w+),\s*'
  r'voice:\s*\.(\w+)\.with\s*\{([^}]*)\},\s*'
  r'art:\s*CreatureRecipe\(body:\s*\.(\w+),\s*head:\s*\.(\w+),\s*ears:\s*\.(\w+),\s*limbs:\s*\.(\w+),\s*'
  r'eyes:\s*\.(\w+),\s*mouth:\s*\.(\w+),\s*prop:\s*\.(\w+),\s*pattern:\s*\.(\w+),\s*'
  r'palette:\s*Palette\(body:\s*0x([0-9A-Fa-f]+),\s*bodyShade:\s*0x([0-9A-Fa-f]+),\s*accent:\s*0x([0-9A-Fa-f]+),\s*'
  r'backdropTop:\s*0x([0-9A-Fa-f]+),\s*backdropBottom:\s*0x([0-9A-Fa-f]+)\)\)\)', src, re.S)

out = []
for (cid, name, chant, tagline, family, tier, preset, overrides,
     body, head, ears, limbs, eyes, mouth, prop, pattern,
     pbody, pshade, paccent, ptop, pbot) in blocks:
    v = dict(PRESETS[preset])
    for key, val in re.findall(r'\$0\.(\w+)\s*=\s*(\[[-\d,\s]+\]|[-\d.]+)', overrides):
        v[key] = json.loads(val) if val.startswith('[') else float(val)
    out.append(dict(
        id=cid, name=name, chant=chant, tagline=tagline, family=family, tier=tier,
        voice=v,
        art=dict(body=body, head=head, ears=ears, limbs=limbs, eyes=eyes, mouth=mouth,
                 prop=prop, pattern=pattern,
                 palette=dict(body=int(pbody,16), bodyShade=int(pshade,16), accent=int(paccent,16),
                              backdropTop=int(ptop,16), backdropBottom=int(pbot,16)))))

assert len(out) == 24, f"parsed {len(out)} characters, expected 24"
js = "const CATALOG = " + json.dumps(out, indent=1, ensure_ascii=False) + ";\n"
open("catalog.js","w").write(js)
print(f"generated catalog.js with {len(out)} characters")
for c in out[:3]:
    print(f"  {c['id']:12s} f0={c['voice']['fundamental']:5.0f} tempo={c['voice']['tempo']:.1f} "
          f"scale={c['voice']['scale']:12s} body={c['art']['body']}")
tiers = {}
for c in out: tiers[c['tier']] = tiers.get(c['tier'],0)+1
print("  tiers:", tiers)
