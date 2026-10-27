//
//  SoundPlaybackService.swift
//  Checkitout
//
//  One-shot playback for intents. Unlike `PadPlayerEngine` it waits for the
//  sound to finish, so the intent's run (and Siri's UI) lasts as long as
//  the sound.
//

import AVFoundation
import Foundation

enum SoundPlaybackError: Error, CustomLocalizedStringResourceConvertible {
    case missingFile(String)
    case unplayable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .missingFile(let name): "「\(name)」の音声ファイルが見つかりません。"
        case .unplayable: "音声を再生できませんでした。"
        }
    }
}

@MainActor
final class SoundPlaybackService {
    private var player: AVAudioPlayer?
    /// Session state from before the first overlapping call. Only the latest
    /// call restores it, so an earlier call finishing can't flip the session
    /// back while a newer sound is still playing.
    private var savedSession: (category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions)?
    private var generation = 0

    /// Upper bound on how long an intent keeps the process alive for one sound.
    private let maxWait: Duration = .seconds(30)

    func playToEnd(_ url: URL) async throws {
        player?.stop()
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw SoundPlaybackError.unplayable
        }
        generation += 1
        let myGeneration = generation
        self.player = player
        // `.ambient` (the pads' category) is silenced by the ring/silent switch,
        // so intents use `.playback`, then restore whatever was set before
        // (it may be `.playAndRecord` if the record panel is open).
        let session = AVAudioSession.sharedInstance()
        if savedSession == nil {
            savedSession = (session.category, session.categoryOptions)
        }
        defer {
            if generation == myGeneration {
                if let saved = savedSession {
                    try? session.setCategory(saved.category, options: saved.options)
                }
                savedSession = nil
                self.player = nil
            }
        }
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            throw SoundPlaybackError.unplayable
        }

        guard player.play() else { throw SoundPlaybackError.unplayable }
        let deadline = ContinuousClock.now + min(.seconds(player.duration) + .milliseconds(200), maxWait)
        while player.isPlaying, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        player.stop()
    }
}
