# VideoPlayer 重構計劃

## 目標

將現有的 Massive ViewModel 架構重構為符合 SOLID 原則、依賴方向正確、命名直觀的分層架構。

---

## 當前架構

### 現有檔案結構

```
VideoPlayer/
├── VideoPlayerApp.swift
├── ContentView.swift
├── ViewModels/
│   └── VideoPlayerViewModel.swift    ← 639 行，職責過多
├── Views/
│   ├── PlayerView.swift
│   ├── PlayerControlView.swift
│   ├── PlaylistView.swift
│   └── PlaylistItemView.swift
├── Models/
│   ├── Video.swift
│   ├── PlayerState.swift
│   └── MediaOption.swift
└── Helpers/
    ├── OrientationManager.swift
    ├── TimeManager.swift
    └── ThumbnailGenerator.swift
```

### 已實作功能清單

#### 播放控制
- 播放/暫停切換
- 快進 15 秒
- 快退 15 秒
- 進度條拖曳（seek）
- 播放速度調整（0.5x / 1.0x / 1.5x）

#### 播放列表
- 播放列表顯示
- 點擊播放指定影片
- 播放下一個
- 自動播放下一個影片
- 播放結束後循環到第一個

#### Picture in Picture
- PiP 啟動/停止
- PiP 可用性檢測

#### 媒體選項
- 字幕切換
- 音軌切換

#### 遠程控制（鎖屏/控制中心）
- 播放/暫停
- 下一首
- 快進/快退 15 秒
- 進度條拖曳
- Now Playing 資訊（標題、時長、進度、封面圖）

#### 音訊會話
- 背景播放（AVAudioSession playback mode）

#### 緩衝狀態
- 緩衝中顯示 loading indicator
- 緩衝狀態觀察

#### 全螢幕
- 全螢幕切換
- 自動跟隨設備方向
- 強制橫向/直向

#### UI 控制
- 播放時間顯示
- 影片時長顯示
- 進度條
- 控制條自動隱藏（5 秒）
- 點擊顯示/隱藏控制條

#### Helpers
- 時間格式轉換（TimeManager）
- 縮圖生成（ThumbnailGenerator）
- 設備方向管理（OrientationManager）

---

### 當前問題

**VideoPlayerViewModel 包含過多職責：**
- 播放控制（AVQueuePlayer 操作）
- 音訊會話管理（AVAudioSession 設置）
- 遠程控制（MPRemoteCommandCenter 註冊）
- 播放列表管理
- 媒體選項（字幕/音軌切換）
- PiP 控制
- 時間觀察者管理
- UI 狀態管理

這違反了單一職責原則（SRP），導致難以測試和維護。

---

## 目標架構

### 架構分層

```
依賴方向：由外向內 →

┌──────────────────────────────────────────────────────────────┐
│  最外層：Frameworks & Drivers                                 │
│  - Views (SwiftUI)                                           │
│  - 外部框架 (AVFoundation, MediaPlayer, UIKit)                │
│  - Service 實作 (PlayerService, AudioSessionService...)       │
└────────────────────────────┬─────────────────────────────────┘
                             │ 依賴（實作協議）
                             ↓
┌──────────────────────────────────────────────────────────────┐
│  Interface Adapters                                           │
│  - ViewModels (協調 UI 和業務邏輯)                             │
│  - Service 協議 (PlayerServiceProtocol...)                    │
└────────────────────────────┬─────────────────────────────────┘
                             │ 依賴
                             ↓
┌──────────────────────────────────────────────────────────────┐
│  Use Cases (業務邏輯層)                                        │
│  - Managers (PlaybackManager, PlaylistManager...)             │
└────────────────────────────┬─────────────────────────────────┘
                             │ 依賴
                             ↓
┌──────────────────────────────────────────────────────────────┐
│  最內層：Entities                                             │
│  - Models (Video, PlayerState, MediaOption)                   │
└──────────────────────────────────────────────────────────────┘
```

**關鍵：**
- Service **實作**（依賴 AVFoundation）在最外層
- Service **協議**（純 Swift protocol）在內層
- Managers 只依賴協議，不直接依賴外部框架

### 目標檔案結構

```
VideoPlayer/
├── VideoPlayerApp.swift
├── ContentView.swift
│
├── Models/                              ✓ 已存在
│   ├── Video.swift
│   ├── PlayerState.swift
│   └── MediaOption.swift
│
├── Services/                            ← 需新增
│   ├── Protocols/
│   │   ├── PlayerServiceProtocol.swift
│   │   ├── AudioSessionServiceProtocol.swift
│   │   └── RemoteControlServiceProtocol.swift
│   └── Implementations/
│       ├── PlayerService.swift           ← 封裝 AVQueuePlayer
│       ├── AudioSessionService.swift     ← 封裝 AVAudioSession
│       └── RemoteControlService.swift    ← 封裝 MPRemoteCommandCenter
│
├── Managers/                            ← 需新增
│   ├── PlaybackManager.swift             ← 播放控制業務邏輯
│   ├── PlaylistManager.swift             ← 播放列表業務邏輯
│   ├── MediaOptionsManager.swift         ← 媒體選項業務邏輯
│   └── RemoteControlManager.swift        ← 遠程控制業務邏輯
│
├── ViewModels/                          ✓ 已存在
│   └── VideoPlayerViewModel.swift        ← 需精簡
│
├── Views/                               ✓ 已存在
│   ├── PlayerView.swift
│   ├── PlayerControlView.swift
│   ├── PlaylistView.swift
│   └── PlaylistItemView.swift
│
├── Helpers/                             ✓ 已存在
│   ├── OrientationManager.swift
│   ├── TimeManager.swift
│   └── ThumbnailGenerator.swift
│
└── DI/                                  ← 需新增
    └── DIContainer.swift
```

---

## 命名對照

| 層級 | 命名 | 職責 |
|-----|-----|------|
| Models | Video, PlayerState | 純數據結構，無邏輯 |
| Services | PlayerService, AudioSessionService | 封裝外部框架 |
| Managers | PlaybackManager, PlaylistManager | 業務邏輯協調 |
| ViewModels | VideoPlayerViewModel | UI 狀態協調 |
| Views | PlayerView, ContentView | UI 渲染 |
| Helpers | TimeManager, OrientationManager | 工具函數 |

---

## 重構階段

### 階段 1：定義協議

建立 Services 層的協議，定義抽象接口。

**新增：**
- PlayerServiceProtocol（播放器操作）
- AudioSessionServiceProtocol（音訊會話）
- RemoteControlServiceProtocol（遠程控制）

### 階段 2：實作 Services

從 VideoPlayerViewModel 抽取底層邏輯。

**新增：**
- PlayerService：封裝 AVQueuePlayer
- AudioSessionService：封裝 AVAudioSession
- RemoteControlService：封裝 MPRemoteCommandCenter

### 階段 3：建立 Managers

建立業務邏輯層，協調 Services。

**新增：**
- PlaybackManager：播放控制邏輯
- PlaylistManager：播放列表邏輯
- MediaOptionsManager：媒體選項邏輯
- RemoteControlManager：遠程控制邏輯

### 階段 4：重構 ViewModel

精簡 VideoPlayerViewModel 為協調者角色。

**修改：**
- 注入 Managers
- 只保留 UI 狀態和轉換邏輯
- 所有業務邏輯委託給 Managers

### 階段 5：建立 DI 容器

集中管理依賴創建。

**新增：**
- DIContainer 管理 Services 實例
- 提供 Factory 方法創建 Managers 和 ViewModel

### 階段 6：補充測試

建立單元測試，使用 Mock 對象。

**新增：**
- Mock Services 用於測試 Managers
- Mock Managers 用於測試 ViewModel

---

## 成功指標

### 架構品質
- [ ] 依賴方向正確：外部框架/Views/Service實作 → ViewModels/Service協議 → Managers → Models
- [ ] 所有跨層依賴通過協議
- [ ] VideoPlayerViewModel 從 639 行降至 ~150 行

### SOLID 原則
- [ ] SRP：每個類只有一個職責
- [ ] OCP：可以擴展不需修改（通過協議）
- [ ] DIP：依賴抽象（協議），不依賴具體實作

### 可測試性
- [ ] Services 可以 mock
- [ ] Managers 可以獨立測試
- [ ] ViewModel 可以注入 mock Managers

---

## 參考資料

- [The Clean Architecture - Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [Dependency Injection in Swift](https://www.swiftbysundell.com/articles/dependency-injection-using-factories-in-swift/)
