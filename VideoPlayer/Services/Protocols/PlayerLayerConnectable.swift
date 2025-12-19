//
//  PlayerLayerConnectable.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/19.
//

import AVFoundation
import Combine

/// 播放器 Layer 連接協議
/// 負責將播放器連接到 AVPlayerLayer，並管理 Picture in Picture
protocol PlayerLayerConnectable: AnyObject {

    // MARK: - Layer Connection

    /// 連接播放器到指定的 AVPlayerLayer（同時建立 PiP controller）
    func connect(layer: AVPlayerLayer)

    // MARK: - Picture in Picture

    /// PiP 是否可用
    var isPiPPossiblePublisher: AnyPublisher<Bool, Never> { get }

    /// PiP 是否正在播放
    var isPiPActivePublisher: AnyPublisher<Bool, Never> { get }

    /// 請求恢復 UI（當使用者從 PiP 返回 App 時）
    var restoreUIPublisher: AnyPublisher<Void, Never> { get }

    /// 開始 Picture in Picture
    func startPictureInPicture()

    /// 停止 Picture in Picture
    func stopPictureInPicture()

    /// 通知 PiP 已完成 UI 恢復
    func pictureInPictureUIRestored()
}
