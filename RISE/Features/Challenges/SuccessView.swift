import SwiftUI

struct SuccessView: View {
    let result: ChallengeResult
    let streak: Int
    var isPreview: Bool = false
    let onDone: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: RISETheme.Spacing.lg) {
            Spacer(minLength: RISETheme.Spacing.xl)

            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(RISETheme.Colors.primary)
                .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.85)
                .opacity(hasAppeared || reduceMotion ? 1 : 0)
                .accessibilityHidden(true)

            VStack(spacing: RISETheme.Spacing.sm) {
                Text(isPreview ? "Demo complete." : "You're up.")
                    .font(.system(.largeTitle, design: .default).weight(.bold))
                    .foregroundStyle(RISETheme.Colors.text)

                Text(isPreview
                     ? "This was a preview. Nothing was recorded."
                     : "You completed your morning challenge.")
                    .font(RISETheme.Typography.body)
                    .foregroundStyle(RISETheme.Colors.muted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: RISETheme.Spacing.sm) {
                summaryRow(title: "Wake-up time", value: result.wakeUpTimeLabel)
                Divider().overlay(RISETheme.Colors.elevated)
                summaryRow(title: "Challenge", value: "\(result.correct) / \(result.total)")
                Divider().overlay(RISETheme.Colors.elevated)
                summaryRow(
                    title: isPreview ? "Records" : "Current streak",
                    value: isPreview ? "Not saved" : (streak == 1 ? "1 day" : "\(streak) days")
                )
            }
            .riseCard(padding: RISETheme.Spacing.lg)

            Spacer()

            RISEButton(title: isPreview ? "Done" : "View My Progress", icon: "chart.bar.xaxis", action: onDone)
        }
        .padding(RISETheme.Layout.screenPadding)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                hasAppeared = true
            }
            RiseHaptics.success(enabled: true)
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(RISETheme.Typography.body)
                .foregroundStyle(RISETheme.Colors.muted)

            Spacer()

            Text(value)
                .font(RISETheme.Typography.body.weight(.semibold))
                .foregroundStyle(RISETheme.Colors.text)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
