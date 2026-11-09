//
//  ContentView.swift
//  Checkitout
//
//  The single-screen soundboard: picks the layout for the window shape and
//  owns the playback, recording, and editing actions.
//

import SwiftUI
import SwiftData
import AppIntents

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(SoundLibraryService.self) private var library
    @Query(sort: \SoundData.sortIndex) private var sounds: [SoundData]

    @AppStorage(SettingsKey.playOnTouchDown) private var playOnTouchDown = false
    @State private var mode: Mode = .play
    @State private var selectedID: PersistentIdentifier?
    @State private var padPlayer = PadPlayerEngine()
    @State private var recorder = Recorder()
    @State private var pendingDelete: SoundData?
    @State private var errorMessage: String?
    @State private var saveCount = 0
    @State private var didRun = false
    @State private var isPortrait = false
    @State private var isHingePartiallyOpen = false
    @Namespace private var layoutNamespace

    var body: some View {
        ZStack {
            // Choose the layout from the actual window shape, not the device
            // orientation: on iPadOS 26 any app can be resized into a
            // portrait- or landscape-shaped window.
            Group {
                if #available(iOS 27.1, *), isHingePartiallyOpen {
                    // iPhone Duo half-open: keep all 16 pads on one side of the
                    // fold. Only used in this posture so the regular portrait /
                    // landscape layouts stay untouched.
                    HingeSplitLayout(sounds: sounds, mode: mode, selectedID: $selectedID,
                                     onTap: tapPad, onSelectMode: switchTo,
                                     requestDelete: { pendingDelete = $0 })
                } else if isPortrait {
                    PortraitLayout(sounds: sounds, mode: mode, selectedID: $selectedID,
                                   onTap: tapPad, onSelectMode: switchTo,
                                   requestDelete: { pendingDelete = $0 })
                } else {
                    LandscapeLayout(sounds: sounds, mode: mode, selectedID: $selectedID,
                                    onTap: tapPad, onSelectMode: switchTo,
                                    requestDelete: { pendingDelete = $0 })
                }
            }
            // No crossfade between layouts; the shared pieces morph into
            // place instead (see `morphing(_:)`).
            .transition(.identity)
            .environment(\.layoutMorphNamespace, layoutNamespace)
            // Assigning a sound in edit mode stays on release, so it can
            // still be cancelled by sliding off.
            .environment(\.padsPlayOnTouchDown, playOnTouchDown && mode == .play)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Full-bleed background applied as a modifier so it can't inflate the
        // measured layout size (a `scaledToFill` image reports an oversized
        // frame, which is why measuring it inside the ZStack was unreliable).
        .background {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        // Measure the true laid-out size and reflow when the aspect flips.
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.height > proxy.size.width
        } action: { newValue in
            isPortrait = newValue
        }
        .modifier(HingeStatusObserver(isPartiallyOpen: $isHingePartiallyOpen))
        .animation(.smooth, value: mode)
        .animation(.smooth, value: isHingePartiallyOpen)
        .sensoryFeedback(.success, trigger: saveCount)
        .task {
            guard !didRun else { return }
            didRun = true
            // The screenshot fixture has already seeded its own sounds; don't
            // let first-launch seeding/migration add to them or set its flag.
            if !ScreenshotFixture.isActive && !isTapBench {
                MigrationCoordinator.runIfNeeded(context: context)
            }
            padPlayer.rebuild(from: sounds)
            CheckitoutShortcuts.updateAppShortcutParameters()
            #if DEBUG
            TapLatencyProbe.installIfNeeded()
            TapLatencyProbe.recordReady()
            TapLatencyProbe.runIntentCheckIfNeeded(container: context.container)
            #endif
        }
        // Preview and effect failures are raised by the recorder; show them in the same alert.
        .onChange(of: recorder.errorMessage) { _, message in
            guard let message else { return }
            errorMessage = message
            recorder.errorMessage = nil
        }
        .onChange(of: library.isRecordingRequested, initial: true) { _, requested in
            guard requested else { return }
            library.isRecordingRequested = false
            // Already on the record screen: keep the take in progress instead of resetting it.
            if mode != .record { switchTo(.record) }
        }
        .onChange(of: assignmentSignature) {
            if mode != .record { padPlayer.rebuild(from: sounds) }
            // Phrases with a sound name only match names Siri has fetched.
            CheckitoutShortcuts.updateAppShortcutParameters()
        }
        .alert("削除", isPresented: Binding(get: { pendingDelete != nil },
                                          set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { sound in
            // The alert is the confirmation, so it runs the intent that doesn't ask again.
            Button("削除", role: .destructive, intent: DeleteSoundNowIntent(sound: SoundEntity(sound)))
            Button("キャンセル", role: .cancel) { pendingDelete = nil }
        } message: { sound in
            Text("\(sound.displayName)を削除しますか？")
        }
        .errorAlert($errorMessage, isActive: mode != .record)
        // A system sheet rather than an overlay, so the panel gets the
        // standard dismissal (swipe down) and a real toolbar.
        .sheet(isPresented: Binding(get: { mode == .record },
                                    set: { if !$0, mode == .record { switchTo(.play) } })) {
            RecordPanelView(recorder: recorder, onSave: save(title:), onClose: { switchTo(.play) })
                .presentationDetents([.medium, .large])
                // Errors raised while recording must come from the sheet;
                // the view underneath can't present over it.
                .errorAlert($errorMessage, isActive: mode == .record)
        }
    }

    // MARK: Actions

    private var isTapBench: Bool {
        #if DEBUG
        TapLatencyProbe.isActive
        #else
        false
        #endif
    }

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
        if target == .record, ScreenshotFixture.isActive {
            // Show a finished take instead of asking for the microphone, so
            // no permission alert covers the screenshot.
            recorder.loadScreenshotFixture()
        } else if target == .record {
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
        // The pads take a custom press, not a Button, so this calls the service the
        // Assign Sound to Pad intent uses rather than the intent itself.
        do {
            try library.assign(selected, toSlot: slot)
        } catch {
            errorMessage = "パッドに割り当てられませんでした。"
        }
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
            // Closing the panel is the confirmation: the new sound shows up
            // in the list behind it.
            saveCount += 1
            switchTo(.play)
        } catch {
            errorMessage = "セーブに失敗しました。"
        }
    }

}

extension View {
    /// Shows `message` as an alert while `isActive`, clearing it on dismiss.
    fileprivate func errorAlert(_ message: Binding<String?>, isActive: Bool) -> some View {
        alert("エラー", isPresented: Binding(get: { isActive && message.wrappedValue != nil },
                                           set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

/// Reports whether the device hinge is partially open. No-op before iOS 27.1
/// and on devices without a hinge.
private struct HingeStatusObserver: ViewModifier {
    @Binding var isPartiallyOpen: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, newContext in
                isPartiallyOpen = newContext.hinge?.status == .partiallyOpen
            }
        } else {
            content
        }
    }
}
