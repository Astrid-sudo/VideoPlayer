//
//  PlayerServiceProtocol.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import Combine

/// 播放器服務協議
/// 依賴 Foundation 和 Combine
protocol PlayerServiceProtocol: AnyObject {

    // MARK: - Player Access

    /// 底層播放器（供 View 層使用，需自行轉型為 AVPlayer）
    var underlyingPlayer: Any? { get }

    // MARK: - State

    /// 當前播放項目的時長（秒）
    var currentItemDuration: TimeInterval? { get }

    /// 當前播放項目的播放時間（秒）
    var currentItemCurrentTime: TimeInterval? { get }

    /// 當前播放速度
    var currentRate: Float { get }

    // MARK: - Playback Control

    /// 播放
    func play()

    /// 暫停
    func pause()

    /// 跳轉到指定時間（秒）
    func seek(to seconds: TimeInterval)

    /// 設定播放速度
    func setRate(_ rate: Float)

    // MARK: - Queue Management

    /// 設定播放列表（從 URL 列表）
    func setPlaylist(urls: [URL])

    /// 從指定索引開始重建播放列表
    func rebuildQueue(from urls: [URL], startingAt index: Int)

    /// 前進到下一個項目
    func advanceToNextItem()

    // MARK: - Time Observation

    /// 開始週期性時間觀察
    func startTimeObservation(interval: TimeInterval)

    /// 停止時間觀察
    func stopTimeObservation()

    // MARK: - Publishers

    /// 播放時間更新
    var timePublisher: AnyPublisher<TimeInterval, Never> { get }

    /// 時長更新
    var durationPublisher: AnyPublisher<TimeInterval, Never> { get }

    /// 播放項目狀態變化
    var itemStatusPublisher: AnyPublisher<PlaybackItemStatus, Never> { get }

    /// 緩衝狀態變化
    var bufferingPublisher: AnyPublisher<BufferingState, Never> { get }

    /// 播放結束通知
    var playbackDidEndPublisher: AnyPublisher<Void, Never> { get }
}

// MARK: - Supporting Types

/// 播放項目狀態
enum PlaybackItemStatus {
    case unknown
    case readyToPlay
    case failed
}

/// 緩衝狀態
enum BufferingState {
    case bufferEmpty
    case bufferFull
    case likelyToKeepUp
}
