//
//  NetworkMonitorProtocol.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/20.
//

import Combine

/// Network monitoring service protocol
protocol NetworkMonitorProtocol: AnyObject {
    /// Publisher that emits network connectivity status
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
}
