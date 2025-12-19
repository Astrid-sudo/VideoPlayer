//
//  AudioSessionService.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation

/// 音訊會話服務實作
/// 封裝 AVAudioSession，依賴 AVFoundation（最外層）
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
