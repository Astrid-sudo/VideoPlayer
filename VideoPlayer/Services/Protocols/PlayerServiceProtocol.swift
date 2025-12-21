//
//  PlayerServiceProtocol.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import Combine

/// Protocol defining player service capabilities.
protocol PlayerServiceProtocol: AnyObject {

    // MARK: - State

    var currentItemDuration: TimeInterval? { get }
    var currentItemCurrentTime: TimeInterval? { get }
    var currentRate: Float { get }

    // MARK: - Playback Control

    func play()
    func pause()
    func seek(to seconds: TimeInterval)
    func setRate(_ rate: Float)

    // MARK: - Queue Management

    func setPlaylist(urls: [URL])
    func rebuildQueue(from urls: [URL], startingAt index: Int)
    func advanceToNextItem()

    // MARK: - Time Observation

    func startTimeObservation(interval: TimeInterval)
    func stopTimeObservation()

    // MARK: - Publishers

    var timePublisher: AnyPublisher<TimeInterval, Never> { get }
    var durationPublisher: AnyPublisher<TimeInterval, Never> { get }
    var itemStatusPublisher: AnyPublisher<PlaybackItemStatus, Never> { get }
    var bufferingPublisher: AnyPublisher<BufferingState, Never> { get }
    var playbackDidEndPublisher: AnyPublisher<Void, Never> { get }
    var isPlayingPublisher: AnyPublisher<Bool, Never> { get }

    // MARK: - Media Options

    func getMediaOptions() async -> MediaSelectionOptions?
    func selectMediaOption(type: MediaSelectionType, locale: Locale?) async
}

// MARK: - Supporting Types

/// Media selection type for audio or subtitle.
enum MediaSelectionType {
    case audio
    case subtitle
}

/// Media selection option with display name and locale.
struct MediaSelectionOption {
    let displayName: String
    let locale: Locale?
}

/// Collection of available media options.
struct MediaSelectionOptions {
    let audioOptions: [MediaSelectionOption]
    let subtitleOptions: [MediaSelectionOption]
}

/// Playback item status.
enum PlaybackItemStatus: Equatable {
    case unknown
    case readyToPlay
    case failed(Error?)

    static func == (lhs: PlaybackItemStatus, rhs: PlaybackItemStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.readyToPlay, .readyToPlay):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

/// Buffering state.
enum BufferingState {
    case bufferEmpty
    case bufferFull
    case likelyToKeepUp
}
