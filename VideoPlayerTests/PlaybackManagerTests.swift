//
//  PlaybackManagerTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Testing
import Combine
import Foundation
@testable import VideoPlayer

@MainActor
struct PlaybackManagerTests {

    // MARK: - Helper

    private func makeSUT() -> (sut: PlaybackManager, mockPlayer: MockPlayerService, mockAudio: MockAudioSessionService) {
        let mockPlayerService = MockPlayerService()
        let mockAudioSessionService = MockAudioSessionService()
        let sut = PlaybackManager(
            playerService: mockPlayerService,
            audioSessionService: mockAudioSessionService
        )
        return (sut, mockPlayerService, mockAudioSessionService)
    }

    // MARK: - Audio Session Tests

    @Test func initActivatesAudioSession() {
        let (_, _, mockAudio) = makeSUT()
        #expect(mockAudio.activateCallCount == 1)
    }

    // MARK: - Play Tests

    @Test func playCallsPlayerServicePlay() {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        #expect(mockPlayer.playCallCount == 1)
    }

    @Test func playSetsIsPlayingToTrue() {
        let (sut, _, _) = makeSUT()
        sut.play()
        #expect(sut.isPlaying == true)
    }

    @Test func playStartsTimeObservation() {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        #expect(mockPlayer.startTimeObservationInterval == 0.5)
    }

    @Test func playSetsCorrectRate() {
        let (sut, mockPlayer, _) = makeSUT()
        sut.setSpeed(1.5)
        sut.play()
        #expect(mockPlayer.setRateValue == 1.5)
    }

    // MARK: - Pause Tests

    @Test func pauseCallsPlayerServicePause() {
        let (sut, mockPlayer, _) = makeSUT()
        sut.pause()
        #expect(mockPlayer.pauseCallCount == 1)
    }

    @Test func pauseSetsIsPlayingToFalse() {
        let (sut, _, _) = makeSUT()
        sut.play()
        sut.pause()
        #expect(sut.isPlaying == false)
    }

    @Test func pauseStopsTimeObservation() {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        sut.pause()
        #expect(mockPlayer.stopTimeObservationCallCount == 1)
    }

    // MARK: - Toggle Play Tests

    @Test func togglePlayFromPausedStatePlays() {
        let (sut, mockPlayer, _) = makeSUT()
        sut.togglePlay()
        #expect(sut.isPlaying == true)
        #expect(mockPlayer.playCallCount == 1)
    }

    @Test func togglePlayFromPlayingStatePauses() {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        sut.togglePlay()
        #expect(sut.isPlaying == false)
        #expect(mockPlayer.pauseCallCount == 1)
    }

    // MARK: - Seek Tests

    @Test func seekCallsPlayerServiceSeek() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.durationSubject.send(100)
        try await Task.sleep(for: .milliseconds(50))
        sut.seek(to: 50)
        #expect(mockPlayer.seekToSeconds == 50)
    }

    @Test func seekClampsToZeroWhenNegative() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.durationSubject.send(100)
        try await Task.sleep(for: .milliseconds(50))
        sut.seek(to: -10)
        #expect(mockPlayer.seekToSeconds == 0)
    }

    @Test func seekClampsToDurationWhenExceeds() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.durationSubject.send(100)
        try await Task.sleep(for: .milliseconds(50))
        sut.seek(to: 150)
        #expect(mockPlayer.seekToSeconds == 100)
    }

    // MARK: - Skip Tests

    @Test func skipForwardAddsToCurrentTime() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.durationSubject.send(100)
        mockPlayer.timeSubject.send(30)
        try await Task.sleep(for: .milliseconds(50))
        sut.skipForward(15)
        #expect(mockPlayer.seekToSeconds == 45)
    }

    @Test func skipBackwardSubtractsFromCurrentTime() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.durationSubject.send(100)
        mockPlayer.timeSubject.send(30)
        try await Task.sleep(for: .milliseconds(50))
        sut.skipBackward(15)
        #expect(mockPlayer.seekToSeconds == 15)
    }

    @Test func skipBackwardClampsToZero() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.durationSubject.send(100)
        mockPlayer.timeSubject.send(5)
        try await Task.sleep(for: .milliseconds(50))
        sut.skipBackward(15)
        #expect(mockPlayer.seekToSeconds == 0)
    }

    // MARK: - Set Speed Tests

    @Test func setSpeedUpdatesCurrentRate() {
        let (sut, _, _) = makeSUT()
        sut.setSpeed(1.5)
        #expect(sut.currentRate == 1.5)
    }

    @Test func setSpeedWhilePlayingCallsSetRate() {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        mockPlayer.setRateValue = nil // reset
        sut.setSpeed(2.0)
        #expect(mockPlayer.setRateValue == 2.0)
    }

    @Test func setSpeedWhilePausedDoesNotCallSetRate() {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.setRateValue = nil
        sut.setSpeed(2.0)
        #expect(mockPlayer.setRateValue == nil)
    }

    // MARK: - Binding Tests

    @Test func timePublisherUpdatesCurrentTime() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.timeSubject.send(42.5)
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.currentTime == 42.5)
    }

    @Test func durationPublisherUpdatesDuration() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.durationSubject.send(120.0)
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.duration == 120.0)
    }

    @Test func itemStatusPublisherUpdatesStatus() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.itemStatus == .readyToPlay)
    }

    @Test func bufferingPublisherUpdatesBufferingState() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.bufferingSubject.send(.bufferEmpty)
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.bufferingState == .bufferEmpty)
    }

    @Test func playbackDidEndSetsIsPlayingToFalse() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        #expect(sut.isPlaying == true)
        mockPlayer.playbackDidEndSubject.send()
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.isPlaying == false)
    }
}