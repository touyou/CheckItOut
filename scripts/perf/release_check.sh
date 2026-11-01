#!/bin/bash
#
# Builds Release for the simulator and checks the tap-latency bench is not in
# it: no TapLatencyProbe symbols, no bench launch arguments or keys.
#
#   scripts/perf/release_check.sh [checkout]
#
set -euo pipefail

SRC="$(cd "${1:-$(dirname "$0")/../..}" && pwd)"
WORK="${PERF_WORK_DIR:-$SRC/.perf-runs}/release"
mkdir -p "$WORK"

xcodebuild build -quiet -project "$SRC/Checkitout.xcodeproj" -scheme Checkitout \
  -configuration Release -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$WORK/dd" > "$WORK/build.log" 2>&1 \
  || { echo "Release build failed: $WORK/build.log" >&2; exit 1; }

APP="$WORK/dd/Build/Products/Release-iphonesimulator/Checkitout.app"
found=0
for bin in "$APP/Checkitout" "$APP"/*.dylib; do
  [ -f "$bin" ] || continue
  if strings -a "$bin" | grep -E 'TapLatencyProbe|perf-tap-bench|PERF_TAP_BENCH|perf-two-finger-target' >/dev/null; then
    echo "found bench code in $bin" >&2
    found=1
  fi
done
[ $found = 0 ] && echo "release check: OK (no bench code in $APP)"
exit $found
