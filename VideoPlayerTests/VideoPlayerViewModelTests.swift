//
//  VideoPlayerViewModelTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/21.
//

import Testing
import Combine
import Foundation
@testable import VideoPlayer

@MainActor
struct VideoPlayerViewModelTests {

    // MARK: - Helper

    private func makeSUT() -> (
        sut: VideoPlayerViewModel,
        mockPlayer: MockPlayerService,
        mockRemote: MockRemoteControlService,
        mockNetwork: MockNetworkMonitor
    ) {
        let mockPlayerService = MockPlayerService()
        let mockAudioSessionService = MockAudioSessionService()
        let mockRemoteControlService = MockRemoteControlService()
        let mockNetworkMonitor = MockNetworkMonitor()

        let testVideos = [
            Video(title: "Video 1", url: "https://example.com/1.m3u8", description: "Desc 1"),
            Video(title: "Video 2", url: "https://example.com/2.m3u8", description: "Desc 2"),
            Video(title: "Video 3", url: "https://example.com/3.m3u8", description: "Desc 3")
        ]

        let sut = VideoPlayerViewModel(
            playerService: mockPlayerService,
            layerConnector: mockPlayerService,
            audioSessionService: mockAudioSessionService,
            remoteControlService: mockRemoteControlService,
            networkMonitor: mockNetworkMonitor,
            videos: testVideos
        )

        return (sut, mockPlayerService, mockRemoteControlService, mockNetworkMonitor)
    }

    // MARK: - Player State Tests (updatePlayerState)

    @Test func playerStateIsLoadingWhenItemStatusIsUnknown() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.itemStatusSubject.send(.unknown)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.playerState == .loading)
    }

    @Test func playerStateIsFailedWhenItemStatusIsFailed() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()
        let testError = NSError(domain: "test", code: -1)

        mockPlayer.itemStatusSubject.send(.failed(testError))
        try await Task.sleep(for: .milliseconds(50))

        if case .failed = sut.playerState {
            // Expected
        } else {
            Issue.record("Expected .failed state but got \(sut.playerState)")
        }
    }

    @Test func playerStateIsLoadingWhenReadyButBufferEmpty() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.itemStatusSubject.send(.readyToPlay)
        mockPlayer.bufferingSubject.send(.bufferEmpty)
        mockPlayer.isPlayingSubject.send(false)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.playerState == .loading)
    }

    @Test func playerStateIsPlayingWhenReadyAndPlaying() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.itemStatusSubject.send(.readyToPlay)
        mockPlayer.bufferingSubject.send(.likelyToKeepUp)
        mockPlayer.isPlayingSubject.send(true)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.playerState == .playing)
    }

    @Test func playerStateIsPausedWhenReadyAndNotPlaying() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.itemStatusSubject.send(.readyToPlay)
        mockPlayer.bufferingSubject.send(.likelyToKeepUp)
        mockPlayer.isPlayingSubject.send(false)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.playerState == .paused)
    }

    // MARK: - Slider Touch Ended Tests

    @Test func sliderTouchEndedAtMaxValuePauses() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        // Setup playing state
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        mockPlayer.bufferingSubject.send(.likelyToKeepUp)
        mockPlayer.isPlayingSubject.send(true)
        try await Task.sleep(for: .milliseconds(50))
        mockPlayer.reset()

        sut.sliderTouchEnded(1.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockPlayer.pauseCallCount == 1)
    }

    @Test func sliderTouchEndedAtMaxValueDoesNotPlay() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.bufferingSubject.send(.likelyToKeepUp)
        try await Task.sleep(for: .milliseconds(50))
        mockPlayer.reset()

        sut.sliderTouchEnded(1.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockPlayer.playCallCount == 0)
    }

    @Test func sliderTouchEndedPlaysWhenBufferReady() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.bufferingSubject.send(.likelyToKeepUp)
        try await Task.sleep(for: .milliseconds(50))
        mockPlayer.reset()

        sut.sliderTouchEnded(0.5)
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockPlayer.playCallCount == 1)
    }

    @Test func sliderTouchEndedDoesNotPlayWhenBufferEmpty() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.bufferingSubject.send(.bufferEmpty)
        try await Task.sleep(for: .milliseconds(50))
        mockPlayer.reset()

        sut.sliderTouchEnded(0.5)
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockPlayer.playCallCount == 0)
    }

    // MARK: - Network Recovery Tests

    @Test func networkRecoveryReloadsVideoOnNetworkError() async throws {
        let (sut, mockPlayer, _, mockNetwork) = makeSUT()

        // Simulate network error state
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet
        )
        mockPlayer.itemStatusSubject.send(.failed(networkError))
        try await Task.sleep(for: .milliseconds(50))

        // Verify we're in failed state with network error
        if case .failed(let error) = sut.playerState,
           let playerError = error as? PlayerError {
            #expect(playerError.isNetworkError == true)
        } else {
            Issue.record("Expected .failed state with PlayerError")
        }

        mockPlayer.reset()

        // Simulate network recovery
        mockNetwork.simulateNetworkConnected()
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockPlayer.rebuildQueueStartIndex == 0)
        #expect(mockPlayer.playCallCount == 1)
    }

    @Test func networkRecoveryDoesNotReloadOnNonNetworkError() async throws {
        let (sut, mockPlayer, _, mockNetwork) = makeSUT()
        _ = sut // Keep ViewModel alive

        // Simulate non-network error
        let genericError = NSError(domain: "test", code: -1)
        mockPlayer.itemStatusSubject.send(.failed(genericError))
        try await Task.sleep(for: .milliseconds(50))

        mockPlayer.reset()

        // Simulate network recovery
        mockNetwork.simulateNetworkConnected()
        try await Task.sleep(for: .milliseconds(50))

        // Should not reload because error is not network-related
        #expect(mockPlayer.rebuildQueueStartIndex == nil)
        #expect(mockPlayer.playCallCount == 0)
    }

    @Test func networkRecoveryDoesNotReloadWhenPlaying() async throws {
        let (sut, mockPlayer, _, mockNetwork) = makeSUT()

        // Setup playing state
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        mockPlayer.bufferingSubject.send(.likelyToKeepUp)
        mockPlayer.isPlayingSubject.send(true)
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.playerState == .playing)

        mockPlayer.reset()

        // Simulate network recovery
        mockNetwork.simulateNetworkConnected()
        try await Task.sleep(for: .milliseconds(50))

        // Should not reload when already playing
        #expect(mockPlayer.rebuildQueueStartIndex == nil)
    }

    // MARK: - Progress Binding Tests

    @Test func progressStaysZeroWhenDurationIsZero() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.durationSubject.send(0)
        mockPlayer.timeSubject.send(25)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.playProgress == 0)
    }

    // MARK: - Time Display Tests

    @Test func currentTimeUpdatesFromPlaybackManager() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.timeSubject.send(65) // 1:05
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.currentTime == "01:05 /")
    }

    @Test func durationUpdatesFromPlaybackManager() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.durationSubject.send(3661) // 1:01:01
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.duration == "01:01:01")
    }

    // MARK: - PiP Binding Tests

    @Test func isPiPAvailableUpdatesFromLayerConnector() async throws {
        let (sut, mockPlayer, _, _) = makeSUT()

        mockPlayer.isPiPPossibleSubject.send(true)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.isPiPAvailable == true)
    }

    // MARK: - Now Playing Info Tests

    @Test func playerStateChangeUpdatesNowPlayingInfo() async throws {
        let (sut, mockPlayer, mockRemote, _) = makeSUT()
        _ = sut // Keep ViewModel alive
        mockRemote.reset()

        mockPlayer.itemStatusSubject.send(.readyToPlay)
        mockPlayer.bufferingSubject.send(.likelyToKeepUp)
        mockPlayer.isPlayingSubject.send(true)
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockRemote.updateNowPlayingInfoCallCount >= 1)
    }
}
