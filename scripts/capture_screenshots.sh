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

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/Screenshots"
WORK="${SCREENSHOT_WORK_DIR:-$ROOT/.screenshot-runs}"
# The UI is Japanese only (no localizations yet), so that is the only locale by default.
LOCALES="${LOCALES:-ja}"

TESTID="CheckitoutUITests/ScreenshotTests"

# platform | destination
#
# iPhone Duo only exists on the iOS 27.1 runtime.
PLATFORMS=(
  "iphone|${IPHONE_DEST:-platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0}"
  "ipad|${IPAD_DEST:-platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=27.0}"
  "duo|${DUO_DEST:-platform=iOS Simulator,name=iPhone Duo,OS=27.1}"
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
  if ! xcodebuild test \
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
