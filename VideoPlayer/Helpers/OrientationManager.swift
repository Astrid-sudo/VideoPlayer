//
//  OrientationManager.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI
import Combine

/// Manages device orientation detection and interface orientation control.
///
/// This class serves two purposes:
/// 1. **Orientation Detection**: Observes physical device orientation changes via `isLandscape`
/// 2. **Orientation Control**: Provides static methods to lock/unlock interface orientation
///
/// Usage:
/// - Use `@StateObject` to observe `isLandscape` for reactive UI updates
/// - Use static methods `forceOrientation(_:)` and `unlockOrientation()` to control allowed orientations
///
/// Note: `isLandscape` reflects the physical device orientation, not the interface orientation.
/// The interface may be locked to portrait while `isLandscape` is true.
class OrientationManager: ObservableObject {
    @Published var orientation: UIDeviceOrientation = .portrait
    @Published var isLandscape: Bool = false

    /// The currently allowed interface orientations. Used by AppDelegate to control rotation.
    static var preferredOrientation: UIInterfaceOrientationMask = .portrait

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

        // Ignore portraitUpsideDown to prevent incorrect state changes
        guard orientation != .portraitUpsideDown else { return }

        self.orientation = orientation

        switch orientation {
        case .landscapeLeft, .landscapeRight:
            isLandscape = true
        case .portrait:
            isLandscape = false
        default:
            break
        }
    }

    /// Forces the interface to a specific orientation and locks it.
    /// - Parameter orientation: The target orientation (.portrait, .landscapeLeft, .landscapeRight)
    static func forceOrientation(_ orientation: UIInterfaceOrientation) {
        // Get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        // Update preferred orientation
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            preferredOrientation = .landscape
        case .portrait:
            preferredOrientation = .portrait
        default:
            preferredOrientation = .allButUpsideDown
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

    /// Unlocks orientation to allow all rotations (except upside down).
    /// Call this when entering a view that should support rotation.
    static func unlockOrientation() {
        preferredOrientation = .allButUpsideDown

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
