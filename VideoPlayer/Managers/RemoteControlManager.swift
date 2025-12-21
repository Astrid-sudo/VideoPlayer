//
//  RemoteControlManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// 遠程控制業務邏輯
/// 依賴 RemoteControlServiceProtocol，不依賴 UIKit
final class RemoteControlManager {

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

    /// 設定遠程控制命令
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

    /// 更新 Now Playing 資訊
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
            usePlaceholderArtwork: true  // 讓 Service 生成預設 Artwork
        )

        remoteControlService.updateNowPlayingInfo(info)
    }

    /// 清除 Now Playing 資訊
    func clearNowPlayingInfo() {
        remoteControlService.clearNowPlayingInfo()
    }
}
