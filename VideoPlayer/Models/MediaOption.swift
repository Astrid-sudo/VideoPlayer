//
//  MediaOption.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

// MARK: - Media Selection Types

/// Media option type for UI selection.
enum MediaOptionType {
    case audio
    case subtitle
}

/// Display name with optional locale info.
struct DisplayNameLocale {
    let displayName: String
    let locale: Locale?
}

/// Collection of available audio and subtitle options.
struct MediaOption {
    let avMediaCharacteristicAudible: [DisplayNameLocale]
    let avMediaCharacteristicLegible: [DisplayNameLocale]
}
