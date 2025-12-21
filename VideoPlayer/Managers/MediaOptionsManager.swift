//
//  MediaOptionsManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import Combine

/// 媒體選項（字幕/音軌）業務邏輯
/// 依賴 PlayerServiceProtocol，不直接依賴 AVFoundation
final class MediaOptionsManager {

    // MARK: - Dependencies

    private let playerService: PlayerServiceProtocol

    // MARK: - Published State

    @Published private(set) var mediaOption: MediaOption?
    @Published private(set) var selectedAudioIndex: Int?
    @Published private(set) var selectedSubtitleIndex: Int?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(playerService: PlayerServiceProtocol) {
        self.playerService = playerService
        setupBindings()
    }

    // MARK: - Public Methods

    /// 選擇媒體選項（音軌或字幕）
    func selectOption(type: MediaOptionType, index: Int) {
        guard let mediaOption = mediaOption else { return }

        let options: [DisplayNameLocale]
        let selectionType: MediaSelectionType

        switch type {
        case .audio:
            options = mediaOption.avMediaCharacteristicAudible
            selectionType = .audio
        case .subtitle:
            options = mediaOption.avMediaCharacteristicLegible
            selectionType = .subtitle
        }

        guard index >= 0 && index < options.count else { return }

        let optionName = options[index].displayName
        AppLogger.mediaOptions.info("Selected \(type == .audio ? "audio" : "subtitle"): \(optionName)")

        let locale = options[index].locale
        Task {
            await playerService.selectMediaOption(type: selectionType, locale: locale)
        }

        switch type {
        case .audio:
            selectedAudioIndex = index
        case .subtitle:
            selectedSubtitleIndex = index
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
        Task {
            guard let options = await playerService.getMediaOptions() else {
                await MainActor.run {
                    mediaOption = nil
                }
                return
            }

            let audibleOptions = options.audioOptions.map { option in
                DisplayNameLocale(displayName: option.displayName, locale: option.locale as? Locale)
            }

            let legibleOptions = options.subtitleOptions.map { option in
                DisplayNameLocale(displayName: option.displayName, locale: option.locale as? Locale)
            }

            await MainActor.run {
                mediaOption = MediaOption(
                    avMediaCharacteristicAudible: audibleOptions,
                    avMediaCharacteristicLegible: legibleOptions
                )

                // 重置選擇
                selectedAudioIndex = nil
                selectedSubtitleIndex = nil
            }
        }
    }
}
