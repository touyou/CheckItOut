//
//  TapLatencyProbe.swift
//  Checkitout
//
//  Measures "finger down → sound out" for the pads. Active only when the UI
//  test bench launches the app with `-perf-tap-bench` (see
//  `CheckitoutUITests/TapLatencyBenchTests.swift`, `scripts/perf/bench.sh`
//  and `docs/perf/README.md`). The whole file is compiled out of Release.
//
//  The bench copies this file from the trusted (baseline) checkout over the
//  candidate before building, so a candidate can't change how it is measured.
//  The hooks in app code are `willPlay` / `didPlay` in `PadPlayerEngine.play`
//  and the bench-only setup calls listed in `docs/perf/README.md`.
//

#if DEBUG
import AVFoundation
import SwiftData
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

enum TapLatencyProbe {
    static let launchArgument = "-perf-tap-bench"
    /// Also run `PlaySoundIntent` once after launch to check intents still play.
    static let intentCheckArgument = "-perf-intent-check"
    /// Directory (on the host) the log is written to; set by the UI test.
    static let outputDirectoryKey = "PERF_TAP_BENCH_OUT"
    /// Name of the scenario, used as the log's file name.
    static let scenarioKey = "PERF_TAP_BENCH_SCENARIO"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// The fixed pad assignment the bench expects (mirrored in
    /// `docs/perf/expected.json`). Every pad gets a bundled sound so all of
    /// them have a real file; pad 0 has the longest one, so repeated taps land
    /// while it is still playing.
    static let assignment: [(key: String, pad: Int)] = [
        ("11yourname_cut", 0), ("touyou", 1), ("15minnade_cut", 2), ("16chekera_cut", 3),
        ("1korekara_cut", 4), ("2korekara_cut", 5), ("3apuri_cut", 6), ("4setumei_cut", 7),
        ("5suruze_cut", 8), ("6onsei_cut", 9), ("7rokuon_cut", 10), ("8minnnawo_cut", 11),
        ("9rockon_cut", 12), ("10korede_cut", 13), ("12todoroku_cut", 14), ("13menber_cut", 15),
    ]

    @MainActor
    static func seed(into context: ModelContext) {
        for (index, sound) in assignment.enumerated() {
            context.insert(SoundData(storageKey: sound.key, isBundle: true,
                                     displayName: "bench-\(sound.pad)", padNum: sound.pad,
                                     sortIndex: index))
        }
        try? context.save()
    }

    // MARK: Events

    /// Seconds on the same clock as `UITouch.timestamp` (system uptime).
    static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    nonisolated(unsafe) private static var events: [[String: Any]] = []
    private static let lock = NSLock()
    private static let writer = DispatchQueue(label: "TapLatencyProbe.writer", qos: .utility)

    private static func log(_ event: [String: Any]) {
        guard isActive else { return }
        // Locked: a candidate may call the hooks off the main thread.
        let snapshot = lock.withLock {
            events.append(event)
            return events
        }
        // Encoding and writing happen off the main thread so logging doesn't
        // delay the next touch.
        writer.async { write(snapshot) }
    }

    private static func write(_ snapshot: [[String: Any]]) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env[outputDirectoryKey], let scenario = env[scenarioKey],
              let data = try? JSONSerialization.data(withJSONObject: ["events": snapshot],
                                                     options: [.sortedKeys]) else { return }
        let url = URL(filePath: dir).appending(path: "\(scenario).json")
        try? data.write(to: url, options: .atomic)
    }

    nonisolated(unsafe) private static var pending: [Int: (entry: TimeInterval, wasPlaying: Bool)] = [:]

    /// Called from `PadPlayerEngine.play` right before the pad's player is
    /// (re)started. The probe takes its own timestamps and reads the player's
    /// state itself rather than trusting values passed in.
    static func willPlay(slot: Int, player: AVAudioPlayer) {
        let entry = now
        let wasPlaying = player.isPlaying
        lock.withLock { pending[slot] = (entry, wasPlaying) }
    }

    /// Called right after the player is started, with what `play()` returned.
    static func didPlay(slot: Int, player: AVAudioPlayer, started: Bool) {
        let returned = now
        let before = lock.withLock { pending.removeValue(forKey: slot) }
        let session = AVAudioSession.sharedInstance()
        log([
            "kind": "play", "slot": slot, "t_entry": before?.entry ?? -1, "t_returned": returned,
            "was_playing": before?.wasPlaying ?? false,
            "output_latency": session.outputLatency, "io_buffer": session.ioBufferDuration,
            "category": session.category.rawValue,
            "sound": player.url?.deletingPathExtension().lastPathComponent ?? "",
            "started": started, "is_playing": player.isPlaying, "position": player.currentTime,
            "volume": player.volume, "rate": player.rate, "pan": player.pan,
        ])
        // A sound cut off right after starting must not pass.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak player] in
            log(["kind": "play_check", "slot": slot, "t_returned": returned,
                 "is_playing": player?.isPlaying ?? false, "position": player?.currentTime ?? 0])
        }
    }

    static func recordReady() {
        log(["kind": "ready", "t": now])
    }

    // MARK: Touches

    private static var installed = false

    /// Observes every touch in the key window without taking part in gesture
    /// recognition.
    @MainActor
    static func installIfNeeded() {
        guard isActive, !installed else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard let window else { return }
        installed = true
        window.addGestureRecognizer(TouchObserver())
    }

    fileprivate static func recordTouches(_ touches: Set<UITouch>, phase: String, in view: UIView?) {
        let received = now
        for touch in touches {
            let point = touch.location(in: view)
            log(["kind": phase, "t": touch.timestamp, "t_received": received,
                 "touch": ObjectIdentifier(touch).hashValue, "x": point.x, "y": point.y])
        }
    }

    // MARK: Intent check

    /// Plays pad 0's sound through `SoundPlaybackService` (what
    /// `PlaySoundIntent.perform` runs; the intent itself can't be performed
    /// outside the App Intents runtime, its `@Dependency` traps) and logs the
    /// audio session category before, during and after.
    @MainActor
    static func runIntentCheckIfNeeded(container: ModelContainer) {
        guard isActive, ProcessInfo.processInfo.arguments.contains(intentCheckArgument),
              let key = assignment.first(where: { $0.pad == 0 })?.key else { return }
        let session = AVAudioSession.sharedInstance()
        let sound = try? container.mainContext.fetch(
            FetchDescriptor<SoundData>(predicate: #Predicate { $0.storageKey == key })).first
        guard let url = sound?.resolvedURL else {
            log(["kind": "intent", "error": "missing sound"])
            return
        }
        let before = session.category.rawValue
        let start = now
        Task { @MainActor in
            // Twice: early in the sound and near its end (it is about 1.3 s).
            for delay in [150, 750] {
                try? await Task.sleep(for: .milliseconds(delay))
                log(["kind": "intent_during", "t": now, "category": session.category.rawValue])
            }
        }
        Task { @MainActor in
            var failure = ""
            do {
                try await SoundPlaybackService().playToEnd(url)
            } catch {
                failure = String(describing: error)
            }
            log(["kind": "intent", "t_start": start, "t_end": now, "category_before": before,
                 "category_after": session.category.rawValue, "error": failure])
        }
    }
}

extension View {
    /// An invisible, untouchable element centered on the boundary between
    /// pads 1 and 2. XCUITest can't place two fingers on chosen points, but
    /// `tap(withNumberOfTaps:numberOfTouches: 2)` puts them side by side around
    /// an element's center, about 0.9 × its width apart; this element is one
    /// pad wide, so one finger lands on each pad. Applied to the 4x4 grid in bench mode only.
    func tapBenchTwoFingerTarget() -> some View {
        overlay(alignment: .topLeading) {
            if TapLatencyProbe.isActive {
                GeometryReader { proxy in
                    Color.clear
                        .frame(width: proxy.size.width / 4, height: proxy.size.height / 16)
                        .offset(x: proxy.size.width * 3 / 8, y: proxy.size.height * 3 / 32)
                        .accessibilityElement()
                        .accessibilityIdentifier("perf-two-finger-target")
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

/// A recognizer that never recognizes: it only reports touch timestamps.
private final class TouchObserver: UIGestureRecognizer {
    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        TapLatencyProbe.recordTouches(touches, phase: "down", in: view)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        TapLatencyProbe.recordTouches(touches, phase: "up", in: view)
        finishIfIdle(event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        TapLatencyProbe.recordTouches(touches, phase: "cancel", in: view)
        finishIfIdle(event)
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    private func finishIfIdle(_ event: UIEvent) {
        let active = event.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? []
        if active.isEmpty { state = .failed }
    }
}
#endif
