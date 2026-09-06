---
name: run-yame
description: Build, install, launch, and drive the Yame Flutter Android app (VTC app for Pointe-Noire). Use when asked to run Yame, build the Android APK, start the Yame_Pixel emulator, take a screenshot of the app, or interact with its UI (tap, navigate screens).
---

Yame is a Flutter app (Android + iOS targets, Android verified here).
Drive it via `adb` through `.claude/skills/run-yame/driver.sh` — no
custom REPL is needed because the emulator/adb server is already a
long-lived daemon; each driver subcommand is a fresh `adb` call. This
was run on macOS (not a Linux container) with the Android SDK and
Flutter already installed locally — adjust `ANDROID_SDK`/`FLUTTER_BIN`
env vars if your machine differs.

All paths below are relative to `YAME/` (this Flutter project root,
one level above `.claude/`).

## Prerequisites

Flutter SDK and Android SDK installed locally (verified with Flutter
3.47.1 stable, Android SDK at `~/.local/android-sdk`, JDK 17 at
`~/.local/jdk17`, Gradle 9.3.1 via the project's wrapper). An AVD named
`Yame_Pixel` already exists (`~/.local/android-sdk/emulator -list-avds`).
No physical device was used — all verification here was on that emulator.

```bash
export PATH="$HOME/.local/android-sdk/platform-tools:$HOME/.local/android-sdk/emulator:$HOME/.local/flutter/bin:$PATH"
```

## Build

```bash
flutter pub get
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk` (~168MB debug
build). **First build is slow** — cold Gradle daemon + Kotlin daemon
compile took several minutes with no progress output until it's done;
this is normal, don't kill it early. Subsequent builds are much faster
(daemons stay warm).

Firebase is already wired up (`android/app/google-services.json`,
`lib/firebase_options.dart` both present, `lib/main.dart` calls
`Firebase.initializeApp` before `runApp`) — no extra setup needed to
launch past the splash screen.

## Run (agent path)

```bash
chmod +x .claude/skills/run-yame/driver.sh   # once
.claude/skills/run-yame/driver.sh boot-emulator   # starts Yame_Pixel if nothing attached
.claude/skills/run-yame/driver.sh install         # adb install -r the debug APK
.claude/skills/run-yame/driver.sh launch          # am start MainActivity
sleep 6                                            # let splash + Firebase init finish
.claude/skills/run-yame/driver.sh ss 01-home       # -> /tmp/yame-shots/01-home.png
```

Then look at the screenshot, pick coordinates for the element you want
(screenshots are full device resolution, e.g. 1080x2400 for
Yame_Pixel), and:

```bash
.claude/skills/run-yame/driver.sh tap 540 1392   # the "Client" role card, verified on Yame_Pixel (1080x2400)
sleep 1
.claude/skills/run-yame/driver.sh ss 02-signup
```

Screenshots land in `/tmp/yame-shots/` (override with `SHOT_DIR=...`).

| command | what it does |
|---|---|
| `boot-emulator` | starts the `Yame_Pixel` AVD if no device is attached |
| `build` | `flutter pub get` + `flutter build apk --debug` |
| `install` | `adb install -r` the built debug APK |
| `launch` | `am start` the app (`com.yame.yame/.MainActivity`) |
| `stop` | `am force-stop` the app |
| `uninstall` | `adb uninstall com.yame.yame` |
| `ss [name]` | screenshot → `$SHOT_DIR/<name>.png` |
| `tap <x> <y>` | tap at device-pixel coords (get coords from a screenshot) |
| `tap-text <substring>` | **does not work on this app** — see Gotchas |
| `text <string>` | type into the focused field |
| `key <BACK\|ENTER\|...>` | send a key event |
| `dump` | dump UI hierarchy XML — **empty for this app**, see Gotchas |
| `logs [n]` | last n logcat lines filtered to `yame`/`FATAL`/`AndroidRuntime` |
| `devices` | `adb devices -l` |

## Run (human path)

`flutter run -d <device-id>` from `YAME/` (pick the emulator or a
USB-connected phone via `flutter devices`). Opens a hot-reload session
in the terminal; `q` to quit. Not used for agent verification here —
use the `driver.sh` path above instead.

## Test

```bash
flutter test
```

## Gotchas

- **`tap-text` / `dump` return nothing.** Flutter renders its own
  widgets on a canvas and does not populate the Android accessibility
  tree that `uiautomator` reads unless an accessibility service is
  actively running. `adb shell uiautomator dump` on this app returns
  nodes with `text=""` everywhere. Enabling TalkBack
  (`adb shell settings put secure enabled_accessibility_services
  com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService`)
  does turn on Flutter's semantics tree, but it also switches the whole
  device to explore-by-touch gestures (single tap = focus, not click),
  which breaks the plain `tap x y` flow this driver relies on. **Not
  worth it** — use `ss` + `tap <x> <y>` from screenshot coordinates
  instead; that's what was used to verify onboarding → role selection
  → signup screen end-to-end.
- **Clearing `enabled_accessibility_services` needs `settings delete`,
  not `settings put ... ""`.** `adb shell settings put secure
  enabled_accessibility_services ""` returns `Bad arguments` and leaves
  the old value in place (a lingering green TalkBack focus-highlight
  box was visible in a screenshot after this). Use
  `adb shell settings delete secure enabled_accessibility_services`
  followed by `adb shell settings put secure accessibility_enabled 0`.
- **Screenshot right after `launch` can catch the Flutter splash**
  (blue Flutter logo on white, not the app UI) — `Firebase.initializeApp`
  runs before `runApp`. Wait ~5-6s after `launch` before the first `ss`.
- **`am start -n com.yame.yame/.MainActivity` is correct**, not the
  package-only form — `MainActivity.kt` lives at
  `android/app/src/main/kotlin/com/yame/yame/MainActivity.kt`.

## Troubleshooting

- **`flutter devices` doesn't list the emulator right after
  `boot-emulator`**: normal, cold boot takes ~1-2 minutes. Poll with
  `adb wait-for-device && until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done`
  before installing.
- **`adb: no devices/emulators found`**: the `adb` daemon may need a
  moment after emulator launch; `adb devices -l` will show it once
  ready, or run `adb start-server` explicitly.
