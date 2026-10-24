//
//  ModeControls.swift
//  Checkitout
//
//  The brand logo and the play / edit / record controls.
//

import SwiftUI

/// The brand logo, shared by both layouts.
struct LogoView: View {
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 32)
    }
}

struct ModeControls: View {
    let mode: Mode
    let onSelect: (Mode) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 再生 / 編集 are two states of one mode → a segmented control.
            Picker("モード", selection: Binding(
                get: { mode == .edit ? Mode.edit : Mode.play },
                set: { onSelect($0) }
            )) {
                Text("再生").tag(Mode.play)
                Text("編集").tag(Mode.edit)
            }
            .pickerStyle(.segmented)
            // Lift the control off the dark background so the unselected
            // segment stays legible.
            .padding(4)
            .background(.regularMaterial, in: .rect(cornerRadius: 12))

            // 録音 opens a modal panel → kept as a distinct action button.
            Button("録音") { onSelect(.record) }
                .font(.brand(15))
                .buttonStyle(.glass)
                .tint(.red)
        }
        .frame(height: 44)
    }
}
