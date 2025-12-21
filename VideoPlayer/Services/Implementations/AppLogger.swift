//
//  AppLogger.swift
//  VideoPlayer
//

import os

/// OSLog-based logger with category support
final class AppLogger: LoggerProtocol {

    // MARK: - Category Loggers

    static let playback = AppLogger(category: "Playback")
    static let mediaOptions = AppLogger(category: "MediaOptions")
    static let remoteControl = AppLogger(category: "RemoteControl")
    static let network = AppLogger(category: "Network")
    static let player = AppLogger(category: "Player")
    static let ui = AppLogger(category: "UI")

    // MARK: - Properties

    private let logger: Logger

    // MARK: - Init

    init(category: String) {
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.VideoPlayer",
            category: category
        )
    }

    // MARK: - LoggerProtocol

    func debug(_ message: String) {
        logger.debug("\(message)")
    }

    func info(_ message: String) {
        logger.info("\(message)")
    }

    func notice(_ message: String) {
        logger.notice("\(message)")
    }

    func warning(_ message: String) {
        logger.warning("\(message)")
    }

    func error(_ message: String) {
        logger.error("\(message)")
    }

    func fault(_ message: String) {
        logger.fault("\(message)")
    }
}
