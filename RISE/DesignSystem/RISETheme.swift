import SwiftUI

/// Design tokens from the RISE. design system (section 3 + 8 of the design document).
enum RISETheme {

    enum Colors {
        static let background = Color(hex: "090B14")
        static let surface = Color(hex: "151927")
        static let elevated = Color(hex: "202538")
        static let primary = Color(hex: "A99AFF")
        static let secondary = Color(hex: "7771C8")
        static let text = Color(hex: "F5F5FA")
        static let muted = Color(hex: "9297AA")
        static let success = Color(hex: "73D6A0")
        static let danger = Color(hex: "FF727F")

        /// Text drawn on top of `primary` fills.
        static let onPrimary = Color(hex: "12101F")
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Layout {
        static let screenPadding: CGFloat = 20
        static let primaryButtonHeight: CGFloat = 56
        static let minimumTouchTarget: CGFloat = 44
    }

    enum Typography {
        /// Big clock / key time displays. Scales with Dynamic Type.
        static let display = Font.system(.largeTitle, design: .default).weight(.bold)
        static let screenTitle = Font.system(.title, design: .default).weight(.semibold)
        static let sectionTitle = Font.system(.title3, design: .default).weight(.semibold)
        static let cardTitle = Font.system(.headline, design: .default)
        static let body = Font.system(.body, design: .default)
        static let caption = Font.system(.footnote, design: .default)
        static let button = Font.system(.headline, design: .default)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Shared modifiers

struct RISEScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RISETheme.Colors.background.ignoresSafeArea())
    }
}

struct RISECardStyle: ViewModifier {
    var padding: CGFloat = RISETheme.Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RISETheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: RISETheme.Radius.medium, style: .continuous))
    }
}

extension View {
    func riseScreenBackground() -> some View {
        modifier(RISEScreenBackground())
    }

    func riseCard(padding: CGFloat = RISETheme.Spacing.md) -> some View {
        modifier(RISECardStyle(padding: padding))
    }
}
