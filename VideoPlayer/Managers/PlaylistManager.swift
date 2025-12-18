//
//  PlaylistManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
import Combine

/// 播放列表業務邏輯
/// 依賴 PlayerServiceProtocol
final class PlaylistManager {

    // MARK: - Dependencies

    private let playerService: PlayerServiceProtocol

    // MARK: - Published State

    @Published private(set) var videos: [Video]
    @Published private(set) var currentIndex: Int = 0

    var currentVideo: Video? {
        guard currentIndex >= 0 && currentIndex < videos.count else { return nil }
        return videos[currentIndex]
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(playerService: PlayerServiceProtocol, videos: [Video]) {
        self.playerService = playerService
        self.videos = videos

        setupPlaylist()
        setupBindings()
    }

    // MARK: - Public Methods

    /// 播放指定索引的影片
    func playVideo(at index: Int) {
        guard index >= 0 && index < videos.count else { return }

        currentIndex = index

        let urls = videos.compactMap { URL(string: $0.url) }
        playerService.rebuildQueue(from: urls, startingAt: index)
    }

    /// 播放下一個影片
    func playNext() {
        let nextIndex = currentIndex + 1

        if nextIndex >= videos.count {
            // 已是最後一個，循環到第一個
            currentIndex = 0
            playerService.seek(to: 0)
        } else {
            currentIndex = nextIndex
            playerService.advanceToNextItem()
        }
    }

    /// 播放上一個影片
    func playPrevious() {
        let previousIndex = currentIndex - 1

        if previousIndex < 0 {
            // 已是第一個，循環到最後一個
            playVideo(at: videos.count - 1)
        } else {
            playVideo(at: previousIndex)
        }
    }

    /// 更新影片時長（當取得實際時長時）
    func updateVideoDuration(_ duration: TimeInterval, at index: Int) {
        guard index >= 0 && index < videos.count else { return }

        var updatedVideo = videos[index]
        updatedVideo = Video(
            title: updatedVideo.title,
            url: updatedVideo.url,
            thumbnailURL: updatedVideo.thumbnailURL,
            duration: duration,
            description: updatedVideo.description
        )
        videos[index] = updatedVideo
    }

    // MARK: - Private Methods

    private func setupPlaylist() {
        let urls = videos.compactMap { URL(string: $0.url) }
        playerService.setPlaylist(urls: urls)
    }

    private func setupBindings() {
        // 訂閱播放結束，自動播放下一個
        playerService.playbackDidEndPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handlePlaybackEnd()
            }
            .store(in: &cancellables)
    }

    private func handlePlaybackEnd() {
        // 延遲一點再處理，讓 AVQueuePlayer 有時間切換
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            let nextIndex = self.currentIndex + 1
            if nextIndex < self.videos.count {
                self.currentIndex = nextIndex
            } else {
                // 播放完畢，循環到第一個
                self.currentIndex = 0
            }
        }
    }
}
