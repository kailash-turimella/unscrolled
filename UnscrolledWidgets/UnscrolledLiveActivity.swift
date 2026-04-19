import ActivityKit
import WidgetKit
import SwiftUI

struct UnscrolledLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.startTime, style: .timer)
                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "eye.slash.fill")
                            .foregroundStyle(.red)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "unscrolled://factcheck")!) {
                        Label("Fact Check", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.blue, in: Capsule())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Unscrolled session active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Text(context.attributes.startTime, style: .timer)
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 36)
            } minimal: {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.red)
            }
            .widgetURL(URL(string: "unscrolled://factcheck"))
            .keylineTint(.red)
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<SessionActivityAttributes>) -> some View {
        HStack {
            Label {
                Text(context.attributes.startTime, style: .timer)
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
            } icon: {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.red)
            }
            Spacer()
            Link(destination: URL(string: "unscrolled://factcheck")!) {
                Label("Fact Check", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue, in: Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
