import SwiftUI
import SwiftData

struct ChallengeFlowView: View {
    let alarm: Alarm
    /// Preview runs are started from the alarm card and never write history.
    var isPreview: Bool = false
    let onFinish: (ChallengeResult) -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var mathQuestions: [MathQuestion] = []
    @State private var typingTasks: [TypingTask] = []
    @State private var memoryTasks: [MemoryTask] = []
    @State private var index = 0
    @State private var correctCount = 0
    @State private var feedback: Feedback?
    @State private var result: ChallengeResult?
    @State private var startedAt = Date()
    @State private var remainingSeconds: Int = 0
    @State private var countdown: Task<Void, Never>?

    private var config: ChallengeConfig? { alarm.challengeConfig }
    private var challengeType: ChallengeType { alarm.challengeType }

    private var totalTasks: Int {
        switch challengeType {
        case .math: max(mathQuestions.count, 1)
        case .typing: max(typingTasks.count, 1)
        case .memory: max(memoryTasks.count, 1)
        }
    }

    var body: some View {
        ZStack {
            RISETheme.Colors.background.ignoresSafeArea()

            if let result {
                SuccessView(
                    result: result,
                    streak: currentStreak,
                    isPreview: isPreview,
                    onDone: { onFinish(result) }
                )
            } else {
                challengeContent
            }
        }
        .onAppear(perform: prepare)
        .onDisappear { countdown?.cancel() }
    }

    // MARK: - Main challenge layout

    private var challengeContent: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
            header

            RISEProgressIndicator(completed: index, total: totalTasks)
                .padding(.top, RISETheme.Spacing.xs)

            ScrollView {
                VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
                    Text(challengeType.title)
                        .font(RISETheme.Typography.sectionTitle)
                        .foregroundStyle(RISETheme.Colors.text)

                    taskView

                    if let feedback {
                        RISEInlineMessage(text: feedback.text, kind: feedback.kind)
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, RISETheme.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(RISETheme.Layout.screenPadding)
        .animation(.easeInOut(duration: 0.22), value: feedback?.text)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.xs) {
            HStack {
                Text("RISE.")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(RISETheme.Colors.primary)
                    .accessibilityLabel("RISE")

                Spacer()

                Label("Alarm active", systemImage: "alarm.fill")
                    .font(RISETheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(RISETheme.Colors.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RISETheme.Colors.success.opacity(0.12))
                    .clipShape(Capsule())
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 56, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(RISETheme.Colors.text)
                    .accessibilityLabel("Current time \(context.date.formatted(date: .omitted, time: .shortened))")
            }

            Text(greeting)
                .font(RISETheme.Typography.body)
                .foregroundStyle(RISETheme.Colors.muted)

            if let config, config.timeLimitSeconds > 0 {
                Text("Time limit · \(remainingSeconds)s")
                    .font(RISETheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(remainingSeconds <= 5 ? RISETheme.Colors.danger : RISETheme.Colors.muted)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var taskView: some View {
        switch challengeType {
        case .math:
            if mathQuestions.indices.contains(index) {
                MathChallengeView(
                    question: mathQuestions[index],
                    onAnswer: { answer in
                        evaluate(isCorrect: answer == mathQuestions[index].answer)
                    }
                )
                .id(mathQuestions[index].id)
            }

        case .typing:
            if typingTasks.indices.contains(index), let config {
                TypingChallengeView(
                    task: typingTasks[index],
                    config: config,
                    onSubmit: { input in
                        evaluate(
                            isCorrect: TypingChallengeEngine.matches(
                                input: input,
                                target: typingTasks[index].text,
                                ignoreCapitalization: config.ignoreCapitalization,
                                requirePunctuation: config.requirePunctuation
                            )
                        )
                    }
                )
                .id(typingTasks[index].id)
            }

        case .memory:
            if memoryTasks.indices.contains(index) {
                MemoryChallengeView(task: memoryTasks[index]) { answer in
                    evaluate(isCorrect: answer == memoryTasks[index].sequence)
                }
                .id(memoryTasks[index].id)
            }
        }
    }

    // MARK: - State transitions

    private func prepare() {
        guard mathQuestions.isEmpty, typingTasks.isEmpty, memoryTasks.isEmpty else { return }
        startedAt = .now

        let config = alarm.challengeConfig
        let count = config?.questionCount ?? 5
        let difficulty = config?.difficulty ?? .easy

        switch challengeType {
        case .math:
            mathQuestions = MathChallengeEngine.generate(
                count: count,
                difficulty: difficulty,
                operations: config?.operations ?? [.addition, .subtraction]
            )
        case .typing:
            typingTasks = TypingChallengeEngine.tasks(
                count: count,
                length: config?.typingLength ?? .short,
                customText: config?.customText ?? "",
                difficulty: difficulty
            )
        case .memory:
            memoryTasks = MemoryChallengeEngine.tasks(
                count: count,
                mode: config?.memoryMode ?? .numbers,
                length: config?.memorySequenceLength ?? 4
            )
        }

        startCountdownIfNeeded()
    }

    private func evaluate(isCorrect: Bool) {
        guard result == nil else { return }

        if isCorrect {
            correctCount += 1
            RiseHaptics.success(enabled: hapticsEnabled)
            feedback = Feedback(text: "Correct. Keep going.", kind: .success)
            advance()
        } else {
            RiseHaptics.failure(enabled: hapticsEnabled)
            feedback = Feedback(text: "That is not right yet. Try again.", kind: .error)
            restartCountdown()
        }
    }

    private func advance() {
        countdown?.cancel()

        if index + 1 >= totalTasks {
            complete()
        } else {
            index += 1
            feedback = nil
            startCountdownIfNeeded()
        }
    }

    private func complete() {
        countdown?.cancel()
        let now = Date()
        let completed = ChallengeResult(
            alarmID: alarm.id,
            type: challengeType,
            correct: correctCount,
            total: totalTasks,
            completedAt: now,
            wakeUpTimeLabel: now.formatted(date: .omitted, time: .shortened)
        )

        if !isPreview {
            recordCompletion(at: now)
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            result = completed
        }
    }

    /// Stores the wake-up and turns a one-shot alarm off, like a real alarm clock.
    private func recordCompletion(at now: Date) {
        let history = AlarmHistory(
            alarmID: alarm.id,
            alarmLabel: alarm.displayName,
            scheduledFor: alarm.todayScheduledOccurrence(relativeTo: now) ?? now,
            completedAt: now,
            outcome: .completed,
            challengeType: challengeType,
            correctAnswers: correctCount,
            totalQuestions: totalTasks
        )
        modelContext.insert(history)

        let wasOneShot = alarm.weekdays.isEmpty
        if wasOneShot {
            alarm.isEnabled = false
        }
        try? modelContext.save()

        if wasOneShot {
            Task { await AlarmSchedulerFactory.make().cancel(alarmID: alarm.id) }
        }
    }

    private func startCountdownIfNeeded() {
        restartCountdown()
    }

    private func restartCountdown() {
        countdown?.cancel()
        guard let limit = config?.timeLimitSeconds, limit > 0, result == nil else {
            remainingSeconds = 0
            return
        }

        remainingSeconds = limit
        countdown = Task {
            while remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remainingSeconds -= 1
            }
            guard !Task.isCancelled, result == nil else { return }
            await MainActor.run {
                RiseHaptics.failure(enabled: hapticsEnabled)
                feedback = Feedback(text: "Time is up. Try this one again.", kind: .error)
                restartCountdown()
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        default: return "Good evening."
        }
    }

    private var currentStreak: Int {
        let descriptor = FetchDescriptor<AlarmHistory>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        let history = (try? modelContext.fetch(descriptor)) ?? []
        return InsightCalculator.streak(from: history)
    }

    private struct Feedback: Equatable {
        let text: String
        let kind: RISEInlineMessage.Kind
    }
}
