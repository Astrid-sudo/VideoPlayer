//
//  PlaybackManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import Combine

/// 播放控制業務邏輯
/// 依賴 PlayerServiceProtocol、AudioSessionServiceProtocol
final class PlaybackManager {

    // MARK: - Dependencies

    private let playerService: PlayerServiceProtocol
    private let audioSessionService: AudioSessionServiceProtocol

    // MARK: - Published State

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentRate: Float = 1.0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var itemStatus: PlaybackItemStatus = .unknown
    @Published private(set) var bufferingState: BufferingState = .likelyToKeepUp

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(playerService: PlayerServiceProtocol, audioSessionService: AudioSessionServiceProtocol) {
        self.playerService = playerService
        self.audioSessionService = audioSessionService

        setupBindings()
        activateAudioSession()
    }

    // MARK: - Public Methods

    /// 播放
    func play() {
        playerService.play()
        playerService.setRate(currentRate)
        isPlaying = true
        playerService.startTimeObservation(interval: 0.5)
    }

    /// 暫停
    func pause() {
        playerService.pause()
        isPlaying = false
        playerService.stopTimeObservation()
    }

    /// 切換播放/暫停
    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// 跳轉到指定時間（秒）
    func seek(to seconds: TimeInterval) {
        let validSeconds = max(0, min(seconds, duration))
        playerService.seek(to: validSeconds)
    }

    /// 快進指定秒數
    func skipForward(_ seconds: TimeInterval) {
        let targetTime = currentTime + seconds
        seek(to: targetTime)
    }

    /// 快退指定秒數
    func skipBackward(_ seconds: TimeInterval) {
        let targetTime = currentTime - seconds
        seek(to: targetTime)
    }

    /// 設定播放速度
    func setSpeed(_ rate: Float) {
        currentRate = rate
        if isPlaying {
            playerService.setRate(rate)
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // 訂閱時間更新
        playerService.timePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
            }
            .store(in: &cancellables)

        // 訂閱時長更新
        playerService.durationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.duration = duration
            }
            .store(in: &cancellables)

        // 訂閱播放項目狀態
        playerService.itemStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.itemStatus = status
            }
            .store(in: &cancellables)

        // 訂閱緩衝狀態
        playerService.bufferingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.bufferingState = state
            }
            .store(in: &cancellables)

        // 訂閱播放結束
        playerService.playbackDidEndPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.isPlaying = false
            }
            .store(in: &cancellables)
    }

    private func activateAudioSession() {
        do {
            try audioSessionService.activate()
        } catch {
            print("Failed to activate audio session: \(error)")
        }
    }
}
