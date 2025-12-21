//
//  PlayerConstants.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// Player-related constants
enum PlayerConstants {
    /// Time interval for hiding player controls automatically (in nanoseconds)
    static let controlsAutoHideDelay: UInt64 = 5_000_000_000  // 5 seconds

    /// Time interval for skip forward/backward (in seconds)
    static let skipInterval: NSNumber = 10

    /// Time interval for periodic time observation (in seconds)
    static let timeObservationInterval: TimeInterval = 0.5
}
