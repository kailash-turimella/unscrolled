import UserNotifications
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleSessionNotifications(from start: Date) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Schedule at 5, 10, 15 … 120 minutes
        for i in 1...24 {
            let elapsedSeconds = TimeInterval(i * 5 * 60)
            let fireDate = start.addingTimeInterval(elapsedSeconds)
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Still watching?"
            content.body = "You've been scrolling for \(elapsedSeconds.formattedTime)"
            content.sound = .none

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "unscrolled.session.\(i)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
