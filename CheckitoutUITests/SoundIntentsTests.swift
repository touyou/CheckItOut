//
//  SoundIntentsTests.swift
//  CheckitoutUITests
//
//  Runs the app's intents and queries through AppIntentsTesting, the way Siri
//  and Shortcuts reach them. Needs a live app process, hence a UI test bundle.
//
//  The app is launched on the screenshot fixture's in-memory board (see
//  `ScreenshotFixture`): a fixed set of sounds, nothing written to the
//  simulator's real store, and a record panel that never asks for the mic.
//  Each test relaunches, so every one starts from that same board.
//
//  Not covered here: `DeleteSoundIntent` asks for confirmation, which nothing
//  in a test can answer; its non-asking twin `DeleteSoundNowIntent` is.
//

import AppIntentsTesting
import XCTest

@available(iOS 27.0, *)
final class SoundIntentsTests: XCTestCase {
    private var app: XCUIApplication!
    private var definitions: IntentDefinitions!

    // Fixture sounds (`ScreenshotFixture.seed`).
    private let bassDrum = "touyou"          // バスドラ, pad 1, bundled
    private let chekera = "16chekera_cut"    // チェケラ, pad 3, bundled
    private let laugh = "fixture-laugh.wav"  // 笑い声, no pad, a "recording"
    private let jingle = "fixture-jingle.wav" // ジングル, no pad, a "recording"

    @MainActor override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest-ephemeral-store", "-uitest-screenshot-fixture"]
        app.launch()
        definitions = IntentDefinitions(bundleIdentifier: "com.dev.touyou.Checkitout")
        try await waitForMetadata()
    }

    @MainActor override func tearDown() async throws {
        app.terminate()
        app = nil
    }

    // MARK: Queries

    /// Siri matches spoken names against the suggestions, so the sounds on a
    /// pad must come first, in pad order.
    func testSuggestionsListPadsFirstInPadOrder() async throws {
        let suggested = try await definitions.entities["SoundEntity"].suggestedEntities()
        XCTAssertEqual(suggested.count, 17)
        let firstThree = suggested.prefix(3).map(\.identifier.instanceIdentifier)
        XCTAssertEqual(firstThree, [bassDrum, "15minnade_cut", chekera])
        let first = try XCTUnwrap(suggested.first)
        let firstPad: Int? = try first.pad
        XCTAssertEqual(firstPad, 1)
        let lastTwo = Set(suggested.suffix(2).map(\.identifier.instanceIdentifier))
        XCTAssertEqual(lastTwo, [laugh, jingle])
    }

    func testFindsSoundByName() async throws {
        let found = try await definitions.entities["SoundEntity"].entities(matching: "チェケラ")
        XCTAssertEqual(found.map(\.identifier.instanceIdentifier), [chekera])
        let isRecording: Bool = try XCTUnwrap(found.first).isRecording
        XCTAssertFalse(isRecording)
    }

    func testResolvesSoundByID() async throws {
        let resolved = try await sound(laugh)
        let name: String = try resolved.name
        let isRecording: Bool = try resolved.isRecording
        XCTAssertEqual(name, "笑い声")
        XCTAssertTrue(isRecording)
    }

    // MARK: Intents

    /// Assigning frees whatever was on that pad.
    func testAssignSoundToPadReplacesTheOccupant() async throws {
        _ = try await definitions.intents["AssignSoundToPadIntent"]
            .makeIntent(sound: try await sound(laugh), pad: 1)
            .run()

        let assigned: Int? = try await sound(laugh).pad
        let previous: Int? = try await sound(bassDrum).pad
        XCTAssertEqual(assigned, 1)
        XCTAssertNil(previous)
    }

    func testDeleteSoundNowRemovesTheSound() async throws {
        _ = try await definitions.intents["DeleteSoundNowIntent"]
            .makeIntent(sound: try await sound(jingle))
            .run()

        let remaining = try await definitions.entities["SoundEntity"].entities(identifiers: [jingle])
        XCTAssertTrue(remaining.isEmpty)
    }

    func testPlaySoundFinishes() async throws {
        _ = try await definitions.intents["PlaySoundIntent"]
            .makeIntent(sound: try await sound(chekera))
            .run()
    }

    /// The intent only sets a flag; the soundboard has to notice it and open the panel.
    @MainActor
    func testStartRecordingOpensTheRecordPanel() async throws {
        _ = try await definitions.intents["StartRecordingIntent"].makeIntent().run()
        XCTAssertTrue(app.buttons["保存"].waitForExistence(timeout: 5))
    }

    // MARK: Helpers

    private func sound(_ id: String) async throws -> AnyAppEntity {
        let found = try await definitions.entities["SoundEntity"].entities(identifiers: [id])
        return try XCTUnwrap(found.first, "no sound \(id)")
    }

    /// Right after an install the metadata service may not know the app yet
    /// (`AppIntentsServicesMetadataErrorDomain` 400). A security error is a
    /// signing problem that waiting cannot fix, so it fails at once.
    private func waitForMetadata(timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?
        while Date() < deadline {
            do {
                _ = try await definitions.entities["SoundEntity"].suggestedEntities()
                return
            } catch {
                if (error as NSError).domain == "AppIntentsServicesSecurityErrorDomain" { throw error }
                lastError = error
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        XCTFail("App Intents metadata never became available: \(String(describing: lastError))")
    }
}
