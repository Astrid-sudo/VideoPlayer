//
//  MockNetworkMonitor.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/20.
//

import Combine
@testable import VideoPlayer

final class MockNetworkMonitor: NetworkMonitorProtocol {

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        isConnectedSubject.eraseToAnyPublisher()
    }

    let isConnectedSubject = CurrentValueSubject<Bool, Never>(true)

    // MARK: - Test Helpers

    func simulateNetworkConnected() {
        isConnectedSubject.send(true)
    }

    func simulateNetworkDisconnected() {
        isConnectedSubject.send(false)
    }
}
