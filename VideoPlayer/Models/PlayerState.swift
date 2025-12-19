//
//  PlayerState.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

enum PlayerState {
    case unknown
    case readyToPlay
    case playing
    case buffering
    case failed
    case pause
    case ended
}
