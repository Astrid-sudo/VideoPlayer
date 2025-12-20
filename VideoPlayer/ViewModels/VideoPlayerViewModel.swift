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
    @Published var playerState: PlayerState = .loading
    @Published var playSpeedRate: Float = 1.0

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
    private let mediaOptionsManager: MediaOptionsManager
    private let remoteControlManager: RemoteControlManager

    // MARK: - Layer Connection

    private let layerConnector: PlayerLayerConnectable

    // MARK: - Network Monitoring

    private let networkMonitor: NetworkMonitorProtocol

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var durationSeconds: TimeInterval = 0

    // MARK: - Initialization

    init(
        playerService: PlayerServiceProtocol,
        layerConnector: PlayerLayerConnectable,
        audioSessionService: AudioSessionServiceProtocol,
        remoteControlService: RemoteControlServiceProtocol,
        networkMonitor: NetworkMonitorProtocol,
        videos: [Video]
    ) {
        self.layerConnector = layerConnector
        self.networkMonitor = networkMonitor
        self.videos = videos

        // Create Managers
        self.playbackManager = PlaybackManager(
            playerService: playerService,
            audioSessionService: audioSessionService,
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
        setupNetworkMonitoring()
    }

    /// Convenience initializer: auto-create all dependencies
    convenience init(videos: [Video]) {
        let playerService = PlayerService()
        self.init(
            playerService: playerService,
            layerConnector: playerService,
            audioSessionService: AudioSessionService(),
            remoteControlService: RemoteControlService(),
            networkMonitor: NetworkMonitor.shared,
            videos: videos
        )
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
        playbackManager.playVideo(at: index)
        updateNowPlayingInfo()
    }

    func playNextVideo() {
        playbackManager.playNextVideo()
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
        // Combine itemStatus, bufferingState, isPlaying to determine playerState
        Publishers.CombineLatest3(
            playbackManager.$itemStatus,
            playbackManager.$bufferingState,
            playbackManager.$isPlaying
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] itemStatus, bufferingState, isPlaying in
            self?.updatePlayerState(itemStatus: itemStatus, bufferingState: bufferingState, isPlaying: isPlaying)
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
                self.playbackManager.updateVideoDuration(duration, at: self.currentVideoIndex)
            }
            .store(in: &cancellables)

        // Playlist bindings (from PlaybackManager)
        playbackManager.$currentIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                self?.currentVideoIndex = index
            }
            .store(in: &cancellables)

        playbackManager.$videos
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
        remoteControlManager.onNextTrack = { [weak self] in self?.playNextVideo() }
        remoteControlManager.onSkipForward = { [weak self] seconds in self?.jumpToTime(.forward(seconds)) }
        remoteControlManager.onSkipBackward = { [weak self] seconds in self?.jumpToTime(.backward(seconds)) }
        remoteControlManager.onSeekToPosition = { [weak self] position in
            guard let self = self, self.durationSeconds > 0 else { return }
            let progress = position / self.durationSeconds
            self.slideToTime(progress)
        }

        remoteControlManager.setupCommands()
    }

    private func setupNetworkMonitoring() {
        networkMonitor.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self, isConnected else { return }
                // When network recovers, reload video if current state is network error
                if case .failed(let error) = self.playerState,
                   let playerError = error as? PlayerError,
                   playerError.isNetworkError {
                    self.playbackManager.reloadCurrentVideo()
                }
            }
            .store(in: &cancellables)
    }

    private func updateProgress(currentTime: TimeInterval) {
        guard durationSeconds > 0 else { return }
        playProgress = Float(currentTime / durationSeconds)
    }

    private func updatePlayerState(
        itemStatus: PlaybackItemStatus,
        bufferingState: BufferingState,
        isPlaying: Bool
    ) {
        let newState: PlayerState

        switch itemStatus {
        case .unknown:
            newState = .loading
        case .failed(let error):
            let playerError = PlayerError.from(error: error)
            newState = .failed(playerError)
        case .readyToPlay:
            if bufferingState == .bufferEmpty {
                newState = .loading
            } else if isPlaying {
                newState = .playing
            } else {
                newState = .paused
            }
        }

        if playerState != newState {
            playerState = newState
            updateNowPlayingInfo()
        }
    }

    private func updateNowPlayingInfo() {
        let isPlaying = playerState == .playing
        remoteControlManager.updateNowPlayingInfo(
            title: currentVideo?.title,
            artist: currentVideo?.description,
            duration: durationSeconds,
            elapsedTime: playbackManager.currentTime,
            playbackRate: isPlaying ? playSpeedRate : 0
        )
    }
}

// MARK: - Player Error

enum PlayerError: LocalizedError {
    case playbackFailed
    case networkUnavailable      // -1009: No internet connection
    case connectionTimeout       // -1001: Connection timed out
    case cannotConnectToHost     // -1004: Cannot connect to host
    case connectionLost          // -1005: Network connection lost

    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Failed to play video"
        case .networkUnavailable, .connectionTimeout, .cannotConnectToHost, .connectionLost:
            return "Network connection error"
        }
    }

    var isNetworkError: Bool {
        switch self {
        case .networkUnavailable, .connectionTimeout, .cannotConnectToHost, .connectionLost:
            return true
        case .playbackFailed:
            return false
        }
    }

    static func from(error: Error?) -> PlayerError {
        guard let error = error as NSError? else {
            return .playbackFailed
        }

        // Check if error is from NSURLErrorDomain
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet: // -1009
                return .networkUnavailable
            case NSURLErrorTimedOut: // -1001
                return .connectionTimeout
            case NSURLErrorCannotConnectToHost: // -1004
                return .cannotConnectToHost
            case NSURLErrorNetworkConnectionLost: // -1005
                return .connectionLost
            default:
                break
            }
        }

        // Recursively check underlying error
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
            let result = PlayerError.from(error: underlyingError)
            if result.isNetworkError {
                return result
            }
        }

        return .playbackFailed
    }
}
