#!/usr/bin/env python3
"""Scores one run of the tap-latency bench and checks its integrity.

    analyze.py <log dir> [--mode release|touch] [--expected docs/perf/expected.json] > run.json

--mode is the pad setting the logs were taken with: release (default, pads
play when the finger lifts) or touch ("play on touch" turned on).

<log dir> holds the per-scenario logs written by TapLatencyProbe
(first_tap-0.json ... repeat.json, simultaneous.json, slide_off.json,
intent.json). Prints one JSON object in the shape the autonomous-perf-loop
skill's compare.py reads: score / valid / failures plus metrics.

Times are seconds of system uptime. "audio" is an estimate: the time play()
returned plus the session's outputLatency and ioBufferDuration (the simulator
can't tell us when sound actually leaves the speaker).
See docs/perf/README.md.
"""
import argparse
import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_EXPECTED = os.path.join(HERE, "..", "..", "docs", "perf", "expected.json")


def load_events(log_dir, name, failures):
    path = os.path.join(log_dir, f"{name}.json")
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)["events"]
    except (OSError, ValueError, KeyError) as e:
        failures.append(f"{name}: log missing or unreadable ({e})")
        return None


def touches(events):
    """Groups down/up events into presses (fingers that went down together)."""
    groups = []
    for i, d in enumerate(events):
        if d["kind"] != "down":
            continue
        # UIKit reuses UITouch objects, so the end is the next one with the
        # same identity after this down.
        end = next((e for e in events[i + 1:]
                    if e["kind"] in ("up", "cancel") and e["touch"] == d["touch"]), None)
        if groups and abs(groups[-1][0]["down"]["t"] - d["t"]) < 0.005:
            groups[-1].append({"down": d, "end": end})
        else:
            groups.append([{"down": d, "end": end}])
    return groups


def plays_between(events, start, stop):
    return [e for e in events if e["kind"] == "play" and start <= e["t_entry"] < stop]


def sample(press, play):
    down, end = press["down"], press["end"]
    audio = play["t_returned"] + play["output_latency"] + play["io_buffer"]
    return {
        "touch_to_audio_ms": (audio - down["t"]) * 1000,
        "hold_ms": (end["t"] - down["t"]) * 1000,
        "delivery_ms": (end["t_received"] - end["t"]) * 1000,
        "release_to_play_ms": (play["t_entry"] - end["t"]) * 1000,
        "touch_to_play_ms": (play["t_entry"] - down["t"]) * 1000,
        "play_call_ms": (play["t_returned"] - play["t_entry"]) * 1000,
        "output_est_ms": (play["output_latency"] + play["io_buffer"]) * 1000,
    }


def check_play(name, play, slot, exp, failures, events):
    want = exp["assignment"][str(slot)]
    if play["t_entry"] < 0:
        failures.append(f"{name}: pad {slot} played without willPlay")
    if play["volume"] != 1 or play["rate"] != 1 or play["pan"] != 0:
        failures.append(f"{name}: pad {slot} volume/rate/pan changed "
                        f"({play['volume']}, {play['rate']}, {play['pan']})")
    later = [e for e in events if e["kind"] == "play_check" and e["slot"] == slot
             and e["t_returned"] == play["t_returned"]]
    if not later or not later[0]["is_playing"] or later[0]["position"] < 0.05:
        failures.append(f"{name}: pad {slot} was not still playing 0.1s later")
    if play["slot"] != slot:
        failures.append(f"{name}: played pad {play['slot']}, expected pad {slot}")
    if play["sound"] != want:
        failures.append(f"{name}: pad {slot} played {play['sound']!r}, expected {want!r}")
    if not (play["started"] and play["is_playing"]):
        failures.append(f"{name}: pad {slot} did not start playing")
    if play["position"] > exp["max_start_position_s"]:
        failures.append(f"{name}: pad {slot} did not start from the top (at {play['position']:.3f}s)")
    if play["category"] != exp["category"]:
        failures.append(f"{name}: session category {play['category']}, expected {exp['category']}")


def measure(name, events, groups, pads_per_press, exp, failures, samples, mode):
    """Each press must produce exactly the expected plays, at the time the
    setting says: after the finger lifts (release) or while it is down (touch)."""
    if len(groups) != len(pads_per_press):
        failures.append(f"{name}: {len(groups)} presses, expected {len(pads_per_press)}")
        return
    bounds = [g[0]["down"]["t"] for g in groups] + [float("inf")]
    for i, (group, pads) in enumerate(zip(groups, pads_per_press)):
        label = f"{name}#{i}"
        if len(group) != len(pads) or any(p["end"] is None or p["end"]["kind"] != "up" for p in group):
            failures.append(f"{label}: expected {len(pads)} finger(s) down and up, got {len(group)}")
            continue
        plays = plays_between(events, bounds[i], bounds[i + 1])
        if sorted(p["slot"] for p in plays) != sorted(pads):
            failures.append(f"{label}: played pads {[p['slot'] for p in plays]}, expected {pads}")
            continue
        release = max(p["end"]["t"] for p in group)
        for play in plays:
            check_play(label, play, play["slot"], exp, failures, events)
            if play["t_entry"] < group[0]["down"]["t"]:
                failures.append(f"{label}: pad {play['slot']} play entered before the touch")
            if mode == "release" and play["t_entry"] < release:
                failures.append(f"{label}: pad {play['slot']} played before the finger was lifted")
            if mode == "touch" and play["t_entry"] >= min(p["end"]["t"] for p in group):
                failures.append(f"{label}: pad {play['slot']} played after the finger was lifted")
            samples.append(sample(group[0], play))


def p(values, q):
    values = sorted(values)
    if not values:
        return None
    k = (len(values) - 1) * q
    lo, hi = int(k), min(int(k) + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (k - lo)


def analyze(log_dir, exp, mode):
    failures = []
    per = {"first_tap": [], "repeat": [], "simultaneous": []}

    for i, pad in enumerate(exp["first_tap_pads"]):
        name = f"first_tap-{i}"
        ev = load_events(log_dir, name, failures)
        if ev is not None:
            measure(name, ev, touches(ev), [[pad]], exp, failures, per["first_tap"], mode)

    ev = load_events(log_dir, "repeat", failures)
    if ev is not None:
        r = exp["repeat"]
        before = len(per["repeat"])
        measure("repeat", ev, touches(ev), [[r["pad"]]] * r["count"], exp, failures, per["repeat"], mode)
        # The first press starts from silence; the rest restart a playing sound.
        del per["repeat"][before:before + 1]
        restarts = [e for e in ev if e["kind"] == "play"][1:]
        if not all(e.get("was_playing") for e in restarts):
            failures.append("repeat: a press after the first did not land while the sound was playing")

    ev = load_events(log_dir, "simultaneous", failures)
    if ev is not None:
        s = exp["simultaneous"]
        measure("simultaneous", ev, touches(ev), [s["pads"]] * s["count"], exp, failures, per["simultaneous"], mode)

    ev = load_events(log_dir, "slide_off", failures)
    if ev is not None:
        groups = touches(ev)
        pad = exp["slide_off"]["pad"]
        if len(groups) != 2:
            failures.append(f"slide_off: {len(groups)} presses, expected 2")
        else:
            bounds = [groups[0][0]["down"]["t"], groups[1][0]["down"]["t"], float("inf")]
            slid = plays_between(ev, bounds[0], bounds[1])
            if mode == "release" and slid:
                failures.append("slide_off: a press that slid off the pad still played")
            if mode == "touch":
                end = groups[0][0]["end"]
                if [p["slot"] for p in slid] != [pad]:
                    failures.append(f"slide_off: the sliding press played {[p['slot'] for p in slid]}, expected [{pad}]")
                elif end is None or slid[0]["t_entry"] >= end["t"]:
                    failures.append("slide_off: the sliding press did not play while the finger was down")
                else:
                    check_play("slide_off", slid[0], pad, exp, failures, ev)
            plays = plays_between(ev, bounds[1], bounds[2])
            if [p["slot"] for p in plays] != [pad]:
                failures.append(f"slide_off: the normal press played {[p['slot'] for p in plays]}, expected [{pad}]")
            else:
                check_play("slide_off", plays[0], pad, exp, failures, ev)

    ev = load_events(log_dir, "intent", failures)
    if ev is not None:
        it = exp["intent"]
        result = [e for e in ev if e["kind"] == "intent"]
        during = [e for e in ev if e["kind"] == "intent_during"]
        if len(result) != 1 or result[0].get("error"):
            failures.append(f"intent: playback failed ({result})")
        else:
            res = result[0]
            if res["category_before"] != exp["category"] or res["category_after"] != exp["category"]:
                failures.append(f"intent: session not restored ({res['category_before']} -> {res['category_after']})")
            if res["t_end"] - res["t_start"] < it["min_duration_s"]:
                failures.append(f"intent: returned after {res['t_end'] - res['t_start']:.2f}s, before the sound ended")
        if len(during) != 2 or any(d["category"] != exp["intent_category"] for d in during):
            failures.append(f"intent: category while playing was {[d['category'] for d in during]}")
        plays = [e for e in ev if e["kind"] == "play"]
        if [p["slot"] for p in plays] != [it["tap_pad"]]:
            failures.append(f"intent: pad press after the intent played {[p['slot'] for p in plays]}")
        else:
            check_play("intent", plays[0], it["tap_pad"], exp, failures, ev)

    out = {"score": 0.0, "valid": False, "failures": failures}
    scenarios = {}
    for name, samples in per.items():
        lat = [s["touch_to_audio_ms"] for s in samples]
        scenarios[name] = {"n": len(lat), "p50": p(lat, 0.5), "p95": p(lat, 0.95)}
        if not lat:
            failures.append(f"{name}: no samples")
    if failures:
        out["scenarios"] = scenarios
        return out

    weights = exp["weights"]
    weighted = sum(weights[n] * scenarios[n]["p50"] for n in per) / sum(weights.values())
    every = [s for samples in per.values() for s in samples]
    out.update({
        "score": round(1000.0 / weighted, 4),
        "valid": True,
        "touch_to_audio_ms": round(weighted, 3),
    })
    for key in ("hold_ms", "delivery_ms", "release_to_play_ms", "touch_to_play_ms", "play_call_ms",
                "output_est_ms"):
        out[key] = round(statistics.median(s[key] for s in every), 3)
    out["repeat_play_call_ms"] = round(statistics.median(s["play_call_ms"] for s in per["repeat"]), 3)
    out["first_play_call_ms"] = round(statistics.median(s["play_call_ms"] for s in per["first_tap"]), 3)
    out["scenarios"] = {n: {k: (round(v, 3) if isinstance(v, float) else v) for k, v in s.items()}
                        for n, s in scenarios.items()}
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log_dir")
    ap.add_argument("--mode", choices=["release", "touch"], default="release")
    ap.add_argument("--expected", default=DEFAULT_EXPECTED)
    args = ap.parse_args()
    with open(args.expected, encoding="utf-8") as f:
        exp = json.load(f)
    result = analyze(args.log_dir, exp, args.mode)
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    sys.exit(main())
