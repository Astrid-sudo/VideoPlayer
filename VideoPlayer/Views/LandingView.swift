//
//  LandingView.swift
//  VideoPlayer
//
//  Created by Astrid Lin on 2025/12/19.
//

import SwiftUI

struct LandingView: View {
    @State private var showPlayer = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (same as video cell thumbnail)
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()

                    // Play Playlist Button
                    Button {
                        showPlayer = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Go to Playlist")
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
            .navigationDestination(isPresented: $showPlayer) {
                ContentView()
            }
        }
    }
}

#Preview {
    LandingView()
}
