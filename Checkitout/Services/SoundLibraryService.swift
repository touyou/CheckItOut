//
//  SoundLibraryService.swift
//  Checkitout
//
//  Assigning and deleting sounds. The edit-mode pads, the delete alert and the
//  intents all go through here, so Siri and the screen change the board the
//  same way.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SoundLibraryService {
    private let container: ModelContainer
    /// A recording requested by an intent; the soundboard opens the record panel and clears it.
    var isRecordingRequested = false

    init(container: ModelContainer) {
        self.container = container
    }

    private var context: ModelContext { container.mainContext }

    func sound(storageKey: String) throws -> SoundData {
        let descriptor = FetchDescriptor<SoundData>(predicate: #Predicate { $0.storageKey == storageKey })
        guard let sound = try context.fetch(descriptor).first else {
            throw SoundLibraryError.notFound
        }
        return sound
    }

    /// Puts `sound` on `slot` (0-based), freeing whatever was there.
    func assign(_ sound: SoundData, toSlot slot: Int) throws {
        guard (0..<16).contains(slot) else { throw SoundLibraryError.invalidPad }
        let all = try context.fetch(FetchDescriptor<SoundData>())
        for occupant in all where occupant.padNum == slot && occupant !== sound {
            occupant.padNum = -1
        }
        sound.padNum = slot
        try context.save()
    }

    /// Deletes the sound and, for a recording, its file so it doesn't orphan.
    func delete(_ sound: SoundData) throws {
        if !sound.isBundle, let url = sound.resolvedURL {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(sound)
        try context.save()
    }
}

enum SoundLibraryError: Error, CustomLocalizedStringResourceConvertible {
    case notFound
    case invalidPad

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound: "サウンドが見つかりません。削除された可能性があります。"
        case .invalidPad: "パッドの番号は 1 から 16 で指定してください。"
        }
    }
}
