import SwiftUI
import SwiftData
import ReplayKit

// MARK: - Broadcast picker trigger

func triggerBroadcastPicker() {
    let picker = RPSystemBroadcastPickerView()
    picker.preferredExtension = "com.kailash.unscrolled.broadcast"
    picker.showsMicrophoneButton = false

    func firstButton(in view: UIView) -> UIButton? {
        if let b = view as? UIButton { return b }
        for sub in view.subviews { if let found = firstButton(in: sub) { return found } }
        return nil
    }
    firstButton(in: picker)?.sendActions(for: .touchUpInside)
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.modelContext) private var modelContext
    @State private var showFactCheck = false
    @State private var showResetConfirm = false

    @Query(sort: \SessionItem.startTime, order: .reverse) private var sessions: [SessionItem]
    @Query(sort: \FactCheckItem.timestamp, order: .reverse) private var factChecks: [FactCheckItem]

    private var totalTimeSpent: TimeInterval { sessions.reduce(0) { $0 + $1.duration } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    sessionCard
                    totalTimeCard
                    if !factChecks.isEmpty { analyticsSection }
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
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                Button("End Session", action: endSession)
                    .buttonStyle(.borderedProminent).tint(.red)

            } else {
                Image(systemName: "eye.slash")
                    .font(.system(size: 40)).foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("Step 1 — Start recording")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(action: triggerBroadcastPicker) {
                        Label("Start Screen Recording", systemImage: "record.circle")
                    }
                    .buttonStyle(.bordered)
                }

                VStack(spacing: 6) {
                    Text("Step 2 — Start session")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Start Session & Open Instagram", action: startSession)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24).padding(.horizontal)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Total time card

    private var totalTimeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Total Time", systemImage: "clock.fill")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                Button("Reset") { showResetConfirm = true }
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text(totalTimeSpent.formattedTime)
                .font(.system(size: 36, weight: .semibold, design: .monospaced))

            Text("across \(sessions.count) session\(sessions.count == 1 ? "" : "s")")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .confirmationDialog("Reset all data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { resetAll() }
        } message: {
            Text("Deletes all sessions and fact check history. Cannot be undone.")
        }
    }

    // MARK: – Analytics (only rendered when there's fact check data)

    private var analyticsSection: some View {
        VStack(spacing: 16) {
            manipulationCard
            if !topBiases.isEmpty { biasCard }
            verdictCard
        }
    }

    private var manipulationCard: some View {
        let avg = avgManipulationScore
        let color: Color = avg <= 3 ? .green : avg <= 6 ? .orange : .red

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Manipulation", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                Text("\(factChecks.count) fact check\(factChecks.count == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", avg))
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                Text("/ 10 avg")
                    .font(.caption).foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.2)).frame(height: 6)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(avg / 10), height: 6)
                        .animation(.easeOut, value: avg)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var biasCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Common Biases", systemImage: "brain.fill")
                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(topBiases, id: \.0) { bias, count in
                    HStack {
                        Text(bias)
                            .font(.subheadline)
                        Spacer()
                        Text("\(count)×")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if bias != topBiases.last?.0 { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var verdictCard: some View {
        let counts = verdictCounts

        return VStack(alignment: .leading, spacing: 10) {
            Label("Fact Check Verdicts", systemImage: "checkmark.seal.fill")
                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)

            HStack(spacing: 0) {
                ForEach(verdictOrder, id: \.0) { label, color in
                    if let count = counts[label], count > 0 {
                        VStack(spacing: 4) {
                            Text("\(count)")
                                .font(.system(.title3, design: .monospaced, weight: .semibold))
                                .foregroundStyle(color)
                            Text(label.capitalized)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Recent sessions

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions").font(.headline)

            if sessions.isEmpty {
                Text("No sessions yet. Tap Start Session to begin.")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ForEach(sessions.prefix(15)) { item in
                    SessionRow(item: item)
                    if item.id != sessions.prefix(15).last?.id { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: – Computed analytics

    private var avgManipulationScore: Double {
        guard !factChecks.isEmpty else { return 0 }
        return Double(factChecks.map(\.manipulationScore).reduce(0, +)) / Double(factChecks.count)
    }

    private var topBiases: [(String, Int)] {
        var counts: [String: Int] = [:]
        factChecks.flatMap(\.biasIndicators).forEach { counts[$0, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    private var verdictCounts: [String: Int] {
        var counts: [String: Int] = [:]
        factChecks.map(\.overallVerdict).forEach { counts[$0, default: 0] += 1 }
        return counts
    }

    private let verdictOrder: [(String, Color)] = [
        ("accurate", .green),
        ("mostly accurate", .blue),
        ("misleading", .orange),
        ("false", .red),
        ("unverifiable", .secondary)
    ]

    // MARK: – Actions

    private func startSession() {
        SessionManager.shared.startSession()
        if let url = URL(string: "instagram://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func endSession() { SessionManager.shared.endSession() }

    private func resetAll() {
        sessions.forEach { modelContext.delete($0) }
        factChecks.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: – Supporting views

struct SessionRow: View {
    let item: SessionItem

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.formatter.string(from: item.startTime)).font(.subheadline)
                Text(item.formattedDuration).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView().environmentObject(SessionManager.shared)
}
