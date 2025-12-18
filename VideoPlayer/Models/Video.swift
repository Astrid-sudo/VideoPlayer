//
//  Video.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import Foundation

struct Video: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let thumbnailURL: String?
    let duration: TimeInterval?
    let description: String

    init(title: String, url: String, thumbnailURL: String? = nil, duration: TimeInterval? = nil, description: String) {
        self.title = title
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.description = description
    }
}

// MARK: - Sample Data

extension Video {
    static let sampleVideos: [Video] = [
        Video(
            title: "Mux Test Stream",
            url: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
            description: "Mux test video stream for development and testing"
        ),
        Video(
            title: "Sintel",
            url: "https://cdn.bitmovin.com/content/assets/sintel/hls/playlist.m3u8",
            description: "Blender Foundation open movie project - Fantasy short film"
        ),
        Video(
            title: "Tears of Steel",
            url: "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8",
            description: "Blender Foundation sci-fi short film with visual effects"
        )
    ]
}
