//
//  MediaOption.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import AVFoundation

// MARK: - Media Selection Types

enum MediaOptionType {
    case audio
    case subtitle

    var avMediaCharacteristic: AVMediaCharacteristic {
        switch self {
        case .audio:
            return .audible
        case .subtitle:
            return .legible
        }
    }
}

struct DisplayNameLocale {
    let displayName: String
    let locale: Locale?
}

struct MediaOption {
    let avMediaCharacteristicAudible: [DisplayNameLocale]
    let avMediaCharacteristicLegible: [DisplayNameLocale]
}
