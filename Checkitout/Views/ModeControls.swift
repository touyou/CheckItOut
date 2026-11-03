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

    @AppStorage(SettingsKey.playOnTouchDown) private var playOnTouchDown = false

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
            .accessibilityIdentifier("modePicker")
            // Lift the control off the dark background so the unselected
            // segment stays legible.
            .padding(4)
            .background(.regularMaterial, in: .rect(cornerRadius: 12))

            // 録音 opens a modal panel → kept as a distinct action button.
            Button("録音") { onSelect(.record) }
                .accessibilityIdentifier("recordButton")
                .font(.brand(15))
                .buttonStyle(.glass)
                .tint(.red)

            // The app's only setting, so a menu rather than a settings screen.
            Menu {
                Toggle(isOn: $playOnTouchDown) {
                    Text("触れた瞬間に鳴らす")
                    Text("オフのときは指を離すと鳴り、ずらすと取り消せます")
                }
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("設定")
            .accessibilityIdentifier("settingsMenu")
            .buttonStyle(.glass)
        }
        .frame(height: 44)
    }
}
