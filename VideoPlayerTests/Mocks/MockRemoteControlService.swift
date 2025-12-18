//
//  MockRemoteControlService.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
@testable import VideoPlayer

final class MockRemoteControlService: RemoteControlServiceProtocol {

    // MARK: - Spy Properties

    var setupCommandsCallCount = 0
    var lastHandlers: RemoteCommandHandlers?
    var updateNowPlayingInfoCallCount = 0
    var lastNowPlayingInfo: NowPlayingInfo?
    var clearNowPlayingInfoCallCount = 0

    // MARK: - Protocol Methods

    func setupCommands(handlers: RemoteCommandHandlers) {
        setupCommandsCallCount += 1
        lastHandlers = handlers
    }

    func updateNowPlayingInfo(_ info: NowPlayingInfo) {
        updateNowPlayingInfoCallCount += 1
        lastNowPlayingInfo = info
    }

    func clearNowPlayingInfo() {
        clearNowPlayingInfoCallCount += 1
    }

    // MARK: - Helper Methods

    func reset() {
        setupCommandsCallCount = 0
        lastHandlers = nil
        updateNowPlayingInfoCallCount = 0
        lastNowPlayingInfo = nil
        clearNowPlayingInfoCallCount = 0
    }

    // MARK: - Simulate Remote Commands (測試用)

    func simulatePlayCommand() {
        lastHandlers?.onPlay?()
    }

    func simulatePauseCommand() {
        lastHandlers?.onPause?()
    }

    func simulateTogglePlayPauseCommand() {
        lastHandlers?.onTogglePlayPause?()
    }

    func simulateNextTrackCommand() {
        lastHandlers?.onNextTrack?()
    }

    func simulateSkipForwardCommand(seconds: TimeInterval = 15) {
        lastHandlers?.onSkipForward?(seconds)
    }

    func simulateSkipBackwardCommand(seconds: TimeInterval = 15) {
        lastHandlers?.onSkipBackward?(seconds)
    }
}
