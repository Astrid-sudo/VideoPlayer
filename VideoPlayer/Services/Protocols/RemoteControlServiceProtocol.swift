//
//  RemoteControlServiceProtocol.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// 遠程控制服務協議
/// 純 Swift 協議，不依賴 MediaPlayer
protocol RemoteControlServiceProtocol: AnyObject {

    /// 設定遠程控制命令的回調
    func setupCommands(handlers: RemoteCommandHandlers)

    /// 更新 Now Playing 資訊
    func updateNowPlayingInfo(_ info: NowPlayingInfo)

    /// 清除 Now Playing 資訊
    func clearNowPlayingInfo()
}

// MARK: - Supporting Types

/// 遠程控制命令回調
struct RemoteCommandHandlers {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    var onSkipForward: ((TimeInterval) -> Void)?
    var onSkipBackward: ((TimeInterval) -> Void)?
    var onChangePlaybackPosition: ((TimeInterval) -> Void)?

    init(
        onPlay: (() -> Void)? = nil,
        onPause: (() -> Void)? = nil,
        onTogglePlayPause: (() -> Void)? = nil,
        onNextTrack: (() -> Void)? = nil,
        onPreviousTrack: (() -> Void)? = nil,
        onSkipForward: ((TimeInterval) -> Void)? = nil,
        onSkipBackward: ((TimeInterval) -> Void)? = nil,
        onChangePlaybackPosition: ((TimeInterval) -> Void)? = nil
    ) {
        self.onPlay = onPlay
        self.onPause = onPause
        self.onTogglePlayPause = onTogglePlayPause
        self.onNextTrack = onNextTrack
        self.onPreviousTrack = onPreviousTrack
        self.onSkipForward = onSkipForward
        self.onSkipBackward = onSkipBackward
        self.onChangePlaybackPosition = onChangePlaybackPosition
    }
}

/// Now Playing 資訊
struct NowPlayingInfo {
    var title: String?
    var artist: String?
    var duration: TimeInterval?
    var elapsedTime: TimeInterval?
    var playbackRate: Float
    var artwork: NowPlayingArtwork?
    var usePlaceholderArtwork: Bool  // 是否使用預設 Artwork（由 Service 生成）

    init(
        title: String? = nil,
        artist: String? = nil,
        duration: TimeInterval? = nil,
        elapsedTime: TimeInterval? = nil,
        playbackRate: Float = 0.0,
        artwork: NowPlayingArtwork? = nil,
        usePlaceholderArtwork: Bool = false
    ) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate
        self.artwork = artwork
        self.usePlaceholderArtwork = usePlaceholderArtwork
    }
}

/// Now Playing 封面圖
struct NowPlayingArtwork {
    let imageData: Data
    let size: CGSize

    init(imageData: Data, size: CGSize) {
        self.imageData = imageData
        self.size = size
    }
}
