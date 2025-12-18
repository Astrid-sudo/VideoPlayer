//
//  VideoPlayerViewModel.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation
import AVKit
import Combine
import MediaPlayer
import SwiftUI
import UIKit

class VideoPlayerViewModel: ObservableObject {

    // MARK: - Published Properties (UI State)

    @Published var currentTime: String = "00:00"
    @Published var duration: String = "00:00"
    @Published var playProgress: Float = 0
    @Published var isPlaying: Bool = false
    @Published var playerState: PlayerState = .unknown
    @Published var playSpeedRate: Float = 1.0
    @Published var showIndicator: Bool = false

    // MARK: - Playlist Properties

    @Published var videos: [Video]
    @Published var currentVideoIndex: Int = 0

    var currentVideo: Video? {
        guard currentVideoIndex < videos.count else { return nil }
        return videos[currentVideoIndex]
    }

    // MARK: - Player Properties

    private(set) var player: AVQueuePlayer?

    private var currentItem: AVPlayerItem? {
        return player?.currentItem
    }

    private var currentItemDuration: CMTime? {
        return currentItem?.duration
    }

    private var currentItemCurrentTime: CMTime? {
        return currentItem?.currentTime()
    }

    // MARK: - Media Selection

    @Published var mediaOption: MediaOption?
    @Published var selectedAudioIndex: Int?
    @Published var selectedSubtitleIndex: Int?

    // MARK: - Picture in Picture

    @Published var pipController: AVPictureInPictureController?
    @Published var isPiPAvailable: Bool = false

    // MARK: - Observers

    private var timeObserverToken: Any?
    private var isPlaybackBufferEmptyObserver: NSKeyValueObservation?
    private var isPlaybackBufferFullObserver: NSKeyValueObservation?
    private var isPlaybackLikelyToKeepUpObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(videos: [Video]) {
        self.videos = videos
        setupAudioSession()
        setupPlayer()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }

        setupRemoteCommandCenter()
    }

    // MARK: - Remote Command Center Setup

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playPlayer()
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pausePlayer()
            return .success
        }

        // Toggle play/pause command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlay()
            return .success
        }

        // Next track command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.proceedNextPlayerItem()
            return .success
        }

        // Skip forward command (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.jumpToTime(.forward(15))
            return .success
        }

        // Skip backward command (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.jumpToTime(.backward(15))
            return .success
        }

        // Change playback position command
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let time = event.positionTime
            if let duration = self?.currentItemDuration {
                let progress = time / CMTimeGetSeconds(duration)
                self?.slideToTime(progress)
            }
            return .success
        }
    }

    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        // Set title and duration
        if let video = currentVideo {
            nowPlayingInfo[MPMediaItemPropertyTitle] = video.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = video.description

            // Set artwork if available
            if let artwork = createNowPlayingArtwork() {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }

        if let duration = currentItemDuration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = CMTimeGetSeconds(duration)
        }

        if let currentTime = currentItemCurrentTime {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(currentTime)
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playSpeedRate : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func createNowPlayingArtwork() -> MPMediaItemArtwork? {
        // Create a placeholder artwork with a gradient
        // In the future, this can be replaced with actual video thumbnails
        let size = CGSize(width: 300, height: 300)

        let renderer = UIGraphicsImageRenderer(size: size)
        let placeholderImage = renderer.image { context in
            // Create a simple gradient background
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray,
                                     locations: [0.0, 1.0])

            if let gradient = gradient {
                context.cgContext.drawLinearGradient(gradient,
                                                     start: CGPoint(x: 0, y: 0),
                                                     end: CGPoint(x: size.width, y: size.height),
                                                     options: [])
            }

            // Add a play icon in the center
            let playIconSize: CGFloat = 80
            let playIconRect = CGRect(x: (size.width - playIconSize) / 2,
                                     y: (size.height - playIconSize) / 2,
                                     width: playIconSize,
                                     height: playIconSize)

            let config = UIImage.SymbolConfiguration(pointSize: playIconSize, weight: .light)
            if let playIcon = UIImage(systemName: "play.circle.fill", withConfiguration: config) {
                playIcon.withTintColor(.white, renderingMode: .alwaysTemplate)
                    .draw(in: playIconRect, blendMode: .normal, alpha: 0.8)
            }
        }

        return MPMediaItemArtwork(boundsSize: size) { _ in placeholderImage }
    }

    deinit {
        cleanup()
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        guard !videos.isEmpty else { return }

        // Create player items for all videos
        var playerItems: [AVPlayerItem] = []
        for video in videos {
            if let url = URL(string: video.url) {
                playerItems.append(AVPlayerItem(url: url))
            }
        }

        // Create queue player with all items
        guard !playerItems.isEmpty else { return }
        player = AVQueuePlayer(items: playerItems)
        observePlayerItem(currentPlayerItem: currentItem)
    }

    // MARK: - Playback Control

    func togglePlay() {
        switch playerState {
        case .buffering:
            playPlayer()
        case .unknown, .pause, .readyToPlay:
            playPlayer()
        case .playing:
            pausePlayer()
        default:
            break
        }
    }

    func playPlayer() {
        guard let player = player else { return }
        player.play()
        playerState = .playing
        player.rate = playSpeedRate
        isPlaying = true
        addPeriodicTimeObserver()
        updateNowPlayingInfo()
    }

    func pausePlayer() {
        guard let player = player else { return }
        player.pause()
        playerState = .pause
        isPlaying = false
        removePeriodicTimeObserver()
        updateNowPlayingInfo()
    }

    func jumpToTime(_ jumpTimeType: JumpTimeType) {
        guard let player = player,
              let currentTime = currentItemCurrentTime,
              let duration = currentItemDuration else { return }

        let seekCMTime = TimeManager.getValidSeekTime(
            duration: duration,
            currentTime: currentTime,
            jumpTimeType: jumpTimeType
        )
        player.seek(to: seekCMTime)
        updateCurrentTime(seekCMTime)
    }

    func slideToTime(_ sliderValue: Double) {
        guard let player = player,
              let duration = currentItemDuration else { return }

        let seekCMTime = TimeManager.getCMTime(from: sliderValue, duration: duration)
        player.seek(to: seekCMTime)
        updateCurrentTime(seekCMTime)
    }

    func sliderTouchEnded(_ sliderValue: Double) {
        guard let player = player,
              let currentItem = currentItem,
              let duration = currentItemDuration else { return }

        // Drag to the end
        if sliderValue == 1 {
            updateCurrentTime(duration)
            pausePlayer()
            return
        }

        // Resume playing if buffer is ready
        if currentItem.isPlaybackLikelyToKeepUp {
            playPlayer()
        }
    }

    func adjustSpeed(_ speedButtonType: SpeedButtonType) {
        guard let currentItem = currentItem,
              let player = player else { return }

        currentItem.audioTimePitchAlgorithm = .spectral
        playSpeedRate = speedButtonType.speedRate

        if playerState == .playing {
            playPlayer()
        } else {
            player.rate = playSpeedRate
        }
    }

    // MARK: - Playlist Management

    func playVideo(at index: Int) {
        guard index >= 0 && index < videos.count else { return }

        pausePlayer()
        currentVideoIndex = index
		print("嘎 playVideo currentVideoIndex \(currentVideoIndex)")

        // Remove all items from the current queue
        player?.removeAllItems()

        // Create player items for videos starting from the selected index
        var playerItems: [AVPlayerItem] = []
        for i in index..<videos.count {
			print("嘎 index for loop \(i)")
            if let url = URL(string: videos[i].url) {
                playerItems.append(AVPlayerItem(url: url))
				print("嘎 playerItems.append index \(i), url: \(url)")
            }
        }

        // Insert items in correct order (insert in reverse to maintain order)
        for item in playerItems {
            player?.insert(item, after: nil)
        }

        observePlayerItem(currentPlayerItem: currentItem)
        playPlayer()
        updateNowPlayingInfo()
    }

    func proceedNextPlayerItem() {
        guard let player = player,
              let currentItem = currentItem else { return }

        let items = player.items()

        // Check if this is the last video
        if currentItem == items.last {
            player.seek(to: .zero)
            currentVideoIndex = 0
            return
        }

        // Advance to next item
        player.advanceToNextItem()
        currentVideoIndex += 1
        observePlayerItem(previousPlayerItem: currentItem, currentPlayerItem: self.currentItem)
        playPlayer()
    }

    // MARK: - Picture in Picture

    func startPictureInPicture() {
        guard let pipController = pipController,
              pipController.isPictureInPicturePossible else {
            return
        }
        pipController.startPictureInPicture()
    }

    func stopPictureInPicture() {
        guard let pipController = pipController,
              pipController.isPictureInPictureActive else {
            return
        }
        pipController.stopPictureInPicture()
    }

    // MARK: - Media Selection

    func selectMediaOption(mediaOptionType: MediaOptionType, index: Int) {
        var displayNameLocaleArray: [DisplayNameLocale]? {
            switch mediaOptionType {
            case .audio:
                return mediaOption?.avMediaCharacteristicAudible
            case .subtitle:
                return mediaOption?.avMediaCharacteristicLegible
            }
        }

        guard let currentItem = currentItem,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: mediaOptionType.avMediaCharacteristic),
              let locale = displayNameLocaleArray?[index].locale else { return }

        let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
        if let option = options.first {
            currentItem.select(option, in: group)

            switch mediaOptionType {
            case .audio:
                selectedAudioIndex = index
            case .subtitle:
                selectedSubtitleIndex = index
            }
        }
    }

    // MARK: - Time Observers

    private func addPeriodicTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.updateCurrentTime(time)

            if let duration = self.currentItemDuration {
                self.updateProgress(currentTime: time, duration: duration)
            }
        }
    }

    private func removePeriodicTimeObserver() {
        guard let player = player, let token = timeObserverToken else { return }
        player.removeTimeObserver(token)
        timeObserverToken = nil
    }

    // MARK: - Player Item Observers

    private func observePlayerItem(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        observeItemBuffering(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
        observeItemStatus(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
        observeItemPlayEnd(previousPlayerItem: previousPlayerItem, currentPlayerItem: currentPlayerItem)
    }

    private func observeItemBuffering(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }

        isPlaybackBufferEmptyObserver = currentPlayerItem.observe(\.isPlaybackBufferEmpty) { [weak self] item, _ in
            if item.isPlaybackBufferEmpty {
                self?.showIndicator = true
            }
        }

        isPlaybackBufferFullObserver = currentPlayerItem.observe(\.isPlaybackBufferFull) { [weak self] item, _ in
            if item.isPlaybackBufferFull {
                self?.showIndicator = false
            }
        }

        isPlaybackLikelyToKeepUpObserver = currentPlayerItem.observe(\.isPlaybackLikelyToKeepUp) { [weak self] item, _ in
            if item.isPlaybackLikelyToKeepUp {
                self?.showIndicator = false
            }
        }
    }

    private func observeItemStatus(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        guard let currentPlayerItem = currentPlayerItem else { return }

        statusObserver = currentPlayerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self = self else { return }

            if item.status == .readyToPlay {
                // Only update playerState if it's not already playing
                if self.playerState != .playing {
                    self.playerState = .readyToPlay
                }
                self.updateDuration(item.duration)
                self.getMediaSelectionOptions(currentPlayerItem: item)
                self.updateNowPlayingInfo()
            } else if item.status == .failed {
                self.playerState = .failed
            }
        }
    }

    private func observeItemPlayEnd(previousPlayerItem: AVPlayerItem? = nil, currentPlayerItem: AVPlayerItem?) {
        if let previousPlayerItem = previousPlayerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: previousPlayerItem)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didPlaybackEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: currentPlayerItem
        )
    }

    @objc private func didPlaybackEnd() {
        playerState = .ended
        isPlaying = false

        // Auto play next video
        // Note: AVQueuePlayer automatically advances to the next item when current finishes
        // We just need to update our index, observe the new item, and start playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.handleAutoAdvance()
        }
    }

    private func handleAutoAdvance() {
        guard let player = player,
              let newCurrentItem = currentItem else { return }

        let items = player.items()

        // Check if queue is empty (was last video)
        if items.isEmpty {
            currentVideoIndex = 0
            return
        }

        // Update video index to match the new current item
        currentVideoIndex += 1

        // If we've reached the end, loop back to start
        if currentVideoIndex >= videos.count {
            currentVideoIndex = 0
        }

        // Observe the new current item
        observePlayerItem(currentPlayerItem: newCurrentItem)

        // Start playing the next video
        playPlayer()

        // Update now playing info for the new video
        updateNowPlayingInfo()
    }

    // MARK: - Media Selection Options

    private func getMediaSelectionOptions(currentPlayerItem: AVPlayerItem) {
        var audibleOptions = [DisplayNameLocale]()
        var legibleOptions = [DisplayNameLocale]()

        for characteristic in currentPlayerItem.asset.availableMediaCharacteristicsWithMediaSelectionOptions {
            if characteristic == .audible {
                audibleOptions = getMediaOptionDisplayDetail(currentPlayerItem: currentPlayerItem, characteristic: characteristic)
            }
            if characteristic == .legible {
                legibleOptions = getMediaOptionDisplayDetail(currentPlayerItem: currentPlayerItem, characteristic: characteristic)
            }
        }

        mediaOption = MediaOption(
            avMediaCharacteristicAudible: audibleOptions,
            avMediaCharacteristicLegible: legibleOptions
        )
    }

    private func getMediaOptionDisplayDetail(currentPlayerItem: AVPlayerItem, characteristic: AVMediaCharacteristic) -> [DisplayNameLocale] {
        var result = [DisplayNameLocale]()

        if let group = currentPlayerItem.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
            for option in group.options {
                let displayNameLocale = DisplayNameLocale(
                    displayName: option.displayName,
                    locale: option.locale
                )
                result.append(displayNameLocale)
            }
        }

        return result
    }

    // MARK: - UI Updates

    private func updateCurrentTime(_ time: CMTime) {
        let seconds = CMTimeGetSeconds(time)
        currentTime = TimeManager.floatToTimecodeString(seconds: Float(seconds)) + " /"
    }

    private func updateDuration(_ duration: CMTime) {
        let seconds = CMTimeGetSeconds(duration)
        self.duration = TimeManager.floatToTimecodeString(seconds: Float(seconds))

        // Update video duration in the list
        if currentVideoIndex < videos.count {
            videos[currentVideoIndex] = Video(
                title: videos[currentVideoIndex].title,
                url: videos[currentVideoIndex].url,
                thumbnailURL: videos[currentVideoIndex].thumbnailURL,
                duration: seconds,
                description: videos[currentVideoIndex].description
            )
        }
    }

    private func updateProgress(currentTime: CMTime, duration: CMTime) {
        guard duration >= currentTime else { return }
        let current = CMTimeGetSeconds(currentTime)
        let total = CMTimeGetSeconds(duration)
        playProgress = Float(current / total)
    }

    // MARK: - Cleanup

    private func cleanup() {
        removePeriodicTimeObserver()
        isPlaybackBufferEmptyObserver?.invalidate()
        isPlaybackBufferFullObserver?.invalidate()
        isPlaybackLikelyToKeepUpObserver?.invalidate()
        statusObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
