//
//  VideoPlayerViewModel.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation
import Combine
import SwiftUI

/// 影片播放器 ViewModel
/// 協調 Managers，管理 UI 狀態
final class VideoPlayerViewModel: ObservableObject {

    // MARK: - UI State (Published)

    @Published var currentTime: String = "00:00"
    @Published var duration: String = "00:00"
    @Published var playProgress: Float = 0
    @Published var isPlaying: Bool = false
    @Published var playerState: PlayerState = .unknown
    @Published var playSpeedRate: Float = 1.0
    @Published var showIndicator: Bool = true

    // Playlist
    @Published var videos: [Video]
    @Published var currentVideoIndex: Int = 0

    // Media Options
    @Published var mediaOption: MediaOption?
    @Published var selectedAudioIndex: Int?
    @Published var selectedSubtitleIndex: Int?

    // PiP
    @Published var isPiPAvailable: Bool = false

    var currentVideo: Video? {
        guard currentVideoIndex >= 0 && currentVideoIndex < videos.count else { return nil }
        return videos[currentVideoIndex]
    }

    // MARK: - Managers

    private let playbackManager: PlaybackManager
    private let playlistManager: PlaylistManager
    private let mediaOptionsManager: MediaOptionsManager
    private let remoteControlManager: RemoteControlManager

    // MARK: - Layer Connection

    private let layerConnector: PlayerLayerConnectable

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var durationSeconds: TimeInterval = 0

    // MARK: - Initialization

    init(
        playerService: PlayerServiceProtocol,
        layerConnector: PlayerLayerConnectable,
        audioSessionService: AudioSessionServiceProtocol,
        remoteControlService: RemoteControlServiceProtocol,
        videos: [Video]
    ) {
        self.layerConnector = layerConnector
        self.videos = videos

        // 建立 Managers
        self.playbackManager = PlaybackManager(
            playerService: playerService,
            audioSessionService: audioSessionService
        )

        self.playlistManager = PlaylistManager(
            playerService: playerService,
            videos: videos
        )

        self.mediaOptionsManager = MediaOptionsManager(
            playerService: playerService
        )

        self.remoteControlManager = RemoteControlManager(
            remoteControlService: remoteControlService
        )

        setupBindings()
        setupRemoteControlCallbacks()
    }

    // MARK: - Playback Control

    func togglePlay() {
        playbackManager.togglePlay()
    }

    func playPlayer() {
        playbackManager.play()
    }

    func pausePlayer() {
        playbackManager.pause()
    }

    func jumpToTime(_ jumpTimeType: JumpTimeType) {
        switch jumpTimeType {
        case .forward(let seconds):
            playbackManager.skipForward(seconds)
        case .backward(let seconds):
            playbackManager.skipBackward(seconds)
        }
        updateNowPlayingInfo()
    }

    func slideToTime(_ sliderValue: Double) {
        let targetTime = durationSeconds * sliderValue
        playbackManager.seek(to: targetTime)
    }

    func sliderTouchEnded(_ sliderValue: Double) {
        if sliderValue >= 1.0 {
            playbackManager.pause()
            return
        }

        if playbackManager.bufferingState == .likelyToKeepUp {
            playbackManager.play()
        }
    }

    func adjustSpeed(_ speedButtonType: SpeedButtonType) {
        playbackManager.setSpeed(speedButtonType.speedRate)
        playSpeedRate = speedButtonType.speedRate
        updateNowPlayingInfo()
    }

    // MARK: - Playlist Control

    func playVideo(at index: Int) {
        playlistManager.playVideo(at: index)
        playbackManager.play()
        updateNowPlayingInfo()
    }

    func proceedNextPlayerItem() {
        playlistManager.playNext()
        playbackManager.play()
        updateNowPlayingInfo()
    }

    // MARK: - Media Options

    func selectMediaOption(mediaOptionType: MediaOptionType, index: Int) {
        mediaOptionsManager.selectOption(type: mediaOptionType, index: index)
    }

    // MARK: - Picture in Picture

    func startPictureInPicture() {
        layerConnector.startPictureInPicture()
    }

    func stopPictureInPicture() {
        layerConnector.stopPictureInPicture()
    }

    // MARK: - Player Connection

    /// 連接 PlayerView 的 layer 到播放器
    func connectPlayerLayer(_ layer: AVPlayerLayer) {
        layerConnector.connect(layer: layer)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // PlaybackManager bindings
        playbackManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        playbackManager.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = TimeManager.floatToTimecodeString(seconds: Float(time)) + " /"
                self?.updateProgress(currentTime: time)
            }
            .store(in: &cancellables)

        playbackManager.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                guard let self = self else { return }
                self.durationSeconds = duration
                self.duration = TimeManager.floatToTimecodeString(seconds: Float(duration))
                self.playlistManager.updateVideoDuration(duration, at: self.currentVideoIndex)
            }
            .store(in: &cancellables)

        playbackManager.$itemStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .unknown:
                    self?.playerState = .unknown
                case .readyToPlay:
                    if self?.playerState != .playing {
                        self?.playerState = .readyToPlay
                    }
                    self?.updateNowPlayingInfo()
                case .failed:
                    self?.playerState = .failed
                }
            }
            .store(in: &cancellables)

        // 結合 itemStatus 和 bufferingState 來決定是否顯示 loading indicator
        // - itemStatus == .unknown → 影片載入中
        // - bufferingState == .bufferEmpty → 播放中緩衝不足
        Publishers.CombineLatest(playbackManager.$itemStatus, playbackManager.$bufferingState)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] itemStatus, bufferingState in
                let isLoading = itemStatus == .unknown
                let isBuffering = bufferingState == .bufferEmpty
                self?.showIndicator = isLoading || isBuffering
            }
            .store(in: &cancellables)

        // PlaylistManager bindings
        playlistManager.$currentIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                self?.currentVideoIndex = index
            }
            .store(in: &cancellables)

        playlistManager.$videos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videos in
                self?.videos = videos
            }
            .store(in: &cancellables)

        // MediaOptionsManager bindings
        mediaOptionsManager.$mediaOption
            .receive(on: DispatchQueue.main)
            .assign(to: &$mediaOption)

        mediaOptionsManager.$selectedAudioIndex
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedAudioIndex)

        mediaOptionsManager.$selectedSubtitleIndex
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedSubtitleIndex)

        // PiP bindings
        layerConnector.isPiPPossiblePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPiPAvailable)

        layerConnector.restoreUIPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                // UI 已經恢復，通知 service
                self?.layerConnector.pictureInPictureUIRestored()
            }
            .store(in: &cancellables)
    }

    private func setupRemoteControlCallbacks() {
        remoteControlManager.onPlay = { [weak self] in self?.playPlayer() }
        remoteControlManager.onPause = { [weak self] in self?.pausePlayer() }
        remoteControlManager.onTogglePlayPause = { [weak self] in self?.togglePlay() }
        remoteControlManager.onNextTrack = { [weak self] in self?.proceedNextPlayerItem() }
        remoteControlManager.onSkipForward = { [weak self] seconds in self?.jumpToTime(.forward(seconds)) }
        remoteControlManager.onSkipBackward = { [weak self] seconds in self?.jumpToTime(.backward(seconds)) }
        remoteControlManager.onSeekToPosition = { [weak self] position in
            guard let self = self, self.durationSeconds > 0 else { return }
            let progress = position / self.durationSeconds
            self.slideToTime(progress)
        }

        remoteControlManager.setupCommands()
    }

    private func updateProgress(currentTime: TimeInterval) {
        guard durationSeconds > 0 else { return }
        playProgress = Float(currentTime / durationSeconds)
    }

    private func updateNowPlayingInfo() {
        remoteControlManager.updateNowPlayingInfo(
            title: currentVideo?.title,
            artist: currentVideo?.description,
            duration: durationSeconds,
            elapsedTime: playbackManager.currentTime,
            playbackRate: isPlaying ? playSpeedRate : 0
        )
    }
}
