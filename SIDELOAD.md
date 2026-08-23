# Getting it onto your iPhone

You need a Mac for this. Not because the project needs one, but because Apple
only ships the iOS toolchain and the code-signing machinery for macOS. Everything
below works with a **free** Apple ID — no $99 developer account.

Budget about 20 minutes, plus however long Xcode takes to download if the Mac
you have borrowed does not already have it (it is ~10 GB, so check first).

## On the Mac

**1. Get Xcode.** Mac App Store → Xcode → install. Open it once and let it
finish installing components.

**2. Get the project.**
```
git clone https://github.com/Draquiem/BrainrotAlarm.git
cd BrainrotAlarm
open BrainrotAlarm.xcodeproj
```

**3. Add your Apple ID.** Xcode → Settings → Accounts → **+** → Apple ID. Sign in
with your normal Apple ID. A "Personal Team" appears — that is all you need.

**4. Set the signing team.** Click the blue `BrainrotAlarm` project icon in the
sidebar → select the **BrainrotAlarm** target → **Signing & Capabilities** tab:

- tick **Automatically manage signing**
- **Team** → your Personal Team

Do the same for the **BrainrotAlarmTests** target.

If Xcode complains the bundle identifier is unavailable, change it to something
nobody else has claimed — `com.<yourname>.brainrotalarm` — and it will re-register.

## On the iPhone

**5. Turn on Developer Mode** (iOS 16 and later). Settings → Privacy & Security →
**Developer Mode** → on → restart the phone.

> Developer Mode only appears in that menu *after* the phone has been plugged
> into Xcode at least once. If you cannot find it, do step 6 first, let the run
> fail, then come back here.

**6. Plug the phone in** with a cable. Tap **Trust** on the phone when asked.

## Run it

**7.** In Xcode's toolbar, change the run destination from a simulator to your
phone by name. Press **⌘R**.

**8. First run will fail** with "Untrusted Developer". That is expected. On the
phone: Settings → General → **VPN & Device Management** → tap your Apple ID under
*Developer App* → **Trust**.

**9. Press ⌘R again.** It installs and launches.

## What to actually test

Grant the notification permission when it asks — the alarm cannot fire without it.

**Fastest check, no waiting:** Alarms tab → **+** → scroll down → **Rehearse this
alarm**. That runs the entire challenge right now: the chant plays on a loop, the
grid appears, wrong answers lock you out. This is the whole app in ten seconds.

Then:

- **Roster** tab → tap any character → **Play the chant**. Every voice is
  synthesised on the spot; this is the fastest way to hear whether they are
  actually distinguishable from each other.
- **Roster** → **Practice round** — same game, nothing scheduled.
- **A real alarm:** set one two minutes out, lock the phone, put it down. The
  notification fires with that character's chant as its sound; tapping it opens
  the grid.
- **Flip the ring/silent switch to silent** and rehearse again. It should still
  make noise — the audio session is configured `.playback` precisely so an alarm
  is not silenceable by accident.

## Things that will look like bugs but are not

- **The app stops working after 7 days.** Free-account provisioning profiles
  expire after a week. Plug in, ⌘R, and you get another 7 days. A paid account
  ($99/yr) raises that to a year.
- **A free account allows only 3 sideloaded apps at once.** Delete an old one if
  the install is refused.
- **Focus / Do Not Disturb silences the alarm.** Breaking through Focus needs the
  Time Sensitive Notifications capability, and a free Personal Team may refuse to
  add it under Signing & Capabilities. Turn Focus off while testing. The real fix
  is the AlarmKit path — see the README.
- **Force-quitting the app from the app switcher stops alarms firing.** That is an
  iOS rule for the notification path, not a defect.

## If the build fails

CI compiles this project on every push, so `main` is known to build:
https://github.com/Draquiem/BrainrotAlarm/actions

If your local build fails but CI is green, it is almost always signing — recheck
step 4.
