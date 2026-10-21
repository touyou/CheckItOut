#!/bin/bash
#
# Captures the App Store submission screenshots for every platform and locale.
#
#   ./scripts/capture_screenshots.sh                 # everything
#   ./scripts/capture_screenshots.sh iphone ipad     # only these platforms
#   LOCALES="ja" ./scripts/capture_screenshots.sh    # only this locale
#
# Output goes to Screenshots/<platform>/<locale>/NN-name.png (gitignored).
#
# XCUITest (CheckitoutUITests/ScreenshotTests) drives the app with the
# screenshot fixture and attaches `XCUIScreen.main.screenshot()`, which is the
# device's framebuffer at exactly the pixel size App Store Connect asks for.
#
# Each destination can be overridden, e.g. to point at a cloned simulator:
#
#   IPHONE_DEST="platform=iOS Simulator,id=<udid>" ./scripts/capture_screenshots.sh iphone
#
# iPhone Duo is shot both folded (outer screen, portrait 1398x2034) and unfolded
# (inner screen, landscape 2853x2007). The fold can't be changed from the command
# line, only with the button under the device in DeviceHub, so each run checks
# the current state first and stops if it doesn't match:
#
#   duo-closed  shoot the folded Duo (a freshly booted Duo is folded)
#   duo-open    unfold it in DeviceHub first
#
# Unfolded, the test captures the inner screen (`SCREENSHOT_DUO_OPEN`). Its
# framebuffer stays portrait-shaped, so this script turns it 90° clockwise and
# sizes it to 2853x2007.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/Screenshots"
WORK="${SCREENSHOT_WORK_DIR:-$ROOT/.screenshot-runs}"
# The UI is Japanese only (no localizations yet), so that is the only locale by default.
LOCALES="${LOCALES:-ja}"

TESTID="CheckitoutUITests/ScreenshotTests"

# iPhone Duo only exists on the iOS 27.1 runtime.
DUO_DEST="${DUO_DEST:-platform=iOS Simulator,name=iPhone Duo,OS=27.1}"
DUO_OPEN_SIZE="2853x2007"
DUO_CLOSED_SIZE="1398x2034"

# platform | destination
PLATFORMS=(
  "iphone|${IPHONE_DEST:-platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0}"
  "ipad|${IPAD_DEST:-platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0}"
  "duo-closed|$DUO_DEST"
  "duo-open|$DUO_DEST"
)

requested=("$@")
failed=()

wanted() {
  [ ${#requested[@]} -eq 0 ] && return 0
  for name in "${requested[@]}"; do
    [ "$name" = "$1" ] && return 0
  done
  return 1
}

region_for() {
  case "$1" in
    ja) echo JP ;;
    *)  echo US ;;
  esac
}

mkdir -p "$WORK"

# The destination's UDID: id= as is, name=/OS= looked up in that runtime (used for the Duo fold check).
udid_for() {
  local destination=$1 udid name os
  udid=$(echo "$destination" | sed -nE 's/.*id=([0-9A-Fa-f-]{36}).*/\1/p')
  if [ -z "$udid" ]; then
    name=$(echo "$destination" | sed -nE 's/.*name=([^,]+).*/\1/p')
    os=$(echo "$destination" | sed -nE 's/.*OS=([0-9.]+).*/\1/p')
    udid=$(xcrun simctl list devices available \
      | awk -v os="-- iOS $os --" -v name="$name" '$0 == os {f=1; next} /^-- /{f=0} f && index($0, "    " name " (") == 1' \
      | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  fi
  echo "$udid"
}

pixel_size() {
  sips -g pixelWidth -g pixelHeight "$1" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w"x"h}'
}

# Whether the Duo is folded the way this platform needs, judged by the default screen's size
# (the outer screen when folded, the inner one when unfolded).
check_duo_state() {
  local platform=$1 destination=$2 udid shot size
  udid=$(udid_for "$destination")
  if [ -z "$udid" ]; then
    echo "    FAILED — no iPhone Duo simulator for $destination"
    return 1
  fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1 || true
  shot="$WORK/duo-state.png"
  xcrun simctl io "$udid" screenshot "$shot" > /dev/null 2>&1
  size=$(pixel_size "$shot")
  case "$platform" in
    duo-open)
      [ "$size" = "$DUO_OPEN_SIZE" ] && return 0
      echo "    FAILED — the Duo is folded ($size). Unfold it with the button under the device in DeviceHub, then run again" ;;
    duo-closed)
      [ "$size" = "$DUO_CLOSED_SIZE" ] && return 0
      echo "    FAILED — the Duo is unfolded ($size). Fold it in DeviceHub or reboot the simulator, then run again" ;;
  esac
  return 1
}

# The unfolded Duo's inner screen comes back as a portrait-shaped framebuffer: turn it to
# landscape and size it to 2853x2007 (XCUIScreen's image is 1px short, 2006x2852).
normalize_duo_open() {
  local dest=$1 png size w h
  for png in "$dest"/*.png; do
    size=$(pixel_size "$png")
    w=${size%x*}; h=${size#*x}
    if [ "$w" -lt "$h" ]; then
      sips -r 90 "$png" > /dev/null
    fi
    if [ "$(pixel_size "$png")" != "$DUO_OPEN_SIZE" ]; then
      sips -z "${DUO_OPEN_SIZE#*x}" "${DUO_OPEN_SIZE%x*}" "$png" > /dev/null
    fi
  done
  echo "    normalized to $DUO_OPEN_SIZE"
}

capture() {
  local platform=$1 destination=$2 locale=$3
  local bundle="$WORK/$platform-$locale.xcresult"
  local log="$WORK/$platform-$locale.log"
  rm -rf "$bundle"

  # xcodebuild pins the status bar to 9:41 on iPhone / iPad, but not the
  # clock iPhone Duo shows in its side bar. When the destination names a
  # simulator by id, pin it here too (best-effort).
  local udid
  udid=$(sed -nE 's/.*id=([0-9A-Fa-f-]{36}).*/\1/p' <<< "$destination")
  if [ -n "$udid" ]; then
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1 || true
    xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
      --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 \
      > /dev/null 2>&1 || true
  fi

  # -testLanguage / -testRegion, not -AppleLanguages launch arguments: this is
  # what moves `Locale.current` inside the app under test.
  case "$platform" in
    duo-*)
      if ! check_duo_state "$platform" "$destination"; then
        failed+=("$platform/$locale")
        return
      fi ;;
  esac

  # Only for the unfolded Duo: have the test capture the inner screen (the test
  # sees it without the TEST_RUNNER_ prefix).
  local duo_open=0
  if [ "$platform" = "duo-open" ]; then
    duo_open=1
  fi

  if ! TEST_RUNNER_SCREENSHOT_DUO_OPEN=$duo_open xcodebuild test \
    -project Checkitout.xcodeproj \
    -scheme Checkitout \
    -destination "$destination" \
    -only-testing:"$TESTID" \
    -resultBundlePath "$bundle" \
    -testLanguage "$locale" \
    -testRegion "$(region_for "$locale")" \
    -collect-test-diagnostics never \
    > "$log" 2>&1; then
    echo "    FAILED — see $log"
    failed+=("$platform/$locale")
    return
  fi

  local dest="$OUT/$platform/$locale"
  rm -rf "$dest" && mkdir -p "$dest"

  local staging="$WORK/$platform-$locale-attachments"
  rm -rf "$staging"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$staging" > /dev/null

  # The exported filenames are opaque; manifest.json maps them back to the
  # names the test gave each attachment.
  if ! python3 - "$staging" "$dest" <<'PY'
import json, pathlib, re, shutil, sys

staging, dest = (pathlib.Path(p) for p in sys.argv[1:3])
manifest = json.loads((staging / "manifest.json").read_text())

# XCTest appends "_<index>_<uuid>" to the name the test gave the attachment.
SUFFIX = re.compile(r"_\d+_[0-9A-Fa-f-]{36}$")

count = 0
for test in manifest:
    for attachment in test.get("attachments", []):
        exported = attachment.get("exportedFileName")
        name = attachment.get("suggestedHumanReadableName") or exported
        if not exported:
            continue
        stem = SUFFIX.sub("", pathlib.Path(name).stem)
        shutil.copyfile(staging / exported, dest / f"{stem}.png")
        count += 1

if count == 0:
    sys.exit("no attachments in the result bundle")
print(f"    {count} screenshot(s) -> {dest}")
PY
  then
    echo "    FAILED — no screenshots extracted from $bundle"
    failed+=("$platform/$locale")
    return
  fi

  if [ "$platform" = "duo-open" ]; then
    normalize_duo_open "$dest"
  fi
}

for entry in "${PLATFORMS[@]}"; do
  IFS='|' read -r platform destination <<< "$entry"
  wanted "$platform" || continue
  for locale in $LOCALES; do
    echo "==> $platform / $locale"
    capture "$platform" "$destination" "$locale"
  done
done

echo
echo "=== sizes ==="
if [ -d "$OUT" ]; then
  find "$OUT" -name "*.png" | sort | while read -r png; do
    size=$(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w"x"h}')
    printf '%-40s %s\n' "${png#"$OUT"/}" "$size"
  done
fi

echo
if [ ${#failed[@]} -gt 0 ]; then
  echo "FAILED: ${failed[*]}"
  echo "Logs are in $WORK"
  exit 1
fi
echo "All captures succeeded. Open with: open $OUT"
