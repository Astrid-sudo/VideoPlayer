//
//  PlayerLayerConnectable.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/19.
//

import AVFoundation
import Combine

/// Protocol for connecting player to AVPlayerLayer and managing PiP.
protocol PlayerLayerConnectable: AnyObject {

    // MARK: - Layer Connection

    func connect(layer: AVPlayerLayer)

    // MARK: - Picture in Picture

    var isPiPPossiblePublisher: AnyPublisher<Bool, Never> { get }
    var isPiPActivePublisher: AnyPublisher<Bool, Never> { get }
    var restoreUIPublisher: AnyPublisher<Void, Never> { get }

    func startPictureInPicture()
    func stopPictureInPicture()
    func pictureInPictureUIRestored()
}
