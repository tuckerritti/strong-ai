import SwiftUI

// MARK: - Color Helper

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Adaptive Color Tokens

extension Color {
    private static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    // MARK: Backgrounds

    static let appBackground = adaptive(light: 0xFFFFFF, dark: 0x0A0A0A)
    static let appSurface = adaptive(light: 0xF5F5F5, dark: 0x1A1A1A)
    static let appSurfaceAlt = adaptive(
        light: UIColor(red: 0xF0/255, green: 0xF0/255, blue: 0xF0/255, alpha: 1),
        dark: UIColor(white: 1, alpha: 0.08)
    )
    static let appSurfaceSubtle = adaptive(
        light: UIColor(red: 0xFA/255, green: 0xFA/255, blue: 0xFA/255, alpha: 1),
        dark: UIColor(white: 1, alpha: 0.05)
    )

    // MARK: Text

    static let textPrimary = adaptive(light: 0x0A0A0A, dark: 0xF5F5F5)
    static let textHeading = adaptive(light: 0x1A1A1A, dark: 0xF5F5F5)
    static let textSecondary = adaptive(
        light: UIColor(white: 0, alpha: 0.55),
        dark: UIColor(white: 1, alpha: 0.70)
    )
    static let textTertiary = adaptive(
        light: UIColor(white: 0, alpha: 0.40),
        dark: UIColor(white: 1, alpha: 0.50)
    )
    static let textQuaternary = adaptive(
        light: UIColor(white: 0, alpha: 0.25),
        dark: UIColor(white: 1, alpha: 0.30)
    )
    static let textMuted = adaptive(
        light: UIColor(red: 0x99/255, green: 0x99/255, blue: 0x99/255, alpha: 1),
        dark: UIColor(white: 1, alpha: 0.30)
    )
    static let textBody = adaptive(
        light: UIColor(red: 0x44/255, green: 0x44/255, blue: 0x44/255, alpha: 1),
        dark: UIColor(white: 1, alpha: 0.70)
    )

    // MARK: Accent

    static let accent = Color(hex: 0x34C759)
    static let accentAlt = Color(hex: 0x3CB371)
    static let accentSurface = adaptive(
        light: UIColor(red: 0xE8/255, green: 0xF5/255, blue: 0xE9/255, alpha: 1),
        dark: UIColor(red: 0x34/255, green: 0xC7/255, blue: 0x59/255, alpha: 0.14)
    )

    // MARK: Buttons

    static let buttonPrimary = adaptive(light: 0x0A0A0A, dark: 0xFFFFFF)
    static let buttonPrimaryText = adaptive(light: 0xFFFFFF, dark: 0x0A0A0A)

    // MARK: Overlays

    static let scrim = Color.black.opacity(0.20)
    static let cardShadow = Color.black.opacity(0.15)

    // MARK: Dividers

    static let divider = adaptive(
        light: UIColor(white: 0, alpha: 0.10),
        dark: UIColor(white: 1, alpha: 0.08)
    )

    // MARK: Insight Callout

    static let insightIcon = adaptive(
        light: UIColor(red: 0.18, green: 0.39, blue: 0.78, alpha: 1),
        dark: UIColor(red: 0.55, green: 0.71, blue: 0.94, alpha: 0.65)
    )
    static let insightText = adaptive(
        light: UIColor(red: 0.12, green: 0.24, blue: 0.47, alpha: 0.6),
        dark: UIColor(red: 0.55, green: 0.71, blue: 0.94, alpha: 0.65)
    )
    static let insightBg = adaptive(
        light: UIColor(red: 0.18, green: 0.39, blue: 0.78, alpha: 0.08),
        dark: UIColor(red: 0.18, green: 0.39, blue: 0.78, alpha: 0.12)
    )

    // MARK: Surfaces

    static let restTimerBg = adaptive(light: 0x0A0A0A, dark: 0x222222)
    static let chatDrawerBg = adaptive(light: 0xFFFFFF, dark: 0x1A1A1A)
    static let chatBubbleUser = adaptive(
        light: UIColor(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255, alpha: 1),
        dark: UIColor(red: 0x34/255, green: 0xC7/255, blue: 0x59/255, alpha: 1)
    )
}
