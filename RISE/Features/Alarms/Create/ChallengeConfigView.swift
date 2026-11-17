import SwiftUI

struct ChallengeConfigView: View {
    @Binding var draft: ChallengeDraft
    @State private var showsDemo = false

    var body: some View {
        Form {
            Section("Challenge") {
                ForEach(ChallengeType.allCases) { type in
                    ChallengeSelectionRow(
                        type: type,
                        isSelected: draft.type == type
                    ) {
                        draft.type = type
                    }
                }
            }

            Section("Difficulty") {
                Picker("Difficulty", selection: $draft.difficulty) {
                    ForEach(ChallengeDifficulty.allCases) { difficulty in
                        Text(difficulty.title).tag(difficulty)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Questions", selection: $draft.questionCount) {
                    ForEach([3, 5, 10], id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
            }

            if draft.type == .math {
                mathSection
            } else if draft.type == .typing {
                typingSection
            } else {
                memorySection
            }

            Section {
                Button {
                    showsDemo = true
                } label: {
                    Label("Try Demo", systemImage: "play.circle")
                }
            } footer: {
                Text("A demo does not record a wake-up or affect your streak.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(RISETheme.Colors.background)
        .listRowBackground(RISETheme.Colors.surface)
        .navigationTitle("Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsDemo) {
            ChallengeDemoView(draft: draft)
        }
    }

    // MARK: - Math

    private var mathSection: some View {
        Section {
            ForEach(MathOperation.allCases) { operation in
                Toggle(isOn: Binding(
                    get: { draft.operations.contains(operation) },
                    set: { isOn in
                        if isOn {
                            draft.operations.insert(operation)
                        } else if draft.operations.count > 1 {
                            draft.operations.remove(operation)
                        }
                    }
                )) {
                    Text("\(operation.title)  \(operation.symbol)")
                }
                .tint(RISETheme.Colors.primary)
            }

            Picker("Time limit", selection: $draft.timeLimitSeconds) {
                Text("Off").tag(0)
                Text("15 seconds").tag(15)
                Text("30 seconds").tag(30)
            }
        } header: {
            Text("Math options")
        } footer: {
            Text("Keep at least one operation selected. A time limit applies to each question.")
        }
    }

    // MARK: - Typing

    private var typingSection: some View {
        Section {
            Picker("Text length", selection: $draft.typingLength) {
                ForEach(TypingLength.allCases) { length in
                    Text(length.title).tag(length)
                }
            }

            TextField("Custom text (optional)", text: $draft.customText, axis: .vertical)
                .lineLimit(2...5)

            Toggle("Ignore capitalization", isOn: $draft.ignoreCapitalization)
                .tint(RISETheme.Colors.primary)

            Toggle("Punctuation and spaces must match", isOn: $draft.requirePunctuation)
                .tint(RISETheme.Colors.primary)
        } header: {
            Text("Typing options")
        } footer: {
            Text("With a custom text, the challenge uses your text instead of the built-in passages.")
        }
    }

    // MARK: - Memory

    private var memorySection: some View {
        Section {
            Picker("Mode", selection: $draft.memoryMode) {
                ForEach(MemoryMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }

            Stepper(
                "Sequence length: \(draft.memorySequenceLength)",
                value: $draft.memorySequenceLength,
                in: 3...10
            )
        } header: {
            Text("Memory options")
        } footer: {
            Text("Longer sequences are shown for slightly longer before they are hidden.")
        }
    }
}

private struct ChallengeSelectionRow: View {
    let type: ChallengeType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: RISETheme.Spacing.md) {
                Image(systemName: type.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(RISETheme.Colors.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(RISETheme.Typography.body.weight(.medium))
                        .foregroundStyle(RISETheme.Colors.text)

                    Text(type.summary)
                        .font(RISETheme.Typography.caption)
                        .foregroundStyle(RISETheme.Colors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: RISETheme.Spacing.sm)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(RISETheme.Colors.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
