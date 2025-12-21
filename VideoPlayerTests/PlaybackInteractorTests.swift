//
//  PlaybackInteractorTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Testing
import Combine
import Foundation
@testable import VideoPlayer

@MainActor
struct PlaybackInteractorTests {

    // MARK: - Helper

    private func makeSUT(videos: [Video] = []) -> (sut: PlaybackInteractor, mockPlayer: MockPlayerService, mockAudio: MockAudioSessionService) {
        let mockPlayerService = MockPlayerService()
        let mockAudioSessionService = MockAudioSessionService()
        let sut = PlaybackInteractor(
            playerService: mockPlayerService,
            audioSessionService: mockAudioSessionService,
            videos: videos
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

    @Test func playSetsIsPlayingToTrue() async throws {
        let (sut, _, _) = makeSUT()
        sut.play()
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.isPlaying == true)
    }

    @Test func playStartsTimeObservation() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        try await Task.sleep(for: .milliseconds(50))
        #expect(mockPlayer.startTimeObservationInterval == PlayerConstants.timeObservationInterval)
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

    @Test func pauseSetsIsPlayingToFalse() async throws {
        let (sut, _, _) = makeSUT()
        sut.play()
        try await Task.sleep(for: .milliseconds(50))
        sut.pause()
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.isPlaying == false)
    }

    @Test func pauseStopsTimeObservation() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        try await Task.sleep(for: .milliseconds(50))
        sut.pause()
        try await Task.sleep(for: .milliseconds(50))
        #expect(mockPlayer.stopTimeObservationCallCount == 1)
    }

    // MARK: - Toggle Play Tests

    @Test func togglePlayFromPausedStatePlays() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        sut.togglePlay()
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.isPlaying == true)
        #expect(mockPlayer.playCallCount == 1)
    }

    @Test func togglePlayFromPlayingStatePauses() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        try await Task.sleep(for: .milliseconds(50))
        sut.togglePlay()
        try await Task.sleep(for: .milliseconds(50))
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

    @Test func setSpeedWhilePlayingCallsSetRate() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        try await Task.sleep(for: .milliseconds(50))
        mockPlayer.setRateValue = nil // reset
        sut.setSpeed(2.0)
        #expect(mockPlayer.setRateValue == 2.0)
    }

    // Setting rate on a paused player would cause it to start playing.
    // Speed should only be stored and applied when play() is called.
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

    // When playback ends, it should loop back to the first video and continue playing
    @Test func playbackDidEndContinuesPlayingWithLoop() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        sut.play()
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.isPlaying == true)
        mockPlayer.playbackDidEndSubject.send()
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.isPlaying == true)
    }

    // MARK: - Playback End Tests

    // When a video ends in the middle of playlist, index should advance and rate should be maintained
    @Test func playbackDidEndAtMiddleVideoAdvancesIndexAndMaintainsRate() async throws {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)
        sut.setSpeed(1.5)
        sut.play()
        try await Task.sleep(for: .milliseconds(50))
        mockPlayer.setRateValue = nil

        mockPlayer.playbackDidEndSubject.send()
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.currentIndex == 1)
        #expect(mockPlayer.setRateValue == 1.5)
    }

    // MARK: - External Control Tests

    // When external control (e.g., PiP) starts playback, time observation should start
    @Test func externalPlayControlStartsTimeObservation() async throws {
        let (sut, mockPlayer, _) = makeSUT()

        mockPlayer.isPlayingSubject.send(true)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.isPlaying == true)
        #expect(mockPlayer.startTimeObservationInterval == PlayerConstants.timeObservationInterval)
    }

    // When external control (e.g., PiP) pauses playback, time observation should stop
    @Test func externalPauseControlStopsTimeObservation() async throws {
        let (sut, mockPlayer, _) = makeSUT()
        mockPlayer.isPlayingSubject.send(true)
        try await Task.sleep(for: .milliseconds(50))

        mockPlayer.isPlayingSubject.send(false)
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.isPlaying == false)
        #expect(mockPlayer.stopTimeObservationCallCount == 1)
    }

    // MARK: - Playlist Tests

    @Test func initSetsPlaylistOnPlayerService() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (_, mockPlayer, _) = makeSUT(videos: videos)
        #expect(mockPlayer.setPlaylistUrls?.count == 3)
    }

    @Test func playVideoAtSameIndexSeeksToZero() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)

        sut.playVideo(at: 0)

        #expect(mockPlayer.seekToSeconds == 0)
        #expect(sut.currentIndex == 0)
    }

    @Test func playVideoAtNextIndexAdvancesToNextItem() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)

        sut.playVideo(at: 1)

        #expect(mockPlayer.advanceToNextItemCallCount == 1)
        #expect(sut.currentIndex == 1)
    }

    @Test func playVideoAtOtherIndexRebuildsQueue() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)

        sut.playVideo(at: 2)

        #expect(mockPlayer.rebuildQueueStartIndex == 2)
        #expect(sut.currentIndex == 2)
    }

    @Test func playVideoAtInvalidIndexDoesNothing() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)
        mockPlayer.reset()

        sut.playVideo(at: 10)

        #expect(mockPlayer.playCallCount == 0)
        #expect(sut.currentIndex == 0)
    }

    @Test func playVideoAtNegativeIndexDoesNothing() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)
        mockPlayer.reset()

        sut.playVideo(at: -1)

        #expect(mockPlayer.playCallCount == 0)
        #expect(sut.currentIndex == 0)
    }

    @Test func playNextVideoAdvancesToNextItem() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)

        sut.playNextVideo()

        #expect(mockPlayer.advanceToNextItemCallCount == 1)
        #expect(sut.currentIndex == 1)
    }

    @Test func playNextVideoAtLastIndexLoopsToFirst() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)
        sut.playVideo(at: 2)
        mockPlayer.reset()

        sut.playNextVideo()

        #expect(mockPlayer.rebuildQueueStartIndex == 0)
        #expect(sut.currentIndex == 0)
    }

    @Test func playPreviousVideoGoesToPreviousIndex() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)
        sut.playVideo(at: 2)
        mockPlayer.reset()

        sut.playPreviousVideo()

        #expect(sut.currentIndex == 1)
    }

    @Test func playPreviousVideoAtFirstIndexLoopsToLast() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, _, _) = makeSUT(videos: videos)

        sut.playPreviousVideo()

        #expect(sut.currentIndex == 2)
    }

    @Test func updateVideoDurationUpdatesVideoAtIndex() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, _, _) = makeSUT(videos: videos)

        sut.updateVideoDuration(120.5, at: 1)

        #expect(sut.videos[1].duration == 120.5)
    }

    @Test func updateVideoDurationAtInvalidIndexDoesNothing() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, _, _) = makeSUT(videos: videos)

        sut.updateVideoDuration(120.5, at: 10)

        // Should not crash, videos remain unchanged
        #expect(sut.videos.count == 3)
    }

    @Test func reloadCurrentVideoRebuildsQueue() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, mockPlayer, _) = makeSUT(videos: videos)
        sut.playVideo(at: 1)
        mockPlayer.reset()

        sut.reloadCurrentVideo()

        #expect(mockPlayer.rebuildQueueStartIndex == 1)
        #expect(mockPlayer.playCallCount == 1)
    }

    @Test func currentVideoReturnsCorrectVideo() {
        let videos = PlaybackInteractorTests.sampleVideos
        let (sut, _, _) = makeSUT(videos: videos)

        sut.playVideo(at: 1)

        #expect(sut.currentVideo?.title == "Video 2")
    }

    @Test func currentVideoReturnsNilForEmptyPlaylist() {
        let (sut, _, _) = makeSUT(videos: [])

        #expect(sut.currentVideo == nil)
    }

    // MARK: - Sample Data

    private static let sampleVideos: [Video] = [
        Video(title: "Video 1", url: "https://example.com/1.m3u8", description: "Desc 1"),
        Video(title: "Video 2", url: "https://example.com/2.m3u8", description: "Desc 2"),
        Video(title: "Video 3", url: "https://example.com/3.m3u8", description: "Desc 3")
    ]
}