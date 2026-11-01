#!/bin/bash
#
# Tap-latency bench: "finger down -> sound out" for the pads, on a simulator.
# Numbers are only for before/after comparison, never real-device values.
# See docs/perf/README.md.
#
#   scripts/perf/bench.sh                         # 3 runs of this checkout
#   scripts/perf/bench.sh --cand ../wt-candidate  # 3 runs each, alternating
#   scripts/perf/bench.sh --runs 5 --out /tmp/perf
#
# The measuring code (Checkitout/PerfBench/, the UI test driving the pads,
# analyze.py and expected.json) always comes from the trusted checkout (the
# one this script lives in, or --trusted), copied over each build, so a
# candidate can't change how it is measured or checked.
#
# Output: <out>/base-N.json (and cand-N.json), one per run, in the shape
# skills/autonomous-perf-loop/scripts/compare.py reads.

set -euo pipefail

TRUSTED="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$TRUSTED"
CAND=""
RUNS=3
OUT=""
SIM_NAME="CheckItOut Perf"
SIM_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
SIM_RUNTIME="${PERF_SIM_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-2}"

while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$(cd "$2" && pwd)"; shift 2 ;;
    --cand) CAND="$(cd "$2" && pwd)"; shift 2 ;;
    --trusted) TRUSTED="$(cd "$2" && pwd)"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

WORK="${PERF_WORK_DIR:-$TRUSTED/.perf-runs}"
OUT="${OUT:-$WORK/results/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$WORK" "$OUT"

# A dedicated simulator, so the bench never touches the user's own ones.
UDID=$(xcrun simctl list devices -j | python3 -c "
import json, sys
for runtime, devices in json.load(sys.stdin)['devices'].items():
    if runtime == '$SIM_RUNTIME':
        for d in devices:
            if d['name'] == '$SIM_NAME' and d['isAvailable']:
                print(d['udid']); sys.exit()
")
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl create "$SIM_NAME" "$SIM_TYPE" "$SIM_RUNTIME")
fi
echo "simulator: $SIM_NAME ($UDID)"

TRUSTED_FILES=(
  "Checkitout/PerfBench"
  "CheckitoutUITests/TapLatencyBenchTests.swift"
)

# Copies a checkout to a build directory and lays the trusted bench over it.
prepare() {
  local src=$1 dest=$2
  mkdir -p "$dest"
  rsync -a --delete --exclude .git --exclude .perf-runs --exclude build --exclude DerivedData \
    --exclude Screenshots --exclude .screenshot-runs "$src/" "$dest/"
  for path in "${TRUSTED_FILES[@]}"; do
    rm -rf "${dest:?}/$path"
    cp -R "$TRUSTED/$path" "$dest/$path"
  done
}

# Things a candidate must not change, since they decide how it is built and
# measured. A deliberate change (reviewed by a person) can be let through with
# PERF_ALLOW_PROJECT_DIFF=1 or PERF_ALLOW_HOOK_DIFF=1.
HOOK_PATTERN='TapLatencyProbe|PERF_TAP_BENCH|perf-tap-bench|perf-intent-check|tapBenchTwoFingerTarget'

hook_lines() {
  (cd "$1" && grep -rhoE ".*($HOOK_PATTERN).*" Checkitout CheckitoutUITests \
    --exclude-dir PerfBench --exclude TapLatencyBenchTests.swift 2>/dev/null \
    | sed -E 's/^[[:space:]]+//' | sort)
}

gate() {
  local src=$1 ok=1
  if [ -n "$(find "$src" -type l -not -path '*/.git/*' | head -1)" ]; then
    echo "gate: $src contains symlinks" >&2; ok=0
  fi
  if ! diff -rq --exclude xcuserdata "$TRUSTED/Checkitout.xcodeproj" "$src/Checkitout.xcodeproj" >/dev/null; then
    if [ "${PERF_ALLOW_PROJECT_DIFF:-0}" = 1 ]; then
      echo "gate: Checkitout.xcodeproj differs (allowed by PERF_ALLOW_PROJECT_DIFF)" >&2
    else
      echo "gate: Checkitout.xcodeproj (build settings, schemes, file membership) differs from trusted" >&2; ok=0
    fi
  fi
  if ! diff -rq "$TRUSTED/Checkitout/AudioSample" "$src/Checkitout/AudioSample" >/dev/null; then
    echo "gate: Checkitout/AudioSample differs from trusted" >&2; ok=0
  fi
  if [ "$(hook_lines "$TRUSTED")" != "$(hook_lines "$src")" ]; then
    if [ "${PERF_ALLOW_HOOK_DIFF:-0}" = 1 ]; then
      echo "gate: bench hooks in app code differ (allowed by PERF_ALLOW_HOOK_DIFF)" >&2
    else
      echo "gate: bench hooks in app code differ from trusted:" >&2
      diff <(hook_lines "$TRUSTED") <(hook_lines "$src") >&2 || true
      ok=0
    fi
  fi
  [ $ok = 1 ] || exit 1
}

build() {
  local name=$1 src=$2
  [ "$src" = "$TRUSTED" ] || gate "$src"
  prepare "$src" "$WORK/$name/src"
  echo "building $name from $src"
  xcodebuild build-for-testing -quiet \
    -project "$WORK/$name/src/Checkitout.xcodeproj" -scheme Checkitout \
    -destination "id=$UDID" -derivedDataPath "$WORK/$name/dd" \
    > "$WORK/$name/build.log" 2>&1 || { echo "build failed: $WORK/$name/build.log" >&2; exit 1; }
}

run() {
  local name=$1 index=$2 logs="$WORK/$1/logs-$2"
  rm -rf "$logs" && mkdir -p "$logs"
  # Exit status is ignored here: a failing UI test leaves logs missing, which
  # analyze.py reports as an integrity failure (score 0).
  TEST_RUNNER_PERF_TAP_BENCH_OUT="$logs" xcodebuild test-without-building -quiet \
    -project "$WORK/$name/src/Checkitout.xcodeproj" -scheme Checkitout \
    -destination "id=$UDID" -derivedDataPath "$WORK/$name/dd" \
    -only-testing:CheckitoutUITests/TapLatencyBenchTests \
    > "$logs/test.log" 2>&1 || true
  python3 "$TRUSTED/scripts/perf/analyze.py" "$logs" \
    --expected "$TRUSTED/docs/perf/expected.json" > "$OUT/$name-$index.json" || true
  python3 -c "
import json; r = json.load(open('$OUT/$name-$index.json'))
print(f\"$name-$index: score {r['score']} valid {r['valid']} touch_to_audio_ms {r.get('touch_to_audio_ms')}\")
for f in r['failures'][:5]: print('  -', f)"
}

build base "$BASE"
[ -n "$CAND" ] && build cand "$CAND"

# Alternate base and candidate so machine load lands on both alike.
for i in $(seq 1 "$RUNS"); do
  run base "$i"
  [ -n "$CAND" ] && run cand "$i"
done

echo "results: $OUT"
