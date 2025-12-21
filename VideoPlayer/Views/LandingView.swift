//
//  LandingView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/19.
//

import SwiftUI

enum NavigationDestination: Hashable {
    case player
}

struct LandingView: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Background gradient (same as video cell thumbnail)
                LinearGradient.appBackground
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    // Play Playlist Button
                    Button {
                        navigationPath.append(NavigationDestination.player)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("navigation.goToPlaylist", tableName: "Localizable")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Video Player")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                OrientationManager.forceOrientation(.portrait)
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .player:
                    NowPlayingView()
                }
            }
        }
        .onChange(of: navigationPath) { _, newPath in
            // When returning to LandingView (path is empty), lock to portrait
            if newPath.isEmpty {
                OrientationManager.forceOrientation(.portrait)
            }
        }
    }
}

#Preview {
    LandingView()
}
