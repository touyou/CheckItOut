//
//  PlaySoundIntent.swift
//  Checkitout
//
//  Plays one sound without opening the app ("Hey Siri, play チェケラ in
//  Checkitout"). The in-app pads keep their own preloaded players for
//  latency; both resolve the file through `SoundData.resolvedURL`.
//

import AppIntents
import SwiftData

struct PlaySoundIntent: AppIntent {
    static let title: LocalizedStringResource = "サウンドを鳴らす"
    static let description = IntentDescription("サウンドボードの音をアプリを開かずに再生します。")
    static let supportedModes: IntentModes = .background

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
