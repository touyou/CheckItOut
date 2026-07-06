//
//  RecordPanelView.swift
//  Checkitout
//
//  The recording panel: live waveform, transport controls, title field, and
//  save. Presented as a floating Liquid Glass panel while in record mode.
//

import SwiftUI

struct RecordPanelView: View {
    @Bindable var recorder: Recorder
    let onSave: (String) -> Void
    let onClose: () -> Void

    @State private var title = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("録音")
                    .font(.brand(18))
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
            }

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
                HStack(spacing: 12) {
                    transportButton("REC", "record.circle", tint: .red,
                                    disabled: recorder.isRecording) {
                        recorder.startRecording()
                    }
                    transportButton("STOP", "stop.fill",
                                    disabled: !recorder.isRecording) {
                        recorder.stopRecording()
                    }
                    transportButton("PLAY", "play.fill",
                                    disabled: recorder.isRecording || !recorder.hasRecording) {
                        recorder.playPreview()
                    }
                    transportButton("SAVE", "square.and.arrow.down",
                                    disabled: recorder.isRecording || !recorder.hasRecording) {
                        onSave(title)
                        title = ""
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 460)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func transportButton(_ label: String,
                                 _ symbol: String,
                                 tint: Color? = nil,
                                 disabled: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.brand(14))
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
