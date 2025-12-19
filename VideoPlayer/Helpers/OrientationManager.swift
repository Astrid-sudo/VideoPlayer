//
//  OrientationManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI
import Combine

class OrientationManager: ObservableObject {
    @Published var orientation: UIDeviceOrientation = .portrait
    @Published var isLandscape: Bool = false

    static var preferredOrientation: UIInterfaceOrientationMask = .allButUpsideDown

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen to device orientation changes
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { _ in UIDevice.current.orientation }
            .sink { [weak self] orientation in
                self?.handleOrientationChange(orientation)
            }
            .store(in: &cancellables)

        // Set initial orientation
        handleOrientationChange(UIDevice.current.orientation)
    }

    private func handleOrientationChange(_ orientation: UIDeviceOrientation) {
        // Only handle valid orientations
        guard orientation.isValidInterfaceOrientation else { return }

        self.orientation = orientation

        switch orientation {
        case .landscapeLeft, .landscapeRight:
            isLandscape = true
        case .portrait, .portraitUpsideDown:
            isLandscape = false
        default:
            break
        }
    }

    func forceOrientation(_ orientation: UIInterfaceOrientation) {
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        // Update preferred orientation
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            OrientationManager.preferredOrientation = .landscape
        case .portrait:
            OrientationManager.preferredOrientation = .portrait
        default:
            OrientationManager.preferredOrientation = .allButUpsideDown
        }

        // Get the root view controller and request update
        if let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        // Create geometry preferences based on orientation
        if #available(iOS 16.0, *) {
            let geometryPreferences: UIWindowScene.GeometryPreferences

            switch orientation {
            case .landscapeLeft, .landscapeRight:
                geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
            case .portrait:
                geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            default:
                geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .allButUpsideDown)
            }

            // Request geometry update
            windowScene.requestGeometryUpdate(geometryPreferences) { error in
                print("Orientation update error: \(error.localizedDescription)")
            }
        }
    }
}
