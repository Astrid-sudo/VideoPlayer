//
//  URLOpener.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/20.
//

import UIKit

enum URLOpener {

    /// Open system Settings app
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            AppLogger.ui.error("Failed to create Settings URL")
            return
        }

        UIApplication.shared.open(url) { success in
            if !success {
                AppLogger.ui.error("Failed to open Settings app")
            }
        }
    }
}
