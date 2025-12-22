//
//  RemoteControlInteractor.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// Handles remote control commands for lock screen and Control Center.
final class RemoteControlInteractor {

    // MARK: - Dependencies

    private let remoteControlService: RemoteControlServiceProtocol

    // MARK: - Callbacks

    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    var onSkipForward: ((TimeInterval) -> Void)?
    var onSkipBackward: ((TimeInterval) -> Void)?
    var onSeekToPosition: ((TimeInterval) -> Void)?

    // MARK: - Initialization

    init(remoteControlService: RemoteControlServiceProtocol) {
        self.remoteControlService = remoteControlService
    }

    // MARK: - Public Methods

    /// Configures remote control command handlers.
    func setupCommands() {
        let handlers = RemoteCommandHandlers(
            onPlay: { [weak self] in
                AppLogger.remoteControl.info("Remote: Play")
                self?.onPlay?()
            },
            onPause: { [weak self] in
                AppLogger.remoteControl.info("Remote: Pause")
                self?.onPause?()
            },
            onTogglePlayPause: { [weak self] in
                AppLogger.remoteControl.info("Remote: Toggle play/pause")
                self?.onTogglePlayPause?()
            },
            onNextTrack: { [weak self] in
                AppLogger.remoteControl.info("Remote: Next track")
                self?.onNextTrack?()
            },
            onPreviousTrack: { [weak self] in
                AppLogger.remoteControl.info("Remote: Previous track")
                self?.onPreviousTrack?()
            },
            onSkipForward: { [weak self] seconds in
                AppLogger.remoteControl.info("Remote: Skip forward \(seconds)s")
                self?.onSkipForward?(seconds)
            },
            onSkipBackward: { [weak self] seconds in
                AppLogger.remoteControl.info("Remote: Skip backward \(seconds)s")
                self?.onSkipBackward?(seconds)
            },
            onChangePlaybackPosition: { [weak self] position in
                AppLogger.remoteControl.info("Remote: Seek to \(position)s")
                self?.onSeekToPosition?(position)
            }
        )

        remoteControlService.setupCommands(handlers: handlers)
    }

    /// Updates Now Playing info displayed on lock screen.
    func updateNowPlayingInfo(
        title: String?,
        artist: String?,
        duration: TimeInterval?,
        elapsedTime: TimeInterval?,
        playbackRate: Float
    ) {
        let info = NowPlayingInfo(
            title: title,
            artist: artist,
            duration: duration,
            elapsedTime: elapsedTime,
            playbackRate: playbackRate,
            artwork: nil,
            usePlaceholderArtwork: true  // Let Service generate placeholder artwork
        )

        remoteControlService.updateNowPlayingInfo(info)
    }

    /// Clears Now Playing info from lock screen.
    func clearNowPlayingInfo() {
        remoteControlService.clearNowPlayingInfo()
    }
}
