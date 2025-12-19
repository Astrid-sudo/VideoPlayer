//
//  PlaylistItemView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI

struct PlaylistItemView: View {
    let video: Video
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail (預設圖示)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 68)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
            }

            // Video Info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .foregroundColor(isPlaying ? .blue : .primary)
                    .lineLimit(2)

                Text(video.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if let duration = video.duration {
                    Text(TimeManager.floatToTimecodeString(seconds: Float(duration)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("--:--")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Playing indicator
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isPlaying ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        PlaylistItemView(
            video: Video.sampleVideos[0],
            isPlaying: true
        )
        PlaylistItemView(
            video: Video.sampleVideos[1],
            isPlaying: false
        )
    }
    .padding()
}
