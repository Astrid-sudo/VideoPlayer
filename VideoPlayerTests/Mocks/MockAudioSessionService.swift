//
//  MockAudioSessionService.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation
@testable import VideoPlayer

final class MockAudioSessionService: AudioSessionServiceProtocol {

    // MARK: - Spy Properties

    var activateCallCount = 0
    var deactivateCallCount = 0

    // MARK: - Stub Properties

    var shouldThrowOnActivate = false
    var shouldThrowOnDeactivate = false

    // MARK: - Protocol Methods

    func activate() throws {
        activateCallCount += 1
        if shouldThrowOnActivate {
            throw AudioSessionError.activationFailed("Mock activation error")
        }
    }

    func deactivate() throws {
        deactivateCallCount += 1
        if shouldThrowOnDeactivate {
            throw AudioSessionError.deactivationFailed("Mock deactivation error")
        }
    }

    // MARK: - Helper Methods

    func reset() {
        activateCallCount = 0
        deactivateCallCount = 0
        shouldThrowOnActivate = false
        shouldThrowOnDeactivate = false
    }
}
