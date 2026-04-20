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
                    .font(.system(size: 36)).foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: triggerBroadcastPicker) {
                        Label("Record", systemImage: "record.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    Button(action: startSession) {
                        Label("Start Session", systemImage: "play.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Start recording first, then tap Start Session")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16).padding(.horizontal)
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
            biasCard
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
        let insight = biasInsight

        return VStack(alignment: .leading, spacing: 10) {
            Label("Bias Patterns", systemImage: "brain.fill")
                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)

            Text(insight.interpretation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if !insight.dominantCategories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(insight.dominantCategories, id: \.self) { cat in
                        Text(cat)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
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

    // Groups raw bias strings (which vary wildly per Claude response) into stable
    // broad categories, then synthesises a one-sentence interpretation.
    private var biasInsight: (interpretation: String, dominantCategories: [String]) {
        let allBiases = factChecks.flatMap(\.biasIndicators)
        guard !allBiases.isEmpty else {
            return ("No strong bias patterns detected yet.", [])
        }

        // Bucket each raw bias string into a broad category
        var categoryCounts: [String: Int] = [:]
        for bias in allBiases {
            categoryCounts[broadCategory(for: bias), default: 0] += 1
        }

        // Stable sort: count desc, then name asc to break ties
        let ranked = categoryCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map(\.key)

        let top = Array(ranked.prefix(3))
        let avg = avgManipulationScore

        // Build a natural-language sentence from the dominant categories
        var sentence = ""
        switch top.count {
        case 0:
            sentence = "No strong bias patterns detected yet."
        case 1:
            sentence = "Your feed consistently relies on \(top[0].lowercased())."
        case 2:
            sentence = "Your feed leans on \(top[0].lowercased()) and \(top[1].lowercased())."
        default:
            sentence = "Your feed mixes \(top[0].lowercased()), \(top[1].lowercased()), and \(top[2].lowercased())."
        }

        // Append a severity note based on manipulation score
        if avg > 7 {
            sentence += " The content you're watching is highly manipulative overall."
        } else if avg > 4 {
            sentence += " Moderate manipulation is common in what you're watching."
        } else if avg > 0 {
            sentence += " The manipulation level is generally low."
        }

        return (sentence, top)
    }

    private func broadCategory(for bias: String) -> String {
        let b = bias.lowercased()
        if b.contains("fear") || b.contains("outrage") || b.contains("anger") ||
           b.contains("emotion") || b.contains("guilt") || b.contains("anxiety") {
            return "Emotional manipulation"
        }
        if b.contains("authority") || b.contains("expert") || b.contains("credib") ||
           b.contains("trust") || b.contains("official") {
            return "Appeal to authority"
        }
        if b.contains("urgency") || b.contains("scarcity") || b.contains("fomo") ||
           b.contains("limited") || b.contains("now or never") {
            return "False urgency"
        }
        if b.contains("confirm") || b.contains("echo") || b.contains("tribal") ||
           b.contains("in-group") || b.contains("us vs") {
            return "Confirmation bias"
        }
        if b.contains("mislead") || b.contains("false") || b.contains("inaccur") ||
           b.contains("misinform") || b.contains("fabricat") {
            return "Misinformation"
        }
        if b.contains("bandwagon") || b.contains("social proof") || b.contains("popular") ||
           b.contains("everyone") || b.contains("viral") {
            return "Social proof"
        }
        if b.contains("sensational") || b.contains("clickbait") || b.contains("exaggerat") ||
           b.contains("hyperbole") || b.contains("shocking") {
            return "Sensationalism"
        }
        if b.contains("nostalg") || b.contains("tradition") || b.contains("used to") {
            return "Appeal to tradition"
        }
        return "Other"
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
