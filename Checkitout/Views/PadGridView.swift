//
//  PadGridView.swift
//  Checkitout
//
//  The 4x4 pad grid.
//

import SwiftUI
import SwiftData

struct PadGridView: View {
    let sounds: [SoundData]
    let onTap: (Int) -> Void

    var body: some View {
        // A non-lazy Grid: lazy containers create cells on demand and fade
        // them in, which breaks the morph between layouts.
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<4, id: \.self) { row in
                GridRow {
                    ForEach(pads[(row * 4)..<(row * 4 + 4)]) { pad in
                        PadButton(pad: pad,
                                  assignedName: sounds.first { $0.padNum == pad.slot }?.displayName) {
                            onTap(pad.slot)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        // Keep the whole grid square so all 16 pads fit within both the
        // available width and height. Pads are flexible rather than a fixed
        // size, so they track the square smoothly while it morphs.
        .aspectRatio(1, contentMode: .fit)
        .morphing(.pads)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PadButton: View {
    let pad: Pad
    let assignedName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let assignedName {
                        Text(assignedName)
                            .font(.brand(11))
                            .foregroundStyle(.white)
                            .padding(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
        }
        .buttonStyle(PadButtonStyle(pad: pad))
    }
}

private struct PadButtonStyle: ButtonStyle {
    let pad: Pad

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Image(configuration.isPressed ? pad.color.selectedImage : pad.color.image)
                    .resizable()
                    .scaledToFit()
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
