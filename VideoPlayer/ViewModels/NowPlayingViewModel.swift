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

    // MARK: - Input (User Actions)

    let togglePlaySubject = PassthroughSubject<Void, Never>()
    let playSubject = PassthroughSubject<Void, Never>()
    let pauseSubject = PassthroughSubject<Void, Never>()
    let jumpTimeSubject = PassthroughSubject<JumpTimeType, Never>()
    let slideToTimeSubject = PassthroughSubject<Double, Never>()
    let sliderTouchEndedSubject = PassthroughSubject<Double, Never>()
    let adjustSpeedSubject = PassthroughSubject<SpeedButtonType, Never>()
    let playVideoAtIndexSubject = PassthroughSubject<Int, Never>()
    let playNextVideoSubject = PassthroughSubject<Void, Never>()
    let selectMediaOptionSubject = PassthroughSubject<(MediaOptionType, Int), Never>()
    let startPiPSubject = PassthroughSubject<Void, Never>()
    let stopPiPSubject = PassthroughSubject<Void, Never>()

    // MARK: - Output (UI State)

    @Published private(set) var currentTime: String = "00:00"
    @Published private(set) var duration: String = "00:00"
    @Published private(set) var playProgress: Double = 0
    @Published private(set) var playerState: PlayerState = .loading
    @Published private(set) var playSpeedRate: Float = 1.0

    // Playlist
    @Published private(set) var videos: [Video]
    @Published private(set) var currentVideoIndex: Int = 0

    // Media Options
    @Published private(set) var mediaOption: MediaOption?
    @Published private(set) var selectedAudioIndex: Int?
    @Published private(set) var selectedSubtitleIndex: Int?

    // PiP
    @Published private(set) var isPiPAvailable: Bool = false

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
    // MARK: - Public Methods

    /// Returns formatted time string for a given progress value (0.0 to 1.0).
    func timeString(for progress: Double) -> String {
        let seconds = progress * durationSeconds
        return TimeManager.timecodeString(from: seconds) + " /"
    }

    /// Connects AVPlayerLayer from PlayerView to the player.
    func connectPlayerLayer(_ layer: AVPlayerLayer) {
        layerConnector.connect(layer: layer)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        setupInputBindings()
        setupOutputBindings()
    }

    private func setupInputBindings() {
        togglePlaySubject
            .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] in
                self?.playbackInteractor.togglePlay()
            }
            .store(in: &cancellables)

        playSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.playbackInteractor.play()
            }
            .store(in: &cancellables)

        pauseSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.playbackInteractor.pause()
            }
            .store(in: &cancellables)

        jumpTimeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] jumpTimeType in
                guard let self else { return }
                switch jumpTimeType {
                case .forward(let seconds):
                    playbackInteractor.skipForward(seconds)
                case .backward(let seconds):
                    playbackInteractor.skipBackward(seconds)
                }
                updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        slideToTimeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sliderValue in
                guard let self else { return }
                let targetTime = durationSeconds * sliderValue
                playbackInteractor.seek(to: targetTime)
            }
            .store(in: &cancellables)

        sliderTouchEndedSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sliderValue in
                guard let self else { return }
                if sliderValue >= 1.0 {
                    playbackInteractor.pause()
                    return
                }
                if playbackInteractor.bufferingState == .likelyToKeepUp {
                    playbackInteractor.play()
                }
            }
            .store(in: &cancellables)

        adjustSpeedSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speedButtonType in
                guard let self else { return }
                playbackInteractor.setSpeed(speedButtonType.speedRate)
                playSpeedRate = speedButtonType.speedRate
                updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        playVideoAtIndexSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                guard let self else { return }
                playbackInteractor.playVideo(at: index)
                updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        playNextVideoSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                playbackInteractor.playNextVideo()
                updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        selectMediaOptionSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mediaOptionType, index in
                self?.mediaOptionsInteractor.selectOption(type: mediaOptionType, index: index)
            }
            .store(in: &cancellables)

        startPiPSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.layerConnector.startPictureInPicture()
            }
            .store(in: &cancellables)

        stopPiPSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.layerConnector.stopPictureInPicture()
            }
            .store(in: &cancellables)
    }

    private func setupOutputBindings() {
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
                self?.currentTime = TimeManager.timecodeString(from: time) + " /"
                self?.updateProgress(currentTime: time)
            }
            .store(in: &cancellables)

        playbackInteractor.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                guard let self = self else { return }
                self.durationSeconds = duration
                self.duration = TimeManager.timecodeString(from: duration)
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
        remoteControlInteractor.onPlay = { [weak self] in self?.playSubject.send() }
        remoteControlInteractor.onPause = { [weak self] in self?.pauseSubject.send() }
        remoteControlInteractor.onTogglePlayPause = { [weak self] in self?.togglePlaySubject.send() }
        remoteControlInteractor.onNextTrack = { [weak self] in self?.playNextVideoSubject.send() }
        remoteControlInteractor.onSkipForward = { [weak self] seconds in self?.jumpTimeSubject.send(.forward(seconds)) }
        remoteControlInteractor.onSkipBackward = { [weak self] seconds in self?.jumpTimeSubject.send(.backward(seconds)) }
        remoteControlInteractor.onSeekToPosition = { [weak self] position in
            guard let self = self, self.durationSeconds > 0 else { return }
            let progress = position / self.durationSeconds
            self.slideToTimeSubject.send(progress)
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
        playProgress = currentTime / durationSeconds
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
