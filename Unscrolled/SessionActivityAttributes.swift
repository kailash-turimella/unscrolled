import ActivityKit
import Foundation

struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
    }
    var startTime: Date
}
