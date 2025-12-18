//
//  MediaOptionsManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation
import Combine

/// 媒體選項（字幕/音軌）業務邏輯
/// 依賴 PlayerServiceProtocol，透過 underlyingPlayer 存取 AVPlayer
final class MediaOptionsManager {

    // MARK: - Dependencies

    private let playerService: PlayerServiceProtocol

    // MARK: - Published State

    @Published private(set) var mediaOption: MediaOption?
    @Published private(set) var selectedAudioIndex: Int?
    @Published private(set) var selectedSubtitleIndex: Int?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    private var currentItem: AVPlayerItem? {
        guard let player = playerService.underlyingPlayer as? AVQueuePlayer else { return nil }
        return player.currentItem
    }

    // MARK: - Initialization

    init(playerService: PlayerServiceProtocol) {
        self.playerService = playerService
        setupBindings()
    }

    // MARK: - Public Methods

    /// 選擇媒體選項（音軌或字幕）
    func selectOption(type: MediaOptionType, index: Int) {
        guard let currentItem = currentItem,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: type.avMediaCharacteristic) else {
            return
        }

        let displayNameLocaleArray: [DisplayNameLocale]?
        switch type {
        case .audio:
            displayNameLocaleArray = mediaOption?.avMediaCharacteristicAudible
        case .subtitle:
            displayNameLocaleArray = mediaOption?.avMediaCharacteristicLegible
        }

        guard let locale = displayNameLocaleArray?[safe: index]?.locale else { return }

        let options = AVMediaSelectionGroup.mediaSelectionOptions(from: group.options, with: locale)
        if let option = options.first {
            currentItem.select(option, in: group)

            switch type {
            case .audio:
                selectedAudioIndex = index
            case .subtitle:
                selectedSubtitleIndex = index
            }
        }
    }

    /// 重新載入媒體選項（當切換影片時呼叫）
    func reloadOptions() {
        loadMediaOptions()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // 當播放項目狀態變為 readyToPlay 時，載入媒體選項
        playerService.itemStatusPublisher
            .filter { $0 == .readyToPlay }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadMediaOptions()
            }
            .store(in: &cancellables)
    }

    private func loadMediaOptions() {
        guard let currentItem = currentItem else {
            mediaOption = nil
            return
        }

        var audibleOptions = [DisplayNameLocale]()
        var legibleOptions = [DisplayNameLocale]()

        for characteristic in currentItem.asset.availableMediaCharacteristicsWithMediaSelectionOptions {
            if characteristic == .audible {
                audibleOptions = getMediaOptionDetails(for: characteristic)
            }
            if characteristic == .legible {
                legibleOptions = getMediaOptionDetails(for: characteristic)
            }
        }

        mediaOption = MediaOption(
            avMediaCharacteristicAudible: audibleOptions,
            avMediaCharacteristicLegible: legibleOptions
        )

        // 重置選擇
        selectedAudioIndex = nil
        selectedSubtitleIndex = nil
    }

    private func getMediaOptionDetails(for characteristic: AVMediaCharacteristic) -> [DisplayNameLocale] {
        guard let currentItem = currentItem,
              let group = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else {
            return []
        }

        return group.options.map { option in
            DisplayNameLocale(
                displayName: option.displayName,
                locale: option.locale
            )
        }
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
