//
//  PlayerLayerConnectable.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/19.
//

import AVFoundation

/// 播放器 Layer 連接協議
/// 負責將播放器連接到 AVPlayerLayer
protocol PlayerLayerConnectable: AnyObject {
    /// 連接播放器到指定的 AVPlayerLayer
    func connect(layer: AVPlayerLayer)
}
