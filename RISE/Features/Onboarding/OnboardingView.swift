import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let headline: String
        let body: String
        let symbol: String
    }

    private let pages: [Page] = [
        Page(
            headline: "Wake up differently.",
            body: "Start your day with a smarter routine.",
            symbol: "alarm.waves.left.and.right"
        ),
        Page(
            headline: "Challenge yourself.",
            body: "Solve, think, and complete your morning mission.",
            symbol: "brain.head.profile"
        ),
        Page(
            headline: "Make it yours.",
            body: "Choose your favorite sounds and customize your alarms.",
            symbol: "waveform"
        )
    ]

    var body: some View {
        VStack(spacing: RISETheme.Spacing.lg) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageContent(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? RISETheme.Colors.primary : RISETheme.Colors.elevated)
                        .frame(width: index == page ? 22 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: page)
                }
            }
            .accessibilityHidden(true)

            RISEButton(title: page == pages.count - 1 ? "Get Started" : "Continue") {
                if page == pages.count - 1 {
                    onFinish()
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                }
            }

            Button("Skip") { onFinish() }
                .font(RISETheme.Typography.caption)
                .foregroundStyle(RISETheme.Colors.muted)
                .frame(minHeight: RISETheme.Layout.minimumTouchTarget)
        }
        .padding(RISETheme.Layout.screenPadding)
        .riseScreenBackground()
        .preferredColorScheme(.dark)
    }

    private func pageContent(_ page: Page) -> some View {
        VStack(spacing: RISETheme.Spacing.lg) {
            Spacer()

            Image(systemName: page.symbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(RISETheme.Colors.primary)
                .accessibilityHidden(true)

            VStack(spacing: RISETheme.Spacing.sm) {
                Text(page.headline)
                    .font(RISETheme.Typography.screenTitle)
                    .foregroundStyle(RISETheme.Colors.text)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(RISETheme.Typography.body)
                    .foregroundStyle(RISETheme.Colors.muted)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView {}
}
