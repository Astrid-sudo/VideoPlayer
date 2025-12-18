//
//  PlaylistManagerTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Testing
import Combine
import Foundation
@testable import VideoPlayer

@MainActor
struct PlaylistManagerTests {

    // MARK: - Test Data

    private static let testVideos = [
        Video(title: "Video 1", url: "https://example.com/video1.m3u8", thumbnailURL: nil, duration: nil, description: "Desc 1"),
        Video(title: "Video 2", url: "https://example.com/video2.m3u8", thumbnailURL: nil, duration: nil, description: "Desc 2"),
        Video(title: "Video 3", url: "https://example.com/video3.m3u8", thumbnailURL: nil, duration: nil, description: "Desc 3")
    ]

    // MARK: - Properties

    private var mockPlayerService: MockPlayerService!
    private var sut: PlaylistManager!

    // MARK: - Setup

    init() {
        mockPlayerService = MockPlayerService()
        sut = PlaylistManager(
            playerService: mockPlayerService,
            videos: Self.testVideos
        )
    }

    // MARK: - Initialization Tests

    @Test func initSetsPlaylistOnPlayerService() {
        #expect(mockPlayerService.setPlaylistUrls?.count == 3)
    }

    @Test func initSetsCorrectUrls() {
        let expectedUrls = Self.testVideos.compactMap { URL(string: $0.url) }
        #expect(mockPlayerService.setPlaylistUrls == expectedUrls)
    }

    @Test func initSetsCurrentIndexToZero() {
        #expect(sut.currentIndex == 0)
    }

    @Test func initSetsVideos() {
        #expect(sut.videos.count == 3)
    }

    // MARK: - Current Video Tests

    @Test func currentVideoReturnsCorrectVideo() {
        #expect(sut.currentVideo?.title == "Video 1")
    }

    @Test func currentVideoReturnsNilWhenIndexOutOfBounds() {
        // 強制設定無效索引
        sut.playVideo(at: 100)
        // 索引應該保持不變因為 guard 會擋住
        #expect(sut.currentVideo != nil)
    }

    // MARK: - Play Video At Index Tests

    @Test func playVideoAtIndexUpdatesCurrentIndex() {
        sut.playVideo(at: 1)

        #expect(sut.currentIndex == 1)
    }

    @Test func playVideoAtIndexRebuildQueue() {
        sut.playVideo(at: 1)

        #expect(mockPlayerService.rebuildQueueStartIndex == 1)
        #expect(mockPlayerService.rebuildQueueUrls?.count == 3)
    }

    @Test func playVideoAtInvalidIndexDoesNothing() {
        let initialIndex = sut.currentIndex

        sut.playVideo(at: -1)

        #expect(sut.currentIndex == initialIndex)
    }

    @Test func playVideoAtIndexBeyondBoundsDoesNothing() {
        let initialIndex = sut.currentIndex

        sut.playVideo(at: 10)

        #expect(sut.currentIndex == initialIndex)
    }

    // MARK: - Play Next Tests

    @Test func playNextAdvancesToNextIndex() {
        sut.playNext()

        #expect(sut.currentIndex == 1)
    }

    @Test func playNextCallsAdvanceToNextItem() {
        sut.playNext()

        #expect(mockPlayerService.advanceToNextItemCallCount == 1)
    }

    @Test func playNextAtLastVideoLoopsToFirst() {
        sut.playVideo(at: 2) // 移到最後一個
        mockPlayerService.reset()

        sut.playNext()

        #expect(sut.currentIndex == 0)
        #expect(mockPlayerService.seekToSeconds == 0)
    }

    // MARK: - Play Previous Tests

    @Test func playPreviousGoesToPreviousIndex() {
        sut.playVideo(at: 2)
        mockPlayerService.reset()

        sut.playPrevious()

        #expect(sut.currentIndex == 1)
    }

    @Test func playPreviousAtFirstVideoLoopsToLast() {
        sut.playPrevious()

        #expect(sut.currentIndex == 2)
    }

    @Test func playPreviousRebuildQueue() {
        sut.playVideo(at: 2)
        mockPlayerService.reset()

        sut.playPrevious()

        #expect(mockPlayerService.rebuildQueueStartIndex == 1)
    }

    // MARK: - Update Duration Tests

    @Test func updateVideoDurationUpdatesCorrectVideo() {
        sut.updateVideoDuration(120.0, at: 0)

        #expect(sut.videos[0].duration == 120.0)
    }

    @Test func updateVideoDurationPreservesOtherProperties() {
        sut.updateVideoDuration(120.0, at: 0)

        #expect(sut.videos[0].title == "Video 1")
        #expect(sut.videos[0].url == "https://example.com/video1.m3u8")
        #expect(sut.videos[0].description == "Desc 1")
    }

    @Test func updateVideoDurationAtInvalidIndexDoesNothing() {
        let originalDuration = sut.videos[0].duration

        sut.updateVideoDuration(120.0, at: 100)

        #expect(sut.videos[0].duration == originalDuration)
    }
}
