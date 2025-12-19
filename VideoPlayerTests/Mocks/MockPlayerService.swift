//
//  MockPlayerService.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation
import Combine
@testable import VideoPlayer

final class MockPlayerService: PlayerServiceProtocol, PlayerLayerConnectable {

    // MARK: - Spy Properties (記錄呼叫)

    var connectLayerCallCount = 0
    var connectedLayer: AVPlayerLayer?
    var startPiPCallCount = 0
    var stopPiPCallCount = 0
    var pipUIRestoredCallCount = 0
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

    // PiP Subjects
    let isPiPPossibleSubject = CurrentValueSubject<Bool, Never>(false)
    let isPiPActiveSubject = CurrentValueSubject<Bool, Never>(false)
    let restoreUISubject = PassthroughSubject<Void, Never>()

    // MARK: - Player Connection

    func connect(layer: AVPlayerLayer) {
        connectLayerCallCount += 1
        connectedLayer = layer
    }

    // MARK: - PiP Publishers

    var isPiPPossiblePublisher: AnyPublisher<Bool, Never> {
        isPiPPossibleSubject.eraseToAnyPublisher()
    }

    var isPiPActivePublisher: AnyPublisher<Bool, Never> {
        isPiPActiveSubject.eraseToAnyPublisher()
    }

    var restoreUIPublisher: AnyPublisher<Void, Never> {
        restoreUISubject.eraseToAnyPublisher()
    }

    // MARK: - PiP Methods

    func startPictureInPicture() {
        startPiPCallCount += 1
    }

    func stopPictureInPicture() {
        stopPiPCallCount += 1
    }

    func pictureInPictureUIRestored() {
        pipUIRestoredCallCount += 1
    }

    // MARK: - Protocol Properties

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
        connectLayerCallCount = 0
        connectedLayer = nil
        startPiPCallCount = 0
        stopPiPCallCount = 0
        pipUIRestoredCallCount = 0
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
