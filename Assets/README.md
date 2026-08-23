# Replacing the generated assets

Every character ships with a synthesised chant and a procedurally drawn portrait.
Both are placeholders in the sense that matters: drop in a real recording or a
real picture and the app uses it instead, with no code change and no Xcode edit.

Missing entries keep falling back, so a half-finished set is fine. Three real
recordings and the other twenty-one still ring.

## The quick version

1. Put whatever you have into `Assets/raw/audio/` and `Assets/raw/images/`.
   Any format, any size, any filename.
2. `python3 Tools/prepare-assets.py`
3. `python3 Tools/check-assets.py`
4. Rebuild the app in Xcode, or `python3 web/src/build.py` for the web version.

`prepare-assets.py` matches files to characters by name, so
`Tralalero Tralala.mp3` and `bombardiro-crocodilo.JPG` both land correctly.
Anything it cannot place is listed so you can rename it. Run it with
`--dry-run` first if you want to see the matching before it writes anything.

## Where the files end up

```
BrainrotAlarm/Assets/audio/<id>.wav     picked up by the app automatically
BrainrotAlarm/Assets/images/<id>.png
```

Those folders are inside the app's synchronized group, so Xcode adds new files
to the bundle without you touching the project.

## The 24 ids

```
tralalero    bombardiro   tungtung     lirili       patapim      chimpanzini
ballerina    cappuccino   trippi       bobritto     frigo        boneca
vaca         glorbo       bombombini   trulimero    girafa       orangutini
burbaloni    blueberrini  trictrac     zibra        piccione     svinino
```

## Format, and why

**Audio — 44.1 kHz mono 16-bit PCM WAV, 28 seconds or less.**

Not a style preference. iOS silently substitutes the default notification ping
for any alarm sound that is compressed or longer than 30 seconds, so a 4-minute
MP3 would leave you waking up to a generic chime with no error anywhere.
`prepare-assets.py` enforces this; `check-assets.py` flags anything that slipped
past. `AssetLibrary.notificationSoundName` checks it once more at runtime and
falls back to a rendered chant rather than let the default through.

Loudness is normalised to about −12 LUFS. It is an alarm.

**Images — square PNG, 1024×1024.**

They are displayed as small tiles, sometimes nine at once on a phone, so what
matters is whether the subject reads at roughly 110 px. High contrast, subject
filling the frame, no fine detail near the edges — the tile is centre-cropped.

## A note before you invest much effort

Artwork and recordings pulled from the internet belong to whoever made them.
For testing on your own phone that is nobody's problem. It becomes one the
moment the app goes to TestFlight testers or the App Store, and "it's a meme"
is not a defence that survives contact with App Review.

If this is heading anywhere public, generating your own art or commissioning it
keeps the whole question closed. The procedural renderer exists partly for that
reason — it is original work, and it is why the app can ship with no assets at
all.
