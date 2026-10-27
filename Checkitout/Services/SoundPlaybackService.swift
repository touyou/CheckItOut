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
        self.player = player
        // `.ambient` (the pads' category) is silenced by the ring/silent switch,
        // so intents use `.playback`, then restore whatever was set before
        // (it may be `.playAndRecord` if the record panel is open).
        let session = AVAudioSession.sharedInstance()
        let previousCategory = session.category
        let previousOptions = session.categoryOptions
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        defer { try? session.setCategory(previousCategory, options: previousOptions) }

        guard player.play() else { throw SoundPlaybackError.unplayable }
        let deadline = ContinuousClock.now + min(.seconds(player.duration) + .milliseconds(200), maxWait)
        while player.isPlaying, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        player.stop()
        self.player = nil
    }
}
