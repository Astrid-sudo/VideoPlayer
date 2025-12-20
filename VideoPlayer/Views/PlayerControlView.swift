//
//  PlayerControlView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI
import AVKit

struct PlayerControlView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var isSeekingProgress = false
    @State private var showSpeedMenu = false
    @State private var showMediaOptionsSheet = false
    var isFullscreen: Bool = false
    var onUserInteraction: (() -> Void)?
    var onFullscreenTap: (() -> Void)?

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Controls
                topControlBar

                Spacer()

                // Center Play/Pause Button
                centerPlayButton

                Spacer()

                // Bottom Controls
                bottomControlBar
            }
            .padding()
        }
        .sheet(isPresented: $showMediaOptionsSheet) {
            MediaOptionsSheet(viewModel: viewModel)
        }
    }

    // MARK: - Top Control Bar

	private var topControlBar: some View {
		HStack {
			if isFullscreen {
				// Back button (exit fullscreen)
				Button(action: {
					onFullscreenTap?()
					onUserInteraction?()
				}) {
					Image(systemName: "chevron.left")
						.font(.title2)
						.foregroundColor(.white)
				}
			}

            Spacer()

            // Video title
            if let currentVideo = viewModel.currentVideo {
                Text(currentVideo.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            // Media selection button (Subtitle/Audio)
            Button(action: {
                showMediaOptionsSheet = true
            }) {
                Image(systemName: "text.bubble")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Center Play/Pause Button

    @ViewBuilder
    private var centerPlayButton: some View {
        switch viewModel.playerState {
        case .loading:
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

        case .playing, .paused:
            HStack(spacing: 60) {
                // Backward 15 seconds
                Button(action: {
                    viewModel.jumpToTime(.backward(15))
                    onUserInteraction?()
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }

                // Play/Pause
                Button(action: {
                    viewModel.togglePlay()
                    onUserInteraction?()
                }) {
                    Image(systemName: viewModel.playerState == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }

                // Forward 15 seconds
                Button(action: {
                    viewModel.jumpToTime(.forward(15))
                    onUserInteraction?()
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }

        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
        }
    }

    // MARK: - Bottom Control Bar

    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            // Progress bar
            progressBar

            // Control buttons row
            HStack(spacing: 20) {
                // Current time / Duration
                timeDisplay

                Spacer()

                // Speed button
                speedButton

                // PiP button
                pipButton

                // Next episode button
                nextEpisodeButton

                // Fullscreen button
                fullscreenButton
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                // Progress track
                Rectangle()
                    .fill(Color.white)
                    .frame(width: CGFloat(viewModel.playProgress) * geometry.size.width, height: 4)
            }
            .cornerRadius(2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isSeekingProgress = true
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        viewModel.slideToTime(Double(progress))
                        onUserInteraction?()
                    }
                    .onEnded { value in
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        viewModel.sliderTouchEnded(Double(progress))
                        isSeekingProgress = false
                        onUserInteraction?()
                    }
            )
        }
        .frame(height: 20)
    }

    // MARK: - Time Display

    private var timeDisplay: some View {
        Text("\(viewModel.currentTime) \(viewModel.duration)")
            .font(.caption)
            .foregroundColor(.white)
    }

    // MARK: - Speed Button

    private var speedButton: some View {
        Button(action: {
            showSpeedMenu.toggle()
            onUserInteraction?()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.caption)
                Text(String(format: "%.1fx", viewModel.playSpeedRate))
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.2))
            .cornerRadius(4)
        }
        .actionSheet(isPresented: $showSpeedMenu) {
            ActionSheet(
                title: Text("播放速度"),
                buttons: [
                    .default(Text("0.5x")) {
                        viewModel.adjustSpeed(.slow)
                    },
                    .default(Text("1.0x (正常)")) {
                        viewModel.adjustSpeed(.normal)
                    },
                    .default(Text("1.5x")) {
                        viewModel.adjustSpeed(.fast)
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
    }

    // MARK: - Next Episode Button

    private var nextEpisodeButton: some View {
        Button(action: {
            viewModel.playNextVideo()
            onUserInteraction?()
        }) {
            Image(systemName: "forward.end")
                .font(.title3)
                .foregroundColor(.white)
        }
    }

    // MARK: - PiP Button

    private var pipButton: some View {
        Button(action: {
            viewModel.startPictureInPicture()
            onUserInteraction?()
        }) {
            Image(systemName: "pip.enter")
                .font(.title3)
                .foregroundColor(.white)
        }
        .opacity(viewModel.isPiPAvailable ? 1.0 : 0.5)
    }

    // MARK: - Fullscreen Button

    private var fullscreenButton: some View {
        Button(action: {
            onFullscreenTap?()
            onUserInteraction?()
        }) {
            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.title3)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Media Options Sheet

struct MediaOptionsSheet: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // Audio Section
                if let mediaOption = viewModel.mediaOption,
                   !mediaOption.avMediaCharacteristicAudible.isEmpty {
                    Section(header: Text("音訊")) {
                        ForEach(Array(mediaOption.avMediaCharacteristicAudible.enumerated()), id: \.offset) { index, option in
                            Button(action: {
                                viewModel.selectMediaOption(mediaOptionType: .audio, index: index)
                                dismiss()
                            }) {
                                HStack {
                                    Text(option.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if viewModel.selectedAudioIndex == index {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                // Subtitle Section
                if let mediaOption = viewModel.mediaOption,
                   !mediaOption.avMediaCharacteristicLegible.isEmpty {
                    Section(header: Text("字幕")) {
                        ForEach(Array(mediaOption.avMediaCharacteristicLegible.enumerated()), id: \.offset) { index, option in
                            Button(action: {
                                viewModel.selectMediaOption(mediaOptionType: .subtitle, index: index)
                                dismiss()
                            }) {
                                HStack {
                                    Text(option.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if viewModel.selectedSubtitleIndex == index {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("字幕與音訊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PlayerControlView(viewModel: VideoPlayerViewModel(videos: Video.sampleVideos))
    }
}
