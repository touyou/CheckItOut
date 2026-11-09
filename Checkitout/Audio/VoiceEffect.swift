//
//  VoiceEffect.swift
//  Checkitout
//
//  Effects for a fresh recording. They are rendered into the saved file, so
//  pad playback keeps using plain AVAudioPlayer and its tap latency.
//

import AVFoundation
import SwiftUI

enum VoiceEffect: String, CaseIterable, Identifiable {
    case none
    case high
    case low
    case fast
    case slow
    case echo
    case hall

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .none: "そのまま"
        case .high: "高い声"
        case .low: "低い声"
        case .fast: "早回し"
        case .slow: "スロー"
        case .echo: "エコー"
        case .hall: "ホール"
        }
    }

    var symbol: String {
        switch self {
        case .none: "waveform"
        case .high: "arrow.up"
        case .low: "arrow.down"
        case .fast: "hare"
        case .slow: "tortoise"
        case .echo: "dot.radiowaves.right"
        case .hall: "building.columns"
        }
    }

    /// Pitch shift in cents.
    fileprivate var pitch: Float {
        switch self {
        case .high: 700
        case .low: -600
        default: 0
        }
    }

    /// Playback rate; the length of the result is divided by it.
    fileprivate var rate: Float {
        switch self {
        case .fast: 1.5
        case .slow: 0.7
        default: 1
        }
    }

    /// Extra time rendered after the source ends, so echoes and reverb fade out instead of being cut.
    fileprivate var tailSeconds: Double {
        switch self {
        case .echo: 1.5
        case .hall: 2.5
        default: 0
        }
    }

    fileprivate func makeTailUnit() -> AVAudioUnit? {
        switch self {
        case .echo:
            let delay = AVAudioUnitDelay()
            delay.delayTime = 0.22
            delay.feedback = 45
            delay.wetDryMix = 35
            return delay
        case .hall:
            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(.largeHall)
            reverb.wetDryMix = 35
            return reverb
        default:
            return nil
        }
    }
}

enum VoiceEffectRenderer {
    enum RenderError: Error {
        case unsupportedFormat
        case renderFailed
    }

    /// Renders `source` through `effect` into a 16-bit stereo WAV at `destination`.
    static func render(_ effect: VoiceEffect, from source: URL, to destination: URL) throws {
        let file = try AVAudioFile(forReading: source)
        let sampleRate = file.processingFormat.sampleRate
        guard let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw RenderError.unsupportedFormat
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        // The effects get a fixed stereo format; this mixer upmixes the mono recording into it.
        let upmix = AVAudioMixerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.pitch = effect.pitch
        timePitch.rate = effect.rate

        engine.attach(player)
        engine.attach(upmix)
        engine.attach(timePitch)
        engine.connect(player, to: upmix, format: file.processingFormat)
        engine.connect(upmix, to: timePitch, format: stereo)
        var last: AVAudioNode = timePitch
        if let tail = effect.makeTailUnit() {
            engine.attach(tail)
            engine.connect(last, to: tail, format: stereo)
            last = tail
        }
        engine.connect(last, to: engine.mainMixerNode, format: stereo)

        try engine.enableManualRenderingMode(.offline, format: stereo, maximumFrameCount: 4096)
        try engine.start()
        defer {
            player.stop()
            engine.stop()
        }
        player.scheduleFile(file, at: nil)
        player.play()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        try? FileManager.default.removeItem(at: destination)
        let output = try AVAudioFile(forWriting: destination, settings: settings,
                                     commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                            frameCapacity: engine.manualRenderingMaximumFrameCount) else {
            throw RenderError.renderFailed
        }

        let total = AVAudioFramePosition(Double(file.length) / Double(effect.rate)
                                         + effect.tailSeconds * sampleRate)
        while engine.manualRenderingSampleTime < total {
            let remaining = total - engine.manualRenderingSampleTime
            let frames = AVAudioFrameCount(min(remaining, AVAudioFramePosition(buffer.frameCapacity)))
            switch try engine.renderOffline(frames, to: buffer) {
            case .success:
                try output.write(from: buffer)
            case .insufficientDataFromInputNode, .cannotDoInCurrentContext, .error:
                // Offline rendering with no input node shouldn't return these; bail out rather than spin.
                throw RenderError.renderFailed
            @unknown default:
                throw RenderError.renderFailed
            }
        }
    }
}
