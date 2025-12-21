//
//  PlaylistView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI

struct PlaylistView: View {
    @ObservedObject var viewModel: NowPlayingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("navigation.playlist".localized)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                        PlaylistItemView(
                            video: video,
                            isPlaying: index == viewModel.currentVideoIndex
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.playVideo(at: index)
                        }

                        if index < viewModel.videos.count - 1 {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
		.background(Color(.systemBackground))
    }
}

#Preview {
    PlaylistView(
        viewModel: NowPlayingViewModel(videos: Video.sampleVideos)
    )
}
