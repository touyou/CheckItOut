//
//  ScreenshotFixture.swift
//  Checkitout
//
//  Presentable, deterministic state for the App Store screenshots. Active only
//  when the UI test launches the app with `-uitest-screenshot-fixture`
//  (see `CheckitoutUITests/ScreenshotTests.swift` and
//  `scripts/capture_screenshots.sh`), and compiled out of Release builds, so
//  production behaviour is untouched.
//

import Foundation
import SwiftData

enum ScreenshotFixture {
    /// Seeds sample sounds and fakes a finished recording instead of touching
    /// the microphone.
    static let launchArgument = "-uitest-screenshot-fixture"
    /// Keeps SwiftData in memory so a capture run never reads or writes the
    /// simulator's real store.
    static let ephemeralStoreArgument = "-uitest-ephemeral-store"

    static var isActive: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }

    static var usesEphemeralStore: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(ephemeralStoreArgument)
        #else
        false
        #endif
    }

    /// The name pre-filled in the recording panel.
    static let recordingTitle = "チェックイットアウト！"

    /// Inserts a full-looking board: most pads assigned, a few sounds still
    /// waiting in the list. Replaces the first-launch seeding/migration.
    @MainActor
    static func seed(into context: ModelContext) {
        #if DEBUG
        // Bundled sounds keep their real files (they ship in Release too); the
        // rest stand in for the user's own recordings. Their files don't
        // exist, which only means those pads stay silent during the capture.
        let sounds: [(key: String, isBundle: Bool, name: String, pad: Int)] = [
            ("touyou", true, "バスドラ", 0),
            ("15minnade_cut", true, "みんなで", 1),
            ("16chekera_cut", true, "チェケラ", 2),
            ("fixture-yeah.wav", false, "イェー！", 3),
            ("fixture-clap.wav", false, "拍手", 4),
            ("fixture-snare.wav", false, "スネア", 5),
            ("fixture-hihat.wav", false, "ハイハット", 6),
            ("fixture-scratch.wav", false, "スクラッチ", 7),
            ("fixture-cheer.wav", false, "歓声", 8),
            ("fixture-drumroll.wav", false, "ドラムロール", 9),
            ("fixture-kanpai.wav", false, "かんぱーい", 10),
            ("fixture-correct.wav", false, "ピンポン", 11),
            ("fixture-wrong.wav", false, "ブブー", 12),
            ("fixture-otsukare.wav", false, "おつかれ", 13),
            ("fixture-horn.wav", false, "エアホーン", 14),
            ("fixture-laugh.wav", false, "笑い声", -1),
            ("fixture-jingle.wav", false, "ジングル", -1),
        ]
        for (index, sound) in sounds.enumerated() {
            context.insert(SoundData(storageKey: sound.key,
                                     isBundle: sound.isBundle,
                                     displayName: sound.name,
                                     padNum: sound.pad,
                                     sortIndex: index))
        }
        try? context.save()
        #endif
    }

    /// A deterministic waveform shaped like a short shout ("Check it out!"):
    /// four syllable bursts with a little texture, filling the panel.
    static var waveformSamples: [Float] {
        let count = 256
        let bursts: [(center: Float, width: Float, peak: Float)] = [
            (0.14, 0.07, 0.55), (0.34, 0.08, 0.80), (0.56, 0.06, 0.65), (0.78, 0.10, 0.95),
        ]
        return (0..<count).map { index in
            let t = Float(index) / Float(count - 1)
            let envelope = bursts.reduce(Float(0.04)) { amp, burst in
                let d = (t - burst.center) / burst.width
                return amp + burst.peak * exp(-d * d)
            }
            let texture = 0.75 + 0.25 * sin(Float(index) * 1.7) * cos(Float(index) * 0.45)
            return min(envelope * texture, 1)
        }
    }
}
