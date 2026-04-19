# Unscrolled

**Unscrolled** is an iOS app that helps you develop media literacy and conscious content consumption habits by monitoring your social media sessions in real time.

---

## How It Works

1. You create a Shortcut on your home screen that opens Unscrolled (via the `unscrolled://` URL scheme).
2. Tapping the Shortcut launches Unscrolled. You tap **Start Session**.
3. A ReplayKit broadcast picker appears — select **Unscrolled Broadcast** to begin screen capture.
4. Instagram opens automatically. A floating semi-transparent bubble appears over all other apps via Picture-in-Picture.
5. Scroll as you normally would. Unscrolled captures every frame silently in the background.
6. When done, return to Unscrolled and tap **End Session**. Your session is logged and data is saved.

---

## Architecture

The project has two targets that communicate through a shared **App Group** (`group.com.unscrolled.app`):

| Target | Role |
|--------|------|
| `Unscrolled` (main app) | Dashboard, session management, floating bubble via PiP, notifications |
| `UnscrolledBroadcast` (broadcast upload extension) | Receives `CMSampleBuffer` frames, writes heartbeat + latest JPEG to the App Group container |

**Key identifiers:**
- Main app bundle ID: `com.unscrolled.app`
- Extension bundle ID: `com.unscrolled.app.broadcast`
- App Group: `group.com.unscrolled.app`
- URL scheme: `unscrolled://`

---

## Phase 1 Status (Current)

- [x] Real-time session timer (live, persists across app launches)
- [x] Total time accumulation across all sessions (stored in App Group UserDefaults)
- [x] Recent sessions list
- [x] Notifications every 5 minutes while a session is active ("Still watching?")
- [x] ReplayKit Broadcast Upload Extension wired up — receives `CMSampleBuffer`, writes heartbeat timestamp + latest frame JPEG to App Group
- [x] Floating bubble via `AVPictureInPictureVideoCallViewController` — persists over all apps, draggable when in-app, tapping PiP window returns to Unscrolled
- [x] Silent audio session (AVAudioSession `.playback`) keeps app process alive in background
- [x] Clean SwiftUI dashboard with placeholder cards for future analytics
- [x] Start/End session flow with broadcast picker integration

---

## Setup Instructions

### Prerequisites
- Xcode 15 or later
- An iPhone running iOS 17+
- An Apple Developer account (free tier works for device testing, paid for distribution)

### Opening the Project
```
open "Unscrolled.xcodeproj"
```

### Signing & Capabilities

**For both targets** (Unscrolled and UnscrolledBroadcast):

1. Open **Signing & Capabilities** for the `Unscrolled` target.
2. Set your **Team** to your Apple ID / developer team.
3. The **Bundle Identifier** is pre-set to `com.unscrolled.app` — change it to something unique if needed (e.g. `com.yourname.unscrolled`). If you change it, also update `com.unscrolled.app.broadcast` for the extension and `group.com.unscrolled.app` in both entitlements files.
4. Repeat for the **UnscrolledBroadcast** target (Team, Bundle ID).

**Required capabilities to enable:**

| Target | Capability | Notes |
|--------|-----------|-------|
| Unscrolled | **App Groups** | Add `group.com.unscrolled.app` |
| Unscrolled | **Push Notifications** | For local notifications |
| Unscrolled | **Background Modes → Audio** | For silent keepalive (already in Info.plist) |
| UnscrolledBroadcast | **App Groups** | Add `group.com.unscrolled.app` |

These are listed in the `.entitlements` files — Xcode just needs to register them with Apple when you click the `+` in Signing & Capabilities.

### Installing on Device
1. Connect your iPhone.
2. Select your device in the scheme picker.
3. Press **Cmd+R** or click Run.
4. Trust the developer certificate on your iPhone: **Settings → General → VPN & Device Management**.

### Setting Up the iOS Shortcut
1. Open the **Shortcuts** app on your iPhone.
2. Create a new shortcut with the action **Open URLs** → set URL to `unscrolled://`.
3. Add the action **Open App** → Instagram.
4. Give the shortcut a name and add it to your home screen.

> When you tap the shortcut, Unscrolled opens first. Start your session, then Instagram opens automatically after you confirm the broadcast.

---

## Project Structure

```
Unscrolled/
├── AppDelegate.swift          — App entry point, URL scheme handler
├── SceneDelegate.swift        — Window creation, bubble setup
├── ContentView.swift          — Main dashboard (SwiftUI)
├── SessionManager.swift       — Session state, timer, persistence
├── BroadcastManager.swift     — RPBroadcastActivityViewController lifecycle
├── BubbleWindowManager.swift  — PiP floating bubble + in-app UIWindow bubble
├── BubbleView.swift           — BubbleCircleView (SwiftUI)
├── NotificationManager.swift  — Local push notifications every 5 min
├── SilentAudioPlayer.swift    — AVAudioSession keepalive
├── Info.plist
├── Unscrolled.entitlements
└── Assets.xcassets/

UnscrolledBroadcast/
├── SampleHandler.swift        — RPBroadcastSampleHandler: receives frames, writes heartbeat + JPEG
├── Info.plist
└── UnscrolledBroadcast.entitlements
```

---

## Roadmap

### Phase 2 — Reel Intelligence
- Frame diffing to detect reel boundaries (swipe = pixel diff spike)
- Reel count, average reel duration, scroll velocity
- Rewatch detection via perceptual hashing of keyframes
- Save 1 keyframe/second as JPEG to App Group for AI analysis

### Phase 3 — Audio Intelligence
- Pipe `audioApp` CMSampleBuffer into `SFSpeechAudioBufferRecognitionRequest` for real-time on-device transcription
- Audio classification (music / speech / silence) via Apple's SoundAnalysis framework

### Phase 4 — AI Analysis
- On-demand fact checking: tap bubble → latest frame sent to Claude API (`claude-sonnet-4-20250514`) → result shown as bottom sheet overlay
- Cognitive bias detection from transcripts (outrage bait, false urgency, appeal to authority, anecdote as evidence)
- Emotional arc tracking per session

### Phase 5 — Dashboard Intelligence
- Topic classification (politics, comedy, finance, fitness, etc.)
- Rot Score: composite metric of session duration + scroll velocity + time of day
- Bias report card
- Emotional arc visualization
- "What your algorithm thinks you are" weekly summary
- Full bubble menu: single tap = fact check, double tap = deep analysis, long press = feature menu

---

## Technical Notes

- **Minimum deployment target:** iOS 17.0
- **Swift:** 5.9+
- **IPC:** All extension↔app communication goes through the App Group container (UserDefaults + files). No XPC needed for Phase 1.
- **Floating bubble:** Uses `AVPictureInPictureVideoCallViewController` (iOS 15+) to render the bubble in a PiP window that floats over all other apps. The silent `AVAudioSession` (.playback) keeps the app process alive while the user is in Instagram.
- **No data leaves the device** in Phase 1. Future AI features will send frames/text to Claude API over HTTPS.
