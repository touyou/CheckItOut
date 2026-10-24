//
//  Migration.swift
//  Checkitout
//
//  A one-shot migration that imports the legacy RealmSwift database into
//  SwiftData for existing users (fresh installs are seeded by SeedService).
//
//  NOTE: RealmSwift is retained *only* for this transitional migration path.
//  Once the installed base has migrated it (and the `didMigrate` flag) can be
//  removed, leaving the app free of third-party dependencies.
//

import Foundation
import SwiftData
import RealmSwift

// MARK: - Coordinator

enum MigrationCoordinator {
    private static let didMigrateKey = "didMigrateRealmToSwiftData"

    /// Runs exactly once. Imports legacy Realm data if present, otherwise
    /// seeds the bundled sounds for a fresh install.
    @MainActor
    static func runIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didMigrateKey) else { return }

        let legacy = RealmMigrationReader.readLegacySounds()
        if legacy.isEmpty {
            SeedService.seed(into: context)
        } else {
            for item in legacy {
                context.insert(SoundData(storageKey: item.storageKey,
                                         isBundle: item.isBundle,
                                         displayName: item.displayName,
                                         padNum: item.padNum,
                                         sortIndex: item.sortIndex))
            }
            try? context.save()
        }

        defaults.set(true, forKey: didMigrateKey)
        RealmMigrationReader.cleanupLegacyFiles()
    }
}

// MARK: - Legacy Realm reader

struct LegacySound {
    let storageKey: String
    let isBundle: Bool
    let displayName: String
    let padNum: Int
    let sortIndex: Int
}

enum RealmMigrationReader {
    /// Reads the old `SoundData` objects dynamically inside a Realm migration
    /// block. This requires no typed model class (avoiding a name clash with
    /// the new SwiftData `SoundData`) and opens read-write so the latest Realm
    /// SDK can upgrade the legacy file format before enumerating.
    static func readLegacySounds() -> [LegacySound] {
        guard let fileURL = Realm.Configuration.defaultConfiguration.fileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        var collected: [LegacySound] = []
        let config = Realm.Configuration(
            fileURL: fileURL,
            schemaVersion: 2,
            migrationBlock: { migration, _ in
                migration.enumerateObjects(ofType: "SoundData") { oldObject, _ in
                    guard let old = oldObject else { return }
                    let isBundle = (old["isBundle"] as? Bool) ?? false
                    let urlStr = (old["urlStr"] as? String) ?? ""
                    let displayName = (old["displayName"] as? String) ?? ""
                    let id = (old["id"] as? Int) ?? 0

                    // Legacy pad slots used the storyboard tags where PAD16 was
                    // 0 and PAD01…PAD15 were 1…15. Remap to the natural scheme
                    // (PAD01→0 … PAD16→15) so sounds stay on the same physical
                    // pad while the label now matches the position.
                    let rawPad = (old["padNum"] as? Int) ?? -1
                    let padNum = rawPad < 0 ? -1 : (rawPad == 0 ? 15 : rawPad - 1)

                    // Bundled sounds store a bare resource name; recordings
                    // stored an absolute file URL — normalize to just the name.
                    let key = isBundle ? urlStr : (urlStr.components(separatedBy: "/").last ?? urlStr)
                    collected.append(LegacySound(storageKey: key,
                                                 isBundle: isBundle,
                                                 displayName: displayName,
                                                 padNum: padNum,
                                                 sortIndex: id))
                }
            }
        )

        // Opening triggers the file-format upgrade and runs the migration block
        // synchronously, populating `collected`.
        _ = try? Realm(configuration: config)
        return collected.sorted { $0.sortIndex < $1.sortIndex }
    }

    static func cleanupLegacyFiles() {
        guard let fileURL = Realm.Configuration.defaultConfiguration.fileURL else { return }
        let manager = FileManager.default
        for suffix in ["", ".lock", ".note", ".management"] {
            try? manager.removeItem(atPath: fileURL.path + suffix)
        }
    }
}
