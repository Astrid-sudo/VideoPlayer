//
//  PlayerView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI
import AVFoundation

struct PlayerView: UIViewRepresentable {
    let onLayerReady: (AVPlayerLayer) -> Void

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()

        // 連接 player layer 到 service（同時建立 PiP controller）
        onLayerReady(view.playerLayer)

        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // 不需要更新，player 已經透過 layer 連接
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

    init() {
        super.init(frame: .zero)
        playerLayer.videoGravity = .resizeAspect
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
