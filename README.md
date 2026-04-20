# Unscrolled

A personal iOS app that fact-checks whatever is on your screen while you scroll Instagram.

Start a session, open Instagram, scroll. When something looks questionable, tap the Dynamic Island — it captures a screenshot of that moment and runs it through Claude. You get back what the content actually claims, whether those claims hold up, and what manipulation techniques it's using on you.

---

## What It Does

- **Fact check on demand** — Tap the Dynamic Island during a session. The app captures a static frame from that instant and runs a three-step analysis: extract the content, analyze it for bias and manipulation, fact-check the claims.
- **Session tracking** — Timer runs while you're in Instagram. Total time accumulates across sessions.
- **Nudge notifications** — Local notifications every 5 minutes reminding you how long you've been scrolling.
- **Session history** — Log of every session with start time and duration.

## How the Analysis Works

Each fact check makes three separate calls to `claude-sonnet-4-20250514`, each building on the last:

1. **Extract** — The screenshot is sent once. Claude pulls out the content type, username, caption, all visible text, and any factual claims.
2. **Analyze** — The extracted data (no image) is analyzed for cognitive bias, emotional manipulation techniques, and what the content signals about your algorithmic profile.
3. **Fact check** — The claims list is checked individually. Each gets a verdict: true, false, misleading, or unverifiable. Claude uses "unverifiable" rather than guessing.

Using structured tool calls for each step enforces a strict JSON schema on every response — no freeform prose that can drift or hallucinate.

---

## How It Works

1. Open Unscrolled.
2. Tap **Start Screen Recording** and select **Unscrolled Broadcast** from the picker.
3. Tap **Start Session & Open Instagram** — Instagram opens and the session begins.
4. Scroll normally. When you want something fact-checked, tap the Dynamic Island timer.
5. The app captures that frame and runs the analysis. Results appear in three cards.
6. When done, return to Unscrolled and tap **End Session**.

---

## Architecture

Three targets sharing an **App Group** (`group.com.kailash.unscrolled`):

| Target | Role |
|--------|------|
| `Unscrolled` | Dashboard, session management, notifications, Live Activity, analysis pipeline |
| `UnscrolledBroadcast` | Receives `CMSampleBuffer` frames from ReplayKit, writes heartbeat + latest JPEG to App Group |
| `UnscrolledWidgets` | Dynamic Island Live Activity (timer + tap target) |

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
├── AppDelegate.swift               — Entry point, URL scheme handler
├── SceneDelegate.swift             — Window setup, factcheck URL routing
├── ContentView.swift               — Main dashboard (SwiftUI)
├── SessionManager.swift            — Session state, timer, persistence
├── SessionActivityAttributes.swift — Shared Live Activity data model
├── LiveActivityManager.swift       — Starts/stops Dynamic Island activity
├── FactCheckView.swift             — Analysis results UI
├── AnthropicClient.swift           — URLSession wrapper for Claude API
├── AnalysisModels.swift            — Codable structs + tool schemas for all three steps
├── ContentAnalyzer.swift           — Three-step analysis pipeline
├── APIConfig.swift                 — API key (gitignored — see APIConfig.example.swift)
├── BroadcastManager.swift          — Broadcast picker helper
├── NotificationManager.swift       — 5-minute nudge notifications
├── SilentAudioPlayer.swift         — AVAudioSession keepalive in background
├── Info.plist
├── Unscrolled.entitlements
└── Assets.xcassets/

UnscrolledBroadcast/
├── SampleHandler.swift             — RPBroadcastSampleHandler: captures frames, writes heartbeat + JPEG
├── Info.plist
└── UnscrolledBroadcast.entitlements

UnscrolledWidgets/
├── UnscrolledWidgets.swift         — WidgetBundle entry point
├── UnscrolledLiveActivity.swift    — Dynamic Island layout
├── Info.plist
└── UnscrolledWidgets.entitlements
```

---

## Setup

### Prerequisites
- Xcode 15+
- iPhone running iOS 17+
- Free Apple Developer account (sufficient for device testing)
- Anthropic API key

### API Key
Copy `APIConfig.example.swift` to `APIConfig.swift` and paste your key. That file is gitignored.

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

- **IPC:** Extension↔app communication goes through the App Group container (UserDefaults for heartbeat, filesystem for JPEG frames).
- **Background keepalive:** Silent `AVAudioSession` (`.playback`) keeps the main app process alive while on Instagram.
- **No data leaves the device** except the single frame sent to the Claude API when you explicitly tap the Dynamic Island. That image is not stored or logged by the app.

---

## What's Next

The current fact-check is single-frame. The next step is reel-level analysis — detecting reel boundaries from frame diffs, tracking reels watched per session, and running analysis across the full session rather than a single moment. Eventually the dashboard placeholder cards (reels watched, scroll velocity, topic breakdown, bias score) get filled in from real data.
