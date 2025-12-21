# VideoPlayer Project

iOS HLS video player with playlist, PiP, remote control support.

## Architecture

```
Views (SwiftUI)
    ↓
ViewModel (NowPlayingViewModel)
    ↓
Interactors (Business Logic)
    ↓
Services (Protocols + Implementations)
```

### Directory Structure

```
VideoPlayer/
├── Views/                  # SwiftUI views
│   ├── LandingView.swift
│   ├── NowPlayingView.swift
│   ├── PlayerView.swift
│   ├── PlayerControlView.swift
│   └── PlaylistView.swift
├── ViewModels/
│   └── NowPlayingViewModel.swift   # Central coordinator
├── Interactors/
│   ├── PlaybackInteractor.swift        # Playback control & playlist
│   ├── MediaOptionsInteractor.swift    # Audio/subtitle selection
│   └── RemoteControlInteractor.swift   # Lock screen & Control Center
├── Services/
│   ├── Protocols/
│   │   ├── PlayerServiceProtocol.swift
│   │   ├── PlayerLayerConnectable.swift
│   │   ├── AudioSessionServiceProtocol.swift
│   │   ├── RemoteControlServiceProtocol.swift
│   │   ├── NetworkMonitorProtocol.swift
│   │   └── LoggerProtocol.swift
│   └── Implementations/
│       ├── PlayerService.swift          # AVQueuePlayer wrapper
│       ├── PlayerLayerService.swift     # AVPlayerLayer + PiP
│       ├── AudioSessionService.swift
│       ├── RemoteControlService.swift
│       └── NetworkMonitor.swift
├── Models/
│   ├── Video.swift
│   ├── PlayerState.swift
│   └── MediaOption.swift
└── Helpers/
    ├── TimeManager.swift
    └── OrientationManager.swift
```

### Patterns Used

- **Protocol-based DI**: All services have protocols, injected via init
- **Combine**: `@Published` properties + `AnyPublisher` for reactive state
- **Singleton**: `NetworkMonitor.shared` pattern for global services

### Key Components

- **PlayerService**: Wraps AVQueuePlayer with KVO observers
- **NowPlayingViewModel**: Coordinates all interactors, exposes UI state
- **Interactors**: Bridge between ViewModel and Services

---

## Commit Message Format

Format: `[type]: description`

Types:
- `[feat]` - New feature
- `[fix]` - Bug fix
- `[refactor]` - Code refactoring
- `[docs]` - Documentation
- `[test]` - Test updates
- `[chore]` - Maintenance

**Do NOT include AI co-author or generated-by mentions.**

---

## Working Guidelines

- When asked about Apple APIs (AVFoundation, SwiftUI, UIKit, etc.), use MCP tools (`mcp__apple-docs__*`) to search Apple Developer Documentation.
