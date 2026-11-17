import SwiftUI

struct MemoryChallengeView: View {
    let task: MemoryTask
    let onSubmit: ([Int]) -> Void

    private enum Phase { case showing, entering }

    @State private var phase: Phase = .showing
    @State private var secondsRemaining = 0
    @State private var entered: [Int] = []

    private var length: Int { task.sequence.count }

    private var colorPalette: [Color] {
        [
            RISETheme.Colors.primary,
            RISETheme.Colors.success,
            RISETheme.Colors.danger,
            RISETheme.Colors.secondary
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
            switch phase {
            case .showing: showingContent
            case .entering: enteringContent
            }
        }
        .onAppear(perform: beginShowing)
    }

    // MARK: - Memorize phase

    private var showingContent: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
            Text("Memorize this sequence")
                .font(RISETheme.Typography.sectionTitle)
                .foregroundStyle(RISETheme.Colors.text)

            sequenceDisplay

            Text("Hiding in \(secondsRemaining)s")
                .font(RISETheme.Typography.caption.weight(.semibold))
                .foregroundStyle(RISETheme.Colors.muted)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var sequenceDisplay: some View {
        switch task.mode {
        case .numbers:
            HStack(spacing: RISETheme.Spacing.sm) {
                ForEach(Array(task.sequence.enumerated()), id: \.offset) { _, value in
                    Text("\(value)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(RISETheme.Colors.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(RISETheme.Colors.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.small, style: .continuous))
                }
            }
            .accessibilityLabel("Sequence \(task.sequence.map(String.init).joined(separator: ", "))")

        case .colors:
            HStack(spacing: RISETheme.Spacing.sm) {
                ForEach(Array(task.sequence.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: RISETheme.Radius.small, style: .continuous)
                        .fill(colorPalette[value % colorPalette.count])
                        .frame(height: 64)
                }
            }
            .accessibilityLabel("Color sequence of \(length) colors")

        case .patterns:
            patternGrid(highlighted: Set(task.sequence), showsOrder: false)
        }
    }

    // MARK: - Recall phase

    private var enteringContent: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
            Text("Reproduce the sequence")
                .font(RISETheme.Typography.sectionTitle)
                .foregroundStyle(RISETheme.Colors.text)

            Text("\(entered.count) / \(length) entered")
                .font(RISETheme.Typography.caption.weight(.semibold))
                .foregroundStyle(RISETheme.Colors.muted)
                .monospacedDigit()

            switch task.mode {
            case .numbers:
                Text(entered.map(String.init).joined())
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(RISETheme.Colors.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(RISETheme.Colors.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous))
                    .accessibilityLabel("Your sequence")
                    .accessibilityValue(entered.map(String.init).joined(separator: " "))

                NumberPad(
                    isEnabled: entered.count < length,
                    onDigit: { append($0) },
                    onDelete: { if !entered.isEmpty { entered.removeLast() } }
                )

            case .colors:
                HStack(spacing: RISETheme.Spacing.md) {
                    ForEach(0..<colorPalette.count, id: \.self) { index in
                        Button {
                            append(index)
                        } label: {
                            RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous)
                                .fill(colorPalette[index])
                                .frame(height: 88)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(index + 1)")
                    }
                }
                .disabled(entered.count >= length)
                .opacity(entered.count >= length ? 0.5 : 1)

            case .patterns:
                patternGrid(highlighted: [], onTap: { append($0) })
                    .disabled(entered.count >= length)
            }

            RISEButton(title: "Submit Sequence", isEnabled: entered.count == length) {
                onSubmit(entered)
            }
        }
    }

    // MARK: - Pattern grid

    private func patternGrid(
        highlighted: Set<Int>,
        showsOrder: Bool = true,
        onTap: ((Int) -> Void)? = nil
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(0..<9, id: \.self) { index in
                Button {
                    onTap?(index)
                } label: {
                    RoundedRectangle(cornerRadius: RISETheme.Radius.small, style: .continuous)
                        .fill(highlighted.contains(index) ? RISETheme.Colors.primary : RISETheme.Colors.elevated)
                        .frame(height: 64)
                }
                .buttonStyle(.plain)
                .disabled(onTap == nil)
                .accessibilityLabel("Cell \(index + 1)")
                .accessibilityValue(highlighted.contains(index) ? "Highlighted" : "Empty")
            }
        }
    }

    // MARK: - Actions

    private func append(_ value: Int) {
        guard entered.count < length else { return }
        entered.append(value)
        RiseHaptics.tap(enabled: true)

        if entered.count == length {
            let answer = entered
            onSubmit(answer)
        }
    }

    private func beginShowing() {
        let duration = min(max(length + 1, 3), 8)
        secondsRemaining = duration

        Task {
            for remaining in stride(from: duration, to: 0, by: -1) {
                await MainActor.run { secondsRemaining = remaining }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .entering
                }
            }
        }
    }
}

