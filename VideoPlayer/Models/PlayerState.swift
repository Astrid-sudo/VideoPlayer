//
//  PlayerState.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// Player UI state
/// - loading: Show ProgressView (loading or buffering)
/// - playing: Show pause button
/// - paused: Show play button
/// - failed: Show error alert
enum PlayerState: Equatable {
    case loading
    case playing
    case paused
    case failed(Error)

    static func == (lhs: PlayerState, rhs: PlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.playing, .playing), (.paused, .paused):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}
