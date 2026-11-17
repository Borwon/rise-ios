import SwiftUI

/// Runs the configured challenge without recording a wake-up.
struct ChallengeDemoView: View {
    let draft: ChallengeDraft

    @Environment(\.dismiss) private var dismiss

    @State private var mathQuestions: [MathQuestion] = []
    @State private var typingTasks: [TypingTask] = []
    @State private var memoryTasks: [MemoryTask] = []
    @State private var index = 0
    @State private var feedback: String?
    @State private var isComplete = false

    private var total: Int {
        switch draft.type {
        case .math: mathQuestions.count
        case .typing: typingTasks.count
        case .memory: memoryTasks.count
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
                    if isComplete {
                        completionContent
                    } else {
                        RISEProgressIndicator(completed: index, total: max(total, 1))

                        if let feedback {
                            RISEInlineMessage(text: feedback, kind: .error)
                        }

                        currentTask
                    }
                }
                .padding(RISETheme.Layout.screenPadding)
            }
            .riseScreenBackground()
            .navigationTitle("Try Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: prepare)
    }

    @ViewBuilder
    private var currentTask: some View {
        switch draft.type {
        case .math:
            if mathQuestions.indices.contains(index) {
                MathChallengeView(question: mathQuestions[index]) { answer in
                    evaluate(isCorrect: answer == mathQuestions[index].answer)
                }
                .id(mathQuestions[index].id)
            }

        case .typing:
            if typingTasks.indices.contains(index) {
                TypingChallengeView(
                    task: typingTasks[index],
                    config: configPreview,
                    onSubmit: { input in
                        evaluate(isCorrect: TypingChallengeEngine.matches(
                            input: input,
                            target: typingTasks[index].text,
                            ignoreCapitalization: draft.ignoreCapitalization,
                            requirePunctuation: draft.requirePunctuation
                        ))
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

    private var completionContent: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 38))
                .foregroundStyle(RISETheme.Colors.success)

            Text("Demo complete")
                .font(RISETheme.Typography.screenTitle)
                .foregroundStyle(RISETheme.Colors.text)

            Text("This is how the \(draft.type.title) will feel at wake-up. Nothing was recorded.")
                .font(RISETheme.Typography.body)
                .foregroundStyle(RISETheme.Colors.muted)

            RISEButton(title: "Back to Settings") { dismiss() }
                .padding(.top, RISETheme.Spacing.sm)
        }
    }

    /// Non-persisted preview of the configuration for the typing rules summary.
    private var configPreview: ChallengeConfig {
        ChallengeConfig(
            type: draft.type,
            difficulty: draft.difficulty,
            questionCount: draft.questionCount,
            operations: Array(draft.operations),
            timeLimitSeconds: draft.timeLimitSeconds,
            typingLength: draft.typingLength,
            customText: draft.customText,
            ignoreCapitalization: draft.ignoreCapitalization,
            requirePunctuation: draft.requirePunctuation,
            memoryMode: draft.memoryMode,
            memorySequenceLength: draft.memorySequenceLength
        )
    }

    private func prepare() {
        switch draft.type {
        case .math:
            mathQuestions = MathChallengeEngine.generate(
                count: draft.questionCount,
                difficulty: draft.difficulty,
                operations: Array(draft.operations)
            )
        case .typing:
            typingTasks = TypingChallengeEngine.tasks(
                count: draft.questionCount,
                length: draft.typingLength,
                customText: draft.customText,
                difficulty: draft.difficulty
            )
        case .memory:
            memoryTasks = MemoryChallengeEngine.tasks(
                count: draft.questionCount,
                mode: draft.memoryMode,
                length: draft.memorySequenceLength
            )
        }
    }

    private func evaluate(isCorrect: Bool) {
        if isCorrect {
            feedback = nil
            if index + 1 >= total {
                withAnimation { isComplete = true }
            } else {
                index += 1
            }
        } else {
            feedback = "That is not right yet. Try again."
        }
    }
}
