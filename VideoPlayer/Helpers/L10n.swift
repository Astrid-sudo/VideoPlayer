//
//  L10n.swift
//  VideoPlayer
//

import Foundation

extension String {
    var localized: String {
        String(localized: LocalizationValue(self))
    }
}
