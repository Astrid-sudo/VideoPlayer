//
//  DIContainer.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// 依賴注入容器
/// 管理 Services 單例，提供 Factory 方法
final class DIContainer {

    // MARK: - Shared Instance

    static let shared = DIContainer()

    // MARK: - Services (Lazy Singletons)

    private lazy var playerService: PlayerService = {
        PlayerService()
    }()

    private lazy var audioSessionService: AudioSessionServiceProtocol = {
        AudioSessionService()
    }()

    private lazy var remoteControlService: RemoteControlServiceProtocol = {
        RemoteControlService()
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Factory Methods

    /// 建立 VideoPlayerViewModel
    func makeVideoPlayerViewModel(videos: [Video]) -> VideoPlayerViewModel {
        VideoPlayerViewModel(
            playerService: playerService,
            layerConnector: playerService,
            audioSessionService: audioSessionService,
            remoteControlService: remoteControlService,
            videos: videos
        )
    }
}
