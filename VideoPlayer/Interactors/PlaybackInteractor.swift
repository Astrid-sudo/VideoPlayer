//
//  PlaybackInteractor.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import Combine

/// Handles playback control and playlist management logic.
final class PlaybackInteractor {

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

    /// Starts playback.
    func play() {
        AppLogger.playback.notice("Play")
        playerService.play()
        playerService.setRate(currentRate)
    }

    /// Pauses playback.
    func pause() {
        AppLogger.playback.notice("Pause")
        playerService.pause()
    }

    /// Toggles between play and pause.
    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Seeks to the specified time in seconds.
    func seek(to seconds: TimeInterval) {
        let validSeconds = max(0, min(seconds, duration))
        playerService.seek(to: validSeconds)
    }

    /// Skips forward by the specified seconds.
    func skipForward(_ seconds: TimeInterval) {
        let targetTime = currentTime + seconds
        seek(to: targetTime)
    }

    /// Skips backward by the specified seconds.
    func skipBackward(_ seconds: TimeInterval) {
        let targetTime = currentTime - seconds
        seek(to: targetTime)
    }

    /// Sets playback speed rate.
    func setSpeed(_ rate: Float) {
        AppLogger.playback.info("Speed changed to \(rate)x")
        currentRate = rate
        if isPlaying {
            playerService.setRate(rate)
        }
    }

    // MARK: - Playlist Control

    /// Switches to the video at the specified index and plays.
    func playVideo(at index: Int) {
        guard index >= 0 && index < videos.count else { return }
        AppLogger.playback.notice("Switch to video at index \(index): \(videos[index].title)")

        if index == currentIndex {
            // Same video, restart from beginning
            playerService.seek(to: 0)
        } else if index == currentIndex + 1 {
            // Next video, advance without rebuilding queue
            currentIndex = index
            playerService.advanceToNextItem()
        } else {
            // Other cases, need to rebuild queue
            currentIndex = index
            let urls = videos.compactMap { URL(string: $0.url) }
            playerService.rebuildQueue(from: urls, startingAt: index)
        }
        play()
    }

    /// Reloads current video by rebuilding the queue.
    func reloadCurrentVideo() {
        let urls = videos.compactMap { URL(string: $0.url) }
        playerService.rebuildQueue(from: urls, startingAt: currentIndex)
        play()
    }

    /// Advances to and plays the next video.
    func playNextVideo() {
        let nextIndex = currentIndex + 1
        if nextIndex >= videos.count {
            // Loop back to first
            currentIndex = 0
            let urls = videos.compactMap { URL(string: $0.url) }
            playerService.rebuildQueue(from: urls, startingAt: 0)
        } else {
            currentIndex = nextIndex
            playerService.advanceToNextItem()
        }
        play()
    }

    /// Updates video duration when actual duration is available.
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
        // Subscribe to time updates
        playerService.timePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
            }
            .store(in: &cancellables)

        // Subscribe to duration updates
        playerService.durationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.duration = duration
            }
            .store(in: &cancellables)

        // Subscribe to item status
        playerService.itemStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.itemStatus = status
            }
            .store(in: &cancellables)

        // Subscribe to buffering state
        playerService.bufferingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.bufferingState = state
            }
            .store(in: &cancellables)

        // Subscribe to playback end for auto advancement
        playerService.playbackDidEndPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handlePlaybackEnd()
            }
            .store(in: &cancellables)

        // Subscribe to playing state changes (for syncing with PiP and other external controls)
        playerService.isPlayingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.syncPlayingState(isPlaying)
            }
            .store(in: &cancellables)
    }

    /// Syncs playing state from external controls (e.g., PiP).
    private func syncPlayingState(_ isPlaying: Bool) {
        guard self.isPlaying != isPlaying else { return }
        self.isPlaying = isPlaying

        // Sync time observer state
        if isPlaying {
            playerService.startTimeObservation(interval: PlayerConstants.timeObservationInterval)
        } else {
            playerService.stopTimeObservation()
        }
    }

    private func handlePlaybackEnd() {
        // AVQueuePlayer auto-advances, we just update index and maintain playback state
        let nextIndex = currentIndex + 1
        if nextIndex < videos.count {
            AppLogger.playback.notice("Video ended, advancing to next: \(videos[nextIndex].title)")
            currentIndex = nextIndex
            // AVQueuePlayer already switched, ensure rate is maintained
            playerService.setRate(currentRate)
        } else {
            // Playlist ended, loop back to first
            AppLogger.playback.notice("Playlist ended, looping to first video")
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
