//
//  CheckitoutShortcuts.swift
//  Checkitout
//
//  Siri / Spotlight phrases. Must stay in the app target: a provider declared
//  in a package is silently dropped from the app's App Intents metadata.
//  Japanese phrases live in AppShortcuts.xcstrings.
//

import AppIntents

struct CheckitoutShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlaySoundIntent(),
            phrases: [
                "Play \(\.$sound) in \(.applicationName)",
                "Play \(\.$sound) with \(.applicationName)",
                "Play a sound in \(.applicationName)"
            ],
            shortTitle: "サウンドを鳴らす",
            systemImageName: "speaker.wave.2.fill"
        )
    }
}
