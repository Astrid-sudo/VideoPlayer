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
            onPlay: { [weak self] in self?.onPlay?() },
            onPause: { [weak self] in self?.onPause?() },
            onTogglePlayPause: { [weak self] in self?.onTogglePlayPause?() },
            onNextTrack: { [weak self] in self?.onNextTrack?() },
            onPreviousTrack: { [weak self] in self?.onPreviousTrack?() },
            onSkipForward: { [weak self] seconds in self?.onSkipForward?(seconds) },
            onSkipBackward: { [weak self] seconds in self?.onSkipBackward?(seconds) },
            onChangePlaybackPosition: { [weak self] position in self?.onSeekToPosition?(position) }
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
