//
//  AudioSessionServiceProtocol.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// Protocol for audio session management.
protocol AudioSessionServiceProtocol: AnyObject {

    /// Activates audio session for video playback.
    func activate() throws

    /// Deactivates audio session.
    func deactivate() throws
}

// MARK: - Error

/// Audio session error.
enum AudioSessionError: Error {
    case activationFailed(String)
    case deactivationFailed(String)
}
