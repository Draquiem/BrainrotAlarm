#!/usr/bin/env python3
"""Report which characters have real assets, and flag anything out of spec.

    python3 Tools/check-assets.py
"""
import os, re, subprocess, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "BrainrotAlarm", "Assets", "audio")
IMAGE = os.path.join(ROOT, "BrainrotAlarm", "Assets", "images")
CATALOG = os.path.join(ROOT, "BrainrotAlarm", "Model", "BrainrotCatalog.swift")

AUDIO_EXT = ["wav", "caf", "aiff", "m4a", "mp3"]
IMAGE_EXT = ["png", "jpg", "jpeg", "heic"]
# iOS substitutes the default sound for anything compressed or over 30 s.
NOTIFICATION_OK = {"wav", "caf", "aiff", "aif"}

def probe(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_format", "-show_streams",
                        "-of", "json", path], capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except Exception:
        return {}

def find(folder, cid, exts):
    for e in exts:
        p = os.path.join(folder, f"{cid}.{e}")
        if os.path.exists(p):
            return p, e
    return None, None

def main():
    chars = re.findall(r'id:\s*"(\w+)",\s*name:\s*"([^"]+)"', open(CATALOG).read())
    warn = []
    have_a = have_i = 0

    print(f"{'character':14s} {'audio':>26s}   {'image':>18s}")
    print("-" * 64)
    for cid, name in chars:
        apath, aext = find(AUDIO, cid, AUDIO_EXT)
        ipath, iext = find(IMAGE, cid, IMAGE_EXT)

        if apath:
            have_a += 1
            info = probe(apath)
            dur = float(info.get("format", {}).get("duration", 0) or 0)
            st = next((s for s in info.get("streams", []) if s.get("codec_type") == "audio"), {})
            sr = int(st.get("sample_rate", 0) or 0)
            ch = st.get("channels", 0)
            acol = f"{aext} {dur:.1f}s {sr//1000}k {ch}ch"
            if aext not in NOTIFICATION_OK:
                warn.append(f"{cid}: .{aext} cannot be a notification sound (needs wav/caf/aiff)")
            if dur > 30:
                warn.append(f"{cid}: {dur:.1f}s exceeds the 30 s notification cap")
        else:
            acol = "— synthesised"

        if ipath:
            have_i += 1
            info = probe(ipath)
            st = next((s for s in info.get("streams", []) if s.get("codec_type") == "video"), {})
            w, h = st.get("width", 0), st.get("height", 0)
            icol = f"{iext} {w}x{h}"
            if w != h:
                warn.append(f"{cid}: image is {w}x{h}, not square — it will be cropped")
            if w and w < 512:
                warn.append(f"{cid}: image is only {w}px; 1024 recommended")
        else:
            icol = "— drawn"

        print(f"{cid:14s} {acol:>26s}   {icol:>18s}")

    n = len(chars)
    print("-" * 64)
    print(f"audio {have_a}/{n}   images {have_i}/{n}")
    if warn:
        print("\nwarnings:")
        for w in sorted(set(warn)):
            print(f"  - {w}")
    else:
        print("\nno problems found")
    if have_a < n or have_i < n:
        print(f"\nMissing entries fall back to the generated versions — the app works either way.")

if __name__ == "__main__":
    main()
