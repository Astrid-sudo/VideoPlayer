//
//  AppLogger.swift
//  VideoPlayer
//

import os
import Foundation

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

    func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let location = self.formatLocation(file: file, function: function, line: line)
        logger.debug("\(message) \(location)")
    }

    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let location = self.formatLocation(file: file, function: function, line: line)
        logger.info("\(message) \(location)")
    }

    func notice(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let location = self.formatLocation(file: file, function: function, line: line)
        logger.notice("\(message) \(location)")
    }

    func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let location = self.formatLocation(file: file, function: function, line: line)
        logger.warning("\(message) \(location)")
    }

    func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let location = self.formatLocation(file: file, function: function, line: line)
        logger.error("\(message) \(location)")
    }

    func fault(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let location = self.formatLocation(file: file, function: function, line: line)
        logger.fault("\(message) \(location)")
    }

    // MARK: - Private

    private func formatLocation(file: String, function: String, line: Int) -> String {
        let fileName = (file as NSString).lastPathComponent
        return "[\(fileName):\(line) \(function)]"
    }
}
