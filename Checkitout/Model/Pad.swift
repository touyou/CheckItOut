//
//  Pad.swift
//  Checkitout
//
//  The 16 pads of the grid and their colors.
//

import Foundation

enum PadColor {
    case red, yellow, green, blue

    var image: String {
        switch self {
        case .red: "Redpad"
        case .yellow: "Yellowpad"
        case .green: "Greenpad"
        case .blue: "Bluepad"
        }
    }

    var selectedImage: String {
        switch self {
        case .red: "SelectedRedpad"
        case .yellow: "SelectedYellowpad"
        case .green: "SelectedGreenpad"
        case .blue: "SelectedBluepad"
        }
    }
}

struct Pad: Identifiable {
    let id: Int      // display position 0...15
    let slot: Int    // assignment index (preserves the original button tags)
    let color: PadColor
}

/// The 16 pads in display order, using a natural slot mapping (PAD01→slot 0 …
/// PAD16→slot 15) so a sound's pad label matches its on-screen position.
/// (The original storyboard used quirky tags where PAD16 was 0; legacy data is
/// remapped to this scheme during migration — see RealmMigrationReader.)
let pads: [Pad] = {
    let colors: [PadColor] = [.red, .yellow, .green, .blue]
    return (0..<16).map { i in
        Pad(id: i, slot: i, color: colors[i / 4])
    }
}()
