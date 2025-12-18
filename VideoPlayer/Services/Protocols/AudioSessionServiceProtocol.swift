//
//  AudioSessionServiceProtocol.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

/// 音訊會話服務協議
/// 純 Swift 協議，不依賴 AVFoundation
protocol AudioSessionServiceProtocol: AnyObject {

    /// 啟用音訊會話（設定為影片播放模式）
    /// - Throws: 設定失敗時拋出錯誤
    func activate() throws

    /// 停用音訊會話
    /// - Throws: 停用失敗時拋出錯誤
    func deactivate() throws
}

// MARK: - Error

/// 音訊會話錯誤
enum AudioSessionError: Error {
    case activationFailed(String)
    case deactivationFailed(String)
}
