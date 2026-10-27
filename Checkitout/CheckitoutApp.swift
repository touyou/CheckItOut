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

    init() {
        do {
            if ScreenshotFixture.usesEphemeralStore {
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
        // Registered synchronously here: a background intent can launch the
        // app process without ever showing a scene.
        // `dependency:` is an escaping, nonisolated autoclosure: pass locals built here.
        let container = container
        let player = SoundPlaybackService()
        AppDependencyManager.shared.add(dependency: container)
        AppDependencyManager.shared.add(dependency: player)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
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
