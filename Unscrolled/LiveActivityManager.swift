import ActivityKit
import Foundation

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<SessionActivityAttributes>?
    private init() {}

    func start(sessionStart: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = SessionActivityAttributes(startTime: sessionStart)
        let state = SessionActivityAttributes.ContentState(elapsedSeconds: 0)
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("LiveActivity start failed: \(error)")
        }
    }

    func stop() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
