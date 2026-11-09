//
//  AudioEngine.swift
//  Checkitout
//
//  Native audio: session management, pad playback, and recording with a live
//  waveform derived from an AVAudioEngine input tap. Replaces EZAudio.
//

import Foundation
import AVFoundation
import Observation

// MARK: - Audio session

/// Centralizes AVAudioSession transitions with proper error handling
/// (the previous implementation force-tried these and crashed on failure).
enum AudioSessionManager {
    static func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient)
        try session.setActive(true)
    }

    static func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Pad playback

@Observable
final class PadPlayerEngine {
    /// Two players per pad, so a restart can start an idle, prepared player
    /// right away. Stopping or seeking the one that is sounding took about
    /// 10 ms longer before the sound started again.
    private var players: [PlayerPair?] = Array(repeating: nil, count: 16)

    private final class PlayerPair {
        let players: [AVAudioPlayer]
        var current = 0

        init(url: URL) throws {
            players = try (0..<2).map { _ in
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.volume = 1.0
                return player
            }
        }

        var sounding: AVAudioPlayer { players[current] }

        /// Switches to the other player and returns it.
        func swap() -> AVAudioPlayer {
            current = 1 - current
            return players[current]
        }

        func stop() {
            for player in players { player.stop() }
        }
    }

    /// Rebuilds the 16 pad players from the current sound assignments.
    func rebuild(from sounds: [SoundData]) {
        for pair in players { pair?.stop() }
        players = Array(repeating: nil, count: 16)
        try? AudioSessionManager.configureForPlayback()

        for sound in sounds where (0..<16).contains(sound.padNum) {
            guard let url = sound.resolvedURL else { continue }
            do {
                players[sound.padNum] = try PlayerPair(url: url)
            } catch {
                // Skip unplayable files rather than crashing.
                continue
            }
        }
    }

    /// Plays the pad in `slot`, restarting from the top if already playing.
    func play(slot: Int) {
        guard (0..<16).contains(slot), let pair = players[slot] else { return }
        let previous = pair.sounding
        #if DEBUG
        TapLatencyProbe.willPlay(slot: slot, player: previous)
        #endif
        let player = previous.isPlaying ? pair.swap() : previous
        let started = player.play()
        #if DEBUG
        TapLatencyProbe.didPlay(slot: slot, player: player, started: started)
        #else
        _ = started
        #endif
        if player !== previous {
            // Cut the old sound once the new one has started. stop() undoes
            // prepareToPlay(), so prepare it again for the next restart.
            DispatchQueue.main.async {
                previous.stop()
                previous.currentTime = 0
                previous.prepareToPlay()
            }
        }
    }

    func stop(slot: Int) {
        guard (0..<16).contains(slot) else { return }
        players[slot]?.stop()
        players[slot] = nil
    }
}

// MARK: - Recording

@Observable
final class Recorder {
    private(set) var isRecording = false
    private(set) var hasRecording = false
    /// Rolling amplitude samples (0...1) for the live waveform.
    private(set) var waveformSamples: [Float] = []
    var errorMessage: String?
    /// Applied to the take on preview and on save.
    var effect: VoiceEffect = .none

    private let engine = AVAudioEngine()
    private var recorder: AVAudioRecorder?
    private var previewPlayer: AVAudioPlayer?
    private let maxSamples = 256

    private var tempURL: URL { URL.temporaryDirectory.appending(path: "temp.wav") }
    private var effectURL: URL { URL.temporaryDirectory.appending(path: "temp-effect.wav") }
    /// The effect `effectURL` currently holds, so switching back and forth doesn't re-render.
    private var renderedEffect: VoiceEffect?

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func startRecording() {
        errorMessage = nil
        do {
            try AudioSessionManager.configureForRecording()

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]
            let recorder = try AVAudioRecorder(url: tempURL, settings: settings)
            recorder.prepareToRecord()
            self.recorder = recorder

            waveformSamples = []
            renderedEffect = nil
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.process(buffer: buffer)
            }
            engine.prepare()
            try engine.start()
            recorder.record()
            isRecording = true
        } catch {
            errorMessage = "録音の開始に失敗しました。マイクの使用を許可しているか確認してください。"
            teardownEngine()
        }
    }

    func stopRecording() {
        recorder?.stop()
        teardownEngine()
        isRecording = false
        hasRecording = FileManager.default.fileExists(atPath: tempURL.path)
    }

    func playPreview() {
        guard FileManager.default.fileExists(atPath: tempURL.path) else { return }
        let url: URL
        do {
            url = try processedTake()
        } catch {
            errorMessage = "エフェクトをかけられませんでした。"
            return
        }
        do {
            previewPlayer?.stop()
            let player = try AVAudioPlayer(contentsOf: url)
            previewPlayer = player
            player.play()
        } catch {
            errorMessage = "プレビューの再生に失敗しました。"
        }
    }

    /// The take with `effect` applied, rendered on demand.
    private func processedTake() throws -> URL {
        guard effect != .none else { return tempURL }
        if renderedEffect != effect {
            renderedEffect = nil
            try VoiceEffectRenderer.render(effect, from: tempURL, to: effectURL)
            renderedEffect = effect
        }
        return effectURL
    }

    /// Moves the temp recording into Documents under a filesystem-safe unique
    /// name and returns the storage key to persist. Throws on I/O failure so
    /// the caller can surface the error (the old code swallowed it).
    func commitRecording() throws -> String {
        let key = "\(UUID().uuidString).wav"
        let destination = URL.documentsDirectory.appending(path: key)
        previewPlayer?.stop()
        try FileManager.default.moveItem(at: processedTake(), to: destination)
        try? FileManager.default.removeItem(at: tempURL)
        reset()
        return key
    }

    /// Screenshot fixture only: pretends a take was just recorded, without
    /// touching the microphone or the audio session.
    func loadScreenshotFixture() {
        reset()
        waveformSamples = ScreenshotFixture.waveformSamples
        hasRecording = true
    }

    func reset() {
        previewPlayer?.stop()
        previewPlayer = nil
        effect = .none
        renderedEffect = nil
        waveformSamples = []
        hasRecording = false
        recorder = nil
    }

    private func teardownEngine() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
    }

    /// Downsamples an input buffer to a few peak-amplitude values and appends
    /// them to the rolling waveform on the main actor.
    private func process(buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let chunk = max(1, frameLength / 8)
        var peaks: [Float] = []
        var index = 0
        while index < frameLength {
            let end = min(index + chunk, frameLength)
            var peak: Float = 0
            for j in index..<end { peak = max(peak, abs(channel[j])) }
            peaks.append(min(peak, 1))
            index += chunk
        }

        let newPeaks = peaks
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.waveformSamples.append(contentsOf: newPeaks)
            if self.waveformSamples.count > self.maxSamples {
                self.waveformSamples.removeFirst(self.waveformSamples.count - self.maxSamples)
            }
        }
    }
}
