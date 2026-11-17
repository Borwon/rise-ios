import SwiftUI

/// Primary / secondary action button from the RISE. component library.
struct RISEButton: View {
    enum Style: Equatable { case primary, secondary, destructive }

    let title: String
    var icon: String?
    var style: Style = .primary
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.isEnabled) private var environmentEnabled

    private var effectiveEnabled: Bool { isEnabled && environmentEnabled && !isLoading }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foreground)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                }

                Text(title)
                    .font(RISETheme.Typography.button)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: RISETheme.Layout.primaryButtonHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous)
                        .stroke(RISETheme.Colors.elevated, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!effectiveEnabled)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isLoading ? [.isButton, .updatesFrequently] : .isButton)
    }

    private var foreground: Color {
        guard effectiveEnabled else { return RISETheme.Colors.muted }
        switch style {
        case .primary: return RISETheme.Colors.onPrimary
        case .secondary: return RISETheme.Colors.text
        case .destructive: return RISETheme.Colors.danger
        }
    }

    /// Disabled buttons get their own surface and text colours rather than a
    /// blanket opacity, which made the label unreadable on the dark background.
    @ViewBuilder
    private var background: some View {
        if !effectiveEnabled {
            RISETheme.Colors.elevated
        } else {
            switch style {
            case .primary:
                RISETheme.Colors.primary
            case .secondary:
                RISETheme.Colors.surface
            case .destructive:
                RISETheme.Colors.danger.opacity(0.12)
            }
        }
    }
}

#Preview {
    VStack(spacing: RISETheme.Spacing.md) {
        RISEButton(title: "Create Alarm", icon: "plus") {}
        RISEButton(title: "Secondary", style: .secondary) {}
        RISEButton(title: "Delete Alarm", style: .destructive) {}
        RISEButton(title: "Saving", isLoading: true) {}
        RISEButton(title: "Disabled") {}.disabled(true)
    }
    .padding()
    .riseScreenBackground()
}
