//
//  PlayerErrorTests.swift
//  VideoPlayerTests
//
//  Created by Astrid Lin on 2025/12/21.
//

import Testing
import Foundation
@testable import VideoPlayer

struct PlayerErrorTests {

    // MARK: - from(error:) Tests

    @Test func fromError_nilError_returnsPlaybackFailed() {
        let result = PlayerError.from(error: nil)
        #expect(result == .playbackFailed)
    }

    @Test func fromError_nonNSError_returnsPlaybackFailed() {
        struct CustomError: Error {}
        let result = PlayerError.from(error: CustomError())
        #expect(result == .playbackFailed)
    }

    @Test func fromError_notConnectedToInternet_returnsNetworkUnavailable() {
        let nsError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        let result = PlayerError.from(error: nsError)
        #expect(result == .networkUnavailable)
    }

    @Test func fromError_timedOut_returnsConnectionTimeout() {
        let nsError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )
        let result = PlayerError.from(error: nsError)
        #expect(result == .connectionTimeout)
    }

    @Test func fromError_cannotConnectToHost_returnsCannotConnectToHost() {
        let nsError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotConnectToHost,
            userInfo: nil
        )
        let result = PlayerError.from(error: nsError)
        #expect(result == .cannotConnectToHost)
    }

    @Test func fromError_networkConnectionLost_returnsConnectionLost() {
        let nsError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )
        let result = PlayerError.from(error: nsError)
        #expect(result == .connectionLost)
    }

    @Test func fromError_otherURLError_returnsPlaybackFailed() {
        let nsError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorBadURL,
            userInfo: nil
        )
        let result = PlayerError.from(error: nsError)
        #expect(result == .playbackFailed)
    }

    @Test func fromError_nonURLDomain_returnsPlaybackFailed() {
        let nsError = NSError(
            domain: "SomeOtherDomain",
            code: -1009,
            userInfo: nil
        )
        let result = PlayerError.from(error: nsError)
        #expect(result == .playbackFailed)
    }

    @Test func fromError_underlyingNetworkError_returnsNetworkError() {
        let underlyingError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        let wrapperError = NSError(
            domain: "AVFoundationErrorDomain",
            code: -11800,
            userInfo: [NSUnderlyingErrorKey: underlyingError]
        )
        let result = PlayerError.from(error: wrapperError)
        #expect(result == .networkUnavailable)
    }

    @Test func fromError_nestedUnderlyingNetworkError_returnsNetworkError() {
        let deepError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )
        let middleError = NSError(
            domain: "MiddleDomain",
            code: 100,
            userInfo: [NSUnderlyingErrorKey: deepError]
        )
        let outerError = NSError(
            domain: "OuterDomain",
            code: 200,
            userInfo: [NSUnderlyingErrorKey: middleError]
        )
        let result = PlayerError.from(error: outerError)
        #expect(result == .connectionTimeout)
    }
}
