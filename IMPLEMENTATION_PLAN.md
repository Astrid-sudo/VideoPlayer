# Video Player App - Implementation Plan

## Assignment Requirements

Please develop an app that can play a video from the Internet with custom UI and functionalities.

*Please build it using SwiftUI

1. Please design the UI and functionalities yourself, or get inspired by mainstream apps.
2. Please implement the app in the highest standard / quality you can, and as how you do it for a release-ready app in the app store.
3. One or two screens are enough.
4. Please submit the GitHub link of the code.
5. Please deliver in around 5 days, but it is totally okay that if you need more time, and please let us know.

## Planned Features

### Core Features
- Video playback from Internet URLs (HLS streaming)
- Custom player controls (play/pause, seek, skip forward/backward)
- Playback speed adjustment
- Progress bar with current time and duration display
- Fullscreen mode with device orientation support

### Enhanced Features
- Playlist management with multiple videos
- Picture-in-Picture (PiP) support
- Lock screen and Control Center integration (remote commands, now playing info)
- Audio track selection
- Subtitle track selection
- Buffering state indicator

### UI/UX
- Landing page with navigation to player
- Auto-hide controls during playback
- Smooth transitions between normal and fullscreen modes

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Views (SwiftUI)                       │
│  LandingView, NowPlayingView, PlayerView, PlayerControlView, │
│  PlaylistView, PlaylistItemView                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    VideoPlayerViewModel                      │
│              Coordinates UI state and Managers               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                         Managers                             │
│  PlaybackManager, PlaylistManager, MediaOptionsManager,     │
│  RemoteControlManager                                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Services (Protocols)                       │
│  PlayerServiceProtocol, PlayerLayerConnectable,             │
│  AudioSessionServiceProtocol, RemoteControlServiceProtocol  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Service Implementations (AVFoundation)          │
│  PlayerService, AudioSessionService, RemoteControlService   │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
VideoPlayer/
├── Models/
│   ├── Video.swift
│   ├── PlayerState.swift
│   └── MediaOption.swift
├── Services/
│   ├── Protocols/
│   │   ├── PlayerServiceProtocol.swift
│   │   ├── PlayerLayerConnectable.swift
│   │   ├── AudioSessionServiceProtocol.swift
│   │   └── RemoteControlServiceProtocol.swift
│   └── Implementations/
│       ├── PlayerService.swift
│       ├── AudioSessionService.swift
│       └── RemoteControlService.swift
├── Managers/
│   ├── PlaybackManager.swift
│   ├── PlaylistManager.swift
│   ├── MediaOptionsManager.swift
│   └── RemoteControlManager.swift
├── ViewModels/
│   └── VideoPlayerViewModel.swift
├── Views/
│   ├── LandingView.swift
│   ├── NowPlayingView.swift
│   ├── PlayerView.swift
│   ├── PlayerControlView.swift
│   ├── PlaylistView.swift
│   └── PlaylistItemView.swift
├── Helpers/
│   ├── TimeManager.swift
│   └── OrientationManager.swift
└── DI/
    └── DIContainer.swift
```
