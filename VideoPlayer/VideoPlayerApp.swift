//
//  VideoPlayerApp.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI

@main
struct VideoPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.preferredOrientation
    }
}
