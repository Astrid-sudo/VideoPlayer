//
//  RemoteControlService.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import MediaPlayer
import UIKit

/// 遠程控制服務實作
/// 封裝 MPRemoteCommandCenter 和 MPNowPlayingInfoCenter，依賴 MediaPlayer（最外層）
final class RemoteControlService: RemoteControlServiceProtocol {

    // MARK: - Private Properties

    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

    private var handlers: RemoteCommandHandlers?

    // MARK: - Initialization

    init() {}

    deinit {
        removeAllTargets()
    }

    // MARK: - RemoteControlServiceProtocol

    func setupCommands(handlers: RemoteCommandHandlers) {
        self.handlers = handlers

        // 移除舊的 targets
        removeAllTargets()

        // Play
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.handlers?.onPlay?()
            return .success
        }

        // Pause
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.handlers?.onPause?()
            return .success
        }

        // Toggle Play/Pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handlers?.onTogglePlayPause?()
            return .success
        }

        // Next Track
        commandCenter.nextTrackCommand.isEnabled = handlers.onNextTrack != nil
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.handlers?.onNextTrack?()
            return .success
        }

        // Previous Track
        commandCenter.previousTrackCommand.isEnabled = handlers.onPreviousTrack != nil
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.handlers?.onPreviousTrack?()
            return .success
        }

        // Skip Forward (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = handlers.onSkipForward != nil
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.handlers?.onSkipForward?(15)
            return .success
        }

        // Skip Backward (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = handlers.onSkipBackward != nil
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.handlers?.onSkipBackward?(15)
            return .success
        }

        // Change Playback Position
        commandCenter.changePlaybackPositionCommand.isEnabled = handlers.onChangePlaybackPosition != nil
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.handlers?.onChangePlaybackPosition?(event.positionTime)
            return .success
        }
    }

    func updateNowPlayingInfo(_ info: NowPlayingInfo) {
        var nowPlayingInfo = [String: Any]()

        if let title = info.title {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }

        if let artist = info.artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }

        if let duration = info.duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let elapsedTime = info.elapsedTime {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = info.playbackRate

        if let artwork = info.artwork,
           let image = UIImage(data: artwork.imageData) {
            let mpArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mpArtwork
        }

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    func clearNowPlayingInfo() {
        nowPlayingInfoCenter.nowPlayingInfo = nil
    }

    // MARK: - Private Methods

    private func removeAllTargets() {
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }
}
