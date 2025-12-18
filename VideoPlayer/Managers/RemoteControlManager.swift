//
//  RemoteControlManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import UIKit

/// 遠程控制業務邏輯
/// 依賴 RemoteControlServiceProtocol
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
        let artwork = createPlaceholderArtwork()

        let info = NowPlayingInfo(
            title: title,
            artist: artist,
            duration: duration,
            elapsedTime: elapsedTime,
            playbackRate: playbackRate,
            artwork: artwork
        )

        remoteControlService.updateNowPlayingInfo(info)
    }

    /// 清除 Now Playing 資訊
    func clearNowPlayingInfo() {
        remoteControlService.clearNowPlayingInfo()
    }

    // MARK: - Private Methods

    private func createPlaceholderArtwork() -> NowPlayingArtwork? {
        let size = CGSize(width: 300, height: 300)

        let renderer = UIGraphicsImageRenderer(size: size)
        let placeholderImage = renderer.image { context in
            // 漸層背景
            let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 1.0]
            )

            if let gradient = gradient {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            // 播放圖示
            let playIconSize: CGFloat = 80
            let playIconRect = CGRect(
                x: (size.width - playIconSize) / 2,
                y: (size.height - playIconSize) / 2,
                width: playIconSize,
                height: playIconSize
            )

            let config = UIImage.SymbolConfiguration(pointSize: playIconSize, weight: .light)
            if let playIcon = UIImage(systemName: "play.circle.fill", withConfiguration: config) {
                playIcon.withTintColor(.white, renderingMode: .alwaysTemplate)
                    .draw(in: playIconRect, blendMode: .normal, alpha: 0.8)
            }
        }

        guard let imageData = placeholderImage.pngData() else { return nil }
        return NowPlayingArtwork(imageData: imageData, size: size)
    }
}
