import SwiftUI
import SwiftData

struct AlarmEditorView: View {
    let existing: Alarm?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SoundAsset.createdAt) private var sounds: [SoundAsset]

    @State private var draft: AlarmDraft
    @State private var viewModel = AlarmsViewModel()
    @State private var isSaving = false
    @State private var didAttemptSave = false

    init(existing: Alarm? = nil) {
        self.existing = existing
        _draft = State(initialValue: AlarmDraft(alarm: existing))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = viewModel.errorMessage {
                    Section {
                        RISEInlineMessage(text: error, kind: .error)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    DatePicker(
                        "Time",
                        selection: $draft.time,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .environment(\.colorScheme, .dark)

                    Toggle("Alarm On", isOn: $draft.isEnabled)
                        .tint(RISETheme.Colors.primary)
                } header: {
                    Text("Alarm")
                }

                Section {
                    WeekdayPicker(selection: $draft.weekdays)
                } header: {
                    Text("Repeat")
                } footer: {
                    Text(draft.weekdays.isEmpty ? "Rings once at the next occurrence." : repeatSummary)
                        .font(RISETheme.Typography.caption)
                }

                Section("Label") {
                    TextField("Optional name", text: $draft.label)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Wake-up Challenge") {
                    NavigationLink {
                        ChallengeConfigView(draft: $draft.challenge)
                    } label: {
                        HStack(spacing: RISETheme.Spacing.md) {
                            Image(systemName: draft.challenge.type.symbol)
                                .foregroundStyle(RISETheme.Colors.primary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.challenge.type.title)
                                Text("\(draft.challenge.difficulty.title) · \(draft.challenge.questionCount) questions")
                                    .font(RISETheme.Typography.caption)
                                    .foregroundStyle(RISETheme.Colors.muted)
                            }
                        }
                    }
                }

                Section("Sound") {
                    NavigationLink {
                        SoundLibraryView(
                            selectedSoundName: $draft.soundName,
                            selectedSoundID: $draft.soundID
                        )
                    } label: {
                        HStack {
                            Text("Alarm Sound")
                            Spacer()
                            Text(draft.soundName)
                                .foregroundStyle(RISETheme.Colors.muted)
                        }
                    }
                }

                Section("Snooze") {
                    Picker("Snooze duration", selection: $draft.snoozeMinutes) {
                        ForEach([1, 2, 5, 10, 15, 20, 30], id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                }

                if didAttemptSave, !draft.isValid {
                    Section {
                        RISEInlineMessage(text: "Add at least one challenge question before saving.", kind: .error)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RISETheme.Colors.background)
            .listRowBackground(RISETheme.Colors.surface)
            .navigationTitle(draft.isNew ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .task { await viewModel.refreshPermission() }
        }
        .preferredColorScheme(.dark)
    }

    private var hasUnsavedChanges: Bool {
        !isSaving && draft.id == nil && !draft.label.isEmpty
    }

    private var repeatSummary: String {
        draft.weekdays
            .sorted()
            .compactMap { Calendar.current.weekdaySymbols[safe: $0 - 1] }
            .joined(separator: ", ")
    }

    private func save() async {
        didAttemptSave = true
        guard draft.isValid else { return }

        isSaving = true
        let success = await viewModel.save(draft, existing: existing, context: modelContext)
        isSaving = false

        if success {
            dismiss()
        }
    }
}

// MARK: - Weekday selector

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let isSelected = selection.contains(day)
                Button {
                    if isSelected { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(shortSymbol(for: day))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? RISETheme.Colors.onPrimary : RISETheme.Colors.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: RISETheme.Layout.minimumTouchTarget)
                        .background(isSelected ? RISETheme.Colors.primary : RISETheme.Colors.elevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(longSymbol(for: day)))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, RISETheme.Spacing.xs)
    }

    private func shortSymbol(for day: Int) -> String {
        Calendar.current.veryShortWeekdaySymbols[safe: day - 1] ?? "?"
    }

    private func longSymbol(for day: Int) -> String {
        Calendar.current.weekdaySymbols[safe: day - 1] ?? "Day \(day)"
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
