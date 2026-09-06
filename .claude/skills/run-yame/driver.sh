#!/usr/bin/env bash
# adb-based driver for the Yame Flutter app (Android target).
# Verified on macOS with the Android SDK at ~/.local/android-sdk and
# Flutter at ~/.local/flutter (adjust ANDROID_SDK/FLUTTER_BIN below if
# your machine differs).
#
# The Android emulator + adb server are long-lived, so unlike a
# REPL-driven GUI app there is no daemon to keep alive here: every
# subcommand is a fresh adb call talking to whatever device is already
# up. Run subcommands one at a time from an agent.
set -euo pipefail

ANDROID_SDK="${ANDROID_SDK:-$HOME/.local/android-sdk}"
FLUTTER_BIN="${FLUTTER_BIN:-$HOME/.local/flutter/bin}"
export PATH="$ANDROID_SDK/platform-tools:$ANDROID_SDK/emulator:$FLUTTER_BIN:$PATH"

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APK="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
PKG="com.yame.yame"
ACTIVITY="$PKG/.MainActivity"
AVD_NAME="${AVD_NAME:-Yame_Pixel}"
SHOT_DIR="${SHOT_DIR:-/tmp/yame-shots}"
mkdir -p "$SHOT_DIR"

cmd="${1:-help}"; shift || true

case "$cmd" in
  boot-emulator)
    # No-op if a device is already attached.
    if adb devices | grep -q "device$"; then
      echo "already have a device attached:"
      adb devices -l
      exit 0
    fi
    nohup emulator -avd "$AVD_NAME" -no-snapshot -no-boot-anim \
      > "$SHOT_DIR/emulator.log" 2>&1 &
    disown
    echo "booting $AVD_NAME (pid $!), log: $SHOT_DIR/emulator.log"
    echo "poll with: adb wait-for-device && until [ \"\$(adb shell getprop sys.boot_completed | tr -d '\\r')\" = 1 ]; do sleep 2; done"
    ;;

  build)
    (cd "$APP_DIR" && flutter pub get && flutter build apk --debug)
    ls -la "$APK"
    ;;

  install)
    [ -f "$APK" ] || { echo "no APK at $APK — run '$0 build' first"; exit 1; }
    adb install -r "$APK"
    ;;

  launch)
    adb shell am start -n "$ACTIVITY"
    ;;

  stop)
    adb shell am force-stop "$PKG"
    ;;

  uninstall)
    adb uninstall "$PKG" || true
    ;;

  ss|screenshot)
    name="${1:-ss-$(date +%s)}"
    f="$SHOT_DIR/$name.png"
    adb exec-out screencap -p > "$f"
    echo "screenshot: $f"
    ;;

  tap)
    x="$1"; y="$2"
    adb shell input tap "$x" "$y"
    ;;

  # Tap the first element whose uiautomator text matches (substring).
  # Slower than `tap x y` (dumps+parses the view tree) but coordinate-free.
  tap-text)
    needle="$1"
    dump="$SHOT_DIR/uidump.xml"
    adb shell uiautomator dump /sdcard/window_dump.xml >/dev/null
    adb pull /sdcard/window_dump.xml "$dump" >/dev/null
    coords=$(python3 - "$dump" "$needle" <<'PY'
import sys, re
path, needle = sys.argv[1], sys.argv[2]
xml = open(path, encoding="utf-8").read()
for m in re.finditer(r'text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
    text, x1, y1, x2, y2 = m.groups()
    if needle.lower() in text.lower():
        print(f"{(int(x1)+int(x2))//2} {(int(y1)+int(y2))//2}")
        break
PY
)
    [ -n "$coords" ] || { echo "NOT_FOUND: $needle"; exit 1; }
    echo "tap-text '$needle' -> $coords"
    adb shell input tap $coords
    ;;

  text)
    # adb input text needs %s for spaces
    adb shell input text "$(printf '%s' "$1" | sed 's/ /%s/g')"
    ;;

  key)
    adb shell input keyevent "$1"   # e.g. BACK, ENTER, or a keycode number
    ;;

  dump)
    adb shell uiautomator dump /sdcard/window_dump.xml >/dev/null
    adb pull /sdcard/window_dump.xml "$SHOT_DIR/uidump.xml" >/dev/null
    echo "$SHOT_DIR/uidump.xml"
    ;;

  logs)
    adb logcat -d -t "${1:-300}" | grep -iE "yame|FATAL|AndroidRuntime"
    ;;

  devices)
    adb devices -l
    ;;

  help|*)
    cat <<EOF
usage: driver.sh <command> [args]

  boot-emulator          start the Yame_Pixel AVD if no device attached
  build                   flutter pub get + flutter build apk --debug
  install                 adb install -r the built debug APK
  launch                  am start the app (MainActivity)
  stop                    am force-stop the app
  uninstall               adb uninstall the package
  ss [name]               screenshot -> $SHOT_DIR/<name>.png
  tap <x> <y>              tap at device pixel coords (screenshots are full-res)
  tap-text <substring>    find + tap first matching visible text (uiautomator)
  text <string>            type text into the focused field
  key <BACK|ENTER|...>     send a key event
  dump                     dump current UI hierarchy XML (for finding text/bounds)
  logs [n]                 last n logcat lines filtered to app/crashes (default 300)
  devices                  adb devices -l
EOF
    ;;
esac
