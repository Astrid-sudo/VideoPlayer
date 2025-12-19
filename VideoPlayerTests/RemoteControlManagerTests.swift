//
//  RemoteControlManagerTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Testing
import Foundation
@testable import VideoPlayer

@MainActor
struct RemoteControlManagerTests {

    // MARK: - Helper

    private func makeSUT() -> (sut: RemoteControlManager, mockService: MockRemoteControlService) {
        let mockService = MockRemoteControlService()
        let sut = RemoteControlManager(remoteControlService: mockService)
        return (sut, mockService)
    }

    // MARK: - Setup Commands Tests

    @Test func setupCommandsCallsService() {
        let (sut, mockService) = makeSUT()
        sut.setupCommands()
        #expect(mockService.setupCommandsCallCount == 1)
    }

    @Test func setupCommandsPassesHandlers() {
        let (sut, mockService) = makeSUT()
        sut.setupCommands()
        #expect(mockService.lastHandlers != nil)
    }

    // MARK: - Callback Tests

    @Test func onPlayCallbackIsTriggered() {
        let (sut, mockService) = makeSUT()
        var callbackTriggered = false
        sut.onPlay = { callbackTriggered = true }
        sut.setupCommands()

        mockService.simulatePlayCommand()

        #expect(callbackTriggered == true)
    }

    @Test func onPauseCallbackIsTriggered() {
        let (sut, mockService) = makeSUT()
        var callbackTriggered = false
        sut.onPause = { callbackTriggered = true }
        sut.setupCommands()

        mockService.simulatePauseCommand()

        #expect(callbackTriggered == true)
    }

    @Test func onTogglePlayPauseCallbackIsTriggered() {
        let (sut, mockService) = makeSUT()
        var callbackTriggered = false
        sut.onTogglePlayPause = { callbackTriggered = true }
        sut.setupCommands()

        mockService.simulateTogglePlayPauseCommand()

        #expect(callbackTriggered == true)
    }

    @Test func onNextTrackCallbackIsTriggered() {
        let (sut, mockService) = makeSUT()
        var callbackTriggered = false
        sut.onNextTrack = { callbackTriggered = true }
        sut.setupCommands()

        mockService.simulateNextTrackCommand()

        #expect(callbackTriggered == true)
    }

    @Test func onSkipForwardCallbackIsTriggeredWithCorrectSeconds() {
        let (sut, mockService) = makeSUT()
        var receivedSeconds: TimeInterval?
        sut.onSkipForward = { seconds in receivedSeconds = seconds }
        sut.setupCommands()

        mockService.simulateSkipForwardCommand(seconds: 15)

        #expect(receivedSeconds == 15)
    }

    @Test func onSkipBackwardCallbackIsTriggeredWithCorrectSeconds() {
        let (sut, mockService) = makeSUT()
        var receivedSeconds: TimeInterval?
        sut.onSkipBackward = { seconds in receivedSeconds = seconds }
        sut.setupCommands()

        mockService.simulateSkipBackwardCommand(seconds: 10)

        #expect(receivedSeconds == 10)
    }

    // MARK: - Update Now Playing Info Tests

    @Test func updateNowPlayingInfoCallsService() {
        let (sut, mockService) = makeSUT()

        sut.updateNowPlayingInfo(
            title: "Test Title",
            artist: "Test Artist",
            duration: 120,
            elapsedTime: 30,
            playbackRate: 1.0
        )

        #expect(mockService.updateNowPlayingInfoCallCount == 1)
    }

    @Test func updateNowPlayingInfoPassesCorrectTitle() {
        let (sut, mockService) = makeSUT()

        sut.updateNowPlayingInfo(
            title: "Test Title",
            artist: nil,
            duration: nil,
            elapsedTime: nil,
            playbackRate: 1.0
        )

        #expect(mockService.lastNowPlayingInfo?.title == "Test Title")
    }

    @Test func updateNowPlayingInfoPassesCorrectDuration() {
        let (sut, mockService) = makeSUT()

        sut.updateNowPlayingInfo(
            title: nil,
            artist: nil,
            duration: 180.5,
            elapsedTime: nil,
            playbackRate: 1.0
        )

        #expect(mockService.lastNowPlayingInfo?.duration == 180.5)
    }

    @Test func updateNowPlayingInfoPassesCorrectElapsedTime() {
        let (sut, mockService) = makeSUT()

        sut.updateNowPlayingInfo(
            title: nil,
            artist: nil,
            duration: nil,
            elapsedTime: 45.0,
            playbackRate: 1.0
        )

        #expect(mockService.lastNowPlayingInfo?.elapsedTime == 45.0)
    }

    @Test func updateNowPlayingInfoPassesCorrectPlaybackRate() {
        let (sut, mockService) = makeSUT()

        sut.updateNowPlayingInfo(
            title: nil,
            artist: nil,
            duration: nil,
            elapsedTime: nil,
            playbackRate: 1.5
        )

        #expect(mockService.lastNowPlayingInfo?.playbackRate == 1.5)
    }

    @Test func updateNowPlayingInfoSetsUsePlaceholderArtwork() {
        let (sut, mockService) = makeSUT()

        sut.updateNowPlayingInfo(
            title: "Test",
            artist: nil,
            duration: nil,
            elapsedTime: nil,
            playbackRate: 1.0
        )

        #expect(mockService.lastNowPlayingInfo?.usePlaceholderArtwork == true)
    }

    // MARK: - Clear Now Playing Info Tests

    @Test func clearNowPlayingInfoCallsService() {
        let (sut, mockService) = makeSUT()

        sut.clearNowPlayingInfo()

        #expect(mockService.clearNowPlayingInfoCallCount == 1)
    }
}
