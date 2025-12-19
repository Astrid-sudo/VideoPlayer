//
//  MediaOptionsManagerTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Testing
import Combine
import Foundation
@testable import VideoPlayer

@MainActor
struct MediaOptionsManagerTests {

    // MARK: - Helper

    private func makeSUT() -> (sut: MediaOptionsManager, mockPlayer: MockPlayerService) {
        let mockPlayerService = MockPlayerService()
        let sut = MediaOptionsManager(playerService: mockPlayerService)
        return (sut, mockPlayerService)
    }

    // MARK: - Initialization Tests

    @Test func initSetsMediaOptionToNil() {
        let (sut, _) = makeSUT()
        #expect(sut.mediaOption == nil)
    }

    @Test func initSetsSelectedAudioIndexToNil() {
        let (sut, _) = makeSUT()
        #expect(sut.selectedAudioIndex == nil)
    }

    @Test func initSetsSelectedSubtitleIndexToNil() {
        let (sut, _) = makeSUT()
        #expect(sut.selectedSubtitleIndex == nil)
    }

    // MARK: - Binding Tests

    @Test func itemStatusReadyToPlayTriggersLoadMediaOptions() {
        let (sut, mockPlayer) = makeSUT()

        // 當沒有 underlying player 時，mediaOption 應該保持 nil
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        // 因為 underlyingPlayer 為 nil，mediaOption 應該被設為 nil
        #expect(sut.mediaOption == nil)
    }

    // MARK: - Select Option Tests (Without AVPlayer)

    @Test func selectOptionWithoutPlayerDoesNothing() {
        let (sut, _) = makeSUT()

        // 沒有 AVPlayer，操作應該安全地什麼都不做
        sut.selectOption(type: .audio, index: 0)

        #expect(sut.selectedAudioIndex == nil)
    }

    @Test func selectSubtitleOptionWithoutPlayerDoesNothing() {
        let (sut, _) = makeSUT()

        sut.selectOption(type: .subtitle, index: 0)

        #expect(sut.selectedSubtitleIndex == nil)
    }

    // MARK: - Reload Options Tests

    @Test func reloadOptionsWithoutPlayerSetsMediaOptionToNil() {
        let (sut, _) = makeSUT()

        sut.reloadOptions()

        #expect(sut.mediaOption == nil)
    }
}
