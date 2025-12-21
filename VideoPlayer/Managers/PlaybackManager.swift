//
//  PlaybackManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import Combine

/// 播放控制與播放列表業務邏輯
/// 依賴 PlayerServiceProtocol、AudioSessionServiceProtocol
final class PlaybackManager {

    // MARK: - Dependencies

    private let playerService: PlayerServiceProtocol
    private let audioSessionService: AudioSessionServiceProtocol

    // MARK: - Playlist State

    @Published private(set) var videos: [Video]
    @Published private(set) var currentIndex: Int = 0

    var currentVideo: Video? {
        guard currentIndex >= 0 && currentIndex < videos.count else { return nil }
        return videos[currentIndex]
    }

    // MARK: - Playback State

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentRate: Float = 1.0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var itemStatus: PlaybackItemStatus = .unknown
    @Published private(set) var bufferingState: BufferingState = .likelyToKeepUp

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        playerService: PlayerServiceProtocol,
        audioSessionService: AudioSessionServiceProtocol,
        videos: [Video]
    ) {
        self.playerService = playerService
        self.audioSessionService = audioSessionService
        self.videos = videos

        setupPlaylist()
        setupBindings()
        activateAudioSession()
    }

    // MARK: - Playback Control

    /// 播放
    func play() {
        playerService.play()
        playerService.setRate(currentRate)
    }

    /// 暫停
    func pause() {
        playerService.pause()
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

    // MARK: - Playlist Control

    /// 切換到指定索引的影片並播放
    func playVideo(at index: Int) {
        guard index >= 0 && index < videos.count else { return }

        if index == currentIndex {
            // 同一部影片，重頭播放
            playerService.seek(to: 0)
        } else if index == currentIndex + 1 {
            // 下一部影片，直接 advance 不需重建 queue
            currentIndex = index
            playerService.advanceToNextItem()
        } else {
            // 其他情況，需要重建 queue
            currentIndex = index
            let urls = videos.compactMap { URL(string: $0.url) }
            playerService.rebuildQueue(from: urls, startingAt: index)
        }
        play()
    }

    /// Reload current video (force rebuild queue)
    func reloadCurrentVideo() {
        let urls = videos.compactMap { URL(string: $0.url) }
        playerService.rebuildQueue(from: urls, startingAt: currentIndex)
        play()
    }

    /// 切換到下一個影片並播放
    func playNextVideo() {
        let nextIndex = currentIndex + 1
        if nextIndex >= videos.count {
            // 循環到第一個
            currentIndex = 0
            let urls = videos.compactMap { URL(string: $0.url) }
            playerService.rebuildQueue(from: urls, startingAt: 0)
        } else {
            currentIndex = nextIndex
            playerService.advanceToNextItem()
        }
        play()
    }

    /// 切換到上一個影片並播放
    func playPreviousVideo() {
        let previousIndex = currentIndex - 1
        if previousIndex < 0 {
            playVideo(at: videos.count - 1)
        } else {
            playVideo(at: previousIndex)
        }
    }

    /// 更新影片時長（當取得實際時長時）
    func updateVideoDuration(_ duration: TimeInterval, at index: Int) {
        guard index >= 0 && index < videos.count else { return }

        let video = videos[index]
        videos[index] = Video(
            title: video.title,
            url: video.url,
            thumbnailURL: video.thumbnailURL,
            duration: duration,
            description: video.description
        )
    }

    // MARK: - Private Methods

    private func setupPlaylist() {
        let urls = videos.compactMap { URL(string: $0.url) }
        playerService.setPlaylist(urls: urls)
    }

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

        // 訂閱播放結束，處理自動換集
        playerService.playbackDidEndPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handlePlaybackEnd()
            }
            .store(in: &cancellables)

        // 訂閱播放狀態變化（用於同步 PiP 等外部控制）
        playerService.isPlayingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.syncPlayingState(isPlaying)
            }
            .store(in: &cancellables)
    }

    /// 同步外部控制（如 PiP）的播放狀態
    private func syncPlayingState(_ isPlaying: Bool) {
        guard self.isPlaying != isPlaying else { return }
        self.isPlaying = isPlaying

        // 同步時間觀察器狀態
        if isPlaying {
            playerService.startTimeObservation(interval: 0.5)
        } else {
            playerService.stopTimeObservation()
        }
    }

    private func handlePlaybackEnd() {
        // AVQueuePlayer 會自動 advance，我們只需更新 index 並維持播放狀態
        let nextIndex = currentIndex + 1
        if nextIndex < videos.count {
            currentIndex = nextIndex
            // AVQueuePlayer 已自動切換，確保速率維持
            playerService.setRate(currentRate)
        } else {
            // 播放完畢，循環到第一個
            currentIndex = 0
            let urls = videos.compactMap { URL(string: $0.url) }
            playerService.rebuildQueue(from: urls, startingAt: 0)
            play()
        }
    }

    private func activateAudioSession() {
        do {
            try audioSessionService.activate()
        } catch {
            AppLogger.playback.error("Failed to activate audio session: \(error)")
        }
    }
}
