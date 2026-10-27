//
//  SoundEntity.swift
//  Checkitout
//
//  A soundboard sound as the system sees it, so Siri and Shortcuts can name
//  the sound to play. Backed by `SoundData`; the id is its `storageKey`.
//

import AppIntents
import SwiftData

struct SoundEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "サウンド"
    static let defaultQuery = SoundEntityQuery()

    let id: String
    let name: String
    /// Assigned pad slot, or nil when the sound is not on a pad.
    let padSlot: Int?

    var displayRepresentation: DisplayRepresentation {
        if let padSlot {
            // `"\(…)"` rather than `LocalizedStringResource(stringLiteral:)`:
            // a user-chosen name must not become a localization key.
            DisplayRepresentation(title: "\(name)", subtitle: "PAD \(padSlot + 1)")
        } else {
            DisplayRepresentation(title: "\(name)")
        }
    }

    init(_ sound: SoundData) {
        id = sound.storageKey
        name = sound.displayName
        padSlot = (0..<16).contains(sound.padNum) ? sound.padNum : nil
    }
}

struct SoundEntityQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    @MainActor
    func entities(for identifiers: [SoundEntity.ID]) async throws -> [SoundEntity] {
        let keys = Set(identifiers)
        return try allSounds().filter { keys.contains($0.storageKey) }.map(SoundEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [SoundEntity] {
        try allSounds()
            .filter { $0.displayName.localizedStandardContains(string) }
            .map(SoundEntity.init)
    }

    /// Sounds on a pad come first, in pad order: those are the ones people
    /// actually play, and Siri matches spoken names against this list.
    @MainActor
    func suggestedEntities() async throws -> [SoundEntity] {
        try allSounds()
            .sorted { lhs, rhs in
                let l = (0..<16).contains(lhs.padNum) ? lhs.padNum : Int.max
                let r = (0..<16).contains(rhs.padNum) ? rhs.padNum : Int.max
                return l == r ? lhs.sortIndex < rhs.sortIndex : l < r
            }
            .map(SoundEntity.init)
    }

    @MainActor
    private func allSounds() throws -> [SoundData] {
        try container.mainContext.fetch(FetchDescriptor<SoundData>(sortBy: [SortDescriptor(\.sortIndex)]))
    }
}
