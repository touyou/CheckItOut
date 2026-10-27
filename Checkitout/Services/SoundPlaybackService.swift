//
//  SoundPlaybackService.swift
//  Checkitout
//
//  One-shot playback for intents. Unlike `PadPlayerEngine` it waits for the
//  sound to finish, because a background intent's process may be suspended
//  as soon as `perform()` returns.
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
        // `.ambient` (the pads' category) is silenced by the ring/silent switch
        // and may not start from the background, so intents use `.playback`
        // and hand the session back to the pads' setting afterwards.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        defer { try? AudioSessionManager.configureForPlayback() }

        guard player.play() else { throw SoundPlaybackError.unplayable }
        let deadline = ContinuousClock.now + min(.seconds(player.duration) + .milliseconds(200), maxWait)
        while player.isPlaying, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        player.stop()
        self.player = nil
    }
}
