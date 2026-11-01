//
//  TapLatencyBenchTests.swift
//  CheckitoutUITests
//
//  Drives the pads for the tap-latency bench. Not a behaviour test: it only
//  presses pads with fixed hold times, and the app (`TapLatencyProbe`) logs
//  the timings. `scripts/perf/bench.sh` runs it and `scripts/perf/analyze.py`
//  scores the logs and checks them against `docs/perf/expected.json`.
//  Skipped unless the bench sets `PERF_TAP_BENCH_OUT`.
//
//  The bench copies this file from the trusted (baseline) checkout over the
//  candidate before building. Keep the press sequences in sync with
//  `docs/perf/expected.json`.
//

import XCTest

final class TapLatencyBenchTests: XCTestCase {
    /// How long each press holds the pad. Pads play on release, so this is
    /// part of the latency.
    static let holdDuration: TimeInterval = 0.08
    /// Launches for the first-tap scenario, one press each on these pads.
    static let firstTapPads = [1, 2, 3, 4, 5]
    /// Presses on pad 0 in a row, each while the previous one is still playing.
    static let repeatCount = 10
    /// Two-finger presses for the simultaneous scenario.
    static let simultaneousCount = 5

    private var outputDirectory: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let dir = ProcessInfo.processInfo.environment["PERF_TAP_BENCH_OUT"] else {
            throw XCTSkip("Run through scripts/perf/bench.sh")
        }
        outputDirectory = dir
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ scenario: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-perf-tap-bench"] + extraArguments
        app.launchEnvironment["PERF_TAP_BENCH_OUT"] = outputDirectory
        app.launchEnvironment["PERF_TAP_BENCH_SCENARIO"] = scenario
        app.launch()
        XCTAssertTrue(app.buttons["pad-0"].waitForExistence(timeout: 30), "The pads should appear")
        // Let `rebuild(from:)` prepare the players before the first press.
        Thread.sleep(forTimeInterval: 1.5)
        return app
    }

    private func press(_ app: XCUIApplication, pad: Int) {
        app.buttons["pad-\(pad)"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: Self.holdDuration)
    }

    /// Lets the probe's background writer flush the last events.
    private func finish(_ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()
    }

    @MainActor
    func testFirstTap() throws {
        for (index, pad) in Self.firstTapPads.enumerated() {
            let app = launch("first_tap-\(index)")
            press(app, pad: pad)
            finish(app)
        }
    }

    @MainActor
    func testRepeatSamePad() throws {
        let app = launch("repeat")
        for _ in 0..<Self.repeatCount {
            press(app, pad: 0)
        }
        finish(app)
    }

    /// Two fingers at once, one on pad 1 and one on pad 2 (see
    /// `tapBenchTwoFingerTarget` in the app).
    @MainActor
    func testSimultaneous() throws {
        let app = launch("simultaneous")
        let target = app.otherElements["perf-two-finger-target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5), "The two-finger target should exist in bench mode")
        for _ in 0..<Self.simultaneousCount {
            target.tap(withNumberOfTaps: 1, numberOfTouches: 2)
            Thread.sleep(forTimeInterval: 0.6)
        }
        finish(app)
    }

    /// Pads play on release and a press that slides off the pad is cancelled:
    /// the first press drags away from pad 3 and must stay silent, the second
    /// is a normal press.
    @MainActor
    func testSlideOffCancels() throws {
        let app = launch("slide_off")
        let start = app.buttons["pad-3"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let away = app.buttons["pad-3"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3.5))
        start.press(forDuration: Self.holdDuration, thenDragTo: away)
        Thread.sleep(forTimeInterval: 0.6)
        press(app, pad: 3)
        finish(app)
    }

    @MainActor
    func testIntentStillPlays() throws {
        let app = launch("intent", extraArguments: ["-perf-intent-check"])
        // The intent plays pad 0's sound to the end (about 1.3 s) first.
        Thread.sleep(forTimeInterval: 2.5)
        press(app, pad: 2)
        finish(app)
    }
}
