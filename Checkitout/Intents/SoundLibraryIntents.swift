//
//  SoundLibraryIntents.swift
//  Checkitout
//
//  Editing the board from Siri and Shortcuts. The delete alert runs
//  `DeleteSoundNowIntent` because a confirmation from an in-app button has
//  nowhere to appear; Siri and Shortcuts get the asking `DeleteSoundIntent`.
//  Every intent here writes to the store, so each is pinned to the app process.
//

import AppIntents

/// Puts a sound on one of the 16 pads.
struct AssignSoundToPadIntent: AppIntent {
    static let title: LocalizedStringResource = "サウンドをパッドに割り当てる"
    static let description = IntentDescription(
        "サウンドを 16 個あるパッドのひとつに割り当てます。そのパッドにあった音は外れます。",
        searchKeywords: ["パッド", "割り当て", "配置"]
    )
    static let supportedModes: IntentModes = .background
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$sound)をパッド\(\.$pad)に割り当てる")
    }

    @Parameter(title: "サウンド")
    var sound: SoundEntity

    @Parameter(title: "パッド", description: "1 から 16 のパッドの番号（左上が 1）", inclusiveRange: (1, 16))
    var pad: Int

    @Dependency private var library: SoundLibraryService

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = try library.sound(storageKey: sound.id)
        try library.assign(data, toSlot: pad - 1)
        return .result(dialog: "\(sound.name)をパッド\(pad)に割り当てました。")
    }
}

/// Deletes sounds after asking (Siri, Shortcuts). A `DeleteIntent`, so the
/// system knows it as "delete" rather than by its title alone.
struct DeleteSoundIntent: DeleteIntent {
    static let title: LocalizedStringResource = "サウンドを削除"
    static let description = IntentDescription("サウンドボードからサウンドを削除します。録音した音は元に戻せません。")
    static let supportedModes: IntentModes = .background
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$entities)を削除")
    }

    @Parameter(title: "サウンド")
    var entities: [SoundEntity]

    @Dependency private var library: SoundLibraryService

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Resolve everything before asking, so a missing sound fails the run
        // before anything is deleted.
        let sounds = try entities.map { try library.sound(storageKey: $0.id) }
        let names = entities.map(\.name).formatted(.list(type: .and))
        // Throws (and cancels the run) when the person declines.
        try await requestConfirmation(dialog: "\(names)を削除してよいですか？")
        for sound in sounds {
            try library.delete(sound)
        }
        return .result(dialog: "\(names)を削除しました。")
    }
}

/// The delete alert's confirm button: the alert already asked.
struct DeleteSoundNowIntent: AppIntent {
    static let title: LocalizedStringResource = "サウンドをすぐに削除"
    static let description = IntentDescription("確認せずにサウンドを削除します。")
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "サウンド")
    var sound: SoundEntity

    @Dependency private var library: SoundLibraryService

    init() {}

    init(sound: SoundEntity) {
        self.sound = sound
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try library.delete(library.sound(storageKey: sound.id))
        return .result()
    }
}

/// Opens the record panel.
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "録音を始める"
    static let description = IntentDescription("チェケラを開いて、新しいサウンドを録音する画面を出します。", searchKeywords: ["マイク", "新しい音"])
    static let supportedModes: IntentModes = .foreground(.immediate)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Dependency private var library: SoundLibraryService

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        library.isRecordingRequested = true
        return .result()
    }
}
