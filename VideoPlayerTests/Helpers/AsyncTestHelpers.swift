//
//  AsyncTestHelpers.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/22.
//

import Foundation

/// Waits for a condition to become true with polling.
/// More reliable than fixed Task.sleep in CI environments.
///
/// - Parameters:
///   - timeout: Maximum time to wait (default: 5 seconds)
///   - pollInterval: Time between condition checks (default: 10ms)
///   - condition: The condition to wait for
/// - Returns: Whether the condition became true before timeout
@MainActor
func waitUntil(
    timeout: TimeInterval = 5.0,
    pollInterval: TimeInterval = 0.01,
    condition: @escaping () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(Int(pollInterval * 1000)))
    }

    return condition()
}

/// Waits for a condition to become true, throwing if it times out.
///
/// - Parameters:
///   - timeout: Maximum time to wait (default: 5 seconds)
///   - pollInterval: Time between condition checks (default: 10ms)
///   - message: Error message if condition is not met
///   - condition: The condition to wait for
@MainActor
func awaitCondition(
    timeout: TimeInterval = 5.0,
    pollInterval: TimeInterval = 0.01,
    message: String = "Condition was not met within timeout",
    condition: @escaping () -> Bool
) async throws {
    let result = await waitUntil(timeout: timeout, pollInterval: pollInterval, condition: condition)
    if !result {
        struct ConditionTimeoutError: Error, CustomStringConvertible {
            let message: String
            var description: String { message }
        }
        throw ConditionTimeoutError(message: message)
    }
}
