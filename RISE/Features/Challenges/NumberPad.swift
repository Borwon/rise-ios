import SwiftUI
import UIKit

/// Large, high-contrast keypad used by the wake-up challenge screens.
struct NumberPad: View {
    var isEnabled: Bool = true
    let onDigit: (Int) -> Void
    let onDelete: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...9, id: \.self) { digit in
                key(digit)
            }

            Button(action: onDelete) {
                Image(systemName: "delete.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(RISETheme.Colors.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(RISETheme.Colors.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.small, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete last digit")

            key(0)
            Color.clear.frame(height: 56)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func key(_ digit: Int) -> some View {
        Button {
            onDigit(digit)
        } label: {
            Text("\(digit)")
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .foregroundStyle(RISETheme.Colors.text)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RISETheme.Colors.elevated)
                .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.small, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: RISETheme.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(digit)")
    }
}

enum RiseHaptics {
    static func success(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func failure(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func tap(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
