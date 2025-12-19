//
//  MediaOption.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

// MARK: - Media Selection Types

/// 媒體選項類型（純 Swift，不依賴 AVFoundation）
enum MediaOptionType {
    case audio
    case subtitle
}

/// 顯示名稱與語系資訊
struct DisplayNameLocale {
    let displayName: String
    let locale: Locale?
}

/// 媒體選項集合
struct MediaOption {
    let avMediaCharacteristicAudible: [DisplayNameLocale]
    let avMediaCharacteristicLegible: [DisplayNameLocale]
}
