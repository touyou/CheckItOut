//
//  Migration.swift
//  Checkitout
//
//  First-launch seeding for fresh installs, plus a one-shot migration that
//  imports the legacy RealmSwift database into SwiftData for existing users.
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

// MARK: - Fresh-install seeding

enum SeedService {
    @MainActor
    static func seed(into context: ModelContext) {
        var index = 0
        func add(_ key: String, _ name: String, padNum: Int = -1) {
            context.insert(SoundData(storageKey: key,
                                     isBundle: true,
                                     displayName: name,
                                     padNum: padNum,
                                     sortIndex: index))
            index += 1
        }

        #if DEBUG
        add("hosaka", "保坂")
        add("kirin", "麒麟")
        add("taguchi", "しゅんぺーさん")
        add("1korekara_cut", "これから")
        add("2korekara_cut", "これから２")
        add("3apuri_cut", "アプリ")
        add("4setumei_cut", "説明")
        add("5suruze_cut", "するぜ")
        add("6onsei_cut", "音声")
        add("7rokuon_cut", "録音")
        add("8minnnawo_cut", "みんなを")
        add("9rockon_cut", "ロックオン")
        add("10korede_cut", "これで")
        add("11yourname_cut", "君の名")
        add("12todoroku_cut", "轟く")
        add("13menber_cut", "メンバー")
        add("14menta-_cut", "メンター")
        #endif

        // Default sounds, pre-assigned to pads 0/1/2 (matching the original app).
        add("touyou", "バスドラ", padNum: 0)
        add("15minnade_cut", "みんなで", padNum: 1)
        add("16chekera_cut", "チェケラ", padNum: 2)

        try? context.save()
    }
}
