//
//  RecordPanelView.swift
//  Checkitout
//
//  The recording panel: live waveform, transport controls, title field, and
//  save. Presented as a sheet while in record mode.
//

import SwiftUI

struct RecordPanelView: View {
    @Bindable var recorder: Recorder
    let onSave: (String) -> Void
    let onClose: () -> Void

    @State private var title = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                WaveformView(samples: recorder.waveformSamples)
                    .frame(height: 96)
                    .clipShape(.rect(cornerRadius: 12))

                TextField("名前", text: $title)
                    .font(.brand(16))
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { titleFocused = false }

                GlassEffectContainer(spacing: 12) {
                    // Narrow windows (e.g. the iPhone Duo cover display) can't
                    // fit the titled buttons on one line; fall back to
                    // icon-only rather than letting the titles wrap mid-word.
                    ViewThatFits(in: .horizontal) {
                        transportButtons
                        transportButtons
                            .labelStyle(.iconOnly)
                            .controlSize(.large)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("録音")
            .navigationBarTitleDisplayMode(.inline)
            // Close and save live in the system toolbar (not in the panel
            // body) so iPhone Duo can move them to its vertical bar. Both
            // carry a title for the overflow menu and for VoiceOver.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark", role: .close) {
                        onClose()
                    }
                }
                ToolbarItem(placement: savePlacement) {
                    Button("保存", systemImage: "square.and.arrow.down", role: .confirm) {
                        onSave(title)
                        title = ""
                    }
                    .disabled(recorder.isRecording || !recorder.hasRecording)
                }
            }
        }
    }

    /// Save is the panel's prominent action: keep it pinned where available.
    private var savePlacement: ToolbarItemPlacement {
        if #available(iOS 27.0, *) {
            .topBarPinnedTrailing
        } else {
            .confirmationAction
        }
    }

    private var transportButtons: some View {
        HStack(spacing: 12) {
            TransportButton(label: "REC", symbol: "record.circle", tint: .red,
                            disabled: recorder.isRecording) {
                recorder.startRecording()
            }
            TransportButton(label: "STOP", symbol: "stop.fill",
                            disabled: !recorder.isRecording) {
                recorder.stopRecording()
            }
            TransportButton(label: "PLAY", symbol: "play.fill",
                            disabled: recorder.isRecording || !recorder.hasRecording) {
                recorder.playPreview()
            }
        }
    }
}

// MARK: - Transport button

struct TransportButton: View {
    let label: String
    let symbol: String
    var tint: Color? = nil
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.brand(14))
                .lineLimit(1)
        }
        .buttonStyle(.glass)
        .tint(tint)
        .disabled(disabled)
    }
}

// MARK: - Waveform

/// Renders the rolling amplitude samples as a centered, mirrored waveform,
/// reproducing the look of the previous EZAudioPlot.
struct WaveformView: View {
    let samples: [Float]

    var body: some View {
        Canvas { context, size in
            let mid = size.height / 2
            let count = max(samples.count, 1)
            let step = size.width / CGFloat(count)

            var path = Path()
            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) * step
                let amp = CGFloat(sample) * mid
                path.move(to: CGPoint(x: x, y: mid - amp))
                path.addLine(to: CGPoint(x: x, y: mid + amp))
            }
            context.stroke(path,
                           with: .color(.black),
                           style: StrokeStyle(lineWidth: max(step, 1), lineCap: .round))
        }
        .background(Color(red: 99 / 255, green: 102 / 255, blue: 104 / 255))
    }
}
