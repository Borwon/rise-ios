import SwiftUI

struct MathChallengeView: View {
    let question: MathQuestion
    let onAnswer: (Int) -> Void

    @State private var input = ""

    private var isSubmitEnabled: Bool { !input.isEmpty }

    var body: some View {
        VStack(spacing: RISETheme.Spacing.md) {
            Text(question.prompt)
                .font(.system(size: 44, weight: .bold, design: .default))
                .monospacedDigit()
                .foregroundStyle(RISETheme.Colors.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("What is \(question.prompt)?")
                .riseCard(padding: RISETheme.Spacing.md)

            Text(input.isEmpty ? "–" : input)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(input.isEmpty ? RISETheme.Colors.muted : RISETheme.Colors.text)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(RISETheme.Colors.elevated)
                .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous))
                .accessibilityLabel("Your answer")
                .accessibilityValue(input.isEmpty ? "Empty" : input)

            NumberPad(
                isEnabled: input.count < 6,
                onDigit: { digit in
                    guard input.count < 6 else { return }
                    input.append(String(digit))
                },
                onDelete: {
                    if !input.isEmpty { input.removeLast() }
                }
            )

            RISEButton(title: "Submit Answer", isEnabled: isSubmitEnabled) {
                guard let value = Int(input) else { return }
                input = ""
                onAnswer(value)
            }
        }
    }
}

#Preview {
    MathChallengeView(question: MathQuestion(prompt: "24 × 3 − 12", answer: 60)) { _ in }
        .padding()
        .riseScreenBackground()
}
