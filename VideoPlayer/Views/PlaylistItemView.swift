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
    @State private var thumbnail: UIImage?
    @State private var isLoading = true

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 68)

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .task {
                await loadThumbnail()
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

    private func loadThumbnail() async {
        isLoading = true
        let result = await ThumbnailGenerator.shared.generateThumbnail(from: video.url)
        print("[PlaylistItem] Thumbnail loaded for \(video.title): \(result != nil ? "✅ Success" : "❌ Failed")")
        if let result = result {
            print("[PlaylistItem] Thumbnail size: \(result.size)")
        }
        thumbnail = result
        isLoading = false
        print("[PlaylistItem] isLoading set to false, thumbnail is \(thumbnail != nil ? "set" : "nil")")
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
