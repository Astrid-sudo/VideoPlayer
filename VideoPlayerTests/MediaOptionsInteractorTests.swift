//
//  MediaOptionsInteractorTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Testing
import Combine
import Foundation
@testable import VideoPlayer

@MainActor
struct MediaOptionsInteractorTests {

    // MARK: - Helper

    private func makeSUT() -> (sut: MediaOptionsInteractor, mockPlayer: MockPlayerService) {
        let mockPlayerService = MockPlayerService()
        let sut = MediaOptionsInteractor(playerService: mockPlayerService)
        return (sut, mockPlayerService)
    }

    private static let sampleMediaOptions = MediaSelectionOptions(
        audioOptions: [
            MediaSelectionOption(displayName: "English", locale: Locale(identifier: "en")),
            MediaSelectionOption(displayName: "Japanese", locale: Locale(identifier: "ja"))
        ],
        subtitleOptions: [
            MediaSelectionOption(displayName: "English CC", locale: Locale(identifier: "en")),
            MediaSelectionOption(displayName: "Chinese", locale: Locale(identifier: "zh-Hant"))
        ]
    )

    // MARK: - Load Media Options Tests

    @Test func readyToPlayLoadsMediaOptions() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions

        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        #expect(sut.mediaOption != nil)
        #expect(sut.mediaOption?.avMediaCharacteristicAudible.count == 2)
        #expect(sut.mediaOption?.avMediaCharacteristicLegible.count == 2)
    }

    @Test func readyToPlayResetsSelectedIndices() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions

        // Load and select options first
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))
        sut.selectOption(type: .audio, index: 1)
        sut.selectOption(type: .subtitle, index: 1)
        #expect(sut.selectedAudioIndex == 1)
        #expect(sut.selectedSubtitleIndex == 1)

        // Trigger readyToPlay again (simulate video switch)
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        // Selections should be reset
        #expect(sut.selectedAudioIndex == nil)
        #expect(sut.selectedSubtitleIndex == nil)
    }

    // MARK: - Select Audio Option Tests

    @Test func selectAudioOptionUpdatesSelectedIndex() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        sut.selectOption(type: .audio, index: 1)

        #expect(sut.selectedAudioIndex == 1)
    }

    @Test func selectAudioOptionCallsPlayerService() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        sut.selectOption(type: .audio, index: 1)
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockPlayer.selectMediaOptionType == .audio)
        let locale = mockPlayer.selectMediaOptionLocale as? Locale
        #expect(locale?.identifier == "ja")
    }

    @Test func selectAudioOptionOutOfBoundsDoesNotUpdate() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        sut.selectOption(type: .audio, index: 10)

        #expect(sut.selectedAudioIndex == nil)
    }

    @Test func selectAudioOptionNegativeIndexDoesNotUpdate() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        sut.selectOption(type: .audio, index: -1)

        #expect(sut.selectedAudioIndex == nil)
    }

    // MARK: - Select Subtitle Option Tests

    @Test func selectSubtitleOptionUpdatesSelectedIndex() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        sut.selectOption(type: .subtitle, index: 1)

        #expect(sut.selectedSubtitleIndex == 1)
    }

    @Test func selectSubtitleOptionCallsPlayerService() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        sut.selectOption(type: .subtitle, index: 1)
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockPlayer.selectMediaOptionType == .subtitle)
        let locale = mockPlayer.selectMediaOptionLocale as? Locale
        #expect(locale?.identifier == "zh-Hant")
    }

    @Test func selectSubtitleOptionOutOfBoundsDoesNotUpdate() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        sut.selectOption(type: .subtitle, index: 10)

        #expect(sut.selectedSubtitleIndex == nil)
    }

    // MARK: - Reload Options Tests

    @Test func reloadOptionsRefreshesMediaOptions() async throws {
        let (sut, mockPlayer) = makeSUT()
        mockPlayer.stubbedMediaOptions = Self.sampleMediaOptions
        mockPlayer.itemStatusSubject.send(.readyToPlay)
        try await Task.sleep(for: .milliseconds(100))

        // Change stubbed options
        mockPlayer.stubbedMediaOptions = MediaSelectionOptions(
            audioOptions: [MediaSelectionOption(displayName: "French", locale: Locale(identifier: "fr"))],
            subtitleOptions: []
        )

        sut.reloadOptions()
        try await Task.sleep(for: .milliseconds(100))

        #expect(sut.mediaOption?.avMediaCharacteristicAudible.count == 1)
        #expect(sut.mediaOption?.avMediaCharacteristicAudible.first?.displayName == "French")
    }

    // MARK: - Guard Tests

    @Test func selectOptionWithoutMediaOptionDoesNothing() {
        let (sut, _) = makeSUT()

        sut.selectOption(type: .audio, index: 0)

        #expect(sut.selectedAudioIndex == nil)
    }
}
