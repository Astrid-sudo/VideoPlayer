//
//  PlayerView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI
import AVKit

struct PlayerView: UIViewRepresentable {
    let player: AVPlayer?
    @Binding var pipController: AVPictureInPictureController?
    @Binding var isPiPAvailable: Bool

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView(player: player)

        // Store the view reference in coordinator for later PiP setup
        context.coordinator.playerView = view
        context.coordinator.pipControllerBinding = $pipController
        context.coordinator.isPiPAvailableBinding = $isPiPAvailable

        // Setup PiP controller after a short delay to ensure player is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            context.coordinator.setupPiPController()
        }

        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player

        // Try to setup PiP controller if not already done
        if pipController == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.setupPiPController()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        weak var playerView: PlayerUIView?
        var pipControllerBinding: Binding<AVPictureInPictureController?>?
        var isPiPAvailableBinding: Binding<Bool>?
        private var pipPossibleObservation: NSKeyValueObservation?

        func setupPiPController() {
            guard let playerView = playerView else { return }
            guard let playerLayer = playerView.layer as? AVPlayerLayer else { return }
            guard playerLayer.player != nil else { return }
            guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

            // Only create if not already created
            if pipControllerBinding?.wrappedValue == nil {
                let controller = AVPictureInPictureController(playerLayer: playerLayer)
                controller?.delegate = self
                pipControllerBinding?.wrappedValue = controller

                // Observe PiP availability and update binding
                pipPossibleObservation = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
                    DispatchQueue.main.async {
                        self?.isPiPAvailableBinding?.wrappedValue = controller.isPictureInPicturePossible
                    }
                }
            }
        }

        deinit {
            pipPossibleObservation?.invalidate()
        }

        func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        }

        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        }

        func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        }

        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        }

        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            // The system calls this method when the user stops PiP from the PiP window
            // Restore your player interface here if needed

            // For this app, the player interface is always available in the main view
            // so we just need to confirm the restoration is complete
            completionHandler(true)
        }
    }
}

// MARK: - PlayerUIView

class PlayerUIView: UIView {

    // Override the property to make AVPlayerLayer the view's backing layer
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    init(player: AVPlayer?) {
        super.init(frame: .zero)
        self.player = player
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
