import Foundation

enum InsightCalculator {
    /// Consecutive days ending today (or yesterday) with a completed wake-up.
    static func streak(from history: [AlarmHistory], calendar: Calendar = .current, now: Date = .now) -> Int {
        let days = Set(
            history
                .filter { $0.outcome == .completed }
                .compactMap { $0.completedAt }
                .map { calendar.startOfDay(for: $0) }
        )
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        var cursor = days.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        guard days.contains(cursor) else { return 0 }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func successfulCount(from history: [AlarmHistory]) -> Int {
        history.filter { $0.outcome == .completed }.count
    }

    static func averageWakeTime(from history: [AlarmHistory]) -> String? {
        let minutes = history
            .filter { $0.outcome == .completed }
            .compactMap(\.completedAt)
            .map { date -> Int in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                return (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }

        guard !minutes.isEmpty else { return nil }
        let average = minutes.reduce(0, +) / minutes.count

        var components = DateComponents()
        components.hour = average / 60
        components.minute = average % 60
        guard let date = Calendar.current.date(from: components) else { return nil }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func challengeSuccessRate(from history: [AlarmHistory]) -> Double? {
        let answered = history.filter { $0.totalQuestions > 0 }
        guard !answered.isEmpty else { return nil }
        let total = answered.reduce(0) { $0 + $1.totalQuestions }
        let correct = answered.reduce(0) { $0 + $1.correctAnswers }
        guard total > 0 else { return nil }
        return Double(correct) / Double(total)
    }

    struct DailyActivity: Identifiable {
        let id: Date
        let date: Date
        let completed: Int
        let missed: Int
    }

    static func weeklyActivity(
        from history: [AlarmHistory],
        calendar: Calendar = .current,
        now: Date = .now,
        days: Int = 7
    ) -> [DailyActivity] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let entries = history.filter {
                let start = $0.completedAt ?? $0.scheduledFor
                return calendar.isDate(start, inSameDayAs: day)
            }
            return DailyActivity(
                id: day,
                date: day,
                completed: entries.filter { $0.outcome == .completed }.count,
                missed: entries.filter { $0.outcome != .completed }.count
            )
        }
    }
}
