import Foundation
import SwiftData

// MARK: - Value types

enum ChallengeType: String, CaseIterable, Codable, Identifiable, Sendable, Equatable {
    case math, typing, memory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .math: "Math Challenge"
        case .typing: "Typing Challenge"
        case .memory: "Memory Challenge"
        }
    }

    var summary: String {
        switch self {
        case .math: "Solve equations to complete the wake-up challenge."
        case .typing: "Type the displayed text accurately."
        case .memory: "Remember and reproduce a sequence."
        }
    }

    var symbol: String {
        switch self {
        case .math: "function"
        case .typing: "keyboard"
        case .memory: "square.grid.3x3.fill"
        }
    }
}

enum ChallengeDifficulty: String, CaseIterable, Codable, Identifiable, Sendable, Equatable {
    case easy, medium, hard

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum MathOperation: String, CaseIterable, Codable, Identifiable, Sendable, Hashable {
    case addition, subtraction, multiplication, division

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .addition: "+"
        case .subtraction: "−"
        case .multiplication: "×"
        case .division: "÷"
        }
    }

    var title: String {
        switch self {
        case .addition: "Addition"
        case .subtraction: "Subtraction"
        case .multiplication: "Multiplication"
        case .division: "Division"
        }
    }
}

enum TypingLength: String, CaseIterable, Codable, Identifiable, Sendable, Equatable {
    case short, medium, long

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum MemoryMode: String, CaseIterable, Codable, Identifiable, Sendable, Equatable {
    case numbers, colors, patterns

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .numbers: "number"
        case .colors: "circle.grid.3x3.fill"
        case .patterns: "square.grid.2x2"
        }
    }
}

enum AlarmOutcome: String, Codable, Sendable, Equatable {
    case completed, missed, dismissed
}

// MARK: - SwiftData models

@Model
final class Alarm {
    @Attribute(.unique) var id: UUID
    var hour: Int
    var minute: Int
    /// 1 = Sunday … 7 = Saturday. Empty means "next occurrence only".
    var weekdaysRaw: [Int]
    var label: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var challengeTypeRaw: String
    var soundName: String
    var soundID: UUID?
    var snoozeMinutes: Int
    var lastScheduledAt: Date?
    var lastScheduleError: String?

    @Relationship(deleteRule: .cascade, inverse: \ChallengeConfig.alarm)
    var challengeConfig: ChallengeConfig?

    init(
        id: UUID = UUID(),
        hour: Int = 7,
        minute: Int = 0,
        weekdays: [Int] = [],
        label: String = "",
        isEnabled: Bool = true,
        challengeType: ChallengeType = .math,
        soundName: String = "Morning Breeze",
        soundID: UUID? = nil,
        snoozeMinutes: Int = 5
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdaysRaw = weekdays
        self.label = label
        self.isEnabled = isEnabled
        self.createdAt = .now
        self.updatedAt = .now
        self.challengeTypeRaw = challengeType.rawValue
        self.soundName = soundName
        self.soundID = soundID
        self.snoozeMinutes = snoozeMinutes
    }

    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday).
    var weekdays: [Int] {
        get { weekdaysRaw }
        set { weekdaysRaw = newValue.sorted() }
    }

    var challengeType: ChallengeType {
        get { ChallengeType(rawValue: challengeTypeRaw) ?? .math }
        set { challengeTypeRaw = newValue.rawValue }
    }

    var displayName: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Alarm"
            : label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var timeLabel: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    var repeatSummary: String {
        if weekdays.isEmpty { return "Once" }
        if weekdays.count == 7 { return "Every day" }
        let weekdaysOnly = [2, 3, 4, 5, 6]
        if weekdays == weekdaysOnly { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        return weekdays
            .map { day -> String in
                let symbols = Calendar.current.veryShortWeekdaySymbols
                let index = day - 1
                return symbols.indices.contains(index) ? symbols[index] : "?"
            }
            .joined(separator: " ")
    }

    func nextFireDate(relativeTo now: Date = .now) -> Date? {
        guard isEnabled else { return nil }
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        if weekdays.isEmpty {
            return calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTime
            )
        }

        return weekdays
            .compactMap { weekday -> Date? in
                var dayComponents = components
                dayComponents.weekday = weekday
                return calendar.nextDate(
                    after: now,
                    matching: dayComponents,
                    matchingPolicy: .nextTime
                )
            }
            .min()
    }

    /// The scheduled occurrence that has just passed, if it is within `window`.
    /// Used to open the wake-up challenge when the user opens the app after an alarm rang.
    func recentlyFiredDate(relativeTo now: Date = .now, window: TimeInterval = 15 * 60) -> Date? {
        guard let occurrence = todayScheduledOccurrence(relativeTo: now) else { return nil }
        return now.timeIntervalSince(occurrence) <= window ? occurrence : nil
    }

    /// Today's scheduled time if it is already in the past and today is a repeat day.
    func todayScheduledOccurrence(relativeTo now: Date = .now) -> Date? {
        guard isEnabled else { return nil }
        let calendar = Calendar.current
        guard let occurrence = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        ), occurrence <= now else { return nil }

        if weekdays.isEmpty { return occurrence }

        let weekday = calendar.component(.weekday, from: occurrence)
        return weekdays.contains(weekday) ? occurrence : nil
    }
}

@Model
final class ChallengeConfig {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var difficultyRaw: String
    var questionCount: Int

    // Math
    var operationsRaw: [String]
    /// 0 = off, otherwise seconds per question.
    var timeLimitSeconds: Int

    // Typing
    var typingLengthRaw: String
    var customText: String
    var ignoreCapitalization: Bool
    var requirePunctuation: Bool

    // Memory
    var memoryModeRaw: String
    var memorySequenceLength: Int

    var alarm: Alarm?

    init(
        id: UUID = UUID(),
        type: ChallengeType = .math,
        difficulty: ChallengeDifficulty = .easy,
        questionCount: Int = 5,
        operations: [MathOperation] = [.addition, .subtraction],
        timeLimitSeconds: Int = 0,
        typingLength: TypingLength = .short,
        customText: String = "",
        ignoreCapitalization: Bool = true,
        requirePunctuation: Bool = false,
        memoryMode: MemoryMode = .numbers,
        memorySequenceLength: Int = 4
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.questionCount = questionCount
        self.operationsRaw = operations.map(\.rawValue)
        self.timeLimitSeconds = timeLimitSeconds
        self.typingLengthRaw = typingLength.rawValue
        self.customText = customText
        self.ignoreCapitalization = ignoreCapitalization
        self.requirePunctuation = requirePunctuation
        self.memoryModeRaw = memoryMode.rawValue
        self.memorySequenceLength = memorySequenceLength
    }

    var type: ChallengeType {
        get { ChallengeType(rawValue: typeRaw) ?? .math }
        set { typeRaw = newValue.rawValue }
    }

    var difficulty: ChallengeDifficulty {
        get { ChallengeDifficulty(rawValue: difficultyRaw) ?? .easy }
        set { difficultyRaw = newValue.rawValue }
    }

    var operations: [MathOperation] {
        get { operationsRaw.compactMap(MathOperation.init(rawValue:)) }
        set { operationsRaw = newValue.map(\.rawValue) }
    }

    var typingLength: TypingLength {
        get { TypingLength(rawValue: typingLengthRaw) ?? .short }
        set { typingLengthRaw = newValue.rawValue }
    }

    var memoryMode: MemoryMode {
        get { MemoryMode(rawValue: memoryModeRaw) ?? .numbers }
        set { memoryModeRaw = newValue.rawValue }
    }
}

@Model
final class SoundAsset {
    @Attribute(.unique) var id: UUID
    var name: String
    /// File name inside the app's managed sounds folder. `nil` for built-in sounds.
    var fileName: String?
    var formatLabel: String
    var durationSeconds: Double
    var isBuiltIn: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        fileName: String?,
        formatLabel: String,
        durationSeconds: Double,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.formatLabel = formatLabel
        self.durationSeconds = durationSeconds
        self.isBuiltIn = isBuiltIn
        self.createdAt = .now
    }

    var metadataLabel: String {
        if isBuiltIn { return "Built-in · \(formatLabel)" }
        let duration = Duration.seconds(durationSeconds)
            .formatted(.time(pattern: .minuteSecond))
        return "\(formatLabel) · \(duration)"
    }
}

@Model
final class AlarmHistory {
    @Attribute(.unique) var id: UUID
    var alarmID: UUID
    var alarmLabel: String
    var scheduledFor: Date
    var completedAt: Date?
    var outcomeRaw: String
    var challengeTypeRaw: String
    var correctAnswers: Int
    var totalQuestions: Int

    init(
        id: UUID = UUID(),
        alarmID: UUID,
        alarmLabel: String,
        scheduledFor: Date,
        completedAt: Date? = nil,
        outcome: AlarmOutcome,
        challengeType: ChallengeType,
        correctAnswers: Int = 0,
        totalQuestions: Int = 0
    ) {
        self.id = id
        self.alarmID = alarmID
        self.alarmLabel = alarmLabel
        self.scheduledFor = scheduledFor
        self.completedAt = completedAt
        self.outcomeRaw = outcome.rawValue
        self.challengeTypeRaw = challengeType.rawValue
        self.correctAnswers = correctAnswers
        self.totalQuestions = totalQuestions
    }

    var outcome: AlarmOutcome {
        get { AlarmOutcome(rawValue: outcomeRaw) ?? .missed }
        set { outcomeRaw = newValue.rawValue }
    }

    var challengeType: ChallengeType {
        get { ChallengeType(rawValue: challengeTypeRaw) ?? .math }
        set { challengeTypeRaw = newValue.rawValue }
    }
}
