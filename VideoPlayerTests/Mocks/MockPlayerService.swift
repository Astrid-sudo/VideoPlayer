//
//  MockPlayerService.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import Combine
@testable import VideoPlayer

final class MockPlayerService: PlayerServiceProtocol {

    // MARK: - Spy Properties (記錄呼叫)

    var playCallCount = 0
    var pauseCallCount = 0
    var seekToSeconds: TimeInterval?
    var setRateValue: Float?
    var setPlaylistUrls: [URL]?
    var rebuildQueueUrls: [URL]?
    var rebuildQueueStartIndex: Int?
    var advanceToNextItemCallCount = 0
    var startTimeObservationInterval: TimeInterval?
    var stopTimeObservationCallCount = 0
    var getMediaOptionsCallCount = 0
    var selectMediaOptionType: MediaSelectionType?
    var selectMediaOptionLocale: Any?

    // MARK: - Stub Properties (模擬回傳值)

    var stubbedCurrentItemDuration: TimeInterval?
    var stubbedCurrentItemCurrentTime: TimeInterval?
    var stubbedCurrentRate: Float = 0
    var stubbedMediaOptions: MediaSelectionOptions?

    // MARK: - Subjects (發送事件)

    let timeSubject = PassthroughSubject<TimeInterval, Never>()
    let durationSubject = PassthroughSubject<TimeInterval, Never>()
    let itemStatusSubject = PassthroughSubject<PlaybackItemStatus, Never>()
    let bufferingSubject = PassthroughSubject<BufferingState, Never>()
    let playbackDidEndSubject = PassthroughSubject<Void, Never>()

    // MARK: - Protocol Properties

    var underlyingPlayer: Any? { nil }

    var currentItemDuration: TimeInterval? { stubbedCurrentItemDuration }

    var currentItemCurrentTime: TimeInterval? { stubbedCurrentItemCurrentTime }

    var currentRate: Float { stubbedCurrentRate }

    // MARK: - Publishers

    var timePublisher: AnyPublisher<TimeInterval, Never> {
        timeSubject.eraseToAnyPublisher()
    }

    var durationPublisher: AnyPublisher<TimeInterval, Never> {
        durationSubject.eraseToAnyPublisher()
    }

    var itemStatusPublisher: AnyPublisher<PlaybackItemStatus, Never> {
        itemStatusSubject.eraseToAnyPublisher()
    }

    var bufferingPublisher: AnyPublisher<BufferingState, Never> {
        bufferingSubject.eraseToAnyPublisher()
    }

    var playbackDidEndPublisher: AnyPublisher<Void, Never> {
        playbackDidEndSubject.eraseToAnyPublisher()
    }

    // MARK: - Protocol Methods

    func play() {
        playCallCount += 1
    }

    func pause() {
        pauseCallCount += 1
    }

    func seek(to seconds: TimeInterval) {
        seekToSeconds = seconds
    }

    func setRate(_ rate: Float) {
        setRateValue = rate
        stubbedCurrentRate = rate
    }

    func setPlaylist(urls: [URL]) {
        setPlaylistUrls = urls
    }

    func rebuildQueue(from urls: [URL], startingAt index: Int) {
        rebuildQueueUrls = urls
        rebuildQueueStartIndex = index
    }

    func advanceToNextItem() {
        advanceToNextItemCallCount += 1
    }

    func startTimeObservation(interval: TimeInterval) {
        startTimeObservationInterval = interval
    }

    func stopTimeObservation() {
        stopTimeObservationCallCount += 1
    }

    func getMediaOptions() -> MediaSelectionOptions? {
        getMediaOptionsCallCount += 1
        return stubbedMediaOptions
    }

    func selectMediaOption(type: MediaSelectionType, locale: Any?) {
        selectMediaOptionType = type
        selectMediaOptionLocale = locale
    }

    // MARK: - Helper Methods (測試用)

    func reset() {
        playCallCount = 0
        pauseCallCount = 0
        seekToSeconds = nil
        setRateValue = nil
        setPlaylistUrls = nil
        rebuildQueueUrls = nil
        rebuildQueueStartIndex = nil
        advanceToNextItemCallCount = 0
        startTimeObservationInterval = nil
        stopTimeObservationCallCount = 0
        getMediaOptionsCallCount = 0
        selectMediaOptionType = nil
        selectMediaOptionLocale = nil
        stubbedMediaOptions = nil
    }
}
