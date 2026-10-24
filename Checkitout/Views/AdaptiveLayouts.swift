//
//  AdaptiveLayouts.swift
//  Checkitout
//
//  Portrait, landscape, and iPhone Duo half-open layouts, and the morph that
//  moves the shared pieces between them.
//

import SwiftUI
import SwiftData

/// Landscape / wide windows: pad grid on the left, a narrow right column with
/// the logo, sound list, and mode controls.
struct LandscapeLayout: View {
    let sounds: [SoundData]
    let mode: Mode
    @Binding var selectedID: PersistentIdentifier?
    let onTap: (Int) -> Void
    let onSelectMode: (Mode) -> Void
    let requestDelete: (SoundData) -> Void

    var body: some View {
        HStack(spacing: 12) {
            PadGridView(sounds: sounds, onTap: onTap)

            VStack(spacing: 12) {
                LogoView()
                    .morphing(.logo)
                SoundListView(sounds: sounds, mode: mode,
                              selectedID: $selectedID, requestDelete: requestDelete)
                    .morphing(.list)
                ModeControls(mode: mode, onSelect: onSelectMode)
                    .morphing(.controls)
            }
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
    }
}

/// Portrait / tall windows: everything stacked vertically so nothing is pushed
/// off the edge (the App Store review case on iPad Air 11").
struct PortraitLayout: View {
    let sounds: [SoundData]
    let mode: Mode
    @Binding var selectedID: PersistentIdentifier?
    let onTap: (Int) -> Void
    let onSelectMode: (Mode) -> Void
    let requestDelete: (SoundData) -> Void

    var body: some View {
        VStack(spacing: 16) {
            LogoView()
                .morphing(.logo)
            PadGridView(sounds: sounds, onTap: onTap)
            SoundListView(sounds: sounds, mode: mode,
                          selectedID: $selectedID, requestDelete: requestDelete)
                .frame(maxHeight: 240)
                .morphing(.list)
            ModeControls(mode: mode, onSelect: onSelectMode)
                .morphing(.controls)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
    }
}

/// iPhone Duo half-open: the pad grid fills one side of the fold and the
/// logo, sound list, and mode controls go on the other.
@available(iOS 27.1, *)
struct HingeSplitLayout: View {
    let sounds: [SoundData]
    let mode: Mode
    @Binding var selectedID: PersistentIdentifier?
    let onTap: (Int) -> Void
    let onSelectMode: (Mode) -> Void
    let requestDelete: (SoundData) -> Void

    var body: some View {
        ArrangementView {
            PadGridView(sounds: sounds, onTap: onTap)
                .padding(20)
        } secondary: {
            HingeControlsPane(sounds: sounds, mode: mode, selectedID: $selectedID,
                              onSelectMode: onSelectMode, requestDelete: requestDelete)
                .padding(20)
        }
        .arrangementViewStyle(.split)
    }
}

/// The non-pad side of the fold. The split can end up side by side or
/// stacked, so lay out from the pane's own shape instead of assuming one.
@available(iOS 27.1, *)
private struct HingeControlsPane: View {
    let sounds: [SoundData]
    let mode: Mode
    @Binding var selectedID: PersistentIdentifier?
    let onSelectMode: (Mode) -> Void
    let requestDelete: (SoundData) -> Void

    @State private var isWide = false

    var body: some View {
        Group {
            if isWide {
                // Short, wide pane: list on the left, logo + controls on the right.
                HStack(spacing: 12) {
                    SoundListView(sounds: sounds, mode: mode,
                                  selectedID: $selectedID, requestDelete: requestDelete)
                        .morphing(.list)
                    VStack(spacing: 12) {
                        LogoView()
                            .morphing(.logo)
                        Spacer(minLength: 0)
                        ModeControls(mode: mode, onSelect: onSelectMode)
                            .morphing(.controls)
                    }
                    .frame(maxWidth: 260)
                }
            } else {
                VStack(spacing: 12) {
                    LogoView()
                        .morphing(.logo)
                    SoundListView(sounds: sounds, mode: mode,
                                  selectedID: $selectedID, requestDelete: requestDelete)
                        .morphing(.list)
                    ModeControls(mode: mode, onSelect: onSelectMode)
                        .morphing(.controls)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height
        } action: { newValue in
            isWide = newValue
        }
    }
}

/// The pieces every layout shares, matched across layout switches so they
/// glide to their new frames instead of crossfading.
enum LayoutPiece: Hashable {
    case logo, pads, list, controls
}

extension EnvironmentValues {
    @Entry var layoutMorphNamespace: Namespace.ID?
}

private struct MorphingModifier: ViewModifier {
    let piece: LayoutPiece
    @Environment(\.layoutMorphNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: piece, in: namespace)
        } else {
            content
        }
    }
}

extension View {
    /// Ties this piece to its counterpart in the other layouts.
    func morphing(_ piece: LayoutPiece) -> some View {
        modifier(MorphingModifier(piece: piece))
    }
}
