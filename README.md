# Unscrolled

A personal iOS app that watches what I watch. It runs silently in the background while I scroll Instagram, capturing every frame and tracking how long I've been on it.

The end goal is to have an app that can tell me: how many reels I watched, what they were about, whether they were accurate, how they made me feel, and how my algorithm has profiled me — all as an ambient part of using my phone, not a separate journaling exercise.

---

## What It Does Today

- **Session tracking** — Start a session, open Instagram, scroll. A timer runs and accumulates across sessions so I can see my total time.
- **Screen capture** — Uses iOS's built-in screen recording to silently capture frames in the background. Nothing leaves the device.
- **Dynamic Island timer** — A live timer shows on the Dynamic Island while a session is active. Tapping it opens a Fact Check view showing the latest captured frame.
- **Floating bubble** — A draggable bubble stays visible while the app is in the foreground so I know a session is active.
- **Nudge notifications** — Notifications every 5 minutes reminding me how long I've been scrolling.
- **Session history** — A log of every session with start time and duration.

---

## How It Works

1. Open Unscrolled.
2. Tap **Start Screen Recording** and select **Unscrolled Broadcast** from the picker.
3. Tap **Start Session & Open Instagram** — Instagram opens and the session begins.
4. Scroll normally. Unscrolled captures frames in the background via ReplayKit.
5. When done, return to Unscrolled and tap **End Session**.

---

## Architecture

Three targets sharing an **App Group** (`group.com.kailash.unscrolled`):

| Target | Role |
|--------|------|
| `Unscrolled` | Dashboard, session management, notifications, Live Activity |
| `UnscrolledBroadcast` | Receives `CMSampleBuffer` frames from ReplayKit, writes heartbeat + latest JPEG to App Group |
| `UnscrolledWidgets` | Dynamic Island Live Activity (timer + Fact Check button) |

**Key identifiers:**
- Main app: `com.kailash.unscrolled`
- Broadcast extension: `com.kailash.unscrolled.broadcast`
- Widget extension: `com.kailash.unscrolled.widgets`
- App Group: `group.com.kailash.unscrolled`
- URL scheme: `unscrolled://`

---

## Project Structure

```
Unscrolled/
├── AppDelegate.swift              — Entry point, URL scheme handler
├── SceneDelegate.swift            — Window setup, factcheck URL routing
├── ContentView.swift              — Main dashboard (SwiftUI)
├── SessionManager.swift           — Session state, timer, persistence
├── SessionActivityAttributes.swift — Shared Live Activity data model
├── LiveActivityManager.swift      — Starts/stops Dynamic Island activity
├── FactCheckView.swift            — Shows latest captured frame
├── BroadcastManager.swift         — Broadcast picker helper
├── BubbleWindowManager.swift      — Draggable in-app bubble (UIWindow)
├── BubbleView.swift               — Bubble circle (SwiftUI)
├── NotificationManager.swift      — 5-minute nudge notifications
├── SilentAudioPlayer.swift        — AVAudioSession keepalive in background
├── Info.plist
├── Unscrolled.entitlements
└── Assets.xcassets/

UnscrolledBroadcast/
├── SampleHandler.swift            — RPBroadcastSampleHandler: captures frames, writes heartbeat + JPEG
├── Info.plist
└── UnscrolledBroadcast.entitlements

UnscrolledWidgets/
├── UnscrolledWidgets.swift        — WidgetBundle entry point
├── UnscrolledLiveActivity.swift   — Dynamic Island layout (compact, expanded, lock screen)
├── Info.plist
└── UnscrolledWidgets.entitlements
```

---

## Setup

### Prerequisites
- Xcode 15+
- iPhone running iOS 17+
- Free Apple Developer account (sufficient for device testing)

### Signing

For each of the three targets (Unscrolled, UnscrolledBroadcast, UnscrolledWidgets):

1. Open **Signing & Capabilities** and set your **Team**.
2. Bundle IDs are pre-set — Xcode will auto-provision them.
3. For **UnscrolledWidgets**, also add the **App Groups** capability → `group.com.kailash.unscrolled`.

### Run

1. Connect your iPhone, select it in the scheme picker.
2. Select the **Unscrolled** scheme and press **Cmd+R**.
3. Trust the developer certificate: **Settings → General → VPN & Device Management**.

---

## Technical Notes

- **IPC:** Extension↔app communication goes through the App Group container (UserDefaults for heartbeat, filesystem for JPEG frames). No XPC.
- **Background keepalive:** Silent `AVAudioSession` (`.playback`) keeps the main app process alive while on Instagram.
- **No data leaves the device.** Screen capture stays local. Future AI features will send frames to an API on explicit user request only.
