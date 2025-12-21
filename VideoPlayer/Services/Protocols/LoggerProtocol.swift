//
//  LoggerProtocol.swift
//  VideoPlayer
//

/// Protocol for logging services, enabling dependency injection and testability
protocol LoggerProtocol {
    func debug(_ message: String)
    func info(_ message: String)
    func notice(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func fault(_ message: String)
}
