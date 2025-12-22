//
//  NowPlayingViewModel.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation
import Combine
import SwiftUI

/// Central ViewModel that coordinates interactors and exposes UI state.
final class NowPlayingViewModel: ObservableObject {

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

    // MARK: - Interactors

    private let playbackInteractor: PlaybackInteractor
    private let mediaOptionsInteractor: MediaOptionsInteractor
    private let remoteControlInteractor: RemoteControlInteractor

    // MARK: - Layer Connection

    private let layerConnector: PlayerLayerConnectable

    // MARK: - Network Monitoring

    private let networkMonitor: NetworkMonitorProtocol

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private(set) var durationSeconds: TimeInterval = 0

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

        // Create Interactors
        self.playbackInteractor = PlaybackInteractor(
            playerService: playerService,
            audioSessionService: audioSessionService,
            videos: videos
        )

        self.mediaOptionsInteractor = MediaOptionsInteractor(
            playerService: playerService
        )

        self.remoteControlInteractor = RemoteControlInteractor(
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

    /// Toggles between play and pause states.
    func togglePlay() {
        playbackInteractor.togglePlay()
    }

    /// Starts playback.
    func playPlayer() {
        playbackInteractor.play()
    }

    /// Pauses playback.
    func pausePlayer() {
        playbackInteractor.pause()
    }

    /// Skips forward or backward by the specified seconds.
    func jumpToTime(_ jumpTimeType: JumpTimeType) {
        switch jumpTimeType {
        case .forward(let seconds):
            playbackInteractor.skipForward(seconds)
        case .backward(let seconds):
            playbackInteractor.skipBackward(seconds)
        }
        updateNowPlayingInfo()
    }

    /// Seeks to position based on slider value (0.0 to 1.0).
    func slideToTime(_ sliderValue: Double) {
        let targetTime = durationSeconds * sliderValue
        playbackInteractor.seek(to: targetTime)
    }

    /// Handles slider release; resumes playback if buffered.
    func sliderTouchEnded(_ sliderValue: Double) {
        if sliderValue >= 1.0 {
            playbackInteractor.pause()
            return
        }

        if playbackInteractor.bufferingState == .likelyToKeepUp {
            playbackInteractor.play()
        }
    }

    /// Adjusts playback speed.
    func adjustSpeed(_ speedButtonType: SpeedButtonType) {
        playbackInteractor.setSpeed(speedButtonType.speedRate)
        playSpeedRate = speedButtonType.speedRate
        updateNowPlayingInfo()
    }

    // MARK: - Playlist Control

    /// Plays video at the specified index.
    func playVideo(at index: Int) {
        playbackInteractor.playVideo(at: index)
        updateNowPlayingInfo()
    }

    /// Advances to the next video in playlist.
    func playNextVideo() {
        playbackInteractor.playNextVideo()
        updateNowPlayingInfo()
    }

    // MARK: - Media Options

    /// Selects audio track or subtitle at the specified index.
    func selectMediaOption(mediaOptionType: MediaOptionType, index: Int) {
        mediaOptionsInteractor.selectOption(type: mediaOptionType, index: index)
    }

    // MARK: - Picture in Picture

    /// Starts Picture in Picture mode.
    func startPictureInPicture() {
        layerConnector.startPictureInPicture()
    }

    /// Stops Picture in Picture mode.
    func stopPictureInPicture() {
        layerConnector.stopPictureInPicture()
    }

    // MARK: - Player Connection

    /// Connects AVPlayerLayer from PlayerView to the player.
    func connectPlayerLayer(_ layer: AVPlayerLayer) {
        layerConnector.connect(layer: layer)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Combine itemStatus, bufferingState, isPlaying to determine playerState
        Publishers.CombineLatest3(
            playbackInteractor.$itemStatus,
            playbackInteractor.$bufferingState,
            playbackInteractor.$isPlaying
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] itemStatus, bufferingState, isPlaying in
            self?.updatePlayerState(itemStatus: itemStatus, bufferingState: bufferingState, isPlaying: isPlaying)
        }
        .store(in: &cancellables)

        playbackInteractor.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = TimeManager.floatToTimecodeString(seconds: Float(time)) + " /"
                self?.updateProgress(currentTime: time)
            }
            .store(in: &cancellables)

        playbackInteractor.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                guard let self = self else { return }
                self.durationSeconds = duration
                self.duration = TimeManager.floatToTimecodeString(seconds: Float(duration))
                self.playbackInteractor.updateVideoDuration(duration, at: self.currentVideoIndex)
            }
            .store(in: &cancellables)

        // Playlist bindings (from PlaybackInteractor)
        playbackInteractor.$currentIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                self?.currentVideoIndex = index
            }
            .store(in: &cancellables)

        playbackInteractor.$videos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videos in
                self?.videos = videos
            }
            .store(in: &cancellables)

        // MediaOptionsInteractor bindings
        mediaOptionsInteractor.$mediaOption
            .receive(on: DispatchQueue.main)
            .assign(to: &$mediaOption)

        mediaOptionsInteractor.$selectedAudioIndex
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedAudioIndex)

        mediaOptionsInteractor.$selectedSubtitleIndex
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedSubtitleIndex)

        // PiP bindings
        layerConnector.isPiPPossiblePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPiPAvailable)

        layerConnector.restoreUIPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                // UI restored, notify service
                self?.layerConnector.pictureInPictureUIRestored()
            }
            .store(in: &cancellables)
    }

    private func setupRemoteControlCallbacks() {
        remoteControlInteractor.onPlay = { [weak self] in self?.playPlayer() }
        remoteControlInteractor.onPause = { [weak self] in self?.pausePlayer() }
        remoteControlInteractor.onTogglePlayPause = { [weak self] in self?.togglePlay() }
        remoteControlInteractor.onNextTrack = { [weak self] in self?.playNextVideo() }
        remoteControlInteractor.onSkipForward = { [weak self] seconds in self?.jumpToTime(.forward(seconds)) }
        remoteControlInteractor.onSkipBackward = { [weak self] seconds in self?.jumpToTime(.backward(seconds)) }
        remoteControlInteractor.onSeekToPosition = { [weak self] position in
            guard let self = self, self.durationSeconds > 0 else { return }
            let progress = position / self.durationSeconds
            self.slideToTime(progress)
        }

        remoteControlInteractor.setupCommands()
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
                    self.playbackInteractor.reloadCurrentVideo()
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
            AppLogger.player.error("Playback failed: \(playerError)")
            newState = .failed(playerError)
        case .readyToPlay:
            if isPlaying && bufferingState == .bufferEmpty {
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
        remoteControlInteractor.updateNowPlayingInfo(
            title: currentVideo?.title,
            artist: currentVideo?.description,
            duration: durationSeconds,
            elapsedTime: playbackInteractor.currentTime,
            playbackRate: isPlaying ? playSpeedRate : 0
        )
    }
}
