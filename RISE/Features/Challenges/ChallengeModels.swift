import Foundation

// MARK: - Math

struct MathQuestion: Identifiable, Sendable {
    let id = UUID()
    let prompt: String
    let answer: Int
}

enum MathChallengeEngine {
    static func generate(
        count: Int,
        difficulty: ChallengeDifficulty,
        operations: [MathOperation]
    ) -> [MathQuestion] {
        let allowed = operations.isEmpty ? [.addition] : operations
        return (0..<max(count, 1)).map { _ in
            makeQuestion(difficulty: difficulty, operations: allowed)
        }
    }

    private static func makeQuestion(
        difficulty: ChallengeDifficulty,
        operations: [MathOperation]
    ) -> MathQuestion {
        let operation = operations.randomElement() ?? .addition

        switch operation {
        case .addition:
            let range = range(for: difficulty, base: 20)
            let lhs = Int.random(in: 2...range)
            let rhs = Int.random(in: 2...range)
            return MathQuestion(prompt: "\(lhs) + \(rhs)", answer: lhs + rhs)

        case .subtraction:
            let range = range(for: difficulty, base: 20)
            let lhs = Int.random(in: 5...range)
            let rhs = Int.random(in: 1...max(lhs - 1, 1))
            return MathQuestion(prompt: "\(lhs) − \(rhs)", answer: lhs - rhs)

        case .multiplication:
            let range: Int
            switch difficulty {
            case .easy: range = 5
            case .medium: range = 9
            case .hard: range = 12
            }
            let lhs = Int.random(in: 2...range)
            let rhs = Int.random(in: 2...range)
            return MathQuestion(prompt: "\(lhs) × \(rhs)", answer: lhs * rhs)

        case .division:
            let range: Int
            switch difficulty {
            case .easy: range = 5
            case .medium: range = 9
            case .hard: range = 12
            }
            let divisor = Int.random(in: 2...range)
            let quotient = Int.random(in: 2...range)
            return MathQuestion(
                prompt: "\(divisor * quotient) ÷ \(divisor)",
                answer: quotient
            )
        }
    }

    private static func range(for difficulty: ChallengeDifficulty, base: Int) -> Int {
        switch difficulty {
        case .easy: base
        case .medium: base * 3
        case .hard: base * 6
        }
    }
}

// MARK: - Typing

struct TypingTask: Identifiable, Sendable {
    let id = UUID()
    let text: String
}

enum TypingChallengeEngine {
    private static let shortTexts = [
        "Wake up and start the day.",
        "One small step at a time.",
        "Breathe in, breathe out.",
        "Today begins with you.",
        "Rise and get moving."
    ]

    private static let mediumTexts = [
        "A calm morning begins with one decision, and that decision is to get up.",
        "The first hour of the day sets the tone for everything that follows it.",
        "Progress is built from small mornings repeated until they become a habit."
    ]

    private static let longTexts = [
        "You do not need a perfect morning. You only need to begin it, because beginning is the part that everything else depends on, and it is always available to you right now.",
        "A steady routine is not a cage, it is a structure that holds your attention in place long enough for the good parts of the day to form without you having to force them."
    ]

    static func tasks(
        count: Int,
        length: TypingLength,
        customText: String,
        difficulty: ChallengeDifficulty
    ) -> [TypingTask] {
        let source = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            return [TypingTask(text: source)]
        }

        let pool: [String]
        switch length {
        case .short: pool = shortTexts
        case .medium: pool = mediumTexts
        case .long: pool = longTexts
        }

        let effectiveCount = difficulty == .easy ? 1 : max(count, 1)
        return (0..<effectiveCount).map { _ in
            TypingTask(text: pool.randomElement() ?? shortTexts[0])
        }
    }

    static func matches(
        input: String,
        target: String,
        ignoreCapitalization: Bool,
        requirePunctuation: Bool
    ) -> Bool {
        normalize(
            input,
            ignoreCapitalization: ignoreCapitalization,
            requirePunctuation: requirePunctuation
        ) == normalize(
            target,
            ignoreCapitalization: ignoreCapitalization,
            requirePunctuation: requirePunctuation
        )
    }

    private static func normalize(
        _ text: String,
        ignoreCapitalization: Bool,
        requirePunctuation: Bool
    ) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if ignoreCapitalization {
            value = value.lowercased()
        }

        if !requirePunctuation {
            let allowed = CharacterSet.alphanumerics.union(.whitespaces)
            value = String(value.filter { character in
                character.unicodeScalars.allSatisfy { allowed.contains($0) }
            })
            value = value.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        }

        return value
    }
}

// MARK: - Memory

struct MemoryTask: Identifiable, Sendable {
    let id = UUID()
    let mode: MemoryMode
    /// Numbers 0–9 for `.numbers`, color indices 0–3 for `.colors`,
    /// grid indices 0–8 for `.patterns`.
    let sequence: [Int]
}

enum MemoryChallengeEngine {
    static func tasks(count: Int, mode: MemoryMode, length: Int) -> [MemoryTask] {
        let clampedLength = min(max(length, 3), 10)
        return (0..<max(count, 1)).map { _ in
            let upperBound: Int
            switch mode {
            case .numbers: upperBound = 9
            case .colors: upperBound = 3
            case .patterns: upperBound = 8
            }

            let sequence = (0..<clampedLength).map { _ in Int.random(in: 0...upperBound) }
            return MemoryTask(mode: mode, sequence: sequence)
        }
    }
}
