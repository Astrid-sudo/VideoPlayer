//
//  ContentView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DIContainer.shared.makeVideoPlayerViewModel(videos: Video.sampleVideos)
    @StateObject private var orientationManager = OrientationManager()
    @State private var showControls = true
    @State private var showMediaOptionsSheet = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isFullscreen = false

    var body: some View {
        GeometryReader { geometry in
            if isFullscreen {
                // Fullscreen: Fullscreen player only
                fullscreenPlayerView(geometry: geometry)
            } else {
                // Normal: Player + Playlist
                portraitView(geometry: geometry)
            }
        }
        .onChange(of: orientationManager.isLandscape) { _, isLandscape in
            // Auto-enter fullscreen when device rotates to landscape
            // (but only if user didn't manually exit fullscreen)
            if isLandscape && !isFullscreen {
                isFullscreen = true
            } else if !isLandscape && isFullscreen {
                isFullscreen = false
            }
        }
        .onChange(of: viewModel.isPlaying) { _, isPlaying in
            if isPlaying && showControls {
                scheduleHideControls()
            } else {
                cancelHideControls()
            }
        }
        .onAppear {
            if viewModel.isPlaying {
                scheduleHideControls()
            }
        }
    }

    // MARK: - Portrait View

    private func portraitView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Player Section
            playerSection(geometry: geometry, height: geometry.size.width * 9 / 16)

            // Playlist Section
            PlaylistView(viewModel: viewModel)
        }
    }

    // MARK: - Fullscreen View

    private func fullscreenPlayerView(geometry: GeometryProxy) -> some View {
        playerSection(geometry: geometry, height: geometry.size.height)
            .ignoresSafeArea()
    }

    // MARK: - Player Section

    private func playerSection(geometry: GeometryProxy, height: CGFloat) -> some View {
        ZStack {
            // Player
            PlayerView(onLayerReady: viewModel.connectPlayerLayer, pipController: $viewModel.pipController, isPiPAvailable: $viewModel.isPiPAvailable)
                .frame(height: height)
                .background(Color.black)

            // Buffering Indicator
            if viewModel.showIndicator {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // Player Controls
            if showControls {
                PlayerControlView(
                    viewModel: viewModel,
                    isFullscreen: isFullscreen,
                    onUserInteraction: {
                        scheduleHideControls()
                    },
                    onFullscreenTap: {
                        toggleFullscreen()
                    }
                )
                .frame(height: height)
                .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
                if showControls {
                    scheduleHideControls()
                }
            }
        }
    }

    private func scheduleHideControls() {
        // Cancel existing task
        hideControlsTask?.cancel()

        // Only auto-hide when playing
        guard viewModel.isPlaying else { return }

        // Schedule new task to hide controls after 5 seconds
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.5)) {
                showControls = false
            }
        }
    }

    private func cancelHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = nil
    }

    // MARK: - Fullscreen Toggle

    private func toggleFullscreen() {
        isFullscreen.toggle()

        if isFullscreen {
            // Enter fullscreen - force landscape
            orientationManager.forceOrientation(.landscapeRight)
        } else {
            // Exit fullscreen - force portrait
            orientationManager.forceOrientation(.portrait)
        }
    }
}

#Preview {
    ContentView()
}
