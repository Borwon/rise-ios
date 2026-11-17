import SwiftUI
import WidgetKit

#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
#endif

// MARK: - Bundle

@main
struct RISEAlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        RISEStatusWidget()

        #if canImport(AlarmKit)
        RiseAlarmLiveActivity()
        #endif
    }
}

// MARK: - Static widget (every iOS version)

/// Simple home-screen tile so the extension has content on iOS versions
/// without AlarmKit. A next-alarm tile would need an App Group; the alarm
/// data lives in the app's own store today.
struct RISEStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RISEStatusWidget", provider: RISEStatusProvider()) { _ in
            VStack(alignment: .leading, spacing: 6) {
                Text("RISE.")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(RISE.accent)

                Spacer(minLength: 0)

                Text("Wake up.")
                    .font(.system(size: 20, weight: .semibold))
                Text("Think. Get up.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                RISE.background
            }
        }
        .configurationDisplayName("RISE.")
        .description("Your wake-up routine at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct RISEStatusEntry: TimelineEntry {
    let date: Date
}

struct RISEStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> RISEStatusEntry {
        RISEStatusEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (RISEStatusEntry) -> Void) {
        completion(RISEStatusEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RISEStatusEntry>) -> Void) {
        completion(Timeline(entries: [RISEStatusEntry(date: .now)], policy: .never))
    }
}

/// Widget-local copies of the RISE. palette (the app's theme type is not
/// shared with the extension).
enum RISE {
    static let accent = Color(red: 0xA9 / 255, green: 0x9A / 255, blue: 0xFF / 255)
    static let background = Color(red: 0x09 / 255, green: 0x0B / 255, blue: 0x14 / 255)
    static let surface = Color(red: 0x15 / 255, green: 0x19 / 255, blue: 0x27 / 255)
    static let text = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xFA / 255)
}

// MARK: - AlarmKit Live Activity (iOS 26+)

#if canImport(AlarmKit)
/// Countdown / paused Live Activity for RISE. alarms.
/// Alerting is rendered by the system; this extension only styles the
/// countdown and paused phases (see the AlarmKit reference patterns).
@available(iOS 26.0, *)
struct RiseAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<RiseAlarmMetadata>.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "alarm.fill")
                        .foregroundStyle(RISE.accent)
                    Text("RISE.")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(RISE.accent)
                }

                Text(context.attributes.metadata?.label ?? "Alarm")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RISE.text)

                stateText(for: context.state)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(RISE.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .activityBackgroundTint(RISE.surface)
            .activitySystemActionForegroundColor(RISE.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill")
                        .foregroundStyle(RISE.accent)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.metadata?.label ?? "Alarm")
                            .font(.system(size: 13, weight: .semibold))
                        stateText(for: context.state)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(RISE.accent)
            } compactTrailing: {
                stateText(for: context.state)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "alarm.fill")
                    .foregroundStyle(RISE.accent)
            }
            .keylineTint(RISE.accent)
        }
    }

    @ViewBuilder
    private func stateText(for state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(countdown.fireDate, style: .timer)
        case .paused(let paused):
            let remaining = paused.totalCountdownDuration - paused.previouslyElapsedDuration
            Text(Duration.seconds(max(remaining, 0)), format: .time(pattern: .minuteSecond))
        case .alert(let alert):
            Text("\(alert.time.hour):\(String(format: "%02d", alert.time.minute))")
        @unknown default:
            Text("--:--")
        }
    }
}
#endif
