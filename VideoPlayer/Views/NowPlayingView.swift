//
//  NowPlayingView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/18.
//

import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = NowPlayingViewModel(videos: Video.sampleVideos)
    @StateObject private var orientationManager = OrientationManager()
    @State private var showControls = true
    @State private var showMediaOptionsSheet = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var showPlaybackErrorAlert = false
    @State private var showNetworkErrorAlert = false

    // MARK: - Fullscreen State
    // Fullscreen mode is determined by two factors:
    // 1. User manually toggled fullscreen (via button)
    // 2. Device is in landscape orientation (auto-enter)
    //
    // The `userExitedFullscreen` flag prevents auto-entering fullscreen when:
    // - User explicitly exited fullscreen while device is still in landscape
    // - This flag resets when device returns to portrait, allowing auto-enter on next landscape rotation
    @State private var isManualFullscreen = false
    @State private var userExitedFullscreen = false

    private var isFullscreenMode: Bool {
        isManualFullscreen || (orientationManager.isLandscape && !userExitedFullscreen)
    }

    var body: some View {
        GeometryReader { geometry in
            if isFullscreenMode {
                // Fullscreen: Fullscreen player only
                fullscreenPlayerView(geometry: geometry)
            } else {
                // Normal: Player + Playlist
                portraitView(geometry: geometry)
            }
        }
        .navigationTitle("Video Player")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(isFullscreenMode ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: orientationManager.isLandscape) { _, isLandscape in
            if isLandscape {
                // Enter fullscreen when device rotates to landscape
                if !userExitedFullscreen {
                    isManualFullscreen = true
                }
            } else {
                // Device returned to portrait - reset states and unlock orientation
                isManualFullscreen = false
                userExitedFullscreen = false
                OrientationManager.unlockOrientation()
            }
        }
        .onChange(of: viewModel.playerState) { _, newState in
            switch newState {
            case .playing:
                if showControls {
                    scheduleHideControls()
                }
            case .failed(let error):
                if let playerError = error as? PlayerError, playerError.isNetworkError {
                    showNetworkErrorAlert = true
                } else {
                    showPlaybackErrorAlert = true
                }
                cancelHideControls()
            default:
                cancelHideControls()
            }
        }
        .onAppear {
            OrientationManager.unlockOrientation()

            if viewModel.playerState == .playing {
                scheduleHideControls()
            }
        }
        .onDisappear {
            cancelHideControls()
        }
        .alert("alert.playbackError.title".localized, isPresented: $showPlaybackErrorAlert) {
            Button("alert.playbackError.continueNext".localized) {
                viewModel.playNextVideo()
            }
        } message: {
            Text("alert.playbackError.message".localized)
        }
        .alert("alert.networkError.title".localized, isPresented: $showNetworkErrorAlert) {
            Button("alert.networkError.goToSettings".localized) {
                URLOpener.openSettings()
            }
            Button("common.cancel".localized, role: .cancel) { }
        } message: {
            Text("alert.networkError.message".localized)
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
            PlayerView(onLayerReady: viewModel.connectPlayerLayer)
                .frame(height: height)
                .background(Color.black)

            // Loading Indicator (always visible when loading)
            if viewModel.playerState == .loading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // Player Controls (hidden when loading)
            if viewModel.playerState != .loading {
                PlayerControlView(
                    viewModel: viewModel,
                    isFullscreen: isFullscreenMode,
                    onUserInteraction: {
                        scheduleHideControls()
                    },
                    onFullscreenTap: {
                        toggleFullscreen()
                    }
                )
                .frame(height: height)
                .opacity(showControls ? 1 : 0)
                .allowsHitTesting(showControls)
                .animation(.easeInOut(duration: 0.3), value: showControls)
            }
        }
        .onTapGesture {
            showControls.toggle()
            if showControls {
                scheduleHideControls()
            }
        }
    }

    private func scheduleHideControls() {
        // Cancel existing task
        hideControlsTask?.cancel()

        // Only auto-hide when playing
        guard viewModel.playerState == .playing else { return }

        // Schedule new task to hide controls after 5 seconds
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: PlayerConstants.controlsAutoHideDelay)
            guard !Task.isCancelled else { return }
            showControls = false
        }
    }

    private func cancelHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = nil
    }

    // MARK: - Fullscreen Toggle

    private func toggleFullscreen() {
        isManualFullscreen.toggle()

        if isManualFullscreen {
            // Enter fullscreen - force landscape
            userExitedFullscreen = false
            OrientationManager.forceOrientation(.landscapeRight)
        } else {
            // Exit fullscreen - user explicitly exited
            userExitedFullscreen = true
            OrientationManager.forceOrientation(.portrait)
        }
    }
}

#Preview {
    NowPlayingView()
}
