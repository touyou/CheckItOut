//
//  SoundListView.swift
//  Checkitout
//
//  The list of recorded and bundled sounds.
//

import SwiftUI
import SwiftData

struct SoundListView: View {
    let sounds: [SoundData]
    let mode: Mode
    @Binding var selectedID: PersistentIdentifier?
    let requestDelete: (SoundData) -> Void

    var body: some View {
        List(selection: $selectedID) {
            ForEach(sounds) { sound in
                SoundRow(sound: sound)
                    .tag(sound.persistentModelID)
                    .listRowBackground(Color.black.opacity(0.25))
                    .swipeActions {
                        Button("削除", role: .destructive) { requestDelete(sound) }
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(mode == .edit ? .active : .inactive))
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

struct SoundRow: View {
    let sound: SoundData

    var body: some View {
        HStack {
            Text(sound.displayName)
                .font(.brand(15))
                .foregroundStyle(.white)
            Spacer()
            Text(sound.padNum >= 0 ? "PAD \(sound.padNum + 1)" : "NONE")
                .font(.brand(13))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
