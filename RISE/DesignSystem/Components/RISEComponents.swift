import SwiftUI

// MARK: - Section header

struct RISESectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(RISETheme.Typography.sectionTitle)
                .foregroundStyle(RISETheme.Colors.text)

            Spacer(minLength: RISETheme.Spacing.sm)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(RISETheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(RISETheme.Colors.primary)
                    .frame(minHeight: RISETheme.Layout.minimumTouchTarget)
            }
        }
    }
}

// MARK: - Empty state

struct RISEEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: RISETheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(RISETheme.Colors.primary)
                .accessibilityHidden(true)

            Text(title)
                .font(RISETheme.Typography.sectionTitle)
                .foregroundStyle(RISETheme.Colors.text)
                .multilineTextAlignment(.center)

            Text(message)
                .font(RISETheme.Typography.body)
                .foregroundStyle(RISETheme.Colors.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                RISEButton(title: actionTitle, action: action)
                    .padding(.top, RISETheme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(RISETheme.Spacing.lg)
        .riseCard(padding: RISETheme.Spacing.lg)
    }
}

// MARK: - Stat card

struct StatCard: View {
    let title: String
    let value: String
    let caption: String?
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: RISETheme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RISETheme.Colors.primary)
                .accessibilityHidden(true)

            Text(value)
                .font(RISETheme.Typography.screenTitle)
                .foregroundStyle(RISETheme.Colors.text)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title)
                .font(RISETheme.Typography.caption)
                .foregroundStyle(RISETheme.Colors.muted)

            if let caption {
                Text(caption)
                    .font(RISETheme.Typography.caption)
                    .foregroundStyle(RISETheme.Colors.muted.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .riseCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title): \(value)\(caption.map { ", \($0)" } ?? "")"))
    }
}

// MARK: - Progress indicator

struct RISEProgressIndicator: View {
    let completed: Int
    let total: Int

    var body: some View {
        VStack(spacing: RISETheme.Spacing.sm) {
            HStack(spacing: 6) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < completed ? RISETheme.Colors.primary : RISETheme.Colors.elevated)
                        .frame(height: 6)
                }
            }

            Text("\(min(completed, total)) / \(total)")
                .font(RISETheme.Typography.caption.weight(.semibold))
                .foregroundStyle(RISETheme.Colors.muted)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress \(completed) of \(total)"))
    }
}

// MARK: - Sound row

struct SoundPickerRow: View {
    let name: String
    let metadata: String
    let isSelected: Bool
    let isPlaying: Bool
    let onPreview: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: RISETheme.Spacing.md) {
            Button(action: onPreview) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RISETheme.Colors.primary)
                    .frame(width: 40, height: 40)
                    .background(RISETheme.Colors.elevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isPlaying ? "Stop preview of \(name)" : "Preview \(name)"))

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(RISETheme.Typography.body.weight(.medium))
                        .foregroundStyle(RISETheme.Colors.text)

                    Text(metadata)
                        .font(RISETheme.Typography.caption)
                        .foregroundStyle(RISETheme.Colors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(name))
            .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(RISETheme.Colors.primary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, RISETheme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

// MARK: - Toast / inline feedback

struct RISEInlineMessage: View {
    enum Kind: Equatable { case info, success, error }

    let text: String
    var kind: Kind = .info

    private var color: Color {
        switch kind {
        case .info: RISETheme.Colors.muted
        case .success: RISETheme.Colors.success
        case .error: RISETheme.Colors.danger
        }
    }

    private var symbol: String {
        switch kind {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .error: "exclamationmark.triangle"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: RISETheme.Spacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(text)
                .font(RISETheme.Typography.caption)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RISETheme.Spacing.md)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
