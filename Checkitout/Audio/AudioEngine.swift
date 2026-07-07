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
    private var players: [AVAudioPlayer?] = Array(repeating: nil, count: 16)

    /// Rebuilds the 16 pad players from the current sound assignments.
    func rebuild(from sounds: [SoundData]) {
        for player in players { player?.stop() }
        players = Array(repeating: nil, count: 16)
        try? AudioSessionManager.configureForPlayback()

        for sound in sounds where (0..<16).contains(sound.padNum) {
            guard let url = sound.resolvedURL else { continue }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.volume = 1.0
                players[sound.padNum] = player
            } catch {
                // Skip unplayable files rather than crashing.
                continue
            }
        }
    }

    /// Plays the pad in `slot`, restarting from the top if already playing.
    func play(slot: Int) {
        guard (0..<16).contains(slot), let player = players[slot] else { return }
        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
        player.play()
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

    private let engine = AVAudioEngine()
    private var recorder: AVAudioRecorder?
    private var previewPlayer: AVAudioPlayer?
    private let maxSamples = 256

    private var tempURL: URL { URL.temporaryDirectory.appending(path: "temp.wav") }

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
        do {
            let player = try AVAudioPlayer(contentsOf: tempURL)
            previewPlayer = player
            player.play()
        } catch {
            errorMessage = "プレビューの再生に失敗しました。"
        }
    }

    /// Moves the temp recording into Documents under a filesystem-safe unique
    /// name and returns the storage key to persist. Throws on I/O failure so
    /// the caller can surface the error (the old code swallowed it).
    func commitRecording() throws -> String {
        let key = "\(UUID().uuidString).wav"
        let destination = URL.documentsDirectory.appending(path: key)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        reset()
        return key
    }

    func reset() {
        previewPlayer?.stop()
        previewPlayer = nil
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
