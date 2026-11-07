//
//  CheckitoutApp.swift
//  Checkitout
//
//  SwiftUI app entry point. Sets up the SwiftData container and hosts the
//  single-screen soundboard UI.
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct CheckitoutApp: App {
    let container: ModelContainer
    /// Shared with the intents: the same instance edits the board and asks for the record panel.
    let library: SoundLibraryService

    init() {
        do {
            if ScreenshotFixture.usesEphemeralStore || Self.isTapBench {
                container = try ModelContainer(
                    for: SoundData.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            } else {
                container = try ModelContainer(for: SoundData.self)
            }
        } catch {
            fatalError("SwiftData ModelContainer の生成に失敗しました: \(error)")
        }
        if ScreenshotFixture.isActive {
            ScreenshotFixture.seed(into: container.mainContext)
        }
        #if DEBUG
        if Self.isTapBench {
            TapLatencyProbe.seed(into: container.mainContext)
        }
        #endif
        // Registered synchronously here: a background intent can launch the
        // app process without ever showing a scene.
        // `dependency:` is an escaping, nonisolated autoclosure: pass locals built here.
        let container = container
        let player = SoundPlaybackService()
        let library = SoundLibraryService(container: container)
        self.library = library
        AppDependencyManager.shared.add(dependency: container)
        AppDependencyManager.shared.add(dependency: player)
        AppDependencyManager.shared.add(dependency: library)
    }

    /// The tap-latency bench (Debug only) runs on its own in-memory board.
    private static var isTapBench: Bool {
        #if DEBUG
        TapLatencyProbe.isActive
        #else
        false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
        .modelContainer(container)
    }
}

/// `UserDefaults` keys of the app's settings.
enum SettingsKey {
    /// Pads play the moment a finger touches them instead of on release.
    /// Off by default: on release, sliding off a pad cancels the press.
    static let playOnTouchDown = "playOnTouchDown"
}

/// The three interaction modes of the soundboard.
enum Mode {
    case play
    case edit
    case record
}

extension Font {
    /// The app's brand font (registered via `UIAppFonts` in Info.plist).
    static func brand(_ size: CGFloat) -> Font {
        .custom("Corporate-Logo-Bold", size: size)
    }
}
