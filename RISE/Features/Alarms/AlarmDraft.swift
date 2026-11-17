import Foundation
import SwiftData

/// Editable copy of an alarm so unsaved form state survives navigation.
struct AlarmDraft {
    var id: UUID?
    var time: Date
    var weekdays: Set<Int>
    var label: String
    var isEnabled: Bool
    var soundName: String
    var soundID: UUID?
    var snoozeMinutes: Int
    var challenge: ChallengeDraft

    init(alarm: Alarm? = nil) {
        if let alarm {
            id = alarm.id
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            time = Calendar.current.date(from: components) ?? .now
            weekdays = Set(alarm.weekdays)
            label = alarm.label
            isEnabled = alarm.isEnabled
            soundName = alarm.soundName
            soundID = alarm.soundID
            snoozeMinutes = alarm.snoozeMinutes
            challenge = ChallengeDraft(config: alarm.challengeConfig, type: alarm.challengeType)
        } else {
            id = nil
            time = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
            weekdays = []
            label = ""
            isEnabled = true
            soundName = UserDefaults.standard.string(forKey: "defaultSoundName")
                ?? SoundLibrary.defaultSoundName
            soundID = UserDefaults.standard.string(forKey: "defaultSoundID")
                .flatMap { UUID(uuidString: $0) }
            snoozeMinutes = UserDefaults.standard.object(forKey: "defaultSnoozeMinutes") as? Int ?? 5
            challenge = ChallengeDraft()
        }
    }

    var hour: Int { Calendar.current.component(.hour, from: time) }
    var minute: Int { Calendar.current.component(.minute, from: time) }
    var isNew: Bool { id == nil }

    var isValid: Bool {
        challenge.questionCount > 0
    }

    /// Creates or updates the SwiftData models. Call `save` on the context afterwards.
    @discardableResult
    func apply(to existing: Alarm?, in context: ModelContext) -> Alarm {
        let alarm = existing ?? Alarm()
        alarm.hour = hour
        alarm.minute = minute
        alarm.weekdays = Array(weekdays)
        alarm.label = label
        alarm.isEnabled = isEnabled
        alarm.soundName = soundName
        alarm.soundID = soundID
        alarm.snoozeMinutes = snoozeMinutes
        alarm.challengeType = challenge.type
        alarm.updatedAt = .now

        let config: ChallengeConfig
        if let existingConfig = alarm.challengeConfig {
            config = existingConfig
        } else {
            config = ChallengeConfig()
            context.insert(config)
            alarm.challengeConfig = config
        }
        challenge.apply(to: config)

        if existing == nil {
            context.insert(alarm)
        }
        return alarm
    }
}

struct ChallengeDraft {
    var type: ChallengeType = .math
    var difficulty: ChallengeDifficulty = .easy
    var questionCount: Int = 5
    var operations: Set<MathOperation> = [.addition, .subtraction]
    var timeLimitSeconds: Int = 0
    var typingLength: TypingLength = .short
    var customText: String = ""
    var ignoreCapitalization: Bool = true
    var requirePunctuation: Bool = false
    var memoryMode: MemoryMode = .numbers
    var memorySequenceLength: Int = 4

    init() {}

    init(config: ChallengeConfig?, type: ChallengeType) {
        self.type = type
        guard let config else { return }
        difficulty = config.difficulty
        questionCount = config.questionCount
        operations = Set(config.operations)
        timeLimitSeconds = config.timeLimitSeconds
        typingLength = config.typingLength
        customText = config.customText
        ignoreCapitalization = config.ignoreCapitalization
        requirePunctuation = config.requirePunctuation
        memoryMode = config.memoryMode
        memorySequenceLength = config.memorySequenceLength
    }

    func apply(to config: ChallengeConfig) {
        config.type = type
        config.difficulty = difficulty
        config.questionCount = questionCount
        config.operations = operations.isEmpty ? [.addition] : Array(operations)
        config.timeLimitSeconds = timeLimitSeconds
        config.typingLength = typingLength
        config.customText = customText
        config.ignoreCapitalization = ignoreCapitalization
        config.requirePunctuation = requirePunctuation
        config.memoryMode = memoryMode
        config.memorySequenceLength = memorySequenceLength
    }
}
