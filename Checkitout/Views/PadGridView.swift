//
//  PadGridView.swift
//  Checkitout
//
//  The 4x4 pad grid.
//

import SwiftUI
import SwiftData
import UIKit.UIGestureRecognizerSubclass

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
        #if DEBUG
        .tapBenchTwoFingerTarget()
        #endif
        .morphing(.pads)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PadButton: View {
    let pad: Pad
    let assignedName: String?
    let action: () -> Void

    @Environment(\.padsPlayOnTouchDown) private var playsOnTouchDown

    var body: some View {
        Group {
            if playsOnTouchDown {
                TouchDownPad(pad: pad, action: action) { label }
            } else {
                // Fires on release, so sliding off the pad cancels the press.
                Button(action: action) { label }
                    .buttonStyle(PadButtonStyle(pad: pad))
            }
        }
        .accessibilityIdentifier("pad-\(pad.slot)")
    }

    private var label: some View {
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
}

extension EnvironmentValues {
    /// Pads fire as soon as a finger touches them (the "play on touch"
    /// setting, play mode only) instead of on release.
    @Entry var padsPlayOnTouchDown = false
}

/// A pad that fires the moment a finger lands on it. Each pad tracks its own
/// touch, so several pads can be hit at once. VoiceOver activates it like a
/// button.
private struct TouchDownPad<Label: View>: View {
    let pad: Pad
    let action: () -> Void
    @ViewBuilder let label: Label

    @State private var isPressed = false

    var body: some View {
        PadFace(pad: pad, isPressed: isPressed) { label }
            .contentShape(.rect)
            // A UIKit recognizer rather than `DragGesture(minimumDistance: 0)`,
            // which only reported the touch around the time the finger lifted.
            .gesture(TouchDownGesture(isPressed: $isPressed, onTouchDown: action))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

private struct TouchDownGesture: UIGestureRecognizerRepresentable {
    @Binding var isPressed: Bool
    let onTouchDown: () -> Void

    func makeUIGestureRecognizer(context: Context) -> TouchDownRecognizer {
        TouchDownRecognizer()
    }

    func handleUIGestureRecognizerAction(_ recognizer: TouchDownRecognizer, context: Context) {
        switch recognizer.state {
        case .began:
            isPressed = true
            onTouchDown()
        case .ended, .cancelled, .failed:
            isPressed = false
        default:
            break
        }
    }
}

/// Begins on the first touch (no movement or delay needed) and ends when the
/// last finger lifts.
private final class TouchDownRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible { state = .began }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if numberOfTouches == touches.count { state = .ended }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

/// The pad image, swapped and shrunk while pressed. Shared by both pad kinds
/// so they look the same.
private struct PadFace<Content: View>: View {
    let pad: Pad
    let isPressed: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                Image(isPressed ? pad.color.selectedImage : pad.color.image)
                    .resizable()
                    .scaledToFit()
            )
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

private struct PadButtonStyle: ButtonStyle {
    let pad: Pad

    func makeBody(configuration: Configuration) -> some View {
        PadFace(pad: pad, isPressed: configuration.isPressed) { configuration.label }
    }
}
