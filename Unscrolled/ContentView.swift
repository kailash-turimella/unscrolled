import SwiftUI
import ReplayKit

// MARK: - Broadcast picker trigger

func triggerBroadcastPicker() {
    let picker = RPSystemBroadcastPickerView()
    picker.preferredExtension = "com.kailash.unscrolled.broadcast"
    picker.showsMicrophoneButton = false

    func firstButton(in view: UIView) -> UIButton? {
        if let b = view as? UIButton { return b }
        for sub in view.subviews {
            if let found = firstButton(in: sub) { return found }
        }
        return nil
    }

    firstButton(in: picker)?.sendActions(for: .touchUpInside)
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var session: SessionManager
    @State private var showFactCheck = false
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    sessionCard
                    totalTimeCard
                    placeholderGrid
                    recentSessionsCard
                }
                .padding()
            }
            .navigationTitle("Unscrolled")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showFactCheck) {
            FactCheckView().environmentObject(session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFactCheck)) { _ in
            showFactCheck = true
        }
    }

    // MARK: – Session card

    private var sessionCard: some View {
        VStack(spacing: 16) {
            if session.isSessionActive {
                Text(session.currentSessionDuration.formattedTime)
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .contentTransition(.numericText())

                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("Session in progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button("End Session", action: endSession)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

            } else {
                Image(systemName: "eye.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                // Step 1 — start screen recording
                VStack(spacing: 6) {
                    Text("Step 1 — Start recording")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: triggerBroadcastPicker) {
                        Label("Start Screen Recording", systemImage: "record.circle")
                    }
                    .buttonStyle(.bordered)
                }

                // Step 2 — start session
                VStack(spacing: 6) {
                    Text("Step 2 — Start session")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Start Session & Open Instagram", action: startSession)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Stats

    private var totalTimeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Total Time", systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button("Reset") { showResetConfirm = true }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(session.totalTimeSpent.formattedTime)
                .font(.system(size: 36, weight: .semibold, design: .monospaced))

            Text("across all sessions")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .confirmationDialog("Reset all stats?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { session.resetStats() }
        } message: {
            Text("This clears your total time and session history. It cannot be undone.")
        }
    }

    private var placeholderGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            PlaceholderCard(title: "Reels Watched",   icon: "play.rectangle.fill")
            PlaceholderCard(title: "Avg Per Reel",    icon: "timer")
            PlaceholderCard(title: "Scroll Velocity", icon: "arrow.up.arrow.down")
            PlaceholderCard(title: "Rot Score",       icon: "brain.head.profile")
            PlaceholderCard(title: "Top Topics",      icon: "tag.fill")
            PlaceholderCard(title: "Bias Detected",   icon: "exclamationmark.triangle.fill")
            PlaceholderCard(title: "Emotional Arc",   icon: "waveform.path.ecg")
            PlaceholderCard(title: "Fact Checks",     icon: "checkmark.seal.fill")
        }
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if session.recentSessions.isEmpty {
                Text("No sessions yet. Tap Start Session to begin your first monitored scroll.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(session.recentSessions.prefix(15)) { record in
                    SessionRow(record: record)
                    if record.id != session.recentSessions.prefix(15).last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Actions

    private func startSession() {
        SessionManager.shared.startSession()
        if let url = URL(string: "instagram://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func endSession() {
        SessionManager.shared.endSession()
    }
}

// MARK: – Supporting views

struct PlaceholderCard: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("--")
                .font(.system(size: 28, weight: .semibold, design: .monospaced))

            Text("Available after content analysis is enabled")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionRow: View {
    let record: SessionRecord

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.formatter.string(from: record.startTime))
                    .font(.subheadline)
                Text(record.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView().environmentObject(SessionManager.shared)
}
