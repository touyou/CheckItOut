//
//  ContentView.swift
//  Checkitout
//
//  The single-screen soundboard: header mode switch, sound list, and the
//  4x4 pad grid, plus the recording panel overlay.
//

import SwiftUI
import SwiftData

// MARK: - Pad model

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

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SoundData.sortIndex) private var sounds: [SoundData]

    @State private var mode: Mode = .play
    @State private var selectedID: PersistentIdentifier?
    @State private var padPlayer = PadPlayerEngine()
    @State private var recorder = Recorder()
    @State private var pendingDelete: SoundData?
    @State private var errorMessage: String?
    @State private var didRun = false

    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HeaderView(mode: mode, onSelect: switchTo)

                HStack(spacing: 12) {
                    SoundListView(sounds: sounds,
                                  mode: mode,
                                  selectedID: $selectedID,
                                  requestDelete: { pendingDelete = $0 })
                        .frame(maxWidth: 260)

                    PadGridView(sounds: sounds, onTap: tapPad)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)

            if mode == .record {
                RecordPanelView(recorder: recorder, onSave: save(title:), onClose: { switchTo(.play) })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: mode)
        .task {
            guard !didRun else { return }
            didRun = true
            MigrationCoordinator.runIfNeeded(context: context)
            padPlayer.rebuild(from: sounds)
        }
        .onChange(of: assignmentSignature) {
            if mode != .record { padPlayer.rebuild(from: sounds) }
        }
        .alert("削除", isPresented: Binding(get: { pendingDelete != nil },
                                          set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { sound in
            Button("削除", role: .destructive) { delete(sound) }
            Button("キャンセル", role: .cancel) { pendingDelete = nil }
        } message: { sound in
            Text("\(sound.displayName)を削除しますか？")
        }
        .alert("エラー", isPresented: Binding(get: { errorMessage != nil },
                                           set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Actions

    private var assignmentSignature: String {
        sounds.map { "\($0.padNum):\($0.storageKey)" }.joined(separator: "|")
    }

    private func switchTo(_ target: Mode) {
        // Leaving record mode mid-recording must stop the engine/mic tap.
        if mode == .record, target != .record, recorder.isRecording {
            recorder.stopRecording()
        }
        mode = target
        if target != .edit { selectedID = nil }
        if target == .play { padPlayer.rebuild(from: sounds) }
        if target == .record {
            recorder.reset()
            Task {
                let granted = await recorder.requestPermission()
                if !granted {
                    errorMessage = "マイクの使用が許可されていません。設定から許可してください。"
                }
            }
        }
    }

    private func tapPad(_ slot: Int) {
        switch mode {
        case .play:
            padPlayer.play(slot: slot)
        case .edit:
            assignSelected(toSlot: slot)
        case .record:
            break
        }
    }

    private func assignSelected(toSlot slot: Int) {
        guard let selectedID,
              let selected = sounds.first(where: { $0.persistentModelID == selectedID }) else { return }
        // Free any sound currently occupying this pad.
        if let occupant = sounds.first(where: { $0.padNum == slot }) {
            occupant.padNum = -1
        }
        selected.padNum = slot
        try? context.save()
        self.selectedID = nil
    }

    private func save(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "名前を設定してください。"
            return
        }
        do {
            let key = try recorder.commitRecording()
            let sound = SoundData(storageKey: key,
                                  isBundle: false,
                                  displayName: trimmed,
                                  sortIndex: (sounds.map(\.sortIndex).max() ?? 0) + 1)
            context.insert(sound)
            try context.save()
        } catch {
            errorMessage = "セーブに失敗しました。"
        }
    }

    private func delete(_ sound: SoundData) {
        if (0..<16).contains(sound.padNum) {
            padPlayer.stop(slot: sound.padNum)
        }
        // Remove the underlying recording file so it doesn't orphan.
        if !sound.isBundle, let url = sound.resolvedURL {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(sound)
        try? context.save()
        pendingDelete = nil
    }
}

// MARK: - Header

struct HeaderView: View {
    let mode: Mode
    let onSelect: (Mode) -> Void

    var body: some View {
        HStack {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 32)

            Spacer()

            // 再生 / 編集 are two states of one mode → a segmented control.
            Picker("モード", selection: Binding(
                get: { mode == .edit ? Mode.edit : Mode.play },
                set: { onSelect($0) }
            )) {
                Text("再生").tag(Mode.play)
                Text("編集").tag(Mode.edit)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            // Lift the control off the dark background so the unselected
            // segment stays legible.
            .padding(4)
            .background(.regularMaterial, in: .rect(cornerRadius: 12))

            // 録音 opens a modal panel → kept as a distinct action button.
            Button("録音") { onSelect(.record) }
                .font(.brand(15))
                .buttonStyle(.glass)
                .tint(mode == .record ? .accentColor : nil)
        }
        .frame(height: 44)
    }
}

// MARK: - Pad grid

struct PadGridView: View {
    let sounds: [SoundData]
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            // Size pads so all 16 fit within both the available width and
            // height (landscape height is the tight constraint).
            let dim = max(1, min((geo.size.width - spacing * 3) / 4,
                                 (geo.size.height - spacing * 3) / 4))
            let columns = Array(repeating: GridItem(.fixed(dim), spacing: spacing), count: 4)
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(pads) { pad in
                    PadButton(pad: pad,
                              assignedName: sounds.first { $0.padNum == pad.slot }?.displayName) {
                        onTap(pad.slot)
                    }
                    .frame(width: dim, height: dim)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Sound list

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

// MARK: - Pad button

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
