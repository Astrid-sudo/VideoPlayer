//
//  PlayerControlView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI
import AVKit

/// Overlay view containing playback controls.
struct PlayerControlView: View {
    @ObservedObject var viewModel: NowPlayingViewModel
    @State private var showSpeedMenu = false
    @State private var showMediaOptionsSheet = false
    @State private var isDraggingSeekBar = false
    @State private var draggingProgress: Double?
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
            // Loading indicator at play button position, tappable to pause
            Button(action: {
                viewModel.pausePlayer()
                onUserInteraction?()
            }) {
                ProgressView()
                    .scaleEffect(2.0)
                    .tint(.white)
                    .frame(width: 60, height: 60)
            }

        case .playing, .paused:
            HStack(spacing: 60) {
                // Backward 10 seconds
                Button(action: {
                    viewModel.jumpToTime(.backward(10))
                    onUserInteraction?()
                }) {
                    Image(systemName: "gobackward.10")
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

                // Forward 10 seconds
                Button(action: {
                    viewModel.jumpToTime(.forward(10))
                    onUserInteraction?()
                }) {
                    Image(systemName: "goforward.10")
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
            let knobSize: CGFloat = isDraggingSeekBar ? 24 : 12
            let trackHeight: CGFloat = isDraggingSeekBar ? 8 : 4
            let progress = min(max(0, CGFloat(draggingProgress ?? Double(viewModel.playProgress))), 1)
            let trackWidth = geometry.size.width
            let knobRadius = knobSize / 2
            // Clamp knob position to keep it within bounds
            let knobCenterX = knobRadius + progress * (trackWidth - knobSize)
            let progressWidth = max(0, min(knobCenterX, trackWidth))

            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: trackHeight)
                    .cornerRadius(trackHeight / 2)

                // Progress track
                Rectangle()
                    .fill(Color.white)
                    .frame(width: progressWidth, height: trackHeight)
                    .cornerRadius(trackHeight / 2)

                // Knob
                Circle()
                    .fill(Color.purple)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .position(x: knobCenterX, y: geometry.size.height / 2)
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDraggingSeekBar = true
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        draggingProgress = Double(progress)
                        viewModel.slideToTime(Double(progress))
                        onUserInteraction?()
                    }
                    .onEnded { value in
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        draggingProgress = Double(progress)
                        viewModel.sliderTouchEnded(Double(progress))
                        isDraggingSeekBar = false
                        onUserInteraction?()
                    }
            )
            .onChange(of: viewModel.playProgress) { _, newProgress in
                // Clear dragging state when playback catches up
                if let target = draggingProgress,
                   abs(Double(newProgress) - target) < 0.01 {
                    draggingProgress = nil
                }
            }
            .onChange(of: viewModel.currentVideoIndex) { _, _ in
                // Reset seek state when video changes
                draggingProgress = nil
            }
        }
        .frame(height: 24)
    }

    // MARK: - Time Display

    private var displayedCurrentTime: String {
        if let progress = draggingProgress {
            let seconds = progress * viewModel.durationSeconds
            return TimeManager.floatToTimecodeString(seconds: Float(seconds)) + " /"
        }
        return viewModel.currentTime
    }

    private var timeDisplay: some View {
        Text("\(displayedCurrentTime) \(viewModel.duration)")
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
                title: Text("speed.title".localized),
                buttons: [
                    .default(Text("0.5x")) {
                        viewModel.adjustSpeed(.slow)
                    },
                    .default(Text("speed.normal".localized)) {
                        viewModel.adjustSpeed(.normal)
                    },
                    .default(Text("1.5x")) {
                        viewModel.adjustSpeed(.fast)
                    },
                    .cancel(Text("common.cancel".localized))
                ]
            )
        }
    }

    // MARK: - Next Episode Button

    private var nextEpisodeButton: some View {
        ControlIconButton(iconName: "forward.end") {
            viewModel.playNextVideo()
            onUserInteraction?()
        }
    }

    // MARK: - PiP Button

    private var pipButton: some View {
        ControlIconButton(iconName: "pip.enter") {
            viewModel.startPictureInPicture()
            onUserInteraction?()
        }
        .opacity(viewModel.isPiPAvailable ? 1.0 : 0.5)
    }

    // MARK: - Fullscreen Button

    private var fullscreenButton: some View {
        ControlIconButton(
            iconName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        ) {
            onFullscreenTap?()
            onUserInteraction?()
        }
    }
}

// MARK: - Control Icon Button

/// Reusable icon button for player controls.
struct ControlIconButton: View {
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Media Options Sheet

/// Sheet for selecting audio tracks and subtitles.
struct MediaOptionsSheet: View {
    @ObservedObject var viewModel: NowPlayingViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // Audio Section
                if let mediaOption = viewModel.mediaOption,
                   !mediaOption.avMediaCharacteristicAudible.isEmpty {
                    MediaOptionSection(
                        title: "mediaOptions.audio".localized,
                        options: mediaOption.avMediaCharacteristicAudible,
                        selectedIndex: viewModel.selectedAudioIndex
                    ) { index in
                        viewModel.selectMediaOption(mediaOptionType: .audio, index: index)
                        dismiss()
                    }
                }

                // Subtitle Section
                if let mediaOption = viewModel.mediaOption,
                   !mediaOption.avMediaCharacteristicLegible.isEmpty {
                    MediaOptionSection(
                        title: "mediaOptions.subtitles".localized,
                        options: mediaOption.avMediaCharacteristicLegible,
                        selectedIndex: viewModel.selectedSubtitleIndex
                    ) { index in
                        viewModel.selectMediaOption(mediaOptionType: .subtitle, index: index)
                        dismiss()
                    }
                }
            }
            .navigationTitle("mediaOptions.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Media Option Section

/// Section displaying selectable media options.
struct MediaOptionSection: View {
    let title: String
    let options: [DisplayNameLocale]
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        Section(header: Text(title)) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    onSelect(index)
                } label: {
                    HStack {
                        Text(option.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedIndex == index {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PlayerControlView(viewModel: NowPlayingViewModel(videos: Video.sampleVideos))
    }
}
