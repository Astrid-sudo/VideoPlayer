//
//  PlayerService.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation
import AVKit
import Combine

/// Wraps AVQueuePlayer with KVO observers for playback state management.
final class PlayerService: NSObject, PlayerServiceProtocol, PlayerLayerConnectable {

    // MARK: - Private Properties

    private var player: AVQueuePlayer?
    private var timeObserverToken: Any?

    // MARK: - PiP Properties

    private var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?
    private var restoreUICompletionHandler: ((Bool) -> Void)?

    // MARK: - KVO Observers

    private var currentItemObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var isPlaybackBufferEmptyObserver: NSKeyValueObservation?
    private var isPlaybackBufferFullObserver: NSKeyValueObservation?
    private var isPlaybackLikelyToKeepUpObserver: NSKeyValueObservation?

    // MARK: - Combine Subjects

    // Event stream (continuous updates)
    private let timeSubject = PassthroughSubject<TimeInterval, Never>()

    // State subjects (need to retain current value for late subscribers)
    private let durationSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let itemStatusSubject = CurrentValueSubject<PlaybackItemStatus, Never>(.unknown)
    private let bufferingSubject = CurrentValueSubject<BufferingState, Never>(.likelyToKeepUp)
    private let isPlayingSubject = CurrentValueSubject<Bool, Never>(false)

    // One-time events
    private let playbackDidEndSubject = PassthroughSubject<Void, Never>()

    // PiP Subjects
    private let isPiPPossibleSubject = CurrentValueSubject<Bool, Never>(false)
    private let isPiPActiveSubject = CurrentValueSubject<Bool, Never>(false)
    private let restoreUISubject = PassthroughSubject<Void, Never>()

    // MARK: - Publishers

    var timePublisher: AnyPublisher<TimeInterval, Never> {
        timeSubject.eraseToAnyPublisher()
    }

    var durationPublisher: AnyPublisher<TimeInterval, Never> {
        durationSubject.eraseToAnyPublisher()
    }

    var itemStatusPublisher: AnyPublisher<PlaybackItemStatus, Never> {
        itemStatusSubject.eraseToAnyPublisher()
    }

    var bufferingPublisher: AnyPublisher<BufferingState, Never> {
        bufferingSubject.eraseToAnyPublisher()
    }

    var playbackDidEndPublisher: AnyPublisher<Void, Never> {
        playbackDidEndSubject.eraseToAnyPublisher()
    }

    var isPlayingPublisher: AnyPublisher<Bool, Never> {
        isPlayingSubject.eraseToAnyPublisher()
    }

    // MARK: - PiP Publishers

    var isPiPPossiblePublisher: AnyPublisher<Bool, Never> {
        isPiPPossibleSubject.eraseToAnyPublisher()
    }

    var isPiPActivePublisher: AnyPublisher<Bool, Never> {
        isPiPActiveSubject.eraseToAnyPublisher()
    }

    var restoreUIPublisher: AnyPublisher<Void, Never> {
        restoreUISubject.eraseToAnyPublisher()
    }

    // MARK: - Player Connection

    /// Connects player to AVPlayerLayer and sets up PiP.
    func connect(layer: AVPlayerLayer) {
        // Defer player connection to avoid blocking navigation animation
        DispatchQueue.main.async { [weak self] in
            layer.player = self?.player
            self?.setupPictureInPicture(with: layer)
        }
    }

    // MARK: - Protocol Properties

    /// Duration of current item in seconds.
    var currentItemDuration: TimeInterval? {
        guard let duration = player?.currentItem?.duration,
              duration.isNumeric else { return nil }
        return CMTimeGetSeconds(duration)
    }

    /// Current playback time in seconds.
    var currentItemCurrentTime: TimeInterval? {
        guard let time = player?.currentItem?.currentTime(),
              time.isNumeric else { return nil }
        return CMTimeGetSeconds(time)
    }

    /// Current playback rate.
    var currentRate: Float {
        player?.rate ?? 0
    }

    // MARK: - Initialization

    override init() {
        super.init()
    }

    deinit {
        cleanup()
    }

    // MARK: - Picture in Picture

    /// Starts Picture in Picture if available.
    func startPictureInPicture() {
        guard let pipController = pipController,
              pipController.isPictureInPicturePossible else { return }
        pipController.startPictureInPicture()
    }

    /// Stops Picture in Picture if active.
    func stopPictureInPicture() {
        guard let pipController = pipController,
              pipController.isPictureInPictureActive else { return }
        pipController.stopPictureInPicture()
    }

    /// Notifies that UI has been restored after PiP.
    func pictureInPictureUIRestored() {
        restoreUICompletionHandler?(true)
        restoreUICompletionHandler = nil
    }

    private func setupPictureInPicture(with layer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard layer.player != nil else { return }

        // Skip if pipController already exists and is bound to the same layer
        if let existingController = pipController,
           existingController.playerLayer === layer {
            return
        }

        // Clear old PiP controller and observers
        clearPiPObservers()

        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.delegate = self
        pipController = controller

        // Observe PiP availability
        pipPossibleObservation = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            AppLogger.player.debug("PiP possible: \(controller.isPictureInPicturePossible)")
            DispatchQueue.main.async {
                self?.isPiPPossibleSubject.send(controller.isPictureInPicturePossible)
            }
        }
    }

    // MARK: - Playback Control

    /// Starts playback.
    func play() {
        player?.play()
    }

    /// Pauses playback.
    func pause() {
        player?.pause()
    }

    /// Seeks to the specified time in seconds.
    func seek(to seconds: TimeInterval) {
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        player?.seek(to: time)
    }

    /// Sets playback rate.
    func setRate(_ rate: Float) {
        player?.rate = rate
    }

    // MARK: - Queue Management

    /// Initializes player with playlist URLs.
    func setPlaylist(urls: [URL]) {
        let items = urls.map { AVPlayerItem(url: $0) }
        player = AVQueuePlayer(items: items)
        observeQueueItemChange()
        observePlayerRate()
        observeItemPlaybackState()
    }

    /// Observes player rate changes to sync external controls like PiP.
    private func observePlayerRate() {
        rateObserver?.invalidate()
        rateObserver = player?.observe(\.rate, options: [.new, .old]) { [weak self] player, change in
            guard let newRate = change.newValue, let oldRate = change.oldValue else { return }
            // Only send when state actually changes (avoid duplicates)
            let wasPlaying = oldRate > 0
            let isPlaying = newRate > 0
            if wasPlaying != isPlaying {
                AppLogger.player.debug("Player rate changed: \(oldRate) -> \(newRate)")
                DispatchQueue.main.async {
                    self?.isPlayingSubject.send(isPlaying)
                }
            }
        }
    }

    /// Observes queue item changes for auto-advancement.
    private func observeQueueItemChange() {
        currentItemObserver?.invalidate()
        currentItemObserver = player?.observe(\.currentItem, options: [.new, .old]) { [weak self] _, change in
            // Ensure item actually changed (not nil → item initialization)
            guard change.oldValue != nil, change.newValue != nil else { return }
            AppLogger.player.debug("Player currentItem changed")
            self?.observeItemPlaybackState()
        }
    }

    /// Rebuilds queue starting from the specified index.
    func rebuildQueue(from urls: [URL], startingAt index: Int) {
        guard index >= 0 && index < urls.count else { return }

        // Remove all items
        player?.removeAllItems()

        // Build new playlist starting from specified index
        for i in index..<urls.count {
            let item = AVPlayerItem(url: urls[i])
            player?.insert(item, after: nil)
        }

        observeItemPlaybackState()
    }

    /// Advances to the next item in queue.
    func advanceToNextItem() {
        player?.advanceToNextItem()
        observeItemPlaybackState()
    }

    // MARK: - Media Options

    /// Retrieves available audio and subtitle options.
    func getMediaOptions() async -> MediaSelectionOptions? {
        guard let currentItem = player?.currentItem else { return nil }

        var audioOptions = [MediaSelectionOption]()
        var subtitleOptions = [MediaSelectionOption]()

        do {
            let characteristics = try await currentItem.asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions)

            for characteristic in characteristics {
                if characteristic == .audible,
                   let group = try await currentItem.asset.loadMediaSelectionGroup(for: .audible) {
                    audioOptions = group.options.map { option in
                        MediaSelectionOption(displayName: option.displayName, locale: option.locale)
                    }
                }
                if characteristic == .legible,
                   let group = try await currentItem.asset.loadMediaSelectionGroup(for: .legible) {
                    subtitleOptions = group.options.map { option in
                        MediaSelectionOption(displayName: option.displayName, locale: option.locale)
                    }
                }
            }
        } catch {
            AppLogger.player.error("Failed to load media options: \(error.localizedDescription)")
            return nil
        }

        return MediaSelectionOptions(audioOptions: audioOptions, subtitleOptions: subtitleOptions)
    }

    /// Selects audio or subtitle track by locale.
    func selectMediaOption(type: MediaSelectionType, locale: Locale?) async {
        guard let currentItem = player?.currentItem else { return }

        let characteristic: AVMediaCharacteristic = (type == .audio) ? .audible : .legible

        do {
            guard let group = try await currentItem.asset.loadMediaSelectionGroup(for: characteristic) else { return }

            if let locale = locale {
                let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
                if let option = options.first {
                    currentItem.select(option, in: group)
                }
            }
        } catch {
            AppLogger.player.error("Failed to select media option: \(error.localizedDescription)")
        }
    }

    // MARK: - Time Observation

    /// Starts periodic time observation at the specified interval.
    func startTimeObservation(interval: TimeInterval) {
        guard let player = player else { return }

        let cmInterval = CMTime(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: cmInterval,
            queue: .main
        ) { [weak self] time in
            guard time.isNumeric else { return }
            self?.timeSubject.send(CMTimeGetSeconds(time))
        }
    }

    /// Stops periodic time observation.
    func stopTimeObservation() {
        guard let player = player, let token = timeObserverToken else { return }
        player.removeTimeObserver(token)
        timeObserverToken = nil
    }

    // MARK: - Private Methods

    private func observeItemPlaybackState() {
        // Clear old observers
        clearItemObservers()

        guard let currentItem = player?.currentItem else { return }

        // Observe playback status
        statusObserver = currentItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status: PlaybackItemStatus
            switch item.status {
            case .unknown:
                AppLogger.player.debug("Current Item status: unknown. Current Item \(currentItem.description)")
                status = .unknown
            case .readyToPlay:
                AppLogger.player.debug("Current Item status: readyToPlay. Current Item \(currentItem.description)")
                status = .readyToPlay
                // Send duration
                if item.duration.isNumeric {
                    self?.durationSubject.send(CMTimeGetSeconds(item.duration))
                }
            case .failed:
                AppLogger.player.error("Current Item status: failed - \(item.error?.localizedDescription ?? "Unknown error"). Current Item \(currentItem.description)")
                status = .failed(item.error)
            @unknown default:
                AppLogger.player.debug("Current Item status: unknown (default). Current Item \(currentItem.description)")
                status = .unknown
            }
            self?.itemStatusSubject.send(status)
        }

        // Observe buffering state
        isPlaybackBufferEmptyObserver = currentItem.observe(\.isPlaybackBufferEmpty) { [weak self] item, _ in
            if item.isPlaybackBufferEmpty {
                self?.bufferingSubject.send(.bufferEmpty)
            }
        }

        isPlaybackBufferFullObserver = currentItem.observe(\.isPlaybackBufferFull) { [weak self] item, _ in
            if item.isPlaybackBufferFull {
                self?.bufferingSubject.send(.bufferFull)
            }
        }

        isPlaybackLikelyToKeepUpObserver = currentItem.observe(\.isPlaybackLikelyToKeepUp) { [weak self] item, _ in
            if item.isPlaybackLikelyToKeepUp {
                self?.bufferingSubject.send(.likelyToKeepUp)
            }
        }

        // Observe playback end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: currentItem
        )
    }

    @objc private func handlePlaybackEnd() {
        AppLogger.player.debug("Playback did end")
        playbackDidEndSubject.send()
    }

    private func clearItemObservers() {
        statusObserver?.invalidate()
        statusObserver = nil
        isPlaybackBufferEmptyObserver?.invalidate()
        isPlaybackBufferEmptyObserver = nil
        isPlaybackBufferFullObserver?.invalidate()
        isPlaybackBufferFullObserver = nil
        isPlaybackLikelyToKeepUpObserver?.invalidate()
        isPlaybackLikelyToKeepUpObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func clearPlayerObservers() {
        currentItemObserver?.invalidate()
        currentItemObserver = nil
        rateObserver?.invalidate()
        rateObserver = nil
    }

    private func cleanup() {
        stopTimeObservation()
        clearItemObservers()
        clearPlayerObservers()
        clearPiPObservers()
        player = nil
    }

    private func clearPiPObservers() {
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil
        pipController = nil
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PlayerService: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        AppLogger.player.debug("PiP will start")
        isPiPActiveSubject.send(true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        AppLogger.player.debug("PiP did stop")
        isPiPActiveSubject.send(false)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        AppLogger.player.debug("PiP restore UI requested")
        // Store completion handler, call after UI is restored
        restoreUICompletionHandler = completionHandler
        restoreUISubject.send()
    }
}
