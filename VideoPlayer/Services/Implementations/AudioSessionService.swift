//
//  AudioSessionService.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation

/// Wraps AVAudioSession for audio playback configuration.
final class AudioSessionService: AudioSessionServiceProtocol {

    // MARK: - Initialization

    init() {}

    // MARK: - AudioSessionServiceProtocol

    func activate() throws {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            throw AudioSessionError.activationFailed(error.localizedDescription)
        }
    }

    func deactivate() throws {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            throw AudioSessionError.deactivationFailed(error.localizedDescription)
        }
    }
}
