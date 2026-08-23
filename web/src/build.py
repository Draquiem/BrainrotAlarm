#!/usr/bin/env python3
"""Assemble web/index.html.

Regenerates the catalogue from the Swift, inlines any real assets found in
BrainrotAlarm/Assets/, and concatenates the sources into a single self-contained
page. Characters with no asset fall back to the synthesiser and the procedural
drawing, so this works at any level of completeness.

Assets are recompressed on the way in — MP3 for audio, WebP for images —
because an Artifact is one file with a 16 MB ceiling and raw WAV would blow
through it after about eight characters.

    python3 web/src/build.py
    python3 web/src/build.py --no-assets    # force the generated versions
"""
import base64, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "web", "index.html")
SRC_AUDIO = os.path.join(ROOT, "BrainrotAlarm", "Assets", "audio")
SRC_IMAGE = os.path.join(ROOT, "BrainrotAlarm", "Assets", "images")

LIMIT = 16 * 1024 * 1024
AUDIO_BITRATE = "64k"
IMAGE_PX = 512
IMAGE_QUALITY = "82"

def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or "").strip().splitlines()[-1:] or ["ffmpeg failed"])
    return r

def ids():
    src = open(os.path.join(ROOT, "BrainrotAlarm", "Model", "BrainrotCatalog.swift")).read()
    return [m for m in re.findall(r'id:\s*"(\w+)"', src)]

def find(folder, cid, exts):
    for e in exts:
        p = os.path.join(folder, f"{cid}.{e}")
        if os.path.exists(p):
            return p
    return None

def build_assets(enabled):
    out = {}
    if not enabled:
        return out
    for cid in ids():
        entry = {}
        a = find(SRC_AUDIO, cid, ["wav", "caf", "aiff", "m4a", "mp3"])
        if a:
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as t:
                tmp = t.name
            try:
                sh(["ffmpeg", "-y", "-loglevel", "error", "-i", a, "-ac", "1",
                    "-b:a", AUDIO_BITRATE, "-c:a", "libmp3lame", tmp])
                entry["audio"] = base64.b64encode(open(tmp, "rb").read()).decode()
            finally:
                os.path.exists(tmp) and os.unlink(tmp)
        i = find(SRC_IMAGE, cid, ["png", "jpg", "jpeg", "webp"])
        if i:
            with tempfile.NamedTemporaryFile(suffix=".webp", delete=False) as t:
                tmp = t.name
            try:
                sh(["ffmpeg", "-y", "-loglevel", "error", "-i", i, "-frames:v", "1",
                    "-vf", f"scale={IMAGE_PX}:{IMAGE_PX}:force_original_aspect_ratio=increase,"
                           f"crop={IMAGE_PX}:{IMAGE_PX}",
                    "-c:v", "libwebp", "-quality", IMAGE_QUALITY, tmp])
                b64 = base64.b64encode(open(tmp, "rb").read()).decode()
                entry["image"] = "data:image/webp;base64," + b64
            finally:
                os.path.exists(tmp) and os.unlink(tmp)
        if entry:
            out[cid] = entry
    return out

def main():
    use_assets = "--no-assets" not in sys.argv
    subprocess.run([sys.executable, os.path.join(HERE, "gencatalog.py")], check=True, cwd=HERE)

    assets = build_assets(use_assets)
    n_audio = sum(1 for v in assets.values() if "audio" in v)
    n_image = sum(1 for v in assets.values() if "image" in v)

    strip = lambda p: re.sub(r"^export ", "", open(os.path.join(HERE, p)).read(), flags=re.M)
    shell = open(os.path.join(HERE, "shell.html")).read()
    js = "\n".join([
        "// ===== bundled assets (empty entries fall back to synthesis/drawing) =====",
        "const ASSETS = " + json.dumps(assets) + ";",
        "// ===== catalogue (generated from BrainrotCatalog.swift) =====",
        open(os.path.join(HERE, "catalog.js")).read(),
        "// ===== chant synthesiser (port of ChantSynth.swift) =====", strip("synth.js"),
        "// ===== creature renderer (port of CreatureRenderer.swift) =====", strip("creature.js"),
        "// ===== game =====", open(os.path.join(HERE, "app.js")).read(),
    ])
    html = shell + "\n<script>\n" + js + "\n</script>\n"
    open(OUT, "w").write(html)

    size = len(html.encode())
    print(f"wrote {os.path.relpath(OUT, ROOT)}  {size/1024:.0f} KB")
    print(f"  bundled audio  {n_audio}/24")
    print(f"  bundled images {n_image}/24")
    print(f"  budget {size/LIMIT*100:.1f}% of the 16 MB artifact limit")
    if size > LIMIT * 0.85:
        print("  WARNING: close to the limit — drop AUDIO_BITRATE or IMAGE_PX in this script")
    if size > LIMIT:
        sys.exit("  too large to publish")

if __name__ == "__main__":
    main()
