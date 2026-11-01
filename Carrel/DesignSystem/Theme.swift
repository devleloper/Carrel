import SwiftUI
import UIKit

/// Reading Room colors: the single source for UIKit views and, through `Theme`, for SwiftUI.
/// Every interface color has a light and a dark value.
enum Palette {
    static let desk = UIColor(light: 0xE9E1D3, dark: 0x1B1815)
    static let surface = UIColor(light: 0xF8F3EA, dark: 0x25211D)
    static let primaryText = UIColor(light: 0x2B241E, dark: 0xEEE6DA)
    static let secondaryText = UIColor(light: 0x65584B, dark: 0xABA092)
    static let accent = UIColor(light: 0x2F6B4F, dark: 0x84BD9D)
    static let secondaryAccent = UIColor(light: 0x9A6A2C, dark: 0xD8A866)
    static let separator = UIColor(light: 0xDDD2C2, dark: 0x3A332C)
    static let destructive = UIColor(light: 0xB3261E, dark: 0xF28B82)
    static let pageShadow = UIColor(light: 0x3B2A1A, dark: 0x000000)
    /// Text printed on paper labels of covers. Covers are objects on the desk and do not change in dark mode.
    static let coverLabelText = UIColor(hex: 0x2B241E)
}

enum Theme {
    static let desk = Color(uiColor: Palette.desk)
    static let surface = Color(uiColor: Palette.surface)
    static let primaryText = Color(uiColor: Palette.primaryText)
    static let secondaryText = Color(uiColor: Palette.secondaryText)
    static let accent = Color(uiColor: Palette.accent)
    static let secondaryAccent = Color(uiColor: Palette.secondaryAccent)
    static let separator = Color(uiColor: Palette.separator)
    static let destructive = Color(uiColor: Palette.destructive)
    static let pageShadow = Color(uiColor: Palette.pageShadow)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Motion {
        static let chrome = Animation.spring(duration: 0.3, bounce: 0)
        static let morph = Animation.spring(duration: 0.4, bounce: 0.15)
        static let settle = Animation.spring(duration: 0.45, bounce: 0.1)
    }
}

extension Font {
    /// Titles use New York, the serif that carries the library-desk character of Reading Room.
    static func serifTitle(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif, weight: .semibold)
    }
}

extension UIColor {
    nonisolated convenience init(light: UInt32, dark: UInt32) {
        self.init { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    nonisolated convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// The color as 0xRRGGBB, used to store ink colors the user picks.
    var hexValue: UInt32 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let channel = { (value: CGFloat) in UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return channel(red) << 16 | channel(green) << 8 | channel(blue)
    }
}
