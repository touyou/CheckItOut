//
//  SoundData.swift
//  Checkitout
//
//  SwiftData model for a single sound (either a bundled sample or a user
//  recording). Replaces the former RealmSwift `Object` model.
//

import Foundation
import SwiftData

@Model
final class SoundData {
    /// Resolves to a bundled resource name (e.g. `"touyou"`) when `isBundle`,
    /// otherwise the *relative* filename of a recording in Documents
    /// (e.g. `"<uuid>.wav"`). Storing only the relative name — rather than an
    /// absolute URL containing the sandbox container UUID — keeps recordings
    /// resolvable across app reinstalls and updates.
    @Attribute(.unique) var storageKey: String
    var isBundle: Bool
    var displayName: String
    /// Assigned pad slot, or -1 when unassigned.
    var padNum: Int
    /// Stable ordering for the sound list (was the Realm `id`).
    var sortIndex: Int

    init(storageKey: String,
         isBundle: Bool,
         displayName: String,
         padNum: Int = -1,
         sortIndex: Int) {
        self.storageKey = storageKey
        self.isBundle = isBundle
        self.displayName = displayName
        self.padNum = padNum
        self.sortIndex = sortIndex
    }

    /// The playable file URL, resolved at runtime. Returns `nil` when the
    /// underlying file is missing (e.g. a stale metadata entry).
    var resolvedURL: URL? {
        if isBundle {
            return Bundle.main.url(forResource: storageKey, withExtension: "wav")
        }
        let url = URL.documentsDirectory.appending(path: storageKey)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
