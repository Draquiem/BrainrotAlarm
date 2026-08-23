#!/usr/bin/env python3
"""Normalise dropped-in assets into what the app needs.

Put whatever you have — any format, any name, any size — into:

    Assets/raw/audio/     mp3, m4a, wav, mp4, webm, opus ...
    Assets/raw/images/    jpg, png, webp, heic, gif ...

then run this. Files are matched to characters by name (fuzzily, so
"Tralalero Tralala.mp3" and "bombardiro_crocodilo.JPG" both land correctly),
converted, and written into the app's bundle folders.

Audio becomes 44.1 kHz mono 16-bit PCM WAV, trimmed to 28 s and loudness
normalised. Those constraints are not arbitrary: iOS silently substitutes the
default ping for any notification sound that is compressed or over 30 seconds,
so a 4-minute MP3 would leave your alarm playing a generic chime.

Images become 1024x1024 PNG, scaled to fill and centre-cropped.

    python3 Tools/prepare-assets.py            # convert everything
    python3 Tools/prepare-assets.py --dry-run  # just show the matching
"""
import json, os, re, subprocess, sys, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_AUDIO = os.path.join(ROOT, "Assets", "raw", "audio")
RAW_IMAGE = os.path.join(ROOT, "Assets", "raw", "images")
OUT_AUDIO = os.path.join(ROOT, "BrainrotAlarm", "Assets", "audio")
OUT_IMAGE = os.path.join(ROOT, "BrainrotAlarm", "Assets", "images")
CATALOG = os.path.join(ROOT, "BrainrotAlarm", "Model", "BrainrotCatalog.swift")

MAX_SECONDS = 28
IMAGE_PX = 1024

def characters():
    src = open(CATALOG).read()
    return re.findall(r'id:\s*"(\w+)",\s*name:\s*"([^"]+)"', src)

def slug(text):
    return re.sub(r'[^a-z0-9]', '', text.lower())

def match(stem, chars):
    """Best character for a filename, or None if nothing is close enough."""
    s = slug(stem)
    if not s:
        return None
    best, score = None, 0
    for cid, name in chars:
        n = slug(name)
        if s == cid or s == n:
            return cid
        candidates = [cid, n] + [slug(w) for w in name.split() if len(w) > 3]
        for c in candidates:
            if not c:
                continue
            if s.startswith(c) or c.startswith(s) or c in s or s in c:
                # longer overlaps win, so "bombombini" beats "bomb"
                if len(c) > score:
                    best, score = cid, len(c)
    return best if score >= 4 else None

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "ffmpeg failed")

def duration(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                        "-of", "csv=p=0", path], capture_output=True, text=True)
    try:
        return float(r.stdout.strip())
    except ValueError:
        return 0.0

def convert_audio(src, cid, dry):
    dst = os.path.join(OUT_AUDIO, cid + ".wav")
    if dry:
        return dst, None
    dur = min(MAX_SECONDS, duration(src) or MAX_SECONDS)
    fade_at = max(0.0, dur - 0.06)
    filters = (f"loudnorm=I=-12:TP=-1.0:LRA=11,"
               f"afade=t=in:st=0:d=0.01,afade=t=out:st={fade_at:.3f}:d=0.06")
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-t", str(MAX_SECONDS),
         "-ac", "1", "-ar", "44100", "-c:a", "pcm_s16le", "-af", filters, dst])
    return dst, duration(dst)

def convert_image(src, cid, dry):
    dst = os.path.join(OUT_IMAGE, cid + ".png")
    if dry:
        return dst, None
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-frames:v", "1",
         "-vf", f"scale={IMAGE_PX}:{IMAGE_PX}:force_original_aspect_ratio=increase,"
                f"crop={IMAGE_PX}:{IMAGE_PX}",
         dst])
    return dst, None

def collect(folder):
    if not os.path.isdir(folder):
        return []
    out = []
    for name in sorted(os.listdir(folder)):
        path = os.path.join(folder, name)
        if os.path.isfile(path) and not name.startswith('.'):
            out.append(path)
    return out

def main():
    dry = "--dry-run" in sys.argv
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg not found. Install it: sudo apt install ffmpeg")

    chars = characters()
    ids = {c[0] for c in chars}
    os.makedirs(OUT_AUDIO, exist_ok=True)
    os.makedirs(OUT_IMAGE, exist_ok=True)

    unmatched, done = [], {"audio": 0, "images": 0}

    for kind, folder, convert in (("audio", RAW_AUDIO, convert_audio),
                                  ("images", RAW_IMAGE, convert_image)):
        files = collect(folder)
        if not files:
            print(f"  {kind}: nothing in {os.path.relpath(folder, ROOT)}")
            continue
        print(f"\n{kind} ({len(files)} file{'s' if len(files) != 1 else ''}):")
        for path in files:
            stem = os.path.splitext(os.path.basename(path))[0]
            cid = match(stem, chars)
            if not cid:
                unmatched.append((kind, os.path.basename(path)))
                print(f"  ?  {os.path.basename(path)[:44]:46s} no match")
                continue
            try:
                dst, dur = convert(path, cid, dry)
                extra = f"{dur:.1f}s" if dur else ""
                verb = "would write" if dry else "wrote"
                print(f"  ok {os.path.basename(path)[:44]:46s} -> {cid}.{'wav' if kind=='audio' else 'png'} {extra}")
                if not dry:
                    done[kind] += 1
            except Exception as e:
                print(f"  !! {os.path.basename(path)[:44]:46s} {e}")

    if unmatched:
        print("\nCould not match these to a character:")
        for kind, name in unmatched:
            print(f"  {kind}/{name}")
        print("\nRename them to the character id and rerun. Valid ids:")
        print("  " + ", ".join(sorted(ids)))

    if not dry:
        print(f"\nConverted {done['audio']} audio and {done['images']} image files.")
        print("Run  python3 Tools/check-assets.py  to see coverage.")

if __name__ == "__main__":
    main()
