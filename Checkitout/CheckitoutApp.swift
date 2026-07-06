//
//  CheckitoutApp.swift
//  Checkitout
//
//  SwiftUI app entry point. Sets up the SwiftData container and hosts the
//  single-screen soundboard UI.
//

import SwiftUI
import SwiftData

@main
struct CheckitoutApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: SoundData.self)
        } catch {
            fatalError("SwiftData ModelContainer の生成に失敗しました: \(error)")
        }
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
