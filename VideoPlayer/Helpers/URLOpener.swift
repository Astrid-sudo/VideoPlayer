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
        if let url = URL(string: "App-Prefs:") {
            UIApplication.shared.open(url)
        }
    }
}
