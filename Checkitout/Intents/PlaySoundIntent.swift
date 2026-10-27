//
//  PlaySoundIntent.swift
//  Checkitout
//
//  Plays one sound by name ("Hey Siri, play チェケラ in Checkitout"). The
//  in-app pads keep their own preloaded players for latency; both resolve
//  the file through `SoundData.resolvedURL`.
//

import AppIntents
import SwiftData

struct PlaySoundIntent: AppIntent {
    static let title: LocalizedStringResource = "サウンドを鳴らす"
    static let description = IntentDescription("サウンドボードの音を再生します。")
    // Foreground: without the `audio` background mode a background launch
    // cannot start an audio session, and the app has no other use for it.
    static let supportedModes: IntentModes = .foreground(.immediate)

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$sound)を鳴らす")
    }

    @Parameter(title: "サウンド")
    var sound: SoundEntity

    @Dependency private var container: ModelContainer
    @Dependency private var player: SoundPlaybackService

    init() {}

    init(sound: SoundEntity) {
        self.sound = sound
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let key = sound.id
        let descriptor = FetchDescriptor<SoundData>(predicate: #Predicate { $0.storageKey == key })
        guard let url = try container.mainContext.fetch(descriptor).first?.resolvedURL else {
            throw SoundPlaybackError.missingFile(sound.name)
        }
        try await player.playToEnd(url)
        return .result()
    }
}
