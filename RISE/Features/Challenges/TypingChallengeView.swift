import SwiftUI

struct TypingChallengeView: View {
    let task: TypingTask
    let config: ChallengeConfig
    let onSubmit: (String) -> Void

    @State private var input = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: RISETheme.Spacing.sm) {
                Text("Type this exactly")
                    .font(RISETheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(RISETheme.Colors.muted)

                Text(task.text)
                    .font(.system(.title3, design: .default).weight(.medium))
                    .foregroundStyle(RISETheme.Colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Target text: \(task.text)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .riseCard(padding: RISETheme.Spacing.lg)

            VStack(alignment: .leading, spacing: RISETheme.Spacing.sm) {
                TextField("Type here", text: $input, axis: .vertical)
                    .font(RISETheme.Typography.body)
                    .foregroundStyle(RISETheme.Colors.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .lineLimit(3...6)
                    .padding(RISETheme.Spacing.md)
                    .background(RISETheme.Colors.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous))
                    .accessibilityLabel("Your typed answer")

                Text(rulesSummary)
                    .font(RISETheme.Typography.caption)
                    .foregroundStyle(RISETheme.Colors.muted)
            }

            RISEButton(title: "Submit Text", isEnabled: !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                let value = input
                input = ""
                onSubmit(value)
            }
        }
        .onAppear { isFocused = true }
    }

    private var rulesSummary: String {
        var rules: [String] = []
        rules.append(config.ignoreCapitalization ? "Capitalization ignored" : "Case sensitive")
        rules.append(config.requirePunctuation ? "Punctuation required" : "Punctuation optional")
        return rules.joined(separator: " · ")
    }
}
