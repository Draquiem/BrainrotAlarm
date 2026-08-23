# Brainrot Alarm

An iOS alarm clock that wakes you with an Italian-brainrot chant and will not shut
up until you tap the creature making it.

The chant loops. A grid of creatures appears. None of them are labelled. Pick the
right one, the required number of times, and the alarm stops. Pick wrong and the
grid locks for a couple of seconds while the chant keeps going.

```
        ┌──────────────────┐
        │      6:45        │   chant loops ──┐
        │  ▁▃▅▂▆  Who is   │                 │
        │      chanting?   │                 ▼
        │  ┌────┐  ┌────┐  │        ┌──────────────────┐
        │  │ 🦈 │  │ 🐄 │  │        │  wrong → lockout │
        │  └────┘  └────┘  │───────▶│  right → advance │
        │  ┌────┐  ┌────┐  │        │  all rounds → 🔇 │
        │  │ 🐊 │  │ ☕ │  │        └──────────────────┘
        │  └────┘  └────┘  │
        └──────────────────┘
```

[![build](https://github.com/Draquiem/BrainrotAlarm/actions/workflows/ios.yml/badge.svg)](https://github.com/Draquiem/BrainrotAlarm/actions/workflows/ios.yml)

Builds and runs its tests on every push against Xcode 26.6 / Swift 6.3.

## Getting it on a phone

See [SIDELOAD.md](SIDELOAD.md) — about 20 minutes on any Mac, with a free Apple ID.

## Opening it

```
open BrainrotAlarm.xcodeproj
```

Xcode 16 or newer (the project uses synchronized folder groups, so adding a Swift
file anywhere under `BrainrotAlarm/` picks it up with no project edit). Deployment
target iOS 17. Set your own signing team on both targets and run on a device —
the simulator will show you the UI but its audio session behaviour is not
representative.

`⌘U` runs the tests. If the project file is ever damaged, `xcodegen generate`
rebuilds an equivalent one from `project.yml`.

## Hear it before you build it

Two rendered previews sit in the repo root, produced by the same DSP the app
ships:

```
aplay preview_all_voices.wav     # all 24 characters, 66 seconds
aplay preview_alarm_loop.wav     # what one alarm actually sounds like
```

## There are no audio files and no images

Both halves of the puzzle are generated at runtime.

**The voices** come from `ChantSynth`, a source–filter vocal synthesiser. A
Rosenberg glottal pulse is differentiated to approximate lip radiation, then run
through three resonators parked on the formants of whichever Italian vowel the
syllable contains. Consonants come from a separate noise path *and* from moving
the formants — a burst on its own is just static; a burst plus an F2 transition
from the right locus is what makes `ba`, `da` and `ga` different sounds.

`"Tra-la-le-ro Tra-la-la"` is parsed into syllables, each carrying an onset, a
vowel, a stress mark and a coda flag, and the synthesiser sings it.

**The pictures** come from `CreatureRenderer`, which draws each character from a
parts vocabulary — body, head, ears, limbs, eyes, mouth, prop, pattern, palette —
in one `Canvas` pass. Every character in this meme family is some animal welded
to some object, so eight body shapes and twenty-one props cover the whole roster.

Consequences: the bundle carries no media, art stays sharp at any size, and
nothing in the app is anybody else's artwork or recording. The names are the
community's; the renderings are original.

## What was measured

There was no Swift toolchain on the machine this was written on, so the DSP was
verified by porting it line-by-line to Python (`Tools/synth_port.py`) and
measuring the result. That caught four real defects:

| finding | fix |
| --- | --- |
| Every render was 33 dB peaky — a stop burst towering over the vowels, because burst amplitude was absolute instead of a fraction of the syllable peak | levels are now relative to the syllable; crest factor is 10–17 dB, the speech range |
| The whole signal was ~22 dB too quiet: the lip-radiation difference `x − 0.97·x₋₁` has a gain of 0.076 at 500 Hz and had no makeup | `Level.sourceMakeup` restores unity around F1 |
| F2 of /i/ sat 24 dB under F1, burying the main vowel-identity cue | formant gains now compensate the source tilt; /i/'s F2 is at −16 dB |
| A daily 07:00 alarm rang **the same character every single morning** — the minute slot was added into the hash, and a day is 1440 minutes, an exact multiple of the roster size | the slot goes through a murmur3 finaliser; 21 days of a daily alarm now draw 10+ distinct characters |

Independently confirmed: the formant resonators land within 0.9 % of their target
frequencies for all five vowels, and the 24 characters separate cleanly — closest
pair at 1.25 against a roster median of 4.74, spanning 81–459 Hz and 1.8–4.8
syllables per second.

`Tools/parity.py` fails if a constant is changed in `ChantSynth.swift` without
being changed in the Python reference, which is what would otherwise silently
invalidate all of the above.

## Difficulty

Wrong answers are not drawn at random. Each character has a `distance` to every
other built from pitch, speaking rate, length and family, and each difficulty
draws its decoys from a different slice of that ranking.

| | tiles | rounds | decoys drawn from | a miss costs you |
| --- | --- | --- | --- | --- |
| Gentle | 3 | 1 | the least similar 45 % | 0.6 s |
| Standard | 4 | 2 | the middle | 1.0 s |
| Brutal | 6 | 3 | the most similar 50 % | 1.5 s **and an extra round** |
| Nightmare | 9 | 3 | the most similar 30 %, no replays | 2.5 s **and back to round one** |

Restarting keeps round one on the character you already heard — dropping you onto
an unheard chant would be unfair rather than hard.

Snoozing is capped, not blocked: you get a set number of free passes, and after
that the grid is the only way out.

## How it rings — and the honest limits

iOS does not let a third-party app ring a loud alarm from a terminated state
without AlarmKit. The app therefore has two paths.

**Notifications (default, works everywhere).** `NotificationScheduler` renders the
chosen character's chant to `Library/Sounds/` and schedules a *chain* of
notifications 30 seconds apart, because a notification sound is capped at 30
seconds. Chain length is budgeted against the 64-pending-notification limit rather
than fixed. The notification body deliberately never names the character — that is
the answer.

Its limits, plainly: it respects Do Not Disturb unless the Time Sensitive
capability is enabled, it will not fire if the app has been force-quit from the
app switcher, and the chain nags for a few minutes rather than indefinitely.

**AlarmKit (iOS 26+, opt-in).** `AlarmKitScheduler.swift` targets the real alarm
API — breaks through silent mode and Focus, survives termination, no 30-second
cap. It is behind the `BRAINROT_ALARMKIT` compilation condition because it was written
without an iOS 26 SDK to hand. CI now type-checks it against that SDK on every
push and it compiles clean, but it has not been exercised on a device — so it
stays opt-in. Enable it under Build Settings → Swift Compiler – Custom Flags →
Active Compilation Conditions. Until you do, the app runs entirely on the
notification path.

**Verified since:** CI compiles the AlarmKit path against the real iOS 26 SDK on
every push, and it builds clean — the API spellings were right. It stays behind
the flag because it has been type-checked but not yet run on a device.

## Layout

```
BrainrotAlarm/
├── Chant/          ChantParser, ChantSynth, Biquad, VoiceProfile  — pure, testable
├── Art/            CreatureRenderer and the parts vocabulary
├── Challenge/      ChallengeSession (rules) + ChallengeView (screen)
├── Model/          AlarmItem, BrainrotCharacter, the 24-character catalogue
├── Audio/          AVAudioEngine playback, chant-to-disk for notifications
├── Scheduling/     notification + AlarmKit schedulers, store, character casting
├── Intents/        the AlarmKit stop button's App Intent
└── Views/          alarm list, editor, roster, stats
```

The rules live in plain value types with no SwiftUI, Foundation timers or audio in
them — `ChallengeSession` is a struct you can drive from a test, and
`ChantSynth` is Foundation-only. That is what made the Python cross-check possible.

## Tests

51 tests across 6 suites, covering the parser, the synthesiser's output
characteristics, the challenge rules, date arithmetic and streak counting.

The ones worth knowing about:

- `testCrestFactorIsSpeechLike` renders all 24 characters and fails if any becomes
  peaky or over-compressed — the regression guard for the first two defects above.
- `testFormantResonatorsLandOnTarget` sweeps a sine through the filter bank and
  checks the peaks against the vowel table.
- `testCastingVariesDayToDay` steps by whole days, not minutes. The original
  version stepped by minutes and passed against the broken hash — which is exactly
  the kind of test that manufactures false confidence.
- `testHarderDifficultiesChooseMoreConfusableDecoys` fails if the difficulty
  gradient ever collapses.

## Known gaps

- The AlarmKit path type-checks but has not been run on a device.
- The roster is 24 characters; the meme family is larger.
- Stats are local only, no sync.
- Notification sounds are written to `Library/Sounds` at ~2.5 MB per scheduled
  character and pruned when no longer needed, so a handful of alarms costs a few
  megabytes of disk.
