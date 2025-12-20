//
//  NetworkMonitor.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/20.
//

import Network
import Combine

/// Network status monitoring service
final class NetworkMonitor: NetworkMonitorProtocol {

    static let shared = NetworkMonitor()

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        isConnectedSubject.eraseToAnyPublisher()
    }

    private let isConnectedSubject = CurrentValueSubject<Bool, Never>(true)
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnectedSubject.send(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
