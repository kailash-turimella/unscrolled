import Foundation
import UIKit
import SwiftData

final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    private lazy var defaults: UserDefaults = {
        UserDefaults(suiteName: "group.com.kailash.unscrolled") ?? .standard
    }()

    private lazy var appGroupURL: URL? = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kailash.unscrolled")
    }()

    @Published var isSessionActive = false
    @Published var sessionStartTime: Date?
    @Published var currentSessionDuration: TimeInterval = 0
    @Published var isBroadcastAlive = false
    @Published var latestFrame: UIImage?
    @Published var factCheckFrame: UIImage?

    private var modelContext: ModelContext?
    private var timer: Timer?
    private var broadcastPollTimer: Timer?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        migrateFromUserDefaultsIfNeeded()
        resumeActiveSessionIfNeeded()
    }

    // MARK: - Session lifecycle

    func startSession() {
        let now = Date()
        sessionStartTime = now
        isSessionActive = true
        defaults.set(now, forKey: "sessionStartTime")
        startLiveTimer()
        NotificationManager.shared.scheduleSessionNotifications(from: now)
        LiveActivityManager.shared.start(sessionStart: now)
    }

    func endSession() {
        guard let start = sessionStartTime else { return }
        let duration = Date().timeIntervalSince(start)

        let item = SessionItem(startTime: start, duration: duration)
        modelContext?.insert(item)
        try? modelContext?.save()

        defaults.removeObject(forKey: "sessionStartTime")
        sessionStartTime = nil
        isSessionActive = false
        currentSessionDuration = 0
        timer?.invalidate()
        timer = nil

        NotificationManager.shared.cancelAll()
        LiveActivityManager.shared.stop()
    }

    // MARK: - Fact check frame

    func captureFactCheckFrame() {
        loadLatestFrame()
        factCheckFrame = latestFrame
    }

    // MARK: - Broadcast polling

    func startBroadcastPolling() {
        refreshBroadcastHeartbeat()
        broadcastPollTimer?.invalidate()
        broadcastPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshBroadcastHeartbeat()
        }
    }

    func stopBroadcastPolling() {
        broadcastPollTimer?.invalidate()
        broadcastPollTimer = nil
    }

    func refreshBroadcastHeartbeat() {
        guard let heartbeat = defaults.object(forKey: "broadcastHeartbeat") as? Date else {
            isBroadcastAlive = false
            return
        }
        isBroadcastAlive = Date().timeIntervalSince(heartbeat) < 5
        if isBroadcastAlive { loadLatestFrame() }
    }

    func loadLatestFrame() {
        guard let url = appGroupURL?.appendingPathComponent("latest_frame.jpg"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return }
        latestFrame = image
    }

    // MARK: - Private

    private func startLiveTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartTime else { return }
            self.currentSessionDuration = Date().timeIntervalSince(start)
        }
    }

    private func resumeActiveSessionIfNeeded() {
        if let startTime = defaults.object(forKey: "sessionStartTime") as? Date {
            sessionStartTime = startTime
            isSessionActive = true
            startLiveTimer()
        }
    }

    // One-time migration from UserDefaults to SwiftData
    private func migrateFromUserDefaultsIfNeeded() {
        guard !defaults.bool(forKey: "swiftDataMigrated"),
              let data = defaults.data(forKey: "recentSessions"),
              let old = try? JSONDecoder().decode([LegacySessionRecord].self, from: data)
        else {
            defaults.set(true, forKey: "swiftDataMigrated")
            return
        }
        for record in old {
            modelContext?.insert(SessionItem(startTime: record.startTime, duration: record.duration))
        }
        try? modelContext?.save()
        defaults.set(true, forKey: "swiftDataMigrated")
        defaults.removeObject(forKey: "recentSessions")
        defaults.removeObject(forKey: "totalTimeSpent")
    }
}

// Used only for the one-time UserDefaults migration
private struct LegacySessionRecord: Codable {
    let id: UUID
    let startTime: Date
    let duration: TimeInterval
}
