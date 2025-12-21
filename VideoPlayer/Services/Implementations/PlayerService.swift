//
//  PlayerService.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation
import AVKit
import Combine

/// 播放器服務實作
/// 封裝 AVQueuePlayer，依賴 AVFoundation（最外層）
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

    func connect(layer: AVPlayerLayer) {
        // Defer player connection to avoid blocking navigation animation
        DispatchQueue.main.async { [weak self] in
            layer.player = self?.player
            self?.setupPictureInPicture(with: layer)
        }
    }

    // MARK: - Protocol Properties

    var currentItemDuration: TimeInterval? {
        guard let duration = player?.currentItem?.duration,
              duration.isNumeric else { return nil }
        return CMTimeGetSeconds(duration)
    }

    var currentItemCurrentTime: TimeInterval? {
        guard let time = player?.currentItem?.currentTime(),
              time.isNumeric else { return nil }
        return CMTimeGetSeconds(time)
    }

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

    func startPictureInPicture() {
        guard let pipController = pipController,
              pipController.isPictureInPicturePossible else { return }
        pipController.startPictureInPicture()
    }

    func stopPictureInPicture() {
        guard let pipController = pipController,
              pipController.isPictureInPictureActive else { return }
        pipController.stopPictureInPicture()
    }

    func pictureInPictureUIRestored() {
        restoreUICompletionHandler?(true)
        restoreUICompletionHandler = nil
    }

    private func setupPictureInPicture(with layer: AVPlayerLayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard layer.player != nil else { return }

        // 如果已經有 pipController 且綁定的是同一個 layer，則不需要重新設置
        if let existingController = pipController,
           existingController.playerLayer === layer {
            return
        }

        // 清除舊的 PiP controller 和觀察者
        clearPiPObservers()

        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.delegate = self
        pipController = controller

        // 觀察 PiP 可用狀態
        pipPossibleObservation = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            AppLogger.player.debug("PiP possible: \(controller.isPictureInPicturePossible)")
            DispatchQueue.main.async {
                self?.isPiPPossibleSubject.send(controller.isPictureInPicturePossible)
            }
        }
    }

    // MARK: - Playback Control

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(to seconds: TimeInterval) {
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        player?.seek(to: time)
    }

    func setRate(_ rate: Float) {
        player?.rate = rate
    }

    // MARK: - Queue Management

    func setPlaylist(urls: [URL]) {
        let items = urls.map { AVPlayerItem(url: $0) }
        player = AVQueuePlayer(items: items)
        observeQueueItemChange()
        observePlayerRate()
        observeItemPlaybackState()
    }

    /// 觀察 AVPlayer 的 rate 變化（用於同步 PiP 等外部控制的播放狀態）
    private func observePlayerRate() {
        rateObserver?.invalidate()
        rateObserver = player?.observe(\.rate, options: [.new, .old]) { [weak self] player, change in
            guard let newRate = change.newValue, let oldRate = change.oldValue else { return }
            // 只在狀態真正改變時發送（避免重複發送）
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

    /// 觀察 AVQueuePlayer 的 currentItem 變化（自動換集時觸發）
    private func observeQueueItemChange() {
        currentItemObserver?.invalidate()
        currentItemObserver = player?.observe(\.currentItem, options: [.new, .old]) { [weak self] _, change in
            // 確保是真的換了一個 item（不是 nil → item 的初始化）
            guard change.oldValue != nil, change.newValue != nil else { return }
            AppLogger.player.debug("Player currentItem changed")
            self?.observeItemPlaybackState()
        }
    }

    func rebuildQueue(from urls: [URL], startingAt index: Int) {
        guard index >= 0 && index < urls.count else { return }

        // 移除所有項目
        player?.removeAllItems()

        // 從指定索引開始建立新的播放列表
        for i in index..<urls.count {
            let item = AVPlayerItem(url: urls[i])
            player?.insert(item, after: nil)
        }

        observeItemPlaybackState()
    }

    func advanceToNextItem() {
        player?.advanceToNextItem()
        observeItemPlaybackState()
    }

    // MARK: - Media Options

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

    func stopTimeObservation() {
        guard let player = player, let token = timeObserverToken else { return }
        player.removeTimeObserver(token)
        timeObserverToken = nil
    }

    // MARK: - Private Methods

    private func observeItemPlaybackState() {
        // 清除舊的觀察者
        clearItemObservers()

        guard let currentItem = player?.currentItem else { return }

        // 觀察播放狀態
        statusObserver = currentItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status: PlaybackItemStatus
            switch item.status {
            case .unknown:
                AppLogger.player.debug("Current Item status: unknown. Current Item \(currentItem.description)")
                status = .unknown
            case .readyToPlay:
                AppLogger.player.debug("Current Item status: readyToPlay. Current Item \(currentItem.description)")
                status = .readyToPlay
                // 發送時長
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

        // 觀察緩衝狀態
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

        // 觀察播放結束
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
        // 儲存 completion handler，等 UI 恢復後呼叫
        restoreUICompletionHandler = completionHandler
        restoreUISubject.send()
    }
}
