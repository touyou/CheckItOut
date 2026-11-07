//
//  SoundLibraryIntents.swift
//  Checkitout
//
//  Editing the board from Siri and Shortcuts. The delete alert runs
//  `DeleteSoundNowIntent` because a confirmation from an in-app button has
//  nowhere to appear; Siri and Shortcuts get the asking `DeleteSoundIntent`.
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

/// Deletes a sound after asking (Siri, Shortcuts).
struct DeleteSoundIntent: AppIntent {
    static let title: LocalizedStringResource = "サウンドを削除"
    static let description = IntentDescription("サウンドボードからサウンドを削除します。録音した音は元に戻せません。")
    static let supportedModes: IntentModes = .background
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$sound)を削除")
    }

    @Parameter(title: "サウンド")
    var sound: SoundEntity

    @Dependency private var library: SoundLibraryService

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        // Throws (and cancels the run) when the person declines.
        try await requestConfirmation(dialog: "\(sound.name)を削除しますか？")
        try library.delete(library.sound(storageKey: sound.id))
        return .result()
    }
}

/// The delete alert's confirm button: the alert already asked.
struct DeleteSoundNowIntent: AppIntent {
    static let title: LocalizedStringResource = "サウンドをすぐに削除"
    static let description = IntentDescription("確認せずにサウンドを削除します。")
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background
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
    static let description = IntentDescription("チェケラを開いて、新しいサウンドを録音する画面を出します。", searchKeywords: ["録音", "マイク", "新しい音"])
    static let supportedModes: IntentModes = .foreground(.immediate)
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Dependency private var library: SoundLibraryService

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        library.isRecordingRequested = true
        return .result()
    }
}
