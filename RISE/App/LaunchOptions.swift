import Foundation
import SwiftData

#if DEBUG
/// Debug-only launch arguments used by the CI screenshot job.
///
/// Everything here is compiled out of Release builds, so the shipping app has
/// no screenshot or demo-data surface at all.
enum LaunchOptions {
    /// `-riseScreen alarms|insights|settings` selects the starting tab.
    static var screen: String? {
        value(after: "-riseScreen")
    }

    /// `-riseSeedDemoData` fills an empty store with sample alarms and history.
    static var seedsDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains("-riseSeedDemoData")
    }

    /// True for any automated run, so time-based behaviour stays deterministic.
    static var isAutomatedRun: Bool {
        seedsDemoData || screen != nil
    }

    static var skipsOnboarding: Bool {
        screen != nil
    }

    static var initialTab: Int {
        switch screen {
        case "insights": 1
        case "settings": 2
        default: 0
        }
    }

    /// Keeps the app from auto-opening a challenge when a seeded alarm happens
    /// to fall inside the wake-up window during a screenshot run.
    static var suppressesAutomaticChallenge: Bool {
        isAutomatedRun
    }

    static func seedDemoDataIfNeeded(context: ModelContext, calendar: Calendar = .current) {
        guard seedsDemoData else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Alarm>())) ?? 0
        guard existing == 0 else { return }

        let morningRun = Alarm(
            hour: 6,
            minute: 30,
            weekdays: [2, 3, 4, 5, 6],
            label: "Morning run",
            challengeType: .math,
            snoozeMinutes: 5
        )
        let morningRunConfig = ChallengeConfig(
            type: .math,
            difficulty: .medium,
            questionCount: 5,
            operations: [.addition, .subtraction, .multiplication]
        )

        let deepWork = Alarm(
            hour: 8,
            minute: 0,
            weekdays: [2, 4, 6],
            label: "Deep work",
            challengeType: .typing,
            snoozeMinutes: 3
        )
        let deepWorkConfig = ChallengeConfig(
            type: .typing,
            difficulty: .easy,
            typingLength: .short
        )

        let weekendReset = Alarm(
            hour: 9,
            minute: 15,
            weekdays: [1, 7],
            label: "Weekend reset",
            isEnabled: false,
            challengeType: .memory,
            snoozeMinutes: 10
        )
        let weekendResetConfig = ChallengeConfig(
            type: .memory,
            difficulty: .easy,
            memoryMode: .numbers,
            memorySequenceLength: 4
        )

        context.insert(morningRun)
        context.insert(morningRunConfig)
        context.insert(deepWork)
        context.insert(deepWorkConfig)
        context.insert(weekendReset)
        context.insert(weekendResetConfig)

        morningRun.challengeConfig = morningRunConfig
        deepWork.challengeConfig = deepWorkConfig
        weekendReset.challengeConfig = weekendResetConfig

        let today = calendar.startOfDay(for: .now)
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let scheduled = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: day) ?? day
            let missed = offset == 5 || offset == 6

            context.insert(
                AlarmHistory(
                    alarmID: morningRun.id,
                    alarmLabel: morningRun.displayName,
                    scheduledFor: scheduled,
                    completedAt: missed ? nil : scheduled.addingTimeInterval(4 * 60 + Double(offset) * 40),
                    outcome: missed ? .missed : .completed,
                    challengeType: .math,
                    correctAnswers: missed ? 0 : 5,
                    totalQuestions: missed ? 0 : 5
                )
            )
        }

        try? context.save()
    }

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
