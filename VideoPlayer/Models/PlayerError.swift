//
//  PlayerError.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// Player error types for playback and network issues.
enum PlayerError: LocalizedError {
    case playbackFailed
    case networkUnavailable      // -1009: No internet connection
    case connectionTimeout       // -1001: Connection timed out
    case cannotConnectToHost     // -1004: Cannot connect to host
    case connectionLost          // -1005: Network connection lost

    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Failed to play video"
        case .networkUnavailable, .connectionTimeout, .cannotConnectToHost, .connectionLost:
            return "Network connection error"
        }
    }

    var isNetworkError: Bool {
        switch self {
        case .networkUnavailable, .connectionTimeout, .cannotConnectToHost, .connectionLost:
            return true
        case .playbackFailed:
            return false
        }
    }

    static func from(error: Error?) -> PlayerError {
        guard let error = error as NSError? else {
            return .playbackFailed
        }

        // Check if error is from NSURLErrorDomain
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet: // -1009
                return .networkUnavailable
            case NSURLErrorTimedOut: // -1001
                return .connectionTimeout
            case NSURLErrorCannotConnectToHost: // -1004
                return .cannotConnectToHost
            case NSURLErrorNetworkConnectionLost: // -1005
                return .connectionLost
            default:
                break
            }
        }

        // Recursively check underlying error
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
            let result = PlayerError.from(error: underlyingError)
            if result.isNetworkError {
                return result
            }
        }

        return .playbackFailed
    }
}
