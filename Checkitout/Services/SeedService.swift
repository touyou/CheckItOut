//
//  SeedService.swift
//  Checkitout
//
//  The bundled sounds a fresh install starts with.
//

import Foundation
import SwiftData

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
