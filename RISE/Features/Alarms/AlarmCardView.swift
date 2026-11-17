import SwiftUI

struct AlarmCardView: View {
    let alarm: Alarm
    @Binding var isEnabled: Bool
    var onTap: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: RISETheme.Spacing.md) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: RISETheme.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: RISETheme.Spacing.sm) {
                        Text(alarm.timeLabel)
                            .font(.system(.title, design: .default).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(isEnabled ? RISETheme.Colors.text : RISETheme.Colors.muted)

                        Text(alarm.repeatSummary)
                            .font(RISETheme.Typography.caption)
                            .foregroundStyle(RISETheme.Colors.muted)
                    }

                    if !alarm.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(alarm.label)
                            .font(RISETheme.Typography.body)
                            .foregroundStyle(RISETheme.Colors.text)
                            .lineLimit(1)
                    }

                    HStack(spacing: RISETheme.Spacing.sm) {
                        Label(alarm.challengeType.title, systemImage: alarm.challengeType.symbol)
                        Text("·")
                        Text(alarm.soundName)
                    }
                    .font(RISETheme.Typography.caption)
                    .foregroundStyle(RISETheme.Colors.muted)
                    .lineLimit(1)

                    if let error = alarm.lastScheduleError {
                        Text(error)
                            .font(RISETheme.Typography.caption)
                            .foregroundStyle(RISETheme.Colors.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens alarm settings")
            .accessibilityAction(named: Text("Delete alarm"), onDelete)

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(RISETheme.Colors.primary)
                .accessibilityLabel("\(alarm.displayName), \(alarm.timeLabel)")
                .accessibilityValue(isEnabled ? "On" : "Off")
        }
        .padding(RISETheme.Spacing.md)
        .background(RISETheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous))
        .opacity(isEnabled ? 1 : 0.7)
        .contextMenu {
            Button("Delete Alarm", role: .destructive, action: onDelete)
        }
    }
}
