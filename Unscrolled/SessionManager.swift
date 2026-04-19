import Foundation
import UIKit

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let duration: TimeInterval

    init(startTime: Date, duration: TimeInterval) {
        self.id = UUID()
        self.startTime = startTime
        self.duration = duration
    }

    var formattedDuration: String { duration.formattedTime }
}

extension TimeInterval {
    var formattedTime: String {
        let s = Int(self)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}

final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    private lazy var defaults: UserDefaults = {
        UserDefaults(suiteName: "group.com.kailash.unscrolled") ?? .standard
    }()

    @Published var isSessionActive = false
    @Published var sessionStartTime: Date?
    @Published var currentSessionDuration: TimeInterval = 0
    @Published var totalTimeSpent: TimeInterval = 0
    @Published var recentSessions: [SessionRecord] = []
    @Published var isBroadcastAlive = false
    @Published var latestFrame: UIImage?

    private var timer: Timer?
    private var broadcastPollTimer: Timer?

    private lazy var appGroupURL: URL? = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kailash.unscrolled")
    }()

    private init() {
        loadPersistedState()
    }

    private func loadPersistedState() {
        totalTimeSpent = defaults.double(forKey: "totalTimeSpent")
        if let data = defaults.data(forKey: "recentSessions"),
           let sessions = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            recentSessions = sessions
        }
        if let startTime = defaults.object(forKey: "sessionStartTime") as? Date {
            sessionStartTime = startTime
            isSessionActive = true
            startLiveTimer()
        }
    }

    func startSession() {
        let now = Date()
        sessionStartTime = now
        isSessionActive = true
        defaults.set(now, forKey: "sessionStartTime")
        startLiveTimer()
        NotificationManager.shared.scheduleSessionNotifications(from: now)
        BubbleWindowManager.shared.show()
        LiveActivityManager.shared.start(sessionStart: now)
    }

    func endSession() {
        guard let start = sessionStartTime else { return }
        let duration = Date().timeIntervalSince(start)

        totalTimeSpent += duration
        defaults.set(totalTimeSpent, forKey: "totalTimeSpent")
        defaults.removeObject(forKey: "sessionStartTime")

        let record = SessionRecord(startTime: start, duration: duration)
        recentSessions.insert(record, at: 0)
        if recentSessions.count > 50 { recentSessions = Array(recentSessions.prefix(50)) }
        if let data = try? JSONEncoder().encode(recentSessions) {
            defaults.set(data, forKey: "recentSessions")
        }

        sessionStartTime = nil
        isSessionActive = false
        currentSessionDuration = 0
        timer?.invalidate()
        timer = nil

        NotificationManager.shared.cancelAll()
        BubbleWindowManager.shared.hide()
        LiveActivityManager.shared.stop()
    }

    private func startLiveTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.sessionStartTime else { return }
            self.currentSessionDuration = Date().timeIntervalSince(start)
        }
    }

    func startBroadcastPolling() {
        refreshBroadcastHeartbeat()  // immediate update on foreground
        broadcastPollTimer?.invalidate()
        broadcastPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshBroadcastHeartbeat()
        }
    }

    func stopBroadcastPolling() {
        broadcastPollTimer?.invalidate()
        broadcastPollTimer = nil
        // intentionally keep last known isBroadcastAlive / latestFrame visible
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
}
